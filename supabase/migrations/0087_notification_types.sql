insert into private.settings (key, value, description) values
  ('notifications.mention_room_max', '5', 'Maksimal pengguna yang diberi notifikasi mention per pesan room saham'),
  ('notifications.followed_post_batch', '5000',
   'Jumlah pengikut yang diberi notifikasi postingan baru per putaran job social-followed-posts'),
  ('notifications.digest_lookback_hours', '24',
   'Rentang ringkasan saham pantauan pertama (jam) bila belum ada ringkasan sebelumnya')
on conflict (key) do nothing;

alter table public.notifications drop constraint notifications_type;
alter table public.notifications add constraint notifications_type
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation'));

alter table private.notification_prefs drop constraint notification_prefs_type_check;
alter table private.notification_prefs add constraint notification_prefs_type_check
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation',
                  'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'));

create or replace function private.notification_pref_types()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
               'followed_post', 'watchlist_digest', 'moderation',
               'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'];
$$;

create or replace function private.notification_pref_type(p_kind text, p_category text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_kind in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                    'followed_post', 'watchlist_digest', 'moderation') then p_kind
    when not starts_with(p_kind, 'olt.') then null
    when p_category = 'promo' then 'olt.promo'
    when starts_with(p_kind, 'olt.trade') or starts_with(p_kind, 'olt.order') then 'olt.trade'
    when starts_with(p_kind, 'olt.deposit') or starts_with(p_kind, 'olt.withdrawal') or starts_with(p_kind, 'olt.rdn')
      then 'olt.funds'
    when starts_with(p_kind, 'olt.price_alert') or starts_with(p_kind, 'olt.ipo')
         or starts_with(p_kind, 'olt.corporate_action') then 'olt.market'
    else 'olt.info'
  end;
$$;

create or replace function private.notification_pref_default_push(p_type text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_type is null or p_type not in ('olt.promo', 'followed_post');
$$;

create or replace function private.notification_pref_in_app_locked(p_type text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_type = 'moderation', false);
$$;

create or replace function private.push_allowed(p_profile uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select np.push from private.notification_prefs np
                   where np.user_id = p_profile and np.type = private.notification_pref_type(p_kind)),
                  private.notification_pref_default_push(private.notification_pref_type(p_kind)));
$$;

create or replace function private.notifications_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pref private.notification_prefs;
  v_id   uuid;
begin
  if new.type = 'announcement' and new.payload ->> 'source' = 'olt' then
    if new.payload ->> 'category' = 'important' then
      return new;
    end if;
    select * into v_pref from private.notification_prefs np
    where np.user_id = new.user_id
      and np.type = private.notification_pref_type(new.payload ->> 'kind', new.payload ->> 'category');
    if found and not v_pref.in_app then
      return null;
    end if;
    return new;
  end if;

  if not (new.type = 'message' and new.payload ->> 'room_type' = 'support')
     and not private.notification_pref_in_app_locked(new.type) then
    select * into v_pref from private.notification_prefs np
    where np.user_id = new.user_id and np.type = private.notification_pref_type(new.type);
    if found and not v_pref.in_app then
      if v_pref.push then
        perform private.notification_push(new);
      end if;
      return null;
    end if;
  end if;

  if new.type in ('like', 'follow') and new.actor_id is not null then
    select n.id into v_id
    from public.notifications n
    where n.user_id = new.user_id
      and n.type = new.type
      and n.read_at is null
      and (new.type = 'follow' or n.group_key = new.group_key)
      and coalesce((select min(a.created_at) from private.notification_actors a where a.notification_id = n.id),
                   n.created_at)
          > now() - make_interval(mins => private.setting_num('notifications.aggregate_minutes', 60)::integer)
    order by n.created_at desc
    limit 1
    for update;
    if v_id is not null then
      update public.notifications
         set actor_id = new.actor_id, payload = new.payload, event_count = event_count + 1, created_at = now()
       where id = v_id;
      return null;
    end if;
    if new.group_key is not null then
      update public.notifications
         set group_key = null
       where user_id = new.user_id and group_key = new.group_key and read_at is null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.notifications_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type = 'announcement' and new.payload ->> 'source' = 'olt' then
    return null;
  end if;
  if tg_op = 'INSERT'
     or (new.event_count > old.event_count and new.read_at is null
         and new.type not in ('like', 'follow', 'followed_post')) then
    perform private.notification_push(new);
  end if;
  return null;
end;
$$;

create or replace function private.notification_push(n public.notifications)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name     text;
  v_username text;
  v_id       text;
  v_en       text;
  v_others   integer := n.event_count - 1;
  v_snippet  text := coalesce(n.payload ->> 'snippet', '');
  v_snip_en  text;
  v_room     text := nullif(btrim(coalesce(n.payload ->> 'room_name', '')), '');
  v_place    text;
  v_codes    text;
  v_more     integer;
  v_what_id  text;
  v_what_en  text;
  v_title    jsonb;
  v_body     jsonb;
begin
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text), p.username::text into v_name, v_username
  from public.profiles p where p.id = n.actor_id;
  v_id := coalesce(v_name, 'Seseorang');
  v_en := coalesce(v_name, 'Someone');
  v_snip_en := case when v_snippet = '[lampiran]' then '[attachment]' else v_snippet end;
  v_body := jsonb_build_object('id', v_snippet, 'en', v_snip_en);

  case n.type
    when 'reply' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya membalas postingan Anda', v_id, v_others),
                                'en', format('%s and %s others replied to your post', v_en, v_others))
        else jsonb_build_object('id', format('%s membalas Anda', v_id), 'en', format('%s replied to you', v_en)) end;
    when 'mention' then
      if n.payload ? 'room_id' then
        v_place := coalesce('$' || nullif(n.payload ->> 'stock_code', ''), v_room, 'room saham');
        v_title := jsonb_build_object('id', format('%s menyebut Anda di %s', v_id, v_place),
                                      'en', format('%s mentioned you in %s', v_en, v_place));
      else
        v_title := jsonb_build_object('id', format('%s menyebut Anda', v_id), 'en', format('%s mentioned you', v_en));
      end if;
    when 'like' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya menyukai konten Anda', v_id, v_others),
                                'en', format('%s and %s others liked your content', v_en, v_others))
        else jsonb_build_object('id', format('%s menyukai konten Anda', v_id),
                                'en', format('%s liked your content', v_en)) end;
    when 'follow' then
      v_title := jsonb_build_object('id', format('%s mulai mengikuti Anda', v_id),
                                    'en', format('%s started following you', v_en));
      v_body := '""';
    when 'message' then
      if n.payload ->> 'room_type' = 'support' then
        v_title := to_jsonb(coalesce(v_room, cs.setting('brand.support_name') #>> '{}', 'Customer Service'));
      elsif n.payload ->> 'room_type' = 'group' then
        v_title := to_jsonb(coalesce(v_room, v_id));
        v_body := jsonb_build_object('id', format('%s: %s', v_id, v_snippet), 'en', format('%s: %s', v_en, v_snip_en));
      elsif n.event_count > 1 then
        v_title := jsonb_build_object('id', format('%s · %s pesan baru', v_id, n.event_count),
                                      'en', format('%s · %s new messages', v_en, n.event_count));
      else
        v_title := jsonb_build_object('id', v_id, 'en', v_en);
      end if;
    when 'announcement' then
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          jsonb_build_object('id', format('%s membuat pengumuman', v_id),
                                             'en', format('%s posted an announcement', v_en)));
      v_body := to_jsonb(coalesce(n.payload ->> 'body', ''));
    when 'followed_post' then
      v_title := jsonb_build_object('id', format('%s membuat postingan baru', v_id),
                                    'en', format('%s shared a new post', v_en));
    when 'watchlist_digest' then
      select string_agg('$' || t.code, ', ' order by t.ord) into v_codes
      from jsonb_array_elements_text(coalesce(n.payload -> 'stocks', '[]')) with ordinality as t(code, ord);
      v_more := greatest(coalesce((n.payload ->> 'stock_count')::integer, 0)
                         - jsonb_array_length(coalesce(n.payload -> 'stocks', '[]')), 0);
      v_title := '{"id": "Ringkasan saham pantauan", "en": "Watchlist digest"}';
      v_body := jsonb_build_object(
        'id', format('%s postingan baru tentang %s', n.payload ->> 'post_count', coalesce(v_codes, 'saham pantauan'))
              || case when v_more > 0 then format(', dan %s saham lainnya', v_more) else '' end,
        'en', format('%s new posts about %s', n.payload ->> 'post_count', coalesce(v_codes, 'your watchlist'))
              || case when v_more > 0 then format(' and %s more', v_more) else '' end);
    when 'moderation' then
      v_what_id := case n.payload ->> 'target_type' when 'post' then 'Postingan' when 'comment' then 'Komentar' else 'Pesan' end;
      v_what_en := case n.payload ->> 'target_type' when 'post' then 'post' when 'comment' then 'comment' else 'message' end;
      v_title := case when n.payload ->> 'state' = 'removed'
        then jsonb_build_object('id', v_what_id || ' Anda dihapus moderator',
                                'en', format('Your %s was removed by a moderator', v_what_en))
        else jsonb_build_object('id', v_what_id || ' Anda disembunyikan moderator',
                                'en', format('Your %s was hidden by a moderator', v_what_en)) end;
      v_body := case when coalesce((n.payload ->> 'appealable')::boolean, false)
        then '{"id": "Ketuk untuk melihat detail dan mengajukan banding", "en": "Tap to see details and appeal"}'::jsonb
        else '{"id": "Ketuk untuk melihat detail", "en": "Tap to see details"}'::jsonb end;
    else
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          '{"id": "Notifikasi baru", "en": "New notification"}'::jsonb);
      v_body := coalesce(to_jsonb(n.payload ->> 'body'), v_body);
  end case;

  return private.push_enqueue(
    n.user_id, n.type, v_title, v_body,
    (select coalesce(jsonb_object_agg(e.key, e.value), '{}') from jsonb_each(n.payload) e
      where e.key not in ('title', 'body', 'snippet', 'excerpt'))
      || jsonb_build_object('source', 'rendezvous_community', 'type', n.type, 'notification_id', n.id,
                            'actor_id', n.actor_id, 'actor_username', v_username),
    jsonb_build_object(
      'collapse_key', n.group_key,
      'priority', case when n.type in ('like', 'follow', 'followed_post', 'watchlist_digest') then 'normal' else 'high' end,
      'ref', case when n.payload ? 'campaign_id' then 'campaign:' || (n.payload ->> 'campaign_id') end));
end;
$$;

create or replace function private.notification_prefs_view(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'types', (select jsonb_agg(jsonb_build_object(
                       'type', t.type,
                       'in_app', private.notification_pref_in_app_locked(t.type) or coalesce(np.in_app, true),
                       'push', coalesce(np.push, private.notification_pref_default_push(t.type)),
                       'in_app_locked', private.notification_pref_in_app_locked(t.type)) order by t.ord)
              from unnest(private.notification_pref_types()) with ordinality as t(type, ord)
              left join private.notification_prefs np on np.user_id = p_user and np.type = t.type),
    'quiet_hours', coalesce((select jsonb_build_object('enabled', true,
                                                       'start', to_char(s.quiet_start, 'HH24:MI'),
                                                       'end', to_char(s.quiet_end, 'HH24:MI'),
                                                       'timezone', 'Asia/Jakarta')
                             from private.notification_settings s
                             where s.user_id = p_user and s.quiet_start is not null),
                            jsonb_build_object('enabled', false, 'start', null, 'end', null, 'timezone', 'Asia/Jakarta')),
    'aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60));
$$;

create or replace function public.set_notification_prefs(p_prefs jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_types  jsonb;
  v_item   record;
  v_type   text;
  v_in_app boolean;
  v_push   boolean;
  v_quiet  jsonb;
  v_start  time;
  v_end    time;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if jsonb_typeof(p_prefs) is distinct from 'object'
     or exists (select 1 from jsonb_object_keys(p_prefs) k where k not in ('types', 'quiet_hours')) then
    perform private.api_error(400, 'invalid_preferences', 'Format preferensi notifikasi tidak valid');
  end if;
  perform private.consume_rate_limit(v_uid, 'notification_prefs');

  v_types := case coalesce(jsonb_typeof(p_prefs -> 'types'), 'null')
    when 'null' then '[]'::jsonb
    when 'array' then p_prefs -> 'types'
    when 'object' then (select coalesce(jsonb_agg(case when jsonb_typeof(e.value) = 'object'
                                                       then e.value || jsonb_build_object('type', e.key)
                                                       else 'null'::jsonb end), '[]')
                        from jsonb_each(p_prefs -> 'types') e)
  end;
  if v_types is null then
    perform private.api_error(400, 'invalid_preferences', 'types harus berupa daftar atau objek per jenis');
  end if;

  for v_item in select e.value as item from jsonb_array_elements(v_types) e loop
    if jsonb_typeof(v_item.item) <> 'object'
       or not coalesce(v_item.item ->> 'type' = any (private.notification_pref_types()), false) then
      perform private.api_error(400, 'invalid_notification_type',
        'Jenis notifikasi harus salah satu dari ' || array_to_string(private.notification_pref_types(), ', '));
    end if;
    if (v_item.item ? 'in_app' and jsonb_typeof(v_item.item -> 'in_app') not in ('boolean', 'null'))
       or (v_item.item ? 'push' and jsonb_typeof(v_item.item -> 'push') <> 'boolean') then
      perform private.api_error(400, 'invalid_preferences', 'in_app dan push harus bernilai true/false');
    end if;
    v_type := v_item.item ->> 'type';
    select coalesce((v_item.item ->> 'in_app')::boolean, np.in_app, true),
           coalesce((v_item.item ->> 'push')::boolean, np.push, private.notification_pref_default_push(v_type))
      into v_in_app, v_push
    from (select 1) d
    left join private.notification_prefs np on np.user_id = v_uid and np.type = v_type;
    if private.notification_pref_in_app_locked(v_type) then
      v_in_app := true;
    end if;
    if v_in_app and v_push = private.notification_pref_default_push(v_type) then
      delete from private.notification_prefs np where np.user_id = v_uid and np.type = v_type;
    else
      insert into private.notification_prefs (user_id, type, in_app, push)
      values (v_uid, v_type, v_in_app, v_push)
      on conflict (user_id, type) do update set in_app = excluded.in_app, push = excluded.push, updated_at = now();
    end if;
  end loop;

  v_quiet := p_prefs -> 'quiet_hours';
  if v_quiet is not null and jsonb_typeof(v_quiet) <> 'null' then
    if jsonb_typeof(v_quiet) <> 'object' or jsonb_typeof(v_quiet -> 'enabled') <> 'boolean' then
      perform private.api_error(400, 'invalid_quiet_hours', 'quiet_hours butuh enabled, start, dan end');
    end if;
    if (v_quiet ->> 'enabled')::boolean then
      if coalesce(v_quiet ->> 'start', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
         or coalesce(v_quiet ->> 'end', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
         or v_quiet ->> 'start' = v_quiet ->> 'end' then
        perform private.api_error(400, 'invalid_quiet_hours', 'Jam tenang memakai format HH:MM dan jam mulai ≠ jam selesai');
      end if;
      v_start := (v_quiet ->> 'start')::time;
      v_end := (v_quiet ->> 'end')::time;
      insert into private.notification_settings (user_id, quiet_start, quiet_end)
      values (v_uid, v_start, v_end)
      on conflict (user_id) do update
        set quiet_start = excluded.quiet_start, quiet_end = excluded.quiet_end, updated_at = now();
    else
      delete from private.notification_settings s where s.user_id = v_uid;
    end if;
  end if;

  return private.notification_prefs_view(v_uid);
end;
$$;

create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room    public.chat_rooms;
  v_member  record;
  v_target  uuid;
  v_preview text;
begin
  v_preview := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;

  update public.chat_rooms
     set last_message_at = new.created_at,
         last_message_preview = v_preview,
         last_message_sender_id = new.sender_id
   where id = new.room_id
   returning * into v_room;

  update public.chat_members
     set last_read_at = greatest(last_read_at, new.created_at),
         last_delivered_at = greatest(last_delivered_at, new.created_at)
   where room_id = new.room_id and user_id = new.sender_id;

  if v_room.type in ('direct', 'group') then
    for v_member in
      select user_id from public.chat_members
      where room_id = new.room_id and user_id is distinct from new.sender_id and not muted
    loop
      perform private.notify(
        v_member.user_id, new.sender_id, 'message',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', v_room.type,
          'room_name', v_room.name,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'message:room:' || new.room_id
      );
    end loop;
  elsif v_room.type = 'stock' and new.sender_id is not null and new.deleted_at is null
        and new.moderation_status = 'visible' and position('@' in new.body) > 0 then
    for v_target in
      select p.id
      from unnest((private.extract_mentions(new.body))[1:private.setting_num('notifications.mention_room_max', 5)::integer])
           with ordinality as u(username, ord)
      join public.profiles p on p.username = u.username::extensions.citext
      where p.id <> new.sender_id
        and p.deleted_at is null
        and not private.is_banned(p.id)
        and not exists (select 1 from public.mutes m where m.muter_id = p.id and m.muted_id = new.sender_id)
      order by u.ord
    loop
      perform private.notify(
        v_target, new.sender_id, 'mention',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', 'stock',
          'room_name', v_room.name,
          'stock_code', v_room.stock_code,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'mention:room:' || new.room_id
      );
    end loop;
  end if;
  return null;
end;
$$;

create table private.followed_post_queue (
  post_id    uuid primary key references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  cursor_id  uuid,
  created_at timestamptz not null default now()
);
create index followed_post_queue_created_idx on private.followed_post_queue (created_at, post_id);
alter table private.followed_post_queue enable row level security;

create or replace function private.followed_post_enqueue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.profiles p
             where p.id = new.author_id and p.follower_count > 0 and p.deleted_at is null
               and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%') then
    insert into private.followed_post_queue (post_id, author_id) values (new.id, new.author_id)
    on conflict (post_id) do nothing;
  end if;
  return null;
end;
$$;

create trigger posts_60_followed_notify
  after insert on public.posts
  for each row when (new.moderation_status = 'visible' and new.deleted_at is null)
  execute function private.followed_post_enqueue();

create or replace function private.followed_post_tick(p_budget integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_budget integer := greatest(coalesce(p_budget,
                                        private.setting_num('notifications.followed_post_batch', 5000)::integer), 1);
  v_posts  integer := 0;
  v_sent   integer := 0;
  v_batch  integer;
  v_count  integer;
  v_last   text;
  v_key    text;
  v_post   public.posts;
  q        record;
begin
  for q in
    select * from private.followed_post_queue order by created_at, post_id for update skip locked
  loop
    exit when v_budget <= 0;
    select * into v_post from public.posts p where p.id = q.post_id;
    if v_post.id is null or v_post.deleted_at is not null or v_post.moderation_status <> 'visible'
       or v_post.created_at < now() - interval '1 day'
       or private.post_is_bot(v_post.id) or private.is_official_account(v_post.author_id) then
      delete from private.followed_post_queue where post_id = q.post_id;
      continue;
    end if;
    v_key := 'followed_post:' || v_post.author_id || ':'
             || to_char(v_post.created_at at time zone 'UTC', 'YYYYMMDDHH24');

    with batch as (
      select f.follower_id
      from public.follows f
      where f.following_id = v_post.author_id
        and (q.cursor_id is null or f.follower_id > q.cursor_id)
      order by f.follower_id
      limit v_budget
    ), sent as (
      insert into public.notifications as n (user_id, actor_id, type, payload, group_key)
      select b.follower_id, v_post.author_id, 'followed_post',
             jsonb_build_object('post_id', v_post.id, 'author_id', v_post.author_id,
                                'snippet', private.snippet(v_post.body)),
             v_key
      from batch b
      join public.profiles u on u.id = b.follower_id
      where u.deleted_at is null
        and not exists (select 1 from public.mutes m where m.muter_id = b.follower_id and m.muted_id = v_post.author_id)
        and not private.is_blocked_pair(b.follower_id, v_post.author_id)
      on conflict (user_id, group_key) where read_at is null and group_key is not null
      do update set actor_id = excluded.actor_id, payload = excluded.payload,
                    event_count = n.event_count + 1, created_at = now()
      returning 1
    )
    select (select count(*)::integer from batch), (select count(*)::integer from sent),
           (select max(b.follower_id::text) from batch b)
      into v_batch, v_count, v_last;

    v_sent := v_sent + v_count;
    v_budget := v_budget - v_batch;
    v_posts := v_posts + 1;
    if v_batch < greatest(v_budget + v_batch, 1) then
      delete from private.followed_post_queue where post_id = q.post_id;
    else
      update private.followed_post_queue set cursor_id = v_last::uuid where post_id = q.post_id;
    end if;
  end loop;
  return jsonb_build_object('posts', v_posts, 'notifications', v_sent);
end;
$$;

select cron.schedule('social-followed-posts', '30 seconds', 'select private.followed_post_tick()');

create table private.watchlist_digest_runs (
  day        date primary key,
  since      timestamptz not null,
  until      timestamptz not null,
  users      integer not null default 0,
  created_at timestamptz not null default now()
);
alter table private.watchlist_digest_runs enable row level security;

create or replace function private.watchlist_digest(p_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz := coalesce(p_at, now());
  v_day   date := (coalesce(p_at, now()) at time zone 'Asia/Jakarta')::date;
  v_since timestamptz;
  v_users integer;
begin
  select max(r.until) into v_since from private.watchlist_digest_runs r where r.day < v_day;
  v_since := greatest(coalesce(v_since,
                               v_until - make_interval(hours => private.setting_num('notifications.digest_lookback_hours', 24)::integer)),
                      v_until - interval '7 days');

  insert into private.watchlist_digest_runs (day, since, until) values (v_day, v_since, v_until)
  on conflict (day) do nothing;
  if not found then
    return jsonb_build_object('day', v_day, 'skipped', true);
  end if;

  with hits as (
    select w.user_id, ps.stock_code, ps.post_id
    from public.post_stocks ps
    join public.posts p on p.id = ps.post_id
    join public.stock_watchers w on w.stock_code = ps.stock_code
    join public.profiles u on u.id = w.user_id
    where ps.post_created_at > v_since and ps.post_created_at <= v_until
      and p.deleted_at is null and p.moderation_status = 'visible'
      and p.author_id <> w.user_id
      and u.deleted_at is null
      and u.olt_user_id not like 'official:%' and u.olt_user_id not like 'cs-staff:%'
      and not exists (select 1 from public.mutes m where m.muter_id = w.user_id and m.muted_id = p.author_id)
      and not exists (select 1 from public.muted_stocks ms where ms.user_id = w.user_id and ms.stock_code = ps.stock_code)
      and not exists (select 1 from public.blocks b
                      where (b.blocker_id = w.user_id and b.blocked_id = p.author_id)
                         or (b.blocker_id = p.author_id and b.blocked_id = w.user_id))
  ), per_stock as (
    select h.user_id, h.stock_code, count(*) as posts
    from hits h
    group by h.user_id, h.stock_code
  ), per_user as (
    select h.user_id, count(distinct h.post_id)::integer as posts
    from hits h
    group by h.user_id
  ), summary as (
    select u.user_id, u.posts, count(*)::integer as stock_count,
           (array_agg(s.stock_code order by s.posts desc, s.stock_code))[1:3] as top
    from per_user u
    join per_stock s on s.user_id = u.user_id
    group by u.user_id, u.posts
  ), sent as (
    insert into public.notifications (user_id, type, payload, group_key)
    select s.user_id, 'watchlist_digest',
           jsonb_build_object('date', v_day, 'post_count', s.posts, 'stock_count', s.stock_count,
                              'stocks', to_jsonb(s.top), 'since', v_since, 'until', v_until),
           'watchlist_digest:' || v_day
    from summary s
    where s.posts > 0
    on conflict (user_id, group_key) where read_at is null and group_key is not null do nothing
    returning 1
  )
  select count(*)::integer into v_users from sent;

  update private.watchlist_digest_runs set users = v_users where day = v_day;
  return jsonb_build_object('day', v_day, 'since', v_since, 'until', v_until, 'users', v_users);
end;
$$;

select cron.schedule('social-watchlist-digest', '5 10 * * *', 'select private.watchlist_digest()');

create or replace function private.moderation_notice(p_type text, p_id uuid, p_author uuid, p_state text,
                                                     p_excerpt text, p_context jsonb default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_author is null
     or not exists (select 1 from public.profiles p
                    where p.id = p_author and p.deleted_at is null
                      and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%')
     or private.is_official_account(p_author)
     or exists (select 1 from cs.agents a where a.user_id = p_author)
     or exists (select 1 from private.user_sanctions s
                where s.user_id = p_author and s.category = 'zero_tolerance' and s.revoked_at is null) then
    return;
  end if;
  insert into public.notifications (user_id, type, payload)
  values (p_author, 'moderation',
          jsonb_build_object(
            'target_type', p_type, 'target_id', p_id, 'state', p_state,
            'excerpt', private.snippet(btrim(regexp_replace(coalesce(p_excerpt, ''), '\s+', ' ', 'g')), 140),
            'appealable', not exists (select 1 from public.appeals a
                                      where a.user_id = p_author and a.target_type = p_type and a.target_id = p_id))
          || coalesce(p_context, '{}'));
end;
$$;

create or replace function private.notify_moderation_hidden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'posts' then
    perform private.moderation_notice('post', new.id, new.author_id, 'hidden', new.body);
  elsif tg_table_name = 'comments' then
    perform private.moderation_notice('comment', new.id, new.author_id, 'hidden', new.body,
                                      jsonb_build_object('post_id', new.post_id));
  elsif not exists (select 1 from public.chat_rooms r where r.id = new.room_id and r.type = 'support') then
    perform private.moderation_notice('message', new.id, new.sender_id, 'hidden', new.body,
                                      jsonb_build_object('room_id', new.room_id));
  end if;
  return null;
end;
$$;

create trigger posts_33_moderation_notice
  after update of moderation_status on public.posts
  for each row when (new.moderation_status = 'hidden' and old.moderation_status <> 'hidden' and new.deleted_at is null)
  execute function private.notify_moderation_hidden();

create trigger comments_33_moderation_notice
  after update of moderation_status on public.comments
  for each row when (new.moderation_status = 'hidden' and old.moderation_status <> 'hidden' and new.deleted_at is null)
  execute function private.notify_moderation_hidden();

create trigger messages_33_moderation_notice
  after update of moderation_status on public.messages
  for each row when (new.session_id is null and new.moderation_status = 'hidden'
                     and old.moderation_status <> 'hidden' and new.deleted_at is null)
  execute function private.notify_moderation_hidden();

create or replace function private.notify_moderation_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_context jsonb := '{}';
begin
  if new.target_type = 'comment' then
    select jsonb_build_object('post_id', c.post_id) into v_context from public.comments c where c.id = new.target_id;
  elsif new.target_type = 'message' then
    if exists (select 1 from public.messages m
               left join public.chat_rooms r on r.id = m.room_id
               where m.id = new.target_id and (m.session_id is not null or r.type = 'support')) then
      return null;
    end if;
    select jsonb_build_object('room_id', m.room_id) into v_context from public.messages m where m.id = new.target_id;
  end if;
  perform private.moderation_notice(new.target_type, new.target_id, new.author_id, 'removed', new.body,
                                    coalesce(v_context, '{}'));
  return null;
end;
$$;

create trigger content_archive_moderation_notice
  after insert on private.content_archive
  for each row when (new.reason = 'moderator_remove' and new.target_type in ('post', 'comment', 'message'))
  execute function private.notify_moderation_removed();

revoke execute on function private.notification_pref_in_app_locked(text) from public;
revoke execute on function private.followed_post_enqueue() from public;
revoke execute on function private.followed_post_tick(integer) from public;
revoke execute on function private.watchlist_digest(timestamptz) from public;
revoke execute on function private.moderation_notice(text, uuid, uuid, text, text, jsonb) from public;
revoke execute on function private.notify_moderation_hidden() from public;
revoke execute on function private.notify_moderation_removed() from public;
