alter table public.reactions drop constraint reactions_type;
do $$
begin
  execute format(
    'alter table public.reactions add constraint reactions_type check (type = %L or (target_type = %L and type = any (%L::text[])))',
    'like', 'post', array_remove(private.message_reaction_emojis(), '👍'));
end;
$$;

create index reactions_target_created_idx on public.reactions (target_type, target_id, created_at desc, user_id desc);

alter table public.posts add column reaction_summary jsonb not null default '[]'::jsonb;

update public.posts
   set reaction_summary = jsonb_build_array(jsonb_build_object('emoji', '👍', 'count', like_count))
 where like_count > 0;

alter type public.feed_post
  add attribute my_reaction text,
  add attribute reaction_summary jsonb;

create function private.post_reaction_emoji(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_type = 'like' then '👍' else p_type end;
$$;

create function private.post_reaction_type(p_emoji text)
returns text
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  v_emoji text := nullif(btrim(coalesce(p_emoji, '')), '');
begin
  if v_emoji is null then
    return null;
  end if;
  if v_emoji = 'like' or v_emoji = '👍' then
    return 'like';
  end if;
  if v_emoji = '❤' then
    v_emoji := '❤️';
  end if;
  if not (v_emoji = any (private.message_reaction_emojis())) then
    perform private.api_error(400, 'invalid_reaction', 'Reaksi tidak dikenal');
  end if;
  return v_emoji;
end;
$$;

create function private.reaction_summary_adjust(p_summary jsonb, p_emoji text, p_delta integer)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('emoji', t.emoji, 'count', t.n)
                            order by t.n desc, array_position(private.message_reaction_emojis(), t.emoji)), '[]'::jsonb)
  from (
    select s.emoji, sum(s.n)::integer as n
    from (
      select x ->> 'emoji' as emoji, (x ->> 'count')::integer as n
      from jsonb_array_elements(case when jsonb_typeof(p_summary) = 'array' then p_summary else '[]'::jsonb end) x
      union all
      select p_emoji, p_delta where p_emoji is not null
    ) s
    group by s.emoji
  ) t
  where t.n > 0;
$$;

create or replace function private.reactions_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author  uuid;
  v_deleted timestamptz;
  v_status  text;
begin
  if new.type = '👍' then
    new.type := 'like';
  elsif new.type = '❤' then
    new.type := '❤️';
  end if;
  if tg_op = 'UPDATE' and new.type is not distinct from old.type then
    return new;
  end if;
  if new.type is null
     or not (new.type = 'like' or (new.target_type = 'post' and new.type = any (private.message_reaction_emojis()))) then
    perform private.api_error(400, 'invalid_reaction', 'Reaksi tidak dikenal');
  end if;

  if new.target_type = 'post' then
    select author_id, deleted_at, moderation_status into v_author, v_deleted, v_status
    from public.posts where id = new.target_id;
  else
    select author_id, deleted_at, 'visible' into v_author, v_deleted, v_status
    from public.comments where id = new.target_id;
  end if;

  if v_author is null or v_deleted is not null
     or (v_status <> 'visible' and v_author is distinct from new.user_id) then
    perform private.api_error(404, 'target_not_found', 'Konten tidak ditemukan');
  end if;
  if private.is_blocked_pair(new.user_id, v_author) then
    perform private.api_error(403, 'blocked', 'Tidak bisa memberi reaksi pada konten ini');
  end if;
  return new;
end;
$$;

create trigger reactions_21_before_update
  before update of type on public.reactions
  for each row execute function private.reactions_before_insert();

create function private.bump_post_reaction(p_post_id uuid, p_added text, p_removed text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_add    text := private.post_reaction_emoji(p_added);
  v_remove text := private.post_reaction_emoji(p_removed);
begin
  if v_add is not distinct from v_remove then
    return;
  end if;
  update public.posts
     set like_count = greatest(like_count + (v_add is not null)::integer - (v_remove is not null)::integer, 0),
         reaction_summary = private.reaction_summary_adjust(
           private.reaction_summary_adjust(reaction_summary, v_remove, -1), v_add, 1)
   where id = p_post_id;
end;
$$;

create or replace function private.reactions_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.target_type = 'post' then
      perform private.bump_post_reaction(new.target_id, new.type, null);
    else
      perform private.bump_like_count(new.target_type, new.target_id, 1);
    end if;
  elsif tg_op = 'DELETE' then
    if old.target_type = 'post' then
      perform private.bump_post_reaction(old.target_id, null, old.type);
    else
      perform private.bump_like_count(old.target_type, old.target_id, -1);
    end if;
  elsif tg_op = 'UPDATE' and new.type is distinct from old.type and new.target_type = 'post' then
    perform private.bump_post_reaction(new.target_id, new.type, old.type);
  end if;
  return null;
end;
$$;

create or replace function private.notify_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author  uuid;
  v_post_id uuid;
  v_body    text;
begin
  if new.target_type = 'post' then
    select author_id, id, body into v_author, v_post_id, v_body from public.posts where id = new.target_id;
  else
    select author_id, post_id, body into v_author, v_post_id, v_body from public.comments where id = new.target_id;
  end if;

  perform private.notify(
    v_author, new.user_id, 'like',
    jsonb_build_object(
      'target_type', new.target_type,
      'target_id', new.target_id,
      'post_id', v_post_id,
      'reaction', new.type,
      'emoji', private.post_reaction_emoji(new.type),
      'snippet', private.snippet(v_body)
    ),
    'like:' || new.target_type || ':' || new.target_id
  );
  return null;
end;
$$;

create function private.notify_reaction_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
begin
  if new.target_type <> 'post' or new.type is not distinct from old.type then
    return null;
  end if;
  select p.author_id into v_author from public.posts p where p.id = new.target_id;
  if v_author is null then
    return null;
  end if;
  update public.notifications n
     set payload = n.payload || jsonb_build_object('reaction', new.type, 'emoji', private.post_reaction_emoji(new.type))
   where n.user_id = v_author
     and n.type = 'like'
     and n.group_key = 'like:post:' || new.target_id
     and n.actor_id = new.user_id;
  return null;
end;
$$;

create trigger reactions_notify_changed
  after update of type on public.reactions
  for each row execute function private.notify_reaction_changed();

create or replace function private.feed_posts(p_ids uuid[])
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.author_id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         p.body, p.sentiment, p.attachments, p.like_count,
         case when ea.audience = 'off' and p.author_id is distinct from auth.uid() then null
              else p.comment_count end,
         coalesce((select array_agg(ps.stock_code order by ps.stock_code)
                   from public.post_stocks ps where ps.post_id = p.id), '{}'),
         mr.reaction is not null,
         p.edited_at, p.created_at,
         private.make_cursor(p.created_at, p.id),
         private.poll_view(p.id, p.author_id),
         exists (select 1 from public.bookmarks b where b.user_id = auth.uid() and b.post_id = p.id),
         coalesce((select array_agg(ph.tag order by ph.tag) from public.post_hashtags ph where ph.post_id = p.id), '{}'),
         private.post_is_bot(p.id),
         private.is_official_account(p.author_id),
         case when p.author_id = auth.uid() then p.moderation_status end,
         case when p.comment_count > 0 and ea.audience <> 'off' then (
           select to_jsonb(tc)
           from private.thread_comments(array(
             select c.id from public.comments c
             where c.post_id = p.id
               and c.parent_id is null
               and c.deleted_at is null
               and c.moderation_status = 'visible'
             order by c.like_count + c.reply_count desc, c.seq
             limit 1)) tc)
         end,
         case when p.author_id = auth.uid() then p.comment_audience::text end,
         cr.restriction is null,
         cr.restriction,
         case when p.author_id = auth.uid() then ao.all_off end,
         private.post_reaction_emoji(mr.reaction),
         p.reaction_summary
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  cross join lateral (select private.comments_all_off(p.author_id) as all_off) ao
  cross join lateral (
    select case when ao.all_off then 'off'::public.comment_audience else p.comment_audience end as audience) ea
  cross join lateral (
    select private.comment_restriction(p.author_id, ea.audience, auth.uid()) as restriction) cr
  left join lateral (
    select r.type as reaction from public.reactions r
    where r.user_id = auth.uid() and r.target_type = 'post' and r.target_id = p.id) mr on true
  order by u.ord;
$$;

create function public.set_post_reaction(p_post_id uuid, p_emoji text)
returns setof public.feed_post
language plpgsql
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_type text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_post_id is null then
    perform private.api_error(404, 'target_not_found', 'Konten tidak ditemukan');
  end if;
  v_type := private.post_reaction_type(p_emoji);

  if v_type is null then
    delete from public.reactions r
     where r.user_id = v_uid and r.target_type = 'post' and r.target_id = p_post_id;
  else
    insert into public.reactions as r (user_id, target_type, target_id, type)
    values (v_uid, 'post', p_post_id, v_type)
    on conflict (user_id, target_type, target_id) do update
      set type = excluded.type
      where r.type is distinct from excluded.type;
  end if;

  return query select * from private.feed_posts(array[p_post_id]);
end;
$$;

create function public.post_reactors(p_post_id uuid, p_emoji text default null, p_limit integer default 30,
                                     p_cursor text default null)
returns table (
  id           uuid,
  username     text,
  display_name text,
  avatar_url   text,
  is_verified  boolean,
  is_official  boolean,
  is_me        boolean,
  is_following boolean,
  emoji        text,
  reacted_at   timestamptz,
  cursor       text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 50);
  v_type  text;
  v_ts    timestamptz;
  v_id    uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_post_id is null
     or not exists (select 1 from public.posts p
                    where p.id = p_post_id
                      and p.deleted_at is null
                      and (p.moderation_status = 'visible' or p.author_id = v_uid)
                      and not private.is_blocked_pair(v_uid, p.author_id)) then
    perform private.api_error(404, 'target_not_found', 'Konten tidak ditemukan');
  end if;
  v_type := private.post_reaction_type(p_emoji);
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  return query
  select pr.id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         private.is_official_account(pr.id),
         pr.id = v_uid,
         exists (select 1 from public.follows x where x.follower_id = v_uid and x.following_id = pr.id),
         private.post_reaction_emoji(r.type),
         r.created_at,
         private.make_cursor(r.created_at, r.user_id)
  from public.reactions r
  join public.profiles pr on pr.id = r.user_id
  where r.target_type = 'post'
    and r.target_id = p_post_id
    and (v_type is null or r.type = v_type)
    and pr.deleted_at is null
    and not pr.is_guest
    and not cs.is_staff(pr.id)
    and not private.is_banned(pr.id)
    and not private.is_blocked_pair(v_uid, pr.id)
    and (v_ts is null or (r.created_at, r.user_id) < (v_ts, v_id))
  order by r.created_at desc, r.user_id desc
  limit v_limit;
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
  v_emoji    text;
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
      v_emoji := coalesce(nullif(n.payload ->> 'emoji', ''), '👍');
      v_title := case
        when v_others > 0 and v_emoji <> '👍'
          then jsonb_build_object('id', format('%s dan %s lainnya menanggapi konten Anda', v_id, v_others),
                                  'en', format('%s and %s others reacted to your content', v_en, v_others))
        when v_others > 0
          then jsonb_build_object('id', format('%s dan %s lainnya menyukai konten Anda', v_id, v_others),
                                  'en', format('%s and %s others liked your content', v_en, v_others))
        when v_emoji <> '👍'
          then jsonb_build_object('id', format('%s menanggapi konten Anda dengan %s', v_id, v_emoji),
                                  'en', format('%s reacted %s to your content', v_en, v_emoji))
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

create or replace function public.get_client_config(p_platform text default null, p_app_version text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user     uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_version  text := nullif(btrim(coalesce(p_app_version, '')), '');
  v_min      text;
begin
  if v_platform is not null and v_platform <> all (private.client_platforms()) then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_version is not null and private.version_parts(v_version) is null then
    perform private.api_error(400, 'invalid_version', 'Versi aplikasi harus berformat angka, mis. 2.4.1');
  end if;
  select v.min_version into v_min from private.client_versions v where v.platform = v_platform;

  return jsonb_build_object(
    'social_enabled', private.social_enabled(),
    'flags', coalesce((select jsonb_object_agg(f.key, private.flag_enabled(f, v_user, v_platform, v_version))
                       from private.feature_flags f), '{}'),
    'min_version', coalesce((select jsonb_object_agg(v.platform, v.min_version) from private.client_versions v), '{}'),
    'update_required', coalesce(v_min is not null and v_version is not null
                                and private.version_parts(v_version) < private.version_parts(v_min), false),
    'banners', private.client_banners(v_platform, v_version, v_user),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'post_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'account_rejoin_cooldown_hours', greatest(private.setting_num('account.rejoin_cooldown_hours', 72), 0),
      'viewer_id', v_user,
      'server_time', now()));
end;
$$;

revoke execute on function private.post_reaction_emoji(text) from public;
revoke execute on function private.post_reaction_type(text) from public;
revoke execute on function private.reaction_summary_adjust(jsonb, text, integer) from public;
revoke execute on function private.bump_post_reaction(uuid, text, text) from public;
revoke execute on function private.notify_reaction_changed() from public;
revoke execute on function public.set_post_reaction(uuid, text) from public, anon;
revoke execute on function public.post_reactors(uuid, text, integer, text) from public, anon;

grant execute on function private.post_reaction_emoji(text) to authenticated;
grant execute on function private.post_reaction_type(text) to authenticated;
grant execute on function public.set_post_reaction(uuid, text) to authenticated;
grant execute on function public.post_reactors(uuid, text, integer, text) to authenticated;
