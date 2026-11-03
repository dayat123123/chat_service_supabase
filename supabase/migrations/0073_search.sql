insert into private.settings (key, value, description) values
  ('search.min_query_length', '2', 'Panjang minimum kata kunci pencarian (karakter)'),
  ('search.typo_min_length', '4', 'Pencarian toleran salah ketik (trigram) dipakai bila kata kunci minimal sekian karakter'),
  ('trending.new_account_days', '7', 'Akun yang lebih muda dari sekian hari berbobot rendah di trending'),
  ('trending.new_account_weight', '0.2', 'Bobot akun baru atau trust_level 0 di trending (0-1)'),
  ('trending.min_authors', '2', 'Hashtag/saham baru masuk trending bila dibahas minimal sekian penulis berbeda')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('search', 30, 60),
  ('search', 600, 3600)
on conflict (action, window_seconds) do nothing;

create table private.post_search (
  post_id       uuid primary key references public.posts (id) on delete cascade,
  search_vector tsvector not null
);
create index post_search_vector_idx on private.post_search using gin (search_vector);
alter table private.post_search enable row level security;

create index if not exists posts_body_trgm_idx
  on public.posts using gin (body extensions.gin_trgm_ops) where deleted_at is null;
create index if not exists profiles_display_name_trgm_idx
  on public.profiles using gin (display_name extensions.gin_trgm_ops);
create index if not exists post_stocks_created_idx on public.post_stocks (post_created_at);

create table public.post_hashtags (
  post_id         uuid not null references public.posts (id) on delete cascade,
  tag             text not null check (tag ~ '^[a-z0-9_]{2,50}$'),
  post_created_at timestamptz not null,
  primary key (post_id, tag)
);
create index post_hashtags_feed_idx on public.post_hashtags (tag, post_created_at desc, post_id desc);
create index post_hashtags_created_idx on public.post_hashtags (post_created_at);
alter table public.post_hashtags enable row level security;
revoke all on public.post_hashtags from anon, authenticated;
grant select on public.post_hashtags to authenticated;
create policy post_hashtags_select on public.post_hashtags for select to authenticated using (true);

create table private.hashtags (
  tag           text collate "C" primary key,
  first_used_at timestamptz not null default now()
);
alter table private.hashtags enable row level security;

create table private.stock_codes (
  code          text collate "C" primary key check (code ~ '^[A-Z][A-Z0-9]{1,11}$'),
  first_seen_at timestamptz not null default now()
);
alter table private.stock_codes enable row level security;

create or replace function private.post_search_document(p_body text)
returns tsvector
language sql
immutable
set search_path = ''
as $$
  select setweight(to_tsvector('indonesian'::regconfig, coalesce(p_body, '')), 'A')
      || setweight(to_tsvector('simple'::regconfig, coalesce(p_body, '')), 'B');
$$;

create or replace function private.extract_hashtags(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(s.tag order by s.first_pos), '{}')
  from (
    select lower(m[1]) as tag, min(ord) as first_pos
    from regexp_matches(coalesce(p_text, ''),
                        '(?<![[:alnum:]_#&/])#([A-Za-z0-9_]{2,50})(?![A-Za-z0-9_])', 'g')
         with ordinality as t(m, ord)
    group by lower(m[1])
  ) s
  where s.tag ~ '^[a-z0-9_]{2,50}$';
$$;

create or replace function private.search_terms(p_query text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce((array_agg(t.w order by t.n))[1:8], '{}')
  from regexp_split_to_table(lower(coalesce(p_query, '')), '[^[:alnum:]]+') with ordinality as t(w, n)
  where t.w <> '';
$$;

create or replace function private.search_tsquery(p_terms text[])
returns tsquery
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  if p_terms is null or cardinality(p_terms) = 0 then
    return null;
  end if;
  v_text := array_to_string(p_terms, ' & ');
  return to_tsquery('indonesian'::regconfig, v_text) || to_tsquery('simple'::regconfig, v_text || ':*');
end;
$$;

create or replace function private.author_weight(p_created_at timestamptz, p_trust_level smallint)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_trust_level = 0
      or p_created_at > now() - make_interval(days => private.setting_num('trending.new_account_days', 7)::integer)
      then least(greatest(private.setting_num('trending.new_account_weight', 0.2), 0), 1)
    else 1
  end;
$$;

create or replace function private.posts_sync_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tags text[];
begin
  if new.deleted_at is not null then
    delete from private.post_search where post_id = new.id;
    delete from public.post_hashtags where post_id = new.id;
    return null;
  end if;
  if tg_op = 'UPDATE' and new.body is not distinct from old.body and old.deleted_at is null then
    return null;
  end if;

  insert into private.post_search (post_id, search_vector)
  values (new.id, private.post_search_document(new.body))
  on conflict (post_id) do update set search_vector = excluded.search_vector;

  v_tags := (private.extract_hashtags(new.body))[1:10];
  delete from public.post_hashtags where post_id = new.id and tag <> all (v_tags);
  insert into public.post_hashtags (post_id, tag, post_created_at)
  select new.id, t.tag, new.created_at from unnest(v_tags) as t(tag)
  on conflict do nothing;
  return null;
end;
$$;

create or replace function private.hashtags_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.hashtags (tag) values (new.tag) on conflict do nothing;
  return null;
end;
$$;

create or replace function private.stock_codes_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.stock_codes (code) values (new.stock_code) on conflict do nothing;
  return null;
end;
$$;

create trigger posts_42_search
  after insert or update of body, deleted_at on public.posts
  for each row execute function private.posts_sync_search();
create trigger post_hashtags_40_directory
  after insert on public.post_hashtags
  for each row execute function private.hashtags_directory();
create trigger post_stocks_40_directory
  after insert on public.post_stocks
  for each row execute function private.stock_codes_directory();
create trigger stock_watchers_40_directory
  after insert on public.stock_watchers
  for each row execute function private.stock_codes_directory();

insert into private.post_search (post_id, search_vector)
select p.id, private.post_search_document(p.body) from public.posts p where p.deleted_at is null
on conflict do nothing;

insert into public.post_hashtags (post_id, tag, post_created_at)
select p.id, t.tag, p.created_at
from public.posts p
cross join lateral unnest((private.extract_hashtags(p.body))[1:10]) as t(tag)
where p.deleted_at is null
on conflict do nothing;

insert into private.stock_codes (code)
select c.code from (
  select stock_code as code from public.post_stocks
  union select stock_code from public.stock_watchers
  union select stock_code from public.chat_rooms where type = 'stock'
) c
where c.code ~ '^[A-Z][A-Z0-9]{1,11}$'
on conflict do nothing;

create or replace function private.search_page_size(p_limit integer, p_default integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_limit, p_default), 1), 50);
$$;

create or replace function private.search_offset(p_cursor text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_offset integer;
begin
  if coalesce(p_cursor, '') = '' then
    return 0;
  end if;
  if p_cursor !~ '^o:[0-9]{1,4}$' then
    perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
  end if;
  v_offset := substr(p_cursor, 3)::integer;
  if v_offset > 1000 then
    perform private.api_error(400, 'invalid_cursor', 'Hasil pencarian dibatasi 1000 baris');
  end if;
  return v_offset;
end;
$$;

create or replace function private.search_posts(p_uid uuid, p_query text, p_terms text[], p_cursor text,
                                                p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tsq   tsquery := private.search_tsquery(p_terms);
  v_typo  boolean := char_length(p_query) >= private.setting_num('search.typo_min_length', 4);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
  v_items jsonb;
begin
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
  from (
    select p.id, p.created_at
    from (
      select s.post_id from private.post_search s where v_tsq is not null and s.search_vector @@ v_tsq
      union
      select p2.id from public.posts p2
      where v_typo and p2.deleted_at is null and p_query operator(extensions.<%) p2.body
    ) m
    join public.posts p on p.id = m.post_id
    where p.deleted_at is null
      and (p.moderation_status = 'visible' or p.author_id = p_uid)
      and p.author_id not in (select private.blocked_user_ids())
      and p.author_id not in (select mu.muted_id from public.mutes mu where mu.muter_id = p_uid)
      and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
    order by p.created_at desc, p.id desc
    limit p_limit + 1
  ) x;

  select coalesce(jsonb_agg(to_jsonb(f) order by u.ord), '[]') into v_items
  from unnest(coalesce(v_ids[1:p_limit], '{}')) with ordinality as u(id, ord)
  join private.feed_posts(coalesce(v_ids[1:p_limit], '{}')) f on f.id = u.id;

  return jsonb_build_object(
    'items', v_items,
    'next_cursor', case when cardinality(v_ids) > p_limit then v_items -> (p_limit - 1) ->> 'cursor' end);
end;
$$;

create or replace function private.search_users(p_uid uuid, p_query text, p_offset integer, p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term  text := ltrim(btrim(p_query), '@');
  v_like  text := replace(replace(replace(ltrim(btrim(p_query), '@'), '\', '\\'), '%', '\%'), '_', '\_');
  v_typo  boolean := char_length(ltrim(btrim(p_query), '@')) >= private.setting_num('search.typo_min_length', 4);
  v_rows  jsonb;
begin
  select coalesce(jsonb_agg(r.item order by r.n), '[]') into v_rows
  from (
    select jsonb_build_object(
             'id', p.id, 'username', p.username::text, 'display_name', p.display_name,
             'avatar_url', p.avatar_url, 'is_verified', p.is_verified, 'follower_count', p.follower_count,
             'is_official', exists (select 1 from cs.official_accounts o
                                    where o.profile_id = p.id and o.disabled_at is null),
             'is_following', exists (select 1 from public.follows f
                                     where f.follower_id = p_uid and f.following_id = p.id),
             'is_me', p.id = p_uid) as item,
           row_number() over (
             order by (lower(p.username::text) = lower(v_term)) desc,
                      (p.username::text ilike v_like || '%') desc,
                      extensions.similarity(p.username::text, v_term) desc,
                      p.follower_count desc, p.username) as n
    from public.profiles p
    where p.deleted_at is null
      and p.olt_user_id not like 'cs-staff:%'
      and (p.username::text ilike v_like || '%'
           or p.display_name ilike '%' || v_like || '%'
           or (v_typo and p.username::text operator(extensions.%) v_term))
      and p.id not in (select private.blocked_user_ids())
      and not exists (
        select 1 from private.user_sanctions s
        where s.user_id = p.id and s.kind = 'ban' and s.revoked_at is null
          and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()))
    order by n
    offset p_offset
    limit p_limit + 1
  ) r;

  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(e.value order by e.ordinality)
                       from jsonb_array_elements(v_rows) with ordinality e
                       where e.ordinality <= p_limit), '[]'),
    'next_cursor', case when jsonb_array_length(v_rows) > p_limit then 'o:' || (p_offset + p_limit) end);
end;
$$;

create or replace function private.search_stocks(p_uid uuid, p_query text, p_offset integer, p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_prefix text := upper(ltrim(btrim(p_query), '$'));
  v_rows   jsonb;
begin
  if v_prefix !~ '^[A-Z][A-Z0-9]{0,11}$' then
    return jsonb_build_object('items', '[]'::jsonb, 'next_cursor', null);
  end if;

  select coalesce(jsonb_agg(r.item order by r.n), '[]') into v_rows
  from (
    select jsonb_build_object('code', s.code, 'posts_7d', s.posts_7d, 'watcher_count', s.watchers,
                              'is_watching', s.watching) as item,
           row_number() over (order by (s.code = v_prefix) desc, s.posts_7d desc, s.watchers desc, s.code) as n
    from (
      select c.code::text as code,
             (select count(*)::integer from public.post_stocks ps
              where ps.stock_code = c.code and ps.post_created_at > now() - interval '7 days') as posts_7d,
             (select count(*)::integer from public.stock_watchers w where w.stock_code = c.code) as watchers,
             exists (select 1 from public.stock_watchers w where w.stock_code = c.code and w.user_id = p_uid) as watching
      from private.stock_codes c
      where c.code like v_prefix || '%'
    ) s
    order by n
    offset p_offset
    limit p_limit + 1
  ) r;

  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(e.value order by e.ordinality)
                       from jsonb_array_elements(v_rows) with ordinality e
                       where e.ordinality <= p_limit), '[]'),
    'next_cursor', case when jsonb_array_length(v_rows) > p_limit then 'o:' || (p_offset + p_limit) end);
end;
$$;

create or replace function private.search_hashtags(p_uid uuid, p_query text, p_offset integer, p_limit integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_prefix text := lower(ltrim(btrim(p_query), '#'));
  v_rows   jsonb;
begin
  if v_prefix !~ '^[a-z0-9_]{1,50}$' then
    return jsonb_build_object('items', '[]'::jsonb, 'next_cursor', null);
  end if;

  select coalesce(jsonb_agg(r.item order by r.n), '[]') into v_rows
  from (
    select jsonb_build_object('tag', s.tag, 'posts_7d', s.posts_7d) as item,
           row_number() over (order by (s.tag = v_prefix) desc, s.posts_7d desc, s.tag) as n
    from (
      select h.tag::text as tag,
             (select count(*)::integer from public.post_hashtags ph
              join public.posts p on p.id = ph.post_id
              where ph.tag = h.tag and ph.post_created_at > now() - interval '7 days'
                and p.deleted_at is null and p.moderation_status = 'visible') as posts_7d
      from private.hashtags h
      where h.tag like replace(v_prefix, '_', '\_') || '%'
    ) s
    order by n
    offset p_offset
    limit p_limit + 1
  ) r;

  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(e.value order by e.ordinality)
                       from jsonb_array_elements(v_rows) with ordinality e
                       where e.ordinality <= p_limit), '[]'),
    'next_cursor', case when jsonb_array_length(v_rows) > p_limit then 'o:' || (p_offset + p_limit) end);
end;
$$;

create or replace function public.search(
  p_query  text,
  p_type   text default 'all',
  p_cursor text default null,
  p_limit  integer default 20
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_type   text := coalesce(nullif(btrim(p_type), ''), 'all');
  v_query  text := btrim(regexp_replace(coalesce(p_query, ''), '\s+', ' ', 'g'));
  v_terms  text[];
  v_limit  integer := private.search_page_size(p_limit, 20);
  v_page   jsonb;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_type not in ('all', 'posts', 'users', 'stocks', 'hashtags') then
    perform private.api_error(400, 'invalid_type', 'type harus all, posts, users, stocks, atau hashtags');
  end if;
  if char_length(v_query) > 100 then
    perform private.api_error(400, 'query_too_long', 'Kata kunci maksimal 100 karakter');
  end if;
  v_terms := private.search_terms(v_query);
  if char_length(v_query) < private.setting_num('search.min_query_length', 2) or cardinality(v_terms) = 0 then
    perform private.api_error(400, 'query_too_short',
      format('Kata kunci minimal %s karakter', private.setting_num('search.min_query_length', 2)));
  end if;
  if v_type = 'all' and coalesce(p_cursor, '') <> '' then
    perform private.api_error(400, 'invalid_cursor', 'Cursor hanya untuk pencarian per jenis');
  end if;
  perform private.consume_rate_limit(v_uid, 'search');

  if v_type = 'all' then
    return jsonb_build_object(
      'query', v_query, 'type', v_type,
      'posts', private.search_posts(v_uid, v_query, v_terms, null, 5) -> 'items',
      'users', private.search_users(v_uid, v_query, 0, 5) -> 'items',
      'stocks', private.search_stocks(v_uid, v_query, 0, 5) -> 'items',
      'hashtags', private.search_hashtags(v_uid, v_query, 0, 5) -> 'items',
      'next_cursor', null);
  end if;

  v_page := case v_type
    when 'posts' then private.search_posts(v_uid, v_query, v_terms, p_cursor, v_limit)
    when 'users' then private.search_users(v_uid, v_query, private.search_offset(p_cursor), v_limit)
    when 'stocks' then private.search_stocks(v_uid, v_query, private.search_offset(p_cursor), v_limit)
    else private.search_hashtags(v_uid, v_query, private.search_offset(p_cursor), v_limit)
  end;
  return jsonb_build_object('query', v_query, 'type', v_type, v_type, v_page -> 'items',
                            'next_cursor', v_page -> 'next_cursor');
end;
$$;

create or replace function public.get_hashtag_feed(p_tag text, p_cursor text default null, p_limit integer default 20)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_tag   text := lower(ltrim(btrim(coalesce(p_tag, '')), '#'));
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_tag !~ '^[a-z0-9_]{2,50}$' then
    perform private.api_error(400, 'invalid_hashtag', 'Hashtag tidak valid');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  select array_agg(x.post_id order by x.post_created_at desc, x.post_id desc) into v_ids
  from (
    select ph.post_id, ph.post_created_at
    from public.post_hashtags ph
    join public.posts p on p.id = ph.post_id
    where ph.tag = v_tag
      and p.deleted_at is null
      and p.author_id not in (select m.muted_id from public.mutes m where m.muter_id = v_uid)
      and not exists (
        select 1 from public.muted_keywords mk
        where mk.user_id = v_uid and strpos(lower(p.body), lower(mk.keyword::text)) > 0)
      and (v_ts is null or (ph.post_created_at, ph.post_id) < (v_ts, v_id))
    order by ph.post_created_at desc, ph.post_id desc
    limit v_limit
  ) x;

  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.get_trending_hashtags(p_window text default '24h', p_limit integer default 10)
returns table (tag text, post_count integer, author_count integer, score numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  v_since := now() - case coalesce(p_window, '24h')
    when '24h' then interval '24 hours'
    when '7d' then interval '7 days'
  end;
  if v_since is null then
    perform private.api_error(400, 'invalid_window', 'window harus 24h atau 7d');
  end if;

  return query
  select a.tag::text, sum(a.posts)::integer, count(*)::integer, round(sum(a.weight), 2)
  from (
    select ph.tag, p.author_id, count(*) as posts, max(private.author_weight(pr.created_at, pr.trust_level)) as weight
    from public.post_hashtags ph
    join public.posts p on p.id = ph.post_id
    join public.profiles pr on pr.id = p.author_id
    where ph.post_created_at > v_since
      and p.deleted_at is null
      and p.moderation_status = 'visible'
      and pr.deleted_at is null
    group by ph.tag, p.author_id
  ) a
  group by a.tag
  having count(*) >= private.setting_num('trending.min_authors', 2)
  order by sum(a.weight) desc, sum(a.posts) desc, a.tag
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
end;
$$;

revoke execute on function private.post_search_document(text) from public;
revoke execute on function private.extract_hashtags(text) from public;
revoke execute on function private.search_terms(text) from public;
revoke execute on function private.search_tsquery(text[]) from public;
revoke execute on function private.author_weight(timestamptz, smallint) from public;
revoke execute on function private.posts_sync_search() from public;
revoke execute on function private.hashtags_directory() from public;
revoke execute on function private.stock_codes_directory() from public;
revoke execute on function private.search_page_size(integer, integer) from public;
revoke execute on function private.search_offset(text) from public;
revoke execute on function private.search_posts(uuid, text, text[], text, integer) from public;
revoke execute on function private.search_users(uuid, text, integer, integer) from public;
revoke execute on function private.search_stocks(uuid, text, integer, integer) from public;
revoke execute on function private.search_hashtags(uuid, text, integer, integer) from public;
revoke execute on function public.search(text, text, text, integer) from public, anon;
revoke execute on function public.get_hashtag_feed(text, text, integer) from public, anon;
revoke execute on function public.get_trending_hashtags(text, integer) from public, anon;
grant execute on function public.search(text, text, text, integer) to authenticated;
grant execute on function public.get_hashtag_feed(text, text, integer) to authenticated;
grant execute on function public.get_trending_hashtags(text, integer) to authenticated;
