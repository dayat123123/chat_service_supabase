-- 0007_feed_rpc.sql
-- RPC baca untuk feed & thread komentar. Semua SECURITY INVOKER: RLS
-- (blokir, post terhapus) tetap menjadi satu-satunya sumber aturan visibilitas.

-- ---------------------------------------------------------------------------
-- Bentuk data untuk client
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'feed_post' and typnamespace = 'public'::regnamespace) then
    create type public.feed_post as (
      id                  uuid,
      author_id           uuid,
      author_username     text,
      author_display_name text,
      author_avatar_url   text,
      author_is_verified  boolean,
      body                text,
      sentiment           text,
      attachments         jsonb,
      like_count          integer,
      comment_count       integer,
      stock_codes         text[],
      liked_by_me         boolean,
      edited_at           timestamptz,
      created_at          timestamptz,
      cursor              text
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'thread_comment' and typnamespace = 'public'::regnamespace) then
    create type public.thread_comment as (
      id                  uuid,
      post_id             uuid,
      parent_id           uuid,
      author_id           uuid,
      author_username     text,
      author_display_name text,
      author_avatar_url   text,
      author_is_verified  boolean,
      body                text,     -- null jika dihapus
      is_deleted          boolean,
      depth               integer,  -- 0 = komentar langsung di post
      path                text,
      like_count          integer,
      reply_count         integer,
      liked_by_me         boolean,
      edited_at           timestamptz,
      created_at          timestamptz,
      cursor              text      -- seq; dipakai untuk "lihat balasan lainnya"
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cursor keyset "<timestamp UTC mikrodetik>|<uuid>"
-- ---------------------------------------------------------------------------
create or replace function private.make_cursor(p_ts timestamptz, p_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(p_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || p_id::text;
$$;

create or replace function private.parse_cursor(p_cursor text, out ts timestamptz, out id uuid)
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_cursor is null or p_cursor = '' then
    return;
  end if;
  begin
    ts := split_part(p_cursor, '|', 1)::timestamptz;
    id := split_part(p_cursor, '|', 2)::uuid;
  exception when others then
    perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
  end;
  if ts is null or id is null then
    perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Proyeksi
-- ---------------------------------------------------------------------------
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
         private.make_cursor(p.created_at, p.id)
  from unnest(p_ids) with ordinality as u(id, ord)
  join public.posts p on p.id = u.id
  join public.profiles pr on pr.id = p.author_id
  order by u.ord;
$$;

create or replace function private.thread_comments(p_ids uuid[])
returns setof public.thread_comment
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select c.id, c.post_id, c.parent_id,
         case when c.deleted_at is null then c.author_id end,
         case when c.deleted_at is null then pr.username::text end,
         case when c.deleted_at is null then pr.display_name end,
         case when c.deleted_at is null then pr.avatar_url end,
         case when c.deleted_at is null then pr.is_verified else false end,
         case when c.deleted_at is null then c.body end,
         c.deleted_at is not null,
         c.depth, c.path::text, c.like_count, c.reply_count,
         exists (select 1 from public.reactions r
                 where r.user_id = auth.uid() and r.target_type = 'comment' and r.target_id = c.id),
         c.edited_at, c.created_at, c.seq::text
  from public.comments c
  join public.profiles pr on pr.id = c.author_id
  where c.id = any(p_ids)
  order by c.path;
$$;

-- ---------------------------------------------------------------------------
-- get_feed(scope, stock_code, cursor, limit[, author_id])
--   scope: global | following (diri sendiri + yang di-follow) | stock | user
--   cursor: nilai `cursor` dari item terakhir halaman sebelumnya (keyset, bukan OFFSET)
-- ---------------------------------------------------------------------------
create or replace function public.get_feed(
  p_scope      text default 'global',
  p_stock_code text default null,
  p_cursor     text default null,
  p_limit      integer default 20,
  p_author_id  uuid default null
)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_code  text := upper(btrim(coalesce(p_stock_code, '')));
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  case coalesce(p_scope, 'global')
    when 'global' then
      select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
      from (
        select p.id, p.created_at
        from public.posts p
        where p.deleted_at is null
          and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
        order by p.created_at desc, p.id desc
        limit v_limit
      ) x;

    when 'following' then
      select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
      from (
        select p.id, p.created_at
        from public.posts p
        where p.deleted_at is null
          and (p.author_id = v_uid
               or p.author_id in (select f.following_id from public.follows f where f.follower_id = v_uid))
          and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
        order by p.created_at desc, p.id desc
        limit v_limit
      ) x;

    when 'stock' then
      if v_code = '' then
        perform private.api_error(400, 'stock_code_required', 'stock_code wajib diisi untuk scope stock');
      end if;
      select array_agg(x.post_id order by x.post_created_at desc, x.post_id desc) into v_ids
      from (
        select ps.post_id, ps.post_created_at
        from public.post_stocks ps
        join public.posts p on p.id = ps.post_id
        where ps.stock_code = v_code
          and p.deleted_at is null
          and (v_ts is null or (ps.post_created_at, ps.post_id) < (v_ts, v_id))
        order by ps.post_created_at desc, ps.post_id desc
        limit v_limit
      ) x;

    when 'user' then
      if p_author_id is null then
        perform private.api_error(400, 'author_required', 'author_id wajib diisi untuk scope user');
      end if;
      select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
      from (
        select p.id, p.created_at
        from public.posts p
        where p.author_id = p_author_id
          and p.deleted_at is null
          and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
        order by p.created_at desc, p.id desc
        limit v_limit
      ) x;

    else
      perform private.api_error(400, 'invalid_scope', 'scope harus global, following, stock, atau user');
  end case;

  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.get_post(p_post_id uuid)
returns setof public.feed_post
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select * from private.feed_posts(array[p_post_id]);
$$;

-- ---------------------------------------------------------------------------
-- get_comment_thread(post_id, root_comment_id, max_depth, cursor, limit, ...)
--
-- Mengembalikan satu "halaman" anak dari root (root null = komentar langsung
-- di post), masing-masing beserta keturunannya hingga p_max_depth level di
-- bawahnya. Tiap cabang dibatasi p_replies_limit balasan pertama.
-- Hasil terurut sesuai pohon (ORDER BY path).
--
-- Client:
--   * "Lihat N balasan lainnya" : panggil ulang dengan root = parent dan
--                                 cursor = `cursor` balasan terakhir yang sudah tampil.
--   * "Lanjutkan thread"        : panggil dengan root = komentar terdalam yang
--                                 masih punya balasan (p_include_root = true).
--   * reply_count vs jumlah anak yang termuat menentukan tombol mana yang tampil.
-- ---------------------------------------------------------------------------
create or replace function public.get_comment_thread(
  p_post_id         uuid,
  p_root_comment_id uuid default null,
  p_max_depth       integer default 3,
  p_cursor          text default null,
  p_limit           integer default 20,
  p_replies_limit   integer default 3,
  p_include_root    boolean default false
)
returns setof public.thread_comment
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_max_depth integer := least(greatest(coalesce(p_max_depth, 3), 0), 20);
  v_limit     integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_replies   integer := least(greatest(coalesce(p_replies_limit, 3), 0), 50);
  v_cursor    bigint;
  v_page      uuid[];
  v_ids       uuid[];
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.posts where id = p_post_id) then
    perform private.api_error(404, 'post_not_found', 'Post tidak ditemukan');
  end if;
  if p_cursor is not null and p_cursor <> '' then
    begin
      v_cursor := p_cursor::bigint;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
  end if;

  if p_root_comment_id is null then
    select array_agg(x.id order by x.seq) into v_page
    from (
      select c.id, c.seq from public.comments c
      where c.post_id = p_post_id and c.parent_id is null
        and (v_cursor is null or c.seq > v_cursor)
      order by c.seq
      limit v_limit
    ) x;
  else
    if not exists (select 1 from public.comments where id = p_root_comment_id and post_id = p_post_id) then
      perform private.api_error(404, 'comment_not_found', 'Komentar tidak ditemukan');
    end if;
    select array_agg(x.id order by x.seq) into v_page
    from (
      select c.id, c.seq from public.comments c
      where c.parent_id = p_root_comment_id
        and (v_cursor is null or c.seq > v_cursor)
      order by c.seq
      limit v_limit
    ) x;
  end if;

  with recursive tree (id, rel_depth) as (
    select page_id, 0 from unnest(coalesce(v_page, '{}')) as page_id
    union all
    select ch.id, t.rel_depth + 1
    from tree t
    cross join lateral (
      select c.id from public.comments c
      where c.parent_id = t.id
      order by c.seq
      limit v_replies
    ) ch
    where t.rel_depth < v_max_depth
  )
  select array_agg(tree.id) into v_ids from tree;

  if p_include_root and p_root_comment_id is not null and v_cursor is null then
    v_ids := array_prepend(p_root_comment_id, coalesce(v_ids, '{}'));
  end if;

  return query select * from private.thread_comments(coalesce(v_ids, '{}'));
end;
$$;

-- ---------------------------------------------------------------------------
-- create_comment(post_id, parent_id, body)
-- Validasi body di sini; validasi post/parent/blokir/rate limit di trigger
-- (berlaku juga untuk insert langsung lewat REST).
-- ---------------------------------------------------------------------------
create or replace function public.create_comment(p_post_id uuid, p_parent_id uuid, p_body text)
returns setof public.thread_comment
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_body text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_id   uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if char_length(v_body) = 0 then
    perform private.api_error(400, 'empty_body', 'Komentar tidak boleh kosong');
  end if;
  if char_length(v_body) > 1000 then
    perform private.api_error(400, 'body_too_long', 'Komentar maksimal 1000 karakter');
  end if;

  insert into public.comments (post_id, parent_id, author_id, body)
  values (p_post_id, p_parent_id, auth.uid(), v_body)
  returning id into v_id;

  return query select * from private.thread_comments(array[v_id]);
end;
$$;

revoke all on all functions in schema private from public;
grant execute on function private.make_cursor(timestamptz, uuid) to authenticated;
grant execute on function private.parse_cursor(text) to authenticated;
grant execute on function private.feed_posts(uuid[]) to authenticated;
grant execute on function private.thread_comments(uuid[]) to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_feed(text, text, text, integer, uuid) to authenticated;
grant execute on function public.get_post(uuid) to authenticated;
grant execute on function public.get_comment_thread(uuid, uuid, integer, text, integer, integer, boolean) to authenticated;
grant execute on function public.create_comment(uuid, uuid, text) to authenticated;
