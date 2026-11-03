insert into private.settings (key, value, description) values
  ('content.edit_minutes', '15', 'Post dan komentar bisa diedit penulisnya selama sekian menit setelah dibuat')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('content_edit', 20, 60),
  ('bookmark', 120, 60),
  ('message_reaction', 60, 60)
on conflict (action, window_seconds) do nothing;

create table private.content_edits (
  id           bigint generated always as identity primary key,
  target_type  text not null check (target_type in ('post', 'comment')),
  target_id    uuid not null,
  author_id    uuid,
  body         text not null,
  edited_by    uuid,
  edited_at    timestamptz not null default now(),
  legal_hold   boolean not null default false,
  retain_until timestamptz not null
);
create index content_edits_target_idx on private.content_edits (target_type, target_id, edited_at);
create index content_edits_retain_idx on private.content_edits (retain_until) where not legal_hold;
alter table private.content_edits enable row level security;

create or replace function private.guard_content_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null or new.body is not distinct from old.body then
    return new;
  end if;
  if private.is_end_user() then
    if tg_argv[0] = 'post' and exists (select 1 from public.post_polls pp where pp.post_id = new.id) then
      perform private.api_error(409, 'poll_not_editable', 'Postingan berisi polling tidak bisa diedit');
    end if;
    if old.created_at < now() - make_interval(mins => private.setting_num('content.edit_minutes', 15)::integer) then
      perform private.api_error(403, 'edit_window_expired',
        format('Konten hanya bisa diedit %s menit setelah dibuat', private.setting_num('content.edit_minutes', 15)));
    end if;
  end if;
  insert into private.content_edits (target_type, target_id, author_id, body, edited_by, retain_until)
  values (tg_argv[0], old.id, old.author_id, old.body, auth.uid(),
          now() + make_interval(days => private.setting_num('retention.archive_days', 1825)::integer));
  return new;
end;
$$;

create trigger posts_40_edit
  before update of body on public.posts
  for each row execute function private.guard_content_edit('post');
create trigger comments_40_edit
  before update of body on public.comments
  for each row execute function private.guard_content_edit('comment');

create table public.bookmarks (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index bookmarks_user_created_idx on public.bookmarks (user_id, created_at desc, post_id desc);
create index bookmarks_post_idx on public.bookmarks (post_id);
alter table public.bookmarks enable row level security;
revoke all on public.bookmarks from anon, authenticated;
grant select on public.bookmarks to authenticated;
create policy bookmarks_select_own on public.bookmarks
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function private.message_reaction_emojis()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['👍', '❤️', '😂', '😮', '😢', '🔥'];
$$;

create table public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null check (emoji in ('👍', '❤️', '😂', '😮', '😢', '🔥')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
create index message_reactions_user_idx on public.message_reactions (user_id);
alter table public.message_reactions enable row level security;
revoke all on public.message_reactions from anon, authenticated;
grant select on public.message_reactions to authenticated;
create policy message_reactions_select_member on public.message_reactions
  for select to authenticated
  using (exists (select 1 from public.messages m
                 where m.id = message_id and m.room_id in (select private.my_room_ids())));

create or replace function private.is_official_account(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.official_accounts o where o.profile_id = p_profile and o.disabled_at is null);
$$;

alter type public.feed_post
  add attribute is_bookmarked boolean,
  add attribute hashtags text[],
  add attribute is_bot boolean,
  add attribute author_is_official boolean;

create or replace function private.feed_posts(p_ids uuid[])
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.author_id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         p.body, p.sentiment, p.attachments, p.like_count, p.comment_count,
         coalesce((select array_agg(ps.stock_code order by ps.stock_code)
                   from public.post_stocks ps where ps.post_id = p.id), '{}'),
         exists (select 1 from public.reactions r
                 where r.user_id = auth.uid() and r.target_type = 'post' and r.target_id = p.id),
         p.edited_at, p.created_at,
         private.make_cursor(p.created_at, p.id),
         private.poll_view(p.id, p.author_id),
         exists (select 1 from public.bookmarks b where b.user_id = auth.uid() and b.post_id = p.id),
         coalesce((select array_agg(ph.tag order by ph.tag) from public.post_hashtags ph where ph.post_id = p.id), '{}'),
         private.post_is_bot(p.id),
         private.is_official_account(p.author_id)
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  order by u.ord;
$$;

create or replace function private.message_reaction_summary(p_message_id uuid, p_viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('emoji', r.emoji, 'count', r.n, 'me', r.me) order by r.pos), '[]')
  from (
    select mr.emoji, count(*)::integer as n, coalesce(bool_or(mr.user_id = p_viewer), false) as me,
           array_position(private.message_reaction_emojis(), mr.emoji) as pos
    from public.message_reactions mr
    where mr.message_id = p_message_id
    group by mr.emoji
  ) r;
$$;

create or replace function private.shared_post_preview(p_attachments jsonb, p_viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when x.post_id is null then null else coalesce((
    select jsonb_build_object(
             'post_id', p.id, 'available', true, 'author_id', p.author_id,
             'author_username', pr.username::text, 'author_display_name', pr.display_name,
             'author_avatar_url', pr.avatar_url, 'author_is_verified', pr.is_verified,
             'body', private.snippet(p.body, 280), 'attachments', p.attachments, 'sentiment', p.sentiment,
             'stock_codes', coalesce((select jsonb_agg(ps.stock_code order by ps.stock_code)
                                      from public.post_stocks ps where ps.post_id = p.id), '[]'),
             'like_count', p.like_count, 'comment_count', p.comment_count, 'created_at', p.created_at)
    from public.posts p
    join public.profiles pr on pr.id = p.author_id
    where p.id = x.post_id
      and p.deleted_at is null
      and (p.moderation_status = 'visible' or p.author_id = p_viewer)
      and not private.is_blocked_pair(p_viewer, p.author_id)
  ), jsonb_build_object('post_id', x.post_id, 'available', false)) end
  from (
    select (select (e.value ->> 'post_id')::uuid
            from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments
                                           else '[]'::jsonb end) e
            where e.value ->> 'type' = 'post'
            limit 1) as post_id
  ) x;
$$;

alter type public.chat_message
  add attribute reactions jsonb,
  add attribute shared_post jsonb;

create or replace function private.chat_messages(p_ids uuid[])
returns setof public.chat_message
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.id, m.room_id, m.sender_id,
         s.username::text, s.display_name, s.avatar_url,
         case when m.deleted_at is null then m.body end,
         m.deleted_at is not null,
         m.reply_to_id,
         case when rt.deleted_at is null then private.snippet(rt.body, 200) end,
         rs.username::text,
         case when m.deleted_at is null then m.attachments else '[]'::jsonb end,
         m.client_id, m.edited_at, m.created_at,
         private.make_cursor(m.created_at, m.id),
         m.kind,
         case when m.deleted_at is null then m.payload else '{}'::jsonb end,
         m.session_id,
         m.sender_role,
         case when m.deleted_at is null then private.message_reaction_summary(m.id, auth.uid()) else '[]'::jsonb end,
         case when m.deleted_at is null then private.shared_post_preview(m.attachments, auth.uid()) end
  from public.messages m
  left join public.profiles s on s.id = m.sender_id
  left join public.messages rt on rt.id = m.reply_to_id
  left join public.profiles rs on rs.id = rt.sender_id
  where m.id = any(p_ids)
  order by m.created_at desc, m.id desc;
$$;

create or replace function private.validate_shared_post(p_items jsonb, p_room_id uuid, p_sender uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id   text := p_items -> 0 ->> 'post_id';
  v_post public.posts;
begin
  if jsonb_array_length(p_items) <> 1 then
    perform private.api_error(400, 'invalid_attachments', 'Maksimal satu postingan per pesan');
  end if;
  if v_id is null or v_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    perform private.api_error(400, 'invalid_attachments', 'post_id tidak valid');
  end if;
  if exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(400, 'share_not_allowed', 'Postingan tidak bisa dibagikan ke chat CS');
  end if;
  select * into v_post from public.posts p where p.id = v_id::uuid;
  if not found or v_post.deleted_at is not null
     or (v_post.moderation_status <> 'visible' and v_post.author_id is distinct from p_sender)
     or private.is_blocked_pair(p_sender, v_post.author_id) then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;
  return jsonb_build_array(jsonb_build_object('type', 'post', 'post_id', v_post.id));
end;
$$;

create or replace function private.messages_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_media jsonb := new.attachments;
  v_posts jsonb := '[]';
begin
  if tg_op = 'INSERT' then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    if jsonb_typeof(new.attachments) = 'array' then
      select coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' is distinct from 'post'), '[]'),
             coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'post'), '[]')
        into v_media, v_posts
      from jsonb_array_elements(new.attachments) with ordinality e;
    end if;
    perform private.validate_attachments(
      v_media, 'rooms/' || new.room_id || '/' || new.sender_id || '/');
    perform private.check_message_media(v_media, new.room_id);
    if jsonb_array_length(v_posts) > 0 then
      new.attachments := v_media || private.validate_shared_post(v_posts, new.room_id, new.sender_id);
    end if;
    if new.reply_to_id is not null
       and not exists (select 1 from public.messages
                       where id = new.reply_to_id and room_id = new.room_id) then
      perform private.api_error(400, 'invalid_reply', 'Pesan yang dibalas tidak ada di room ini');
    end if;
  elsif new.deleted_at is null and new.body is distinct from old.body then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create or replace function private.dm_request_hidden(p_room_id uuid, p_user uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regprocedure('private.dm_request_pending(uuid,uuid)') is null then
    return false;
  end if;
  return coalesce(private.dm_request_pending(p_room_id, p_user), false);
end;
$$;

create or replace function public.get_my_rooms(p_cursor text default null, p_limit integer default 30)
returns setof public.chat_room_summary
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit  integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_pinned boolean;
  v_ts     timestamptz;
  v_id     uuid;
  v_ids    uuid[];
begin
  if coalesce(p_cursor, '') <> '' then
    begin
      v_pinned := case split_part(p_cursor, '|', 1) when '1' then true when '0' then false end;
      v_ts := split_part(p_cursor, '|', 2)::timestamptz;
      v_id := split_part(p_cursor, '|', 3)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_pinned is null or v_ts is null or v_id is null then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  end if;

  select array_agg(x.id) into v_ids
  from (
    select r.id
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.user_id = auth.uid()
      and (v_ts is null
           or (r.type = 'support', coalesce(r.last_message_at, r.created_at), r.id) < (v_pinned, v_ts, v_id))
      and (r.type <> 'direct' or not private.dm_request_hidden(r.id, m.user_id))
    order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc
    limit v_limit
  ) x;

  return query select * from private.chat_room_summaries(coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.edit_post(p_post_id uuid, p_body text)
returns setof public.feed_post
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_body text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_post public.posts;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_post from public.posts p where p.id = p_post_id for update;
  if not found or v_post.deleted_at is not null
     or (v_post.author_id <> v_uid and (v_post.moderation_status <> 'visible'
                                        or private.is_blocked_pair(v_uid, v_post.author_id))) then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;
  if v_post.author_id <> v_uid then
    perform private.api_error(403, 'forbidden', 'Hanya penulis yang bisa mengedit postingan ini');
  end if;
  if char_length(v_body) = 0 then
    perform private.api_error(400, 'empty_body', 'Postingan tidak boleh kosong');
  end if;
  if char_length(v_body) > 2000 then
    perform private.api_error(400, 'body_too_long', 'Postingan maksimal 2000 karakter');
  end if;
  if v_body is distinct from v_post.body then
    perform private.consume_rate_limit(v_uid, 'content_edit');
    update public.posts set body = v_body where id = v_post.id;
  end if;
  return query select * from private.feed_posts(array[v_post.id]);
end;
$$;

create or replace function public.edit_comment(p_comment_id uuid, p_body text)
returns setof public.thread_comment
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_body    text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_comment public.comments;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_comment from public.comments c where c.id = p_comment_id for update;
  if not found or v_comment.deleted_at is not null
     or (v_comment.author_id <> v_uid and (v_comment.moderation_status <> 'visible'
                                           or private.is_blocked_pair(v_uid, v_comment.author_id))) then
    perform private.api_error(404, 'comment_not_found', 'Komentar tidak ditemukan');
  end if;
  if v_comment.author_id <> v_uid then
    perform private.api_error(403, 'forbidden', 'Hanya penulis yang bisa mengedit komentar ini');
  end if;
  if char_length(v_body) = 0 then
    perform private.api_error(400, 'empty_body', 'Komentar tidak boleh kosong');
  end if;
  if char_length(v_body) > 1000 then
    perform private.api_error(400, 'body_too_long', 'Komentar maksimal 1000 karakter');
  end if;
  if v_body is distinct from v_comment.body then
    perform private.consume_rate_limit(v_uid, 'content_edit');
    update public.comments set body = v_body where id = v_comment.id;
  end if;
  return query select * from private.thread_comments(array[v_comment.id]);
end;
$$;

create or replace function public.toggle_bookmark(p_post_id uuid, p_bookmarked boolean default null)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_exists boolean;
  v_target boolean;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_exists := exists (select 1 from public.bookmarks b where b.user_id = v_uid and b.post_id = p_post_id);
  v_target := coalesce(p_bookmarked, not v_exists);
  if v_target = v_exists then
    return v_exists;
  end if;
  if v_target then
    if not exists (select 1 from public.posts p
                   where p.id = p_post_id and p.deleted_at is null
                     and (p.moderation_status = 'visible' or p.author_id = v_uid)
                     and not private.is_blocked_pair(v_uid, p.author_id)) then
      perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
    end if;
    perform private.consume_rate_limit(v_uid, 'bookmark');
    insert into public.bookmarks (user_id, post_id) values (v_uid, p_post_id) on conflict do nothing;
  else
    delete from public.bookmarks b where b.user_id = v_uid and b.post_id = p_post_id;
  end if;
  return v_target;
end;
$$;

create or replace function public.get_bookmarks(p_cursor text default null, p_limit integer default 20)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  select array_agg(x.post_id order by x.created_at desc, x.post_id desc) into v_ids
  from (
    select b.post_id, b.created_at
    from public.bookmarks b
    join public.posts p on p.id = b.post_id
    where b.user_id = v_uid
      and p.deleted_at is null
      and (v_ts is null or (b.created_at, b.post_id) < (v_ts, v_id))
    order by b.created_at desc, b.post_id desc
    limit v_limit
  ) x;

  return query
  select (jsonb_populate_record(f, jsonb_build_object('cursor', private.make_cursor(b.created_at, b.post_id)))).*
  from unnest(coalesce(v_ids, '{}')) with ordinality as u(id, ord)
  join private.feed_posts(coalesce(v_ids, '{}')) f on f.id = u.id
  join public.bookmarks b on b.user_id = v_uid and b.post_id = u.id
  order by u.ord;
end;
$$;

create or replace function private.broadcast_message_reaction(p_room_id uuid, p_message_id uuid, p_user_id uuid,
                                                              p_emoji text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'message_id', p_message_id,
      'user_id', p_user_id,
      'emoji', p_emoji,
      'reactions', (select coalesce(jsonb_agg(e.value - 'me' order by e.ordinality), '[]')
                    from jsonb_array_elements(private.message_reaction_summary(p_message_id, null)) with ordinality e)),
    'reaction',
    'room:' || p_room_id::text,
    true);
end;
$$;

create or replace function public.react_to_message(p_message_id uuid, p_emoji text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_emoji text := nullif(btrim(coalesce(p_emoji, '')), '');
  v_msg   public.messages;
  v_type  text;
  v_old   text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_emoji = '❤' then
    v_emoji := '❤️';
  end if;
  if v_emoji is not null and not (v_emoji = any (private.message_reaction_emojis())) then
    perform private.api_error(400, 'invalid_emoji', 'Reaksi harus salah satu dari 👍 ❤️ 😂 😮 😢 🔥');
  end if;

  select * into v_msg from public.messages m where m.id = p_message_id;
  if not found or v_msg.deleted_at is not null
     or not exists (select 1 from public.chat_members cm where cm.room_id = v_msg.room_id and cm.user_id = v_uid)
     or (v_msg.moderation_status <> 'visible' and v_msg.sender_id is distinct from v_uid)
     or (v_msg.sender_id is not null and private.is_blocked_pair(v_uid, v_msg.sender_id)) then
    perform private.api_error(404, 'message_not_found', 'Pesan tidak ditemukan');
  end if;
  select r.type into v_type from public.chat_rooms r where r.id = v_msg.room_id;
  if v_type = 'support' then
    perform private.api_error(400, 'reactions_not_supported', 'Reaksi tidak tersedia di chat CS');
  end if;

  select mr.emoji into v_old from public.message_reactions mr
  where mr.message_id = v_msg.id and mr.user_id = v_uid for update;
  if v_emoji is null or v_emoji = v_old then
    delete from public.message_reactions mr where mr.message_id = v_msg.id and mr.user_id = v_uid;
    v_emoji := null;
  else
    perform private.consume_rate_limit(v_uid, 'message_reaction');
    insert into public.message_reactions (message_id, user_id, emoji) values (v_msg.id, v_uid, v_emoji)
    on conflict (message_id, user_id) do update set emoji = excluded.emoji, created_at = now();
  end if;

  if v_emoji is distinct from v_old then
    perform private.broadcast_message_reaction(v_msg.room_id, v_msg.id, v_uid, v_emoji);
  end if;
  return jsonb_build_object('message_id', v_msg.id, 'emoji', v_emoji,
                            'reactions', private.message_reaction_summary(v_msg.id, v_uid));
end;
$$;

create or replace function public.share_post_to_chat(p_room_id uuid, p_post_id uuid, p_body text default null,
                                                     p_client_id uuid default null)
returns setof public.chat_message
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
begin
  return query select * from public.send_message(
    p_room_id, coalesce(p_body, ''), p_client_id, null,
    jsonb_build_array(jsonb_build_object('type', 'post', 'post_id', p_post_id)));
end;
$$;

create or replace function cs_api.community_edit_history(p_target_type text, p_target_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  if p_target_type not in ('post', 'comment') then
    perform private.api_error(400, 'invalid_target', 'Jenis konten harus post atau comment');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('body', e.body, 'edited_at', e.edited_at, 'edited_by', e.edited_by)
                     order by e.edited_at)
    from private.content_edits e
    where e.target_type = p_target_type and e.target_id = p_target_id), '[]');
end;
$$;

revoke execute on function private.guard_content_edit() from public;
revoke execute on function private.message_reaction_emojis() from public;
revoke execute on function private.is_official_account(uuid) from public;
revoke execute on function private.message_reaction_summary(uuid, uuid) from public;
revoke execute on function private.shared_post_preview(jsonb, uuid) from public;
revoke execute on function private.validate_shared_post(jsonb, uuid, uuid) from public;
revoke execute on function private.dm_request_hidden(uuid, uuid) from public;
revoke execute on function private.broadcast_message_reaction(uuid, uuid, uuid, text) from public;
revoke execute on function public.edit_post(uuid, text) from public, anon;
revoke execute on function public.edit_comment(uuid, text) from public, anon;
revoke execute on function public.toggle_bookmark(uuid, boolean) from public, anon;
revoke execute on function public.get_bookmarks(text, integer) from public, anon;
revoke execute on function public.react_to_message(uuid, text) from public, anon;
revoke execute on function public.share_post_to_chat(uuid, uuid, text, uuid) from public, anon;
revoke execute on function cs_api.community_edit_history(text, uuid) from public;
grant execute on function private.is_official_account(uuid) to authenticated;
grant execute on function private.post_is_bot(uuid) to authenticated;
grant execute on function private.message_reaction_summary(uuid, uuid) to authenticated;
grant execute on function private.shared_post_preview(jsonb, uuid) to authenticated;
grant execute on function private.dm_request_hidden(uuid, uuid) to authenticated;
grant execute on function public.edit_post(uuid, text) to authenticated;
grant execute on function public.edit_comment(uuid, text) to authenticated;
grant execute on function public.toggle_bookmark(uuid, boolean) to authenticated;
grant execute on function public.get_bookmarks(text, integer) to authenticated;
grant execute on function public.react_to_message(uuid, text) to authenticated;
grant execute on function public.share_post_to_chat(uuid, uuid, text, uuid) to authenticated;
grant execute on function cs_api.community_edit_history(text, uuid) to authenticated;
