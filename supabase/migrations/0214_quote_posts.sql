alter table public.posts
  add column quoted_post_id uuid references public.posts(id) on delete set null,
  add column quote_count integer not null default 0;
create index posts_quoted_post_idx on public.posts (quoted_post_id, created_at desc, id desc)
  where quoted_post_id is not null;
grant insert (quoted_post_id) on public.posts to authenticated;

alter type public.feed_post
  add attribute quoted_post jsonb,
  add attribute quote_count integer,
  add attribute can_quote boolean;

alter table public.notifications drop constraint notifications_type;
alter table public.notifications add constraint notifications_type
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share', 'quote'));

alter table private.notification_prefs drop constraint notification_prefs_type_check;
alter table private.notification_prefs add constraint notification_prefs_type_check
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share', 'quote',
                  'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'));

create or replace function private.notification_pref_types()
returns text[]
language sql
stable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
               'followed_post', 'watchlist_digest', 'moderation', 'quote']
         || case when private.trade_share_enabled() then array['trade_activity', 'trade_share'] else array[]::text[] end
         || array['olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'];
$$;

create or replace function private.notification_pref_type(p_kind text, p_category text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_kind in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                    'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share', 'quote') then p_kind
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

create function private.quote_restriction(p_post uuid, p_viewer uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  select q.id, q.author_id, q.deleted_at, q.moderation_status, q.comment_audience,
         pr.deleted_at as author_deleted, pr.is_guest
    into v_row
  from public.posts q
  join public.profiles pr on pr.id = q.author_id
  where q.id = p_post;
  if v_row.id is null or v_row.deleted_at is not null or v_row.moderation_status <> 'visible'
     or v_row.author_deleted is not null or v_row.is_guest
     or private.has_active_sanction(v_row.author_id, '{ban}')
     or (p_viewer is not null and private.is_blocked_pair(p_viewer, v_row.author_id)) then
    return 'unavailable';
  end if;
  if v_row.author_id = p_viewer then
    return null;
  end if;
  if private.comment_restriction(
       v_row.author_id,
       case when private.comments_all_off(v_row.author_id) then 'off'::public.comment_audience
            else v_row.comment_audience end,
       p_viewer) is not null then
    return 'restricted';
  end if;
  return null;
end;
$$;

create function private.quoted_post_view(p_id uuid, p_viewer uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  if p_id is null then
    return null;
  end if;
  select q.id, q.author_id, q.body, q.sentiment, q.attachments, q.created_at, q.edited_at, q.deleted_at,
         q.moderation_status, pr.username::text as username, pr.display_name, pr.avatar_url, pr.is_verified,
         pr.deleted_at as author_deleted
    into v_row
  from public.posts q
  join public.profiles pr on pr.id = q.author_id
  where q.id = p_id;
  if v_row.id is null or v_row.deleted_at is not null or v_row.moderation_status <> 'visible'
     or v_row.author_deleted is not null or private.has_active_sanction(v_row.author_id, '{ban}')
     or (p_viewer is not null and private.is_blocked_pair(p_viewer, v_row.author_id)) then
    return jsonb_build_object('id', p_id, 'available', false);
  end if;
  return jsonb_build_object(
    'id', v_row.id,
    'available', true,
    'author_id', v_row.author_id,
    'username', v_row.username,
    'display_name', v_row.display_name,
    'avatar_url', v_row.avatar_url,
    'is_verified', v_row.is_verified,
    'is_official', private.is_official_account(v_row.author_id),
    'body', v_row.body,
    'sentiment', v_row.sentiment,
    'attachments', coalesce(v_row.attachments, '[]'::jsonb),
    'stocks', coalesce((select jsonb_agg(ps.stock_code order by ps.stock_code)
                        from public.post_stocks ps where ps.post_id = v_row.id), '[]'::jsonb),
    'created_at', v_row.created_at,
    'edited_at', v_row.edited_at);
end;
$$;

create function private.posts_quote_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_restriction text;
begin
  if tg_op = 'UPDATE' then
    if new.quoted_post_id is distinct from old.quoted_post_id and new.quoted_post_id is not null then
      perform private.api_error(400, 'quote_immutable', 'Postingan yang dikutip tidak bisa diubah');
    end if;
    return new;
  end if;
  if new.quoted_post_id is null then
    return new;
  end if;
  if new.quoted_post_id = new.id then
    perform private.api_error(400, 'invalid_quote', 'Postingan tidak bisa mengutip dirinya sendiri');
  end if;
  v_restriction := private.quote_restriction(new.quoted_post_id, new.author_id);
  if v_restriction = 'unavailable' then
    perform private.api_error(404, 'quoted_post_not_found', 'Postingan yang dikutip tidak ditemukan');
  elsif v_restriction is not null then
    perform private.api_error(403, 'quote_not_allowed',
      'Pemilik postingan membatasi siapa yang bisa membalas, jadi postingan ini tidak bisa dikutip');
  end if;
  return new;
end;
$$;

create trigger posts_05_quote_guard
  before insert or update of quoted_post_id on public.posts
  for each row execute function private.posts_quote_guard();

create function private.refresh_quote_count(p_post uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.posts p
     set quote_count = c.n
    from (select count(*)::integer as n from public.posts q
          where q.quoted_post_id = p_post and q.deleted_at is null and q.moderation_status = 'visible') c
   where p.id = p_post and p.quote_count is distinct from c.n;
$$;

create function private.posts_quote_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author uuid;
begin
  if tg_op = 'DELETE' then
    perform private.refresh_quote_count(old.quoted_post_id);
    return null;
  end if;
  perform private.refresh_quote_count(new.quoted_post_id);
  if tg_op = 'INSERT' and new.moderation_status = 'visible' and new.deleted_at is null then
    select q.author_id into v_author from public.posts q where q.id = new.quoted_post_id;
    perform private.notify(v_author, new.author_id, 'quote',
      jsonb_build_object('post_id', new.quoted_post_id, 'quote_post_id', new.id, 'snippet', private.snippet(new.body)),
      'quotes:post:' || new.quoted_post_id);
  end if;
  return null;
end;
$$;

create trigger posts_quote_inserted
  after insert on public.posts
  for each row when (new.quoted_post_id is not null)
  execute function private.posts_quote_changed();
create trigger posts_quote_updated
  after update of deleted_at, moderation_status on public.posts
  for each row when (new.quoted_post_id is not null
                     and (old.deleted_at is distinct from new.deleted_at
                          or old.moderation_status is distinct from new.moderation_status))
  execute function private.posts_quote_changed();
create trigger posts_quote_deleted
  after delete on public.posts
  for each row when (old.quoted_post_id is not null)
  execute function private.posts_quote_changed();

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
         p.reaction_summary,
         private.quoted_post_view(p.quoted_post_id, auth.uid()),
         p.quote_count,
         auth.uid() is not null and p.deleted_at is null and p.moderation_status = 'visible'
           and (p.author_id = auth.uid() or cr.restriction is null)
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

drop function public.create_post(text, text, jsonb, uuid, jsonb, text);
create function public.create_post(
  p_body             text,
  p_sentiment        text default null,
  p_attachments      jsonb default '[]'::jsonb,
  p_client_id        uuid default null,
  p_poll             jsonb default null,
  p_comment_audience text default null,
  p_quoted_post_id   uuid default null
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
  if p_quoted_post_id is not null and p_poll is not null then
    perform private.api_error(400, 'invalid_quote', 'Kutipan tidak bisa disertai polling');
  end if;
  if p_poll is not null then
    perform private.validate_poll(p_poll, p_attachments);
  end if;

  insert into public.posts (author_id, body, sentiment, attachments, client_id, comment_audience, quoted_post_id)
  values (auth.uid(), coalesce(p_body, ''), p_sentiment, coalesce(p_attachments, '[]'::jsonb), p_client_id, v_audience,
          p_quoted_post_id)
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

create function public.post_quotes(p_post_id uuid, p_cursor text default null, p_limit integer default 20)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
  select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
  from (
    select p.id, p.created_at
    from public.posts p
    where p.quoted_post_id = p_post_id
      and p.deleted_at is null
      and p.moderation_status = 'visible'
      and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
    order by p.created_at desc, p.id desc
    limit v_limit
  ) x;
  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

revoke execute on function private.notification_pref_types() from public;
revoke execute on function private.quote_restriction(uuid, uuid) from public;
revoke execute on function private.quoted_post_view(uuid, uuid) from public;
revoke execute on function private.posts_quote_guard() from public;
revoke execute on function private.refresh_quote_count(uuid) from public;
revoke execute on function private.posts_quote_changed() from public;
revoke execute on function public.create_post(text, text, jsonb, uuid, jsonb, text, uuid) from public, anon;
revoke execute on function public.post_quotes(uuid, text, integer) from public, anon;

grant execute on function private.quoted_post_view(uuid, uuid) to authenticated;
grant execute on function public.create_post(text, text, jsonb, uuid, jsonb, text, uuid) to authenticated;
grant execute on function public.post_quotes(uuid, text, integer) to authenticated;
