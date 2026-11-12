create table public.feed_filters (
  key        text primary key check (key ~ '^[a-z][a-z0-9_]{1,31}$'),
  label_en   text not null check (char_length(btrim(label_en)) between 1 and 40),
  label_id   text not null check (char_length(btrim(label_id)) between 1 and 40),
  sort       text not null default 'latest' check (sort in ('latest', 'top')),
  content    text check (content in ('media', 'poll')),
  icon       text check (icon ~ '^[a-z0-9_]{1,40}$'),
  position   integer not null default 0,
  enabled    boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.feed_filters enable row level security;
revoke all on public.feed_filters from public, anon, authenticated;

insert into public.feed_filters (key, label_en, label_id, sort, content, icon, position) values
  ('latest', 'Latest', 'Terbaru', 'latest', null, 'schedule', 0),
  ('top', 'Top', 'Teratas', 'top', null, 'trending_up', 1),
  ('media', 'Chart & Media', 'Grafik & Media', 'latest', 'media', 'image', 2),
  ('polls', 'Polls', 'Polling', 'latest', 'poll', 'poll', 3);

create function private.feed_post_matches(p_post public.posts, p_content text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_content
    when 'media' then exists (select 1 from jsonb_array_elements(p_post.attachments) a where a ? 'path')
    when 'poll' then exists (select 1 from public.post_polls pp where pp.post_id = p_post.id)
    else p_content is null
  end;
$$;

create function private.feed_filter_def(p_key text)
returns table (sort text, content text)
language sql
stable
security definer
set search_path = ''
as $$
  select f.sort, f.content from public.feed_filters f where f.key = p_key and f.enabled;
$$;

create function private.feed_stock_codes(p_codes text[])
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array(
    select distinct upper(ltrim(btrim(c), '$'))
    from unnest(coalesce(p_codes, '{}')) c
    where btrim(coalesce(c, '')) <> '');
$$;

drop function public.get_feed(text, text, text, integer, uuid, text, boolean, text[]);

create function public.get_feed(
  p_scope       text default 'global',
  p_stock_code  text default null,
  p_cursor      text default null,
  p_limit       integer default 20,
  p_author_id   uuid default null,
  p_sort        text default 'latest',
  p_media_only  boolean default false,
  p_stock_codes text[] default null,
  p_filter      text default null
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
  v_content text := case when coalesce(p_media_only, false) then 'media' end;
  v_filter  text := nullif(btrim(coalesce(p_filter, '')), '');
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
  v_def     record;
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
  if v_filter is not null then
    select * into v_def from private.feed_filter_def(v_filter);
    if not found then
      perform private.api_error(400, 'invalid_filter', 'Filter feed tidak dikenal atau sedang nonaktif');
    end if;
    v_sort := v_def.sort;
    v_content := v_def.content;
  end if;
  if v_sort not in ('latest', 'top') then
    perform private.api_error(400, 'invalid_sort', 'Urutan feed harus latest atau top');
  end if;
  select * into v_params from private.feed_rank_params();
  if v_scope in ('stock', 'stocks') then
    v_codes := private.feed_stock_codes(case when v_scope = 'stock' then array[p_stock_code] else p_stock_codes end);
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
            and private.feed_post_allowed(p, v_uid, v_scope, false)
            and private.feed_post_matches(p, v_content)
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
        and private.feed_post_allowed(p, v_uid, v_scope, false)
        and private.feed_post_matches(p, v_content)
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
        and private.feed_post_allowed(p, v_uid, case when v_scope = 'for_you' then 'global' else v_scope end, false)
        and private.feed_post_matches(p, v_content)
        and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
      order by p.created_at desc, p.id desc
      limit v_limit
    ) x;
  end if;

  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

create function public.get_feed_filters()
returns table (key text, label_en text, label_id text, sort text, content text, icon text, "position" integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return query
  select f.key, f.label_en, f.label_id, f.sort, f.content, f.icon, f.position
  from public.feed_filters f
  where f.enabled
  order by f.position, f.key;
end;
$$;

create function cs.feed_filter_view(f public.feed_filters)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'key', f.key, 'label_en', f.label_en, 'label_id', f.label_id, 'sort', f.sort,
    'content', f.content, 'icon', f.icon, 'position', f.position, 'enabled', f.enabled,
    'updated_at', f.updated_at, 'updated_by', cs.staff_ref(f.updated_by));
$$;

create function cs_api.admin_feed_filters()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
begin
  return coalesce((select jsonb_agg(cs.feed_filter_view(f) order by f.position, f.key) from public.feed_filters f), '[]');
end;
$$;

create function cs_api.admin_save_feed_filter(
  p_key      text,
  p_label_en text,
  p_label_id text,
  p_sort     text,
  p_content  text default null,
  p_icon     text default null,
  p_position integer default null,
  p_enabled  boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin,product}');
  v_key     text := lower(btrim(coalesce(p_key, '')));
  v_content text := nullif(btrim(coalesce(p_content, '')), '');
  v_icon    text := nullif(lower(btrim(coalesce(p_icon, ''))), '');
  v_old     public.feed_filters;
  v_new     public.feed_filters;
begin
  if v_key !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_filter_key', 'Kunci filter 2-32 huruf kecil, angka, atau garis bawah');
  end if;
  if char_length(btrim(coalesce(p_label_en, ''))) not between 1 and 40
     or char_length(btrim(coalesce(p_label_id, ''))) not between 1 and 40 then
    perform private.api_error(400, 'invalid_filter_label', 'Label filter wajib diisi, maksimal 40 karakter');
  end if;
  if coalesce(p_sort, '') not in ('latest', 'top') then
    perform private.api_error(400, 'invalid_sort', 'Urutan feed harus latest atau top');
  end if;
  if v_content is not null and v_content not in ('media', 'poll') then
    perform private.api_error(400, 'invalid_filter_content', 'Isi filter harus media, poll, atau kosong');
  end if;
  if v_icon is not null and v_icon !~ '^[a-z0-9_]{1,40}$' then
    perform private.api_error(400, 'invalid_filter_icon', 'Ikon filter berupa nama huruf kecil tanpa spasi');
  end if;

  select * into v_old from public.feed_filters where key = v_key for update;
  insert into public.feed_filters as f (key, label_en, label_id, sort, content, icon, position, enabled, updated_at, updated_by)
  values (v_key, btrim(p_label_en), btrim(p_label_id), p_sort, v_content, v_icon,
          coalesce(p_position, (select coalesce(max(x.position), -1) + 1 from public.feed_filters x)),
          coalesce(p_enabled, true), now(), v_me)
  on conflict (key) do update
    set label_en = excluded.label_en, label_id = excluded.label_id, sort = excluded.sort,
        content = excluded.content, icon = excluded.icon,
        position = coalesce(p_position, f.position), enabled = excluded.enabled,
        updated_at = now(), updated_by = v_me
  returning * into v_new;

  perform cs.audit('feed_filter.save', null, null, jsonb_build_object(
    'key', v_key,
    'before', case when v_old.key is null then null else cs.feed_filter_view(v_old) - 'updated_by' - 'updated_at' end,
    'after', cs.feed_filter_view(v_new) - 'updated_by' - 'updated_at'));
  return cs.feed_filter_view(v_new);
end;
$$;

create function cs_api.admin_reorder_feed_filters(p_keys text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin,product}');
  v_keys text[] := array(select lower(btrim(k)) from unnest(coalesce(p_keys, '{}')) k);
begin
  if cardinality(v_keys) <> (select count(*) from public.feed_filters)
     or cardinality(v_keys) <> (select count(distinct k) from unnest(v_keys) k)
     or exists (select 1 from unnest(v_keys) k where not exists (select 1 from public.feed_filters f where f.key = k)) then
    perform private.api_error(400, 'invalid_filter_order', 'Urutan harus memuat setiap filter tepat satu kali');
  end if;
  update public.feed_filters f
     set position = o.ord - 1, updated_at = now(), updated_by = v_me
    from unnest(v_keys) with ordinality as o(key, ord)
   where f.key = o.key and f.position is distinct from o.ord - 1;
  perform cs.audit('feed_filter.reorder', null, null, jsonb_build_object('keys', to_jsonb(v_keys)));
  return cs_api.admin_feed_filters();
end;
$$;

create function cs_api.admin_delete_feed_filter(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin,product}');
  v_old public.feed_filters;
begin
  delete from public.feed_filters where key = lower(btrim(coalesce(p_key, ''))) returning * into v_old;
  if v_old.key is null then
    perform private.api_error(404, 'filter_not_found', 'Filter feed tidak ditemukan');
  end if;
  perform cs.audit('feed_filter.delete', null, null, jsonb_build_object(
    'key', v_old.key, 'before', cs.feed_filter_view(v_old) - 'updated_by' - 'updated_at'));
  return cs_api.admin_feed_filters();
end;
$$;

revoke execute on function private.feed_post_matches(public.posts, text) from public;
revoke execute on function private.feed_filter_def(text) from public;
revoke execute on function private.feed_stock_codes(text[]) from public;
revoke execute on function public.get_feed(text, text, text, integer, uuid, text, boolean, text[], text) from public, anon;
revoke execute on function public.get_feed_filters() from public, anon;
revoke execute on function cs.feed_filter_view(public.feed_filters) from public;
revoke execute on function cs_api.admin_feed_filters() from public;
revoke execute on function cs_api.admin_save_feed_filter(text, text, text, text, text, text, integer, boolean) from public;
revoke execute on function cs_api.admin_reorder_feed_filters(text[]) from public;
revoke execute on function cs_api.admin_delete_feed_filter(text) from public;
grant execute on function private.feed_post_matches(public.posts, text) to authenticated;
grant execute on function private.feed_filter_def(text) to authenticated;
grant execute on function private.feed_stock_codes(text[]) to authenticated;
grant execute on function public.get_feed(text, text, text, integer, uuid, text, boolean, text[], text) to authenticated;
grant execute on function public.get_feed_filters() to authenticated;
grant execute on function cs_api.admin_feed_filters() to authenticated;
grant execute on function cs_api.admin_save_feed_filter(text, text, text, text, text, text, integer, boolean) to authenticated;
grant execute on function cs_api.admin_reorder_feed_filters(text[]) to authenticated;
grant execute on function cs_api.admin_delete_feed_filter(text) to authenticated;
