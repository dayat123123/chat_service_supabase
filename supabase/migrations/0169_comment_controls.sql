create type public.comment_audience as enum ('everyone', 'following', 'followers', 'following_and_followers', 'off');

alter table public.posts add column comment_audience public.comment_audience not null default 'everyone';
create index posts_comments_off_idx on public.posts (id) where comment_audience = 'off';
grant insert (comment_audience) on public.posts to authenticated;

create table private.comment_preferences (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  audience   public.comment_audience not null default 'everyone',
  updated_at timestamptz not null default now(),
  constraint comment_preferences_not_off check (audience <> 'off')
);
alter table private.comment_preferences enable row level security;

create function private.comment_default_audience(p_user uuid)
returns public.comment_audience
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.audience from private.comment_preferences c where c.user_id = p_user),
                  'everyone'::public.comment_audience);
$$;

create function private.parse_comment_audience(p_value text, p_allow_off boolean)
returns public.comment_audience
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_value is null
     or p_value not in ('everyone', 'following', 'followers', 'following_and_followers', 'off')
     or (p_value = 'off' and not p_allow_off) then
    perform private.api_error(400, 'invalid_comment_audience',
      case when p_allow_off
           then 'Pilihan: everyone, following, followers, following_and_followers, atau off'
           else 'Pilihan: everyone, following, followers, atau following_and_followers' end);
  end if;
  return p_value::public.comment_audience;
end;
$$;

create function private.comment_restriction(p_author uuid, p_audience public.comment_audience, p_viewer uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_audience = 'off' then 'off'
    when p_viewer is null then 'blocked'
    when p_viewer = p_author then null
    when private.is_blocked_pair(p_viewer, p_author) then 'blocked'
    when p_audience = 'everyone' then null
    when p_audience = 'following' and private.is_following(p_author, p_viewer) then null
    when p_audience = 'followers' and private.is_following(p_viewer, p_author) then null
    when p_audience = 'following_and_followers'
         and (private.is_following(p_author, p_viewer) or private.is_following(p_viewer, p_author)) then null
    else p_audience::text
  end;
$$;

create function private.comments_off_post_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from public.posts p where p.comment_audience = 'off';
$$;

create function private.comments_enforce_audience()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post        public.posts;
  v_restriction text;
begin
  select * into v_post from public.posts p where p.id = new.post_id;
  if not found then
    return new;
  end if;
  v_restriction := private.comment_restriction(v_post.author_id, v_post.comment_audience, new.author_id);
  if v_restriction = 'off' then
    perform private.api_error(403, 'comments_off', 'Komentar untuk postingan ini dinonaktifkan');
  elsif v_restriction = 'blocked' then
    perform private.api_error(403, 'blocked', 'Tidak bisa berkomentar di post ini');
  elsif v_restriction is not null then
    perform private.api_error(403, 'comments_restricted', 'Anda tidak termasuk yang boleh berkomentar di postingan ini');
  end if;
  return new;
end;
$$;

create trigger comments_25_comment_audience
  before insert on public.comments
  for each row execute function private.comments_enforce_audience();

create policy comments_hidden_when_off on public.comments
  as restrictive
  for select to authenticated
  using (post_id not in (select private.comments_off_post_ids()));

alter type public.feed_post
  add attribute comment_audience text,
  add attribute can_comment boolean,
  add attribute comment_restriction text;

create or replace function private.feed_posts(p_ids uuid[])
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.author_id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         p.body, p.sentiment, p.attachments, p.like_count,
         case when p.comment_audience = 'off' and p.author_id is distinct from auth.uid() then null
              else p.comment_count end,
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
         private.is_official_account(p.author_id),
         case when p.author_id = auth.uid() then p.moderation_status end,
         case when p.comment_count > 0 and p.comment_audience <> 'off' then (
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
         cr.restriction
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  cross join lateral (
    select private.comment_restriction(p.author_id, p.comment_audience, auth.uid()) as restriction) cr
  order by u.ord;
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
             'like_count', p.like_count,
             'comment_count', case when p.comment_audience = 'off' and p.author_id is distinct from p_viewer then null
                                   else p.comment_count end,
             'created_at', p.created_at)
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

drop function public.create_post(text, text, jsonb, uuid, jsonb);
create function public.create_post(
  p_body             text,
  p_sentiment        text default null,
  p_attachments      jsonb default '[]'::jsonb,
  p_client_id        uuid default null,
  p_poll             jsonb default null,
  p_comment_audience text default null
)
returns setof public.feed_post
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_id       uuid;
  v_audience public.comment_audience;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_audience := case when p_comment_audience is null then private.comment_default_audience(auth.uid())
                     else private.parse_comment_audience(p_comment_audience, true) end;
  if p_poll is not null then
    perform private.validate_poll(p_poll, p_attachments);
  end if;

  insert into public.posts (author_id, body, sentiment, attachments, client_id, comment_audience)
  values (auth.uid(), coalesce(p_body, ''), p_sentiment, coalesce(p_attachments, '[]'::jsonb), p_client_id, v_audience)
  on conflict (author_id, client_id) where client_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.posts where author_id = auth.uid() and client_id = p_client_id;
  elsif p_poll is not null then
    perform private.create_poll(v_id, p_poll);
  end if;

  return query select * from private.feed_posts(array[v_id]);
end;
$$;

create function public.get_comment_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return jsonb_build_object('audience', private.comment_default_audience(auth.uid())::text);
end;
$$;

create function public.set_comment_audience(p_audience text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_audience public.comment_audience;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_audience := private.parse_comment_audience(p_audience, false);
  insert into private.comment_preferences (user_id, audience) values (auth.uid(), v_audience)
  on conflict (user_id) do update set audience = excluded.audience, updated_at = now();
  return public.get_comment_settings();
end;
$$;

create function private.set_post_comment_audience_row(p_post_id uuid, p_audience public.comment_audience)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
begin
  select p.author_id into v_author from public.posts p
  where p.id = p_post_id and p.deleted_at is null
  for update;
  if not found then
    perform private.api_error(404, 'post_not_found', 'Post tidak ditemukan');
  end if;
  if v_author is distinct from auth.uid() then
    perform private.api_error(403, 'forbidden', 'Hanya pemilik yang bisa mengatur komentar postingan ini');
  end if;
  update public.posts p set comment_audience = p_audience
  where p.id = p_post_id and p.comment_audience is distinct from p_audience;
end;
$$;

create function public.set_post_comment_audience(p_post_id uuid, p_audience text)
returns setof public.feed_post
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.set_post_comment_audience_row(p_post_id, private.parse_comment_audience(p_audience, true));
  return query select * from private.feed_posts(array[p_post_id]);
end;
$$;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.consume_rate_limit(v_uid, 'data_export');
  perform private.log_personal_data_access(v_uid, 'self_export', '{all}');

  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'olt_user_id' from public.profiles p where p.id = v_uid),
    'email', (select up.email from private.user_private up where up.user_id = v_uid),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'body', body, 'sentiment', sentiment, 'attachments', attachments,
        'comment_audience', comment_audience, 'created_at', created_at, 'edited_at', edited_at) order by created_at)
      from public.posts where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'polls', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', pl.post_id, 'ends_at', pl.ends_at,
        'options', (select jsonb_agg(o.label order by o.position)
                    from public.post_poll_options o where o.post_id = pl.post_id))
        order by pl.created_at)
      from public.post_polls pl join public.posts p on p.id = pl.post_id
      where p.author_id = v_uid and p.deleted_at is null), '[]'::jsonb),
    'poll_votes', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', v.post_id, 'option', o.label, 'created_at', v.created_at) order by v.created_at)
      from public.post_poll_votes v join public.post_poll_options o on o.id = v.option_id
      where v.user_id = v_uid), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'post_id', post_id, 'parent_id', parent_id, 'body', body, 'created_at', created_at)
        order by created_at)
      from public.comments where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'room_id', room_id, 'body', body, 'attachments', attachments, 'created_at', created_at)
        order by created_at)
      from public.messages where sender_id = v_uid and deleted_at is null), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) - 'user_id') from public.reactions r
      where r.user_id = v_uid), '[]'::jsonb),
    'message_reactions', coalesce((select jsonb_agg(jsonb_build_object(
        'message_id', mr.message_id, 'emoji', mr.emoji, 'created_at', mr.created_at) order by mr.created_at)
      from public.message_reactions mr where mr.user_id = v_uid), '[]'::jsonb),
    'bookmarks', coalesce((select jsonb_agg(jsonb_build_object('post_id', b.post_id, 'created_at', b.created_at)
                                            order by b.created_at)
      from public.bookmarks b where b.user_id = v_uid), '[]'::jsonb),
    'following', coalesce((select jsonb_agg(f.following_id) from public.follows f
      where f.follower_id = v_uid), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(b.blocked_id) from public.blocks b
      where b.blocker_id = v_uid), '[]'::jsonb),
    'muted_users', coalesce((select jsonb_agg(m.muted_id) from public.mutes m
      where m.muter_id = v_uid), '[]'::jsonb),
    'muted_keywords', coalesce((select jsonb_agg(k.keyword) from public.muted_keywords k
      where k.user_id = v_uid), '[]'::jsonb),
    'muted_stocks', coalesce((select jsonb_agg(s.stock_code) from public.muted_stocks s
      where s.user_id = v_uid), '[]'::jsonb),
    'watchlist', coalesce((select jsonb_agg(w.stock_code) from public.stock_watchers w
      where w.user_id = v_uid), '[]'::jsonb),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
        'target_type', target_type, 'target_id', target_id, 'reason', reason,
        'status', status, 'created_at', created_at))
      from public.reports where reporter_id = v_uid), '[]'::jsonb),
    'consents', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', d.kind, 'version', d.version, 'title', d.title, 'accepted_at', c.accepted_at)
        order by c.accepted_at)
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb),
    'support_tickets', coalesce((select jsonb_agg(jsonb_build_object(
        'ticket_number', t.ticket_number, 'topic', t.topic, 'status', t.status, 'created_at', t.created_at,
        'closed_at', t.closed_at, 'rating', t.rating, 'rating_comment', t.rating_comment)
        order by t.created_at)
      from cs.tickets t where t.customer_id = v_uid), '[]'::jsonb),
    'push_devices', coalesce((select jsonb_agg(jsonb_build_object(
        'platform', d.platform, 'locale', d.locale, 'app_version', d.app_version,
        'created_at', d.created_at, 'last_seen_at', d.last_seen_at) order by d.created_at)
      from private.push_devices d where d.user_id = v_uid), '[]'::jsonb),
    'notification_preferences', private.notification_prefs_view(v_uid),
    'dm_policy', private.dm_policy(v_uid),
    'comment_audience', private.comment_default_audience(v_uid)::text,
    'linked_accounts', private.export_optional('linked_accounts', v_uid),
    'appeals', private.export_optional('appeals', v_uid),
    'analytics_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'created_at', e.created_at, 'platform', e.platform, 'app_version', e.app_version,
        'props', e.props) order by e.created_at desc)
      from (select * from private.analytics_events a where a.user_id = v_uid order by a.created_at desc limit 5000) e),
      '[]'::jsonb),
    'post_drafts', coalesce((select jsonb_agg(private.post_draft_view(d) order by d.updated_at desc)
      from public.post_drafts d where d.user_id = v_uid), '[]'::jsonb),
    'notification_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'source_type', e.source_type, 'source_id', e.source_id,
        'notification_id', e.notification_id, 'created_at', e.created_at) order by e.created_at desc)
      from (select * from private.notification_events ne where ne.user_id = v_uid
            order by ne.created_at desc limit 5000) e), '[]'::jsonb),
    'trade_share', private.trade_share_export_user(v_uid)
  );
end;
$$;

revoke execute on function private.comment_default_audience(uuid) from public;
revoke execute on function private.parse_comment_audience(text, boolean) from public;
revoke execute on function private.comment_restriction(uuid, public.comment_audience, uuid) from public;
revoke execute on function private.comments_off_post_ids() from public;
revoke execute on function private.comments_enforce_audience() from public;
revoke execute on function private.set_post_comment_audience_row(uuid, public.comment_audience) from public;
revoke execute on function public.create_post(text, text, jsonb, uuid, jsonb, text) from public, anon;
revoke execute on function public.get_comment_settings() from public, anon;
revoke execute on function public.set_comment_audience(text) from public, anon;
revoke execute on function public.set_post_comment_audience(uuid, text) from public, anon;

grant execute on function private.parse_comment_audience(text, boolean) to authenticated;
grant execute on function private.comment_default_audience(uuid) to authenticated;
grant execute on function private.comment_restriction(uuid, public.comment_audience, uuid) to authenticated;
grant execute on function private.comments_off_post_ids() to authenticated;
grant execute on function private.set_post_comment_audience_row(uuid, public.comment_audience) to authenticated;
grant execute on function public.create_post(text, text, jsonb, uuid, jsonb, text) to authenticated;
grant execute on function public.get_comment_settings() to authenticated;
grant execute on function public.set_comment_audience(text) to authenticated;
grant execute on function public.set_post_comment_audience(uuid, text) to authenticated;
