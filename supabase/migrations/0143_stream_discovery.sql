insert into private.settings (key, value, description) values
  ('feed.top_days', '30', 'Feed urutan Top menimbang postingan dalam sekian hari terakhir'),
  ('feed.for_you_days', '7', 'Feed Untuk Anda menimbang postingan dalam sekian hari terakhir'),
  ('suggestions.active_days', '14', 'Saran akun untuk diikuti diambil dari penulis aktif dalam sekian hari terakhir'),
  ('stock_stats.max_codes', '50', 'Maks kode saham per permintaan statistik saham dan feed watchlist')
on conflict (key) do nothing;

alter type public.feed_post add attribute top_comment jsonb;

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
         private.is_official_account(p.author_id),
         case when p.author_id = auth.uid() then p.moderation_status end,
         case when p.comment_count > 0 then (
           select to_jsonb(tc)
           from private.thread_comments(array(
             select c.id from public.comments c
             where c.post_id = p.id
               and c.parent_id is null
               and c.deleted_at is null
               and c.moderation_status = 'visible'
             order by c.like_count + c.reply_count desc, c.seq
             limit 1)) tc)
         end
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  order by u.ord;
$$;

create function private.feed_rank_params()
returns table (top_days integer, for_you_days integer, gravity numeric, max_codes integer)
language sql
stable
security definer
set search_path = ''
as $$
  select private.setting_num('feed.top_days', 30)::integer,
         private.setting_num('feed.for_you_days', 7)::integer,
         greatest(private.setting_num('trending.post_gravity', 1.5), 0.1),
         private.setting_num('stock_stats.max_codes', 50)::integer;
$$;

create function private.post_author_weight(p_author uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select private.author_weight(pr.created_at, pr.trust_level)
                   from public.profiles pr where pr.id = p_author), 1);
$$;

create or replace function private.feed_post_allowed(
  p_post       public.posts,
  p_uid        uuid,
  p_scope      text,
  p_media_only boolean
)
returns boolean
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p_post.deleted_at is null
    and (p_scope = 'user'
         or p_post.author_id not in (select m.muted_id from public.mutes m where m.muter_id = p_uid))
    and (p_scope in ('user', 'stock', 'stocks')
         or not exists (
           select 1 from public.post_stocks ps
           join public.muted_stocks ms on ms.stock_code = ps.stock_code and ms.user_id = p_uid
           where ps.post_id = p_post.id))
    and (p_scope = 'user'
         or not exists (
           select 1 from public.muted_keywords mk
           where mk.user_id = p_uid and strpos(lower(p_post.body), lower(mk.keyword::text)) > 0))
    and (not p_media_only
         or exists (select 1 from jsonb_array_elements(p_post.attachments) a where a ? 'path'));
$$;

drop function if exists public.get_feed(text, text, text, integer, uuid);

create function public.get_feed(
  p_scope       text default 'global',
  p_stock_code  text default null,
  p_cursor      text default null,
  p_limit       integer default 20,
  p_author_id   uuid default null,
  p_sort        text default 'latest',
  p_media_only  boolean default false,
  p_stock_codes text[] default null
)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_scope   text := coalesce(nullif(p_scope, ''), 'global');
  v_sort    text := coalesce(nullif(p_sort, ''), 'latest');
  v_media   boolean := coalesce(p_media_only, false);
  v_limit   integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_codes   text[];
  v_ranked  boolean;
  v_offset  integer := 0;
  v_since   timestamptz;
  v_gravity numeric;
  v_ts      timestamptz;
  v_id      uuid;
  v_ids     uuid[];
  v_params  record;
  v_row     public.feed_post;
  v_n       integer := 0;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_scope not in ('global', 'following', 'stock', 'stocks', 'user', 'official', 'for_you') then
    perform private.api_error(400, 'invalid_scope',
      'scope harus global, following, stock, stocks, user, official, atau for_you');
  end if;
  if v_sort not in ('latest', 'top') then
    perform private.api_error(400, 'invalid_sort', 'Urutan feed harus latest atau top');
  end if;
  select * into v_params from private.feed_rank_params();
  if v_scope in ('stock', 'stocks') then
    v_codes := array(
      select distinct upper(ltrim(btrim(c), '$'))
      from unnest(case when v_scope = 'stock' then array[p_stock_code] else p_stock_codes end) c
      where btrim(coalesce(c, '')) <> '');
    if cardinality(v_codes) = 0 then
      perform private.api_error(400, 'stock_code_required', 'stock_code wajib diisi untuk scope stock');
    end if;
    if cardinality(v_codes) > v_params.max_codes then
      perform private.api_error(400, 'too_many_stocks', 'Terlalu banyak kode saham');
    end if;
  end if;
  if v_scope = 'user' and p_author_id is null then
    perform private.api_error(400, 'author_required', 'author_id wajib diisi untuk scope user');
  end if;

  v_ranked := v_scope = 'for_you' or v_sort = 'top';
  if p_cursor like 'o:%' then
    if not v_ranked then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
    begin
      v_offset := substr(p_cursor, 3)::integer;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_offset < 0 then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  elsif p_cursor is not null and p_cursor <> '' then
    select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
    if v_ranked and v_scope <> 'for_you' then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  end if;

  if v_ranked and v_ts is null then
    v_since := now() - make_interval(days => case when v_scope = 'for_you'
      then v_params.for_you_days else v_params.top_days end);
    v_gravity := v_params.gravity;

    select array_agg(x.id order by x.ord) into v_ids
    from (
      select c.id, c.ord
      from (
        select s.id, row_number() over (order by s.score desc, s.created_at desc, s.id desc) as ord
        from (
          select p.id, p.created_at,
                 case when v_scope = 'for_you' then
                   (p.like_count + 2 * p.comment_count + 1)
                     * private.post_author_weight(p.author_id)
                     * case when p.author_id in (select f.following_id from public.follows f where f.follower_id = v_uid)
                            then 2 else 1 end
                     / power(extract(epoch from (now() - p.created_at)) / 3600 + 2, v_gravity)
                 else (p.like_count + 2 * p.comment_count)::numeric end as score
          from public.posts p
          where (v_scope = 'user' or p.created_at >= v_since)
            and (v_scope <> 'following'
                 or p.author_id = v_uid
                 or p.author_id in (select f.following_id from public.follows f where f.follower_id = v_uid))
            and (v_scope not in ('stock', 'stocks')
                 or exists (select 1 from public.post_stocks ps
                            where ps.post_id = p.id and ps.stock_code = any (v_codes)))
            and (v_scope <> 'user' or p.author_id = p_author_id)
            and (v_scope <> 'official' or private.is_official_account(p.author_id))
            and (v_scope <> 'for_you' or p.author_id <> v_uid)
            and private.feed_post_allowed(p, v_uid, v_scope, v_media)
        ) s
      ) c
      order by c.ord
      offset v_offset
      limit v_limit
    ) x;

    if v_ids is not null or v_scope <> 'for_you' or v_offset > 0 then
      for v_row in select * from private.feed_posts(coalesce(v_ids, '{}')) loop
        v_n := v_n + 1;
        v_row.cursor := 'o:' || (v_offset + v_n);
        return next v_row;
      end loop;
      return;
    end if;
  end if;

  if v_scope in ('stock', 'stocks') then
    select array_agg(x.post_id order by x.post_created_at desc, x.post_id desc) into v_ids
    from (
      select ps.post_id, ps.post_created_at
      from public.post_stocks ps
      join public.posts p on p.id = ps.post_id
      where ps.stock_code = any (v_codes)
        and private.feed_post_allowed(p, v_uid, v_scope, v_media)
        and (v_ts is null or (ps.post_created_at, ps.post_id) < (v_ts, v_id))
      group by ps.post_id, ps.post_created_at
      order by ps.post_created_at desc, ps.post_id desc
      limit v_limit
    ) x;
  else
    select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
    from (
      select p.id, p.created_at
      from public.posts p
      where (v_scope <> 'following'
             or p.author_id = v_uid
             or p.author_id in (select f.following_id from public.follows f where f.follower_id = v_uid))
        and (v_scope <> 'user' or p.author_id = p_author_id)
        and (v_scope <> 'official' or private.is_official_account(p.author_id))
        and private.feed_post_allowed(p, v_uid, case when v_scope = 'for_you' then 'global' else v_scope end, v_media)
        and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
      order by p.created_at desc, p.id desc
      limit v_limit
    ) x;
  end if;

  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

create function public.get_suggested_users(p_limit integer default 5)
returns table (
  id             uuid,
  username       text,
  display_name   text,
  avatar_url     text,
  is_verified    boolean,
  is_official    boolean,
  follower_count integer,
  mutual_count   integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  return query
  with cand as (
    select f2.following_id as profile_id, count(*)::integer as mutual
    from public.follows f1
    join public.follows f2 on f2.follower_id = f1.following_id
    where f1.follower_id = v_uid
    group by f2.following_id
    union all
    select o.profile_id, 0 from cs.official_accounts o where o.disabled_at is null
    union all
    select a.author_id, 0
    from (
      select p.author_id
      from public.posts p
      where p.created_at >= now() - make_interval(days => private.setting_num('suggestions.active_days', 14)::integer)
        and p.deleted_at is null
        and p.moderation_status = 'visible'
      group by p.author_id
      order by count(*) desc
      limit 200
    ) a
  ),
  ranked as (
    select c.profile_id, sum(c.mutual)::integer as mutual
    from cand c
    group by c.profile_id
  )
  select pr.id, pr.username::text, pr.display_name, pr.avatar_url, pr.is_verified,
         private.is_official_account(pr.id), pr.follower_count, r.mutual
  from ranked r
  join public.profiles pr on pr.id = r.profile_id
  where pr.id <> v_uid
    and pr.deleted_at is null
    and not pr.is_guest
    and not cs.is_staff(pr.id)
    and not private.is_banned(pr.id)
    and not exists (select 1 from public.follows f where f.follower_id = v_uid and f.following_id = pr.id)
    and not exists (select 1 from public.blocks b
                    where (b.blocker_id = v_uid and b.blocked_id = pr.id)
                       or (b.blocker_id = pr.id and b.blocked_id = v_uid))
    and not exists (select 1 from public.mutes m where m.muter_id = v_uid and m.muted_id = pr.id)
  order by r.mutual desc, private.is_official_account(pr.id) desc, pr.follower_count desc, pr.username
  limit least(greatest(coalesce(p_limit, 5), 1), 20);
end;
$$;

create function public.get_market_sentiment(p_window text default '24h')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_window text := coalesce(nullif(btrim(p_window), ''), '24h');
  r        record;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_window not in ('24h', '7d') then
    perform private.api_error(400, 'invalid_window', 'window harus 24h atau 7d');
  end if;

  select count(*)::integer as posts,
         count(*) filter (where p.sentiment = 'bullish')::integer as bullish,
         count(*) filter (where p.sentiment = 'bearish')::integer as bearish,
         count(*) filter (where p.sentiment = 'neutral')::integer as neutral,
         coalesce(sum(private.author_weight(pr.created_at, pr.trust_level)) filter (where p.sentiment = 'bullish'), 0) as w_bullish,
         coalesce(sum(private.author_weight(pr.created_at, pr.trust_level)) filter (where p.sentiment = 'bearish'), 0) as w_bearish,
         coalesce(sum(private.author_weight(pr.created_at, pr.trust_level)) filter (where p.sentiment = 'neutral'), 0) as w_neutral
    into r
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  where p.created_at >= now() - case v_window when '24h' then interval '24 hours' else interval '7 days' end
    and p.deleted_at is null
    and p.moderation_status = 'visible'
    and pr.deleted_at is null;

  return jsonb_build_object(
    'window', v_window,
    'posts', r.posts, 'bullish', r.bullish, 'bearish', r.bearish, 'neutral', r.neutral,
    'unlabeled', r.posts - r.bullish - r.bearish - r.neutral,
    'bullish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                        then round(100 * r.w_bullish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
    'bearish_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                        then round(100 * r.w_bearish / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
    'neutral_pct', case when r.w_bullish + r.w_bearish + r.w_neutral > 0
                        then round(100 * r.w_neutral / (r.w_bullish + r.w_bearish + r.w_neutral)) end,
    'updated_at', now());
end;
$$;

create function public.get_stock_stats(p_codes text[])
returns table (code text, posts_today integer, bullish_pct integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_codes text[];
  v_today timestamptz := date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_codes := array(
    select distinct upper(ltrim(btrim(c), '$'))
    from unnest(coalesce(p_codes, '{}')) c
    where upper(ltrim(btrim(c), '$')) ~ '^[A-Z][A-Z0-9]{1,11}$');
  if cardinality(v_codes) > private.setting_num('stock_stats.max_codes', 50) then
    perform private.api_error(400, 'too_many_stocks', 'Terlalu banyak kode saham');
  end if;

  return query
  select c.code,
         coalesce(sum(b.posts), 0)::integer,
         case when coalesce(sum(b.w_bullish + b.w_bearish + b.w_neutral), 0) > 0
              then round(100 * sum(b.w_bullish) / sum(b.w_bullish + b.w_bearish + b.w_neutral))::integer end
  from unnest(v_codes) as c(code)
  left join private.stock_mention_buckets b on b.stock_code = c.code and b.bucket >= v_today
  group by c.code
  order by c.code;
end;
$$;

revoke execute on function private.feed_rank_params() from public;
revoke execute on function private.post_author_weight(uuid) from public;
grant execute on function private.feed_rank_params() to authenticated;
grant execute on function private.post_author_weight(uuid) to authenticated;
revoke execute on function private.feed_post_allowed(public.posts, uuid, text, boolean) from public;
grant execute on function private.feed_post_allowed(public.posts, uuid, text, boolean) to authenticated;
revoke execute on function public.get_feed(text, text, text, integer, uuid, text, boolean, text[]) from public, anon;
revoke execute on function public.get_suggested_users(integer) from public, anon;
revoke execute on function public.get_market_sentiment(text) from public, anon;
revoke execute on function public.get_stock_stats(text[]) from public, anon;
grant execute on function public.get_feed(text, text, text, integer, uuid, text, boolean, text[]) to authenticated;
grant execute on function public.get_suggested_users(integer) to authenticated;
grant execute on function public.get_market_sentiment(text) to authenticated;
grant execute on function public.get_stock_stats(text[]) to authenticated;
