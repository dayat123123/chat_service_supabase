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

  if new.type = 'followed_post' and new.payload ->> 'author_id' is not null then
    new.group_key := 'followed_post:' || (new.payload ->> 'author_id') || ':'
                     || to_char(now() at time zone 'Asia/Jakarta', 'YYYYMMDD');
  elsif new.type = 'like' and new.actor_id is not null and new.group_key is not null then
    select n.id into v_id
    from public.notifications n
    where n.user_id = new.user_id
      and n.type = 'like'
      and n.group_key = new.group_key
    order by (n.read_at is null) desc, n.created_at desc, n.id desc
    limit 1
    for update;
    if v_id is not null then
      update public.notifications
         set actor_id = new.actor_id, payload = new.payload, event_count = event_count + 1,
             read_at = null, created_at = now()
       where id = v_id;
      return null;
    end if;
  elsif new.type = 'follow' and new.actor_id is not null then
    select n.id into v_id
    from public.notifications n
    where n.user_id = new.user_id
      and n.type = 'follow'
      and n.read_at is null
    order by n.created_at desc, n.id desc
    limit 1
    for update;
    if v_id is not null then
      update public.notifications
         set actor_id = new.actor_id, payload = new.payload, event_count = event_count + 1, created_at = now()
       where id = v_id;
      return null;
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
  if new.type in ('trade_activity', 'trade_share') then
    return null;
  end if;
  if tg_op = 'INSERT'
     or (new.event_count > old.event_count and new.read_at is null
         and (new.type not in ('like', 'follow', 'followed_post') or old.read_at is not null)) then
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
  v_until    text;
begin
  if n.type in ('like', 'follow', 'reply') then
    select coalesce(nullif(count(*)::integer, 0) - 1, v_others) into v_others
    from private.notification_actors a where a.notification_id = n.id;
  end if;
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text), p.username::text into v_name, v_username
  from public.profiles p where p.id = n.actor_id;
  v_id := coalesce(v_name, 'Seseorang');
  v_en := coalesce(v_name, 'Someone');
  v_snip_en := case when v_snippet = '[lampiran]' then '[attachment]' else v_snippet end;
  v_body := jsonb_build_object('id', v_snippet, 'en', v_snip_en);

  case n.type
    when 'reply' then
      v_title := case
        when v_others > 0 and n.payload ->> 'scope' = 'comment'
          then jsonb_build_object('id', format('%s dan %s lainnya membalas komentar Anda', v_id, v_others),
                                  'en', format('%s and %s others replied to your comment', v_en, v_others))
        when v_others > 0
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
      if n.payload ->> 'target_type' = 'room' then
        v_place := coalesce('$' || nullif(n.payload ->> 'stock_code', ''), v_room, 'room saham');
        v_until := to_char((n.payload ->> 'until')::timestamptz at time zone 'Asia/Jakarta', 'DD/MM HH24:MI');
        if n.payload ->> 'state' = 'muted' then
          v_title := jsonb_build_object('id', format('Anda dibisukan moderator di %s', v_place),
                                        'en', format('A moderator muted you in %s', v_place));
          v_body := case when v_until is null then '{"id": "", "en": ""}'::jsonb
            else jsonb_build_object('id', format('Anda bisa mengirim pesan lagi setelah %s WIB', v_until),
                                    'en', format('You can send messages again after %s WIB', v_until)) end;
        else
          v_title := jsonb_build_object('id', format('Bisu Anda di %s dicabut', v_place),
                                        'en', format('Your mute in %s was lifted', v_place));
          v_body := '{"id": "Anda bisa mengirim pesan lagi di room ini", "en": "You can send messages in this room again"}'::jsonb;
        end if;
      else
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
      end if;
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

drop trigger if exists notifications_42_actors on public.notifications;
create trigger notifications_42_actors
  after insert or update of event_count on public.notifications
  for each row when (new.type in ('like', 'follow', 'reply') and new.actor_id is not null)
  execute function private.notification_actors_track();

create or replace function private.notify_comment()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_post_author   uuid;
  v_parent_author uuid;
  v_payload       jsonb;
  v_user          uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  v_payload := jsonb_build_object(
    'post_id', new.post_id,
    'comment_id', new.id,
    'parent_id', new.parent_id,
    'snippet', private.snippet(new.body)
  );

  if new.parent_id is not null then
    select author_id into v_parent_author from public.comments where id = new.parent_id;
    perform private.notify(v_parent_author, new.author_id, 'reply',
                           v_payload || '{"scope": "comment"}'::jsonb,
                           'replies:comment:' || new.parent_id);
  end if;

  if v_post_author is distinct from v_parent_author then
    perform private.notify(v_post_author, new.author_id, 'reply',
                           v_payload || '{"scope": "post"}'::jsonb,
                           'comments:post:' || new.post_id);
  end if;

  for v_user in
    select p.id from public.profiles p
    where p.username = any(((private.extract_mentions(new.body))[1:10])::extensions.citext[])
  loop
    if v_user is distinct from v_parent_author and v_user is distinct from v_post_author then
      perform private.notify(v_user, new.author_id, 'mention', v_payload);
    end if;
  end loop;

  return null;
end;
$$;

create function private.notify_reaction_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
  v_id     uuid;
  v_latest uuid;
begin
  if old.target_type = 'post' then
    select author_id into v_author from public.posts where id = old.target_id;
  else
    select author_id into v_author from public.comments where id = old.target_id;
  end if;
  if v_author is null then
    return null;
  end if;

  for v_id in
    select n.id from public.notifications n
    where n.user_id = v_author
      and n.type = 'like'
      and n.group_key = 'like:' || old.target_type || ':' || old.target_id
    for update
  loop
    delete from private.notification_actors a where a.notification_id = v_id and a.actor_id = old.user_id;
    if not found then
      continue;
    end if;
    select a.actor_id into v_latest
    from private.notification_actors a
    where a.notification_id = v_id
    order by a.updated_at desc, a.created_at desc
    limit 1;
    if v_latest is null then
      delete from public.notifications where id = v_id;
    else
      update public.notifications set actor_id = v_latest where id = v_id and actor_id = old.user_id;
    end if;
  end loop;
  return null;
end;
$$;

create trigger reactions_notify_removed
  after delete on public.reactions
  for each row execute function private.notify_reaction_removed();

create or replace function public.get_notifications(p_cursor text default null, p_limit integer default 30)
returns table (
  id                 uuid,
  type               text,
  actor_id           uuid,
  actor_username     text,
  actor_display_name text,
  actor_avatar_url   text,
  payload            jsonb,
  event_count        integer,
  read_at            timestamptz,
  created_at         timestamptz,
  cursor             text,
  actor_count        integer,
  actors             jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ts  timestamptz;
  v_id  uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_cursor is not null then
    begin
      v_ts := split_part(p_cursor, '|', 1)::timestamptz;
      v_id := split_part(p_cursor, '|', 2)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor');
    end;
  end if;

  return query
  select n.id, n.type, n.actor_id, a.username::text, a.display_name, a.avatar_url,
         n.payload || coalesce(pa.extra, '{}'::jsonb), n.event_count, n.read_at, n.created_at,
         to_char(n.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || n.id,
         coalesce(ac.total, case when n.actor_id is null then 0 else 1 end),
         coalesce(ac.actors,
                  case when a.id is null then '[]'::jsonb
                       else jsonb_build_array(jsonb_build_object('id', a.id, 'username', a.username::text,
                                                                 'display_name', a.display_name,
                                                                 'avatar_url', a.avatar_url)) end)
  from public.notifications n
  left join public.profiles a on a.id = n.actor_id
  left join lateral (
    select count(*)::integer as total,
           jsonb_agg(jsonb_build_object('id', x.id, 'username', x.username, 'display_name', x.display_name,
                                        'avatar_url', x.avatar_url) order by x.updated_at desc)
             filter (where x.rn <= 3) as actors
    from (
      select p.id, p.username::text as username, p.display_name, p.avatar_url, na.updated_at,
             row_number() over (order by na.updated_at desc) as rn
      from private.notification_actors na
      join public.profiles p on p.id = na.actor_id
      where na.notification_id = n.id
    ) x
    having count(*) > 0
  ) ac on true
  left join lateral (
    select jsonb_build_object('post_attachment', f.item) as extra
    from public.posts p
    cross join lateral (
      select e.item
      from jsonb_array_elements(p.attachments) with ordinality as e (item, pos)
      where jsonb_typeof(e.item) = 'object'
        and jsonb_typeof(e.item -> 'path') = 'string'
        and coalesce(e.item ->> 'mime', 'image/') like 'image/%'
      order by e.pos
      limit 1
    ) f
    where n.type in ('like', 'reply', 'mention', 'followed_post')
      and n.payload ->> 'post_id' ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      and p.id = (n.payload ->> 'post_id')::uuid
      and p.deleted_at is null
      and p.moderation_status = 'visible'
  ) pa on true
  where n.user_id = v_uid
    and (v_ts is null or (n.created_at, n.id) < (v_ts, v_id))
  order by n.created_at desc, n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

update private.settings
   set description = 'Tidak dipakai lagi sejak 0191: like digabung per post/komentar tanpa batas waktu, follow digabung selama belum dibaca'
 where key = 'notifications.aggregate_minutes';

insert into private.notification_actors (notification_id, actor_id, created_at, updated_at)
select n.id, n.actor_id, n.created_at, n.created_at
from public.notifications n
join public.profiles p on p.id = n.actor_id
where n.type in ('like', 'follow', 'reply')
on conflict (notification_id, actor_id) do nothing;

create temporary table notification_like_groups on commit drop as
select n.id, n.user_id, n.read_at,
       'like:' || (n.payload ->> 'target_type') || ':' || (n.payload ->> 'target_id') as key,
       row_number() over (partition by n.user_id, n.payload ->> 'target_type', n.payload ->> 'target_id'
                          order by n.created_at desc, n.id desc) as rn
from public.notifications n
where n.type = 'like'
  and n.payload ->> 'target_type' in ('post', 'comment')
  and n.payload ->> 'target_id' is not null;

insert into private.notification_actors (notification_id, actor_id, created_at, updated_at)
select k.id, a.actor_id, min(a.created_at), max(a.updated_at)
from notification_like_groups g
join notification_like_groups k on k.user_id = g.user_id and k.key = g.key and k.rn = 1
join private.notification_actors a on a.notification_id = g.id
where g.rn > 1
group by k.id, a.actor_id
on conflict (notification_id, actor_id) do update
  set created_at = least(private.notification_actors.created_at, excluded.created_at),
      updated_at = greatest(private.notification_actors.updated_at, excluded.updated_at);

delete from public.notifications n
using notification_like_groups g
where n.id = g.id and g.rn > 1;

update public.notifications n
   set group_key = k.key,
       read_at = case
         when exists (select 1 from notification_like_groups u
                      where u.user_id = k.user_id and u.key = k.key and u.read_at is null) then null
         else n.read_at
       end
from notification_like_groups k
where n.id = k.id and k.rn = 1;

update public.notifications
   set payload = payload || '{"scope": "post"}'::jsonb
 where type = 'reply' and group_key like 'comments:post:%' and not payload ? 'scope';

update public.notifications
   set payload = payload || '{"scope": "comment"}'::jsonb
 where type = 'reply' and group_key is null and payload ->> 'parent_id' is not null and not payload ? 'scope';

revoke execute on function private.notify_reaction_removed() from public;
