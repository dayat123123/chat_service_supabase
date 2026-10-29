-- 0004_posts.sql
-- Post feed + tag saham ($KODE) + mention (@username).
-- post_stocks & post_mentions diisi otomatis oleh trigger dari isi body.

create table if not exists public.posts (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references public.profiles(id) on delete cascade,
  body          text not null,
  sentiment     text,
  -- [{"path":"posts/<author_id>/<file>","mime":"image/jpeg","width":1080,"height":720}]
  attachments   jsonb not null default '[]'::jsonb,
  like_count    integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  edited_at     timestamptz,
  deleted_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint posts_body_length check (
    deleted_at is not null or (char_length(body) between 1 and 2000)
  ),
  constraint posts_sentiment check (sentiment in ('bullish', 'bearish', 'neutral')),
  constraint posts_attachments check (
    jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 4
  )
);
-- Feed global (keyset created_at, id).
create index if not exists posts_created_idx
  on public.posts (created_at desc, id desc) where deleted_at is null;
-- Feed per user & rate limit per author.
create index if not exists posts_author_created_idx
  on public.posts (author_id, created_at desc, id desc);

create table if not exists public.post_stocks (
  post_id         uuid not null references public.posts(id) on delete cascade,
  stock_code      text not null references public.stocks(code) on update cascade on delete cascade,
  -- Salinan posts.created_at agar feed per saham bisa keyset langsung dari index ini.
  post_created_at timestamptz not null,
  primary key (post_id, stock_code)
);
create index if not exists post_stocks_feed_idx
  on public.post_stocks (stock_code, post_created_at desc, post_id desc);

create table if not exists public.post_mentions (
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists post_mentions_user_idx on public.post_mentions (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Parser (harus konsisten dengan parser Dart di package olt_social)
--   $KODE    : huruf diikuti 1-11 huruf/angka, tidak didahului huruf/angka/_/$
--              ($100 dan US$5 tidak dianggap kode saham)
--   @username: [A-Za-z0-9_]{3,30}, tidak didahului huruf/angka/_/@ (email bukan mention)
-- ---------------------------------------------------------------------------
create or replace function private.extract_cashtags(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(code order by first_pos), '{}')
  from (
    select upper(m[1]) as code, min(ord) as first_pos
    from regexp_matches(coalesce(p_text, ''),
                        '(?<![A-Za-z0-9_$])\$([A-Za-z][A-Za-z0-9]{1,11})(?![A-Za-z0-9_])', 'g')
         with ordinality as t(m, ord)
    group by upper(m[1])
  ) s;
$$;

create or replace function private.extract_mentions(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(username order by first_pos), '{}')
  from (
    select lower(m[1]) as username, min(ord) as first_pos
    from regexp_matches(coalesce(p_text, ''),
                        '(?<![A-Za-z0-9_@])@([A-Za-z0-9_]{3,30})(?![A-Za-z0-9_])', 'g')
         with ordinality as t(m, ord)
    group by lower(m[1])
  ) s;
$$;

-- Validasi lampiran: maks 4, tiap item {"path": "<prefix>..."} tanpa "..".
create or replace function private.validate_attachments(p_attachments jsonb, p_prefix text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_item jsonb;
begin
  if p_attachments is null or jsonb_typeof(p_attachments) <> 'array' then
    perform private.api_error(400, 'invalid_attachments', 'Lampiran harus berupa array');
  end if;
  if jsonb_array_length(p_attachments) > 4 then
    perform private.api_error(400, 'invalid_attachments', 'Maksimal 4 lampiran');
  end if;
  for v_item in select value from jsonb_array_elements(p_attachments) loop
    if jsonb_typeof(v_item) <> 'object'
       or jsonb_typeof(v_item -> 'path') <> 'string'
       or left(v_item ->> 'path', char_length(p_prefix)) <> p_prefix
       or position('..' in (v_item ->> 'path')) > 0 then
      perform private.api_error(400, 'invalid_attachments',
        'Lampiran harus diunggah ke folder ' || p_prefix);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger posts
-- ---------------------------------------------------------------------------
create or replace function private.posts_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is null then
    new.body := regexp_replace(new.body, '^\s+|\s+$', '', 'g');
    perform private.validate_attachments(new.attachments, 'posts/' || new.author_id || '/');
  end if;
  if tg_op = 'UPDATE' then
    new.updated_at := now();
    if new.deleted_at is null and new.body is distinct from old.body then
      new.edited_at := now();
    end if;
  end if;
  return new;
end;
$$;

-- Sinkronkan post_stocks & post_mentions dengan isi body (maks 10 per post).
create or replace function private.sync_post_tags()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_codes     text[];
  v_usernames extensions.citext[];
begin
  if tg_op = 'UPDATE'
     and new.body is not distinct from old.body
     and new.deleted_at is not distinct from old.deleted_at then
    return null;
  end if;

  if new.deleted_at is not null then
    delete from public.post_stocks where post_id = new.id;
    delete from public.post_mentions where post_id = new.id;
    return null;
  end if;

  v_codes := (private.extract_cashtags(new.body))[1:10];
  delete from public.post_stocks where post_id = new.id and stock_code <> all(v_codes);
  insert into public.post_stocks (post_id, stock_code, post_created_at)
  select new.id, s.code, new.created_at
  from public.stocks s
  where s.code = any(v_codes) and s.is_active
  on conflict do nothing;

  v_usernames := ((private.extract_mentions(new.body))[1:10])::extensions.citext[];
  delete from public.post_mentions pm
  where pm.post_id = new.id
    and pm.user_id not in (select p.id from public.profiles p where p.username = any(v_usernames));
  insert into public.post_mentions (post_id, user_id)
  select new.id, p.id
  from public.profiles p
  where p.username = any(v_usernames) and p.id <> new.author_id
  on conflict do nothing;

  return null;
end;
$$;

create or replace function private.posts_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.deleted_at is null then
      update public.profiles set post_count = post_count + 1 where id = new.author_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.deleted_at is null and new.deleted_at is not null then
      update public.profiles set post_count = greatest(post_count - 1, 0) where id = new.author_id;
    elsif old.deleted_at is not null and new.deleted_at is null then
      update public.profiles set post_count = post_count + 1 where id = new.author_id;
    end if;
  elsif tg_op = 'DELETE' then
    if old.deleted_at is null then
      update public.profiles set post_count = greatest(post_count - 1, 0) where id = old.author_id;
    end if;
  end if;
  return null;
end;
$$;

create or replace function private.notify_post_mention()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts where id = new.post_id;
  perform private.notify(
    new.user_id, v_post.author_id, 'mention',
    jsonb_build_object('post_id', v_post.id, 'snippet', private.snippet(v_post.body)),
    'mention:post:' || v_post.id
  );
  return null;
end;
$$;

-- Urutan trigger BEFORE mengikuti nama: rate limit -> normalisasi -> filter kata.
create or replace trigger posts_10_rate_limit
  before insert on public.posts
  for each row execute function private.enforce_rate_limit('post', 'author_id');
create or replace trigger posts_20_before_write
  before insert or update on public.posts
  for each row execute function private.posts_before_write();
create or replace trigger posts_30_content_policy
  before insert or update of body on public.posts
  for each row execute function private.enforce_content_policy();
create or replace trigger posts_sync_tags
  after insert or update of body, deleted_at on public.posts
  for each row execute function private.sync_post_tags();
create or replace trigger posts_counter
  after insert or update of deleted_at or delete on public.posts
  for each row execute function private.posts_counter();
create or replace trigger post_mentions_notify
  after insert on public.post_mentions
  for each row execute function private.notify_post_mention();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.posts enable row level security;
alter table public.post_stocks enable row level security;
alter table public.post_mentions enable row level security;

revoke all on public.posts, public.post_stocks, public.post_mentions from anon, authenticated;
grant select on public.posts to authenticated;
grant insert (id, author_id, body, sentiment, attachments) on public.posts to authenticated;
grant update (body, sentiment, attachments) on public.posts to authenticated;
grant select on public.post_stocks, public.post_mentions to authenticated;

-- Post milik user yang memblokir / diblokir tidak terlihat. Post terhapus disembunyikan.
drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts
  for select to authenticated
  using (
    deleted_at is null
    and author_id not in (select private.blocked_user_ids())
  );
drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own on public.posts
  for insert to authenticated
  with check (author_id = (select auth.uid()));
drop policy if exists posts_update_own on public.posts;
create policy posts_update_own on public.posts
  for update to authenticated
  using (author_id = (select auth.uid()) and deleted_at is null)
  with check (author_id = (select auth.uid()) and deleted_at is null);

drop policy if exists post_stocks_select on public.post_stocks;
create policy post_stocks_select on public.post_stocks
  for select to authenticated using (true);
drop policy if exists post_mentions_select on public.post_mentions;
create policy post_mentions_select on public.post_mentions
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Soft delete post milik sendiri. Isi asli dipindah ke private.content_archive.
create or replace function public.delete_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts where id = p_post_id and deleted_at is null for update;
  if not found then
    perform private.api_error(404, 'not_found', 'Post tidak ditemukan');
  end if;
  if v_post.author_id is distinct from auth.uid() and coalesce(auth.role(), '') <> 'service_role' then
    perform private.api_error(403, 'forbidden', 'Hanya pemilik yang bisa menghapus post ini');
  end if;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by)
  values ('post', v_post.id, v_post.author_id, v_post.body, v_post.attachments, auth.uid());

  update public.posts
     set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where id = p_post_id;
end;
$$;

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.delete_post(uuid) to authenticated;
