-- 0002_profiles.sql
-- Fondasi internal (schema private, rate limit, filter kata, arsip konten)
-- serta profil, follow, block, saham, dan watchlist.
--
-- Konvensi error API: private.api_error(status, code, detail) melempar SQLSTATE
-- 'PT<status>' sehingga PostgREST membalas dengan HTTP status tersebut
-- (mis. PT429 -> 429). Field `message` berisi kode stabil untuk client.

-- ---------------------------------------------------------------------------
-- Schema private: helper & tabel internal, tidak di-expose PostgREST.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- Objek public baru tidak otomatis bisa diakses anon.
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke execute on functions from anon;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- true jika request berasal dari user aplikasi (JWT role authenticated).
-- Koneksi langsung (seed, migrasi, Studio) dan service_role -> false.
create or replace function private.is_end_user()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.role(), '') = 'authenticated';
$$;

-- Lempar error dengan HTTP status khusus untuk PostgREST (SQLSTATE PTxxx).
create or replace function private.api_error(p_status integer, p_code text, p_detail text default null)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'PT' || p_status::text,
    message = p_code,
    detail  = coalesce(p_detail, p_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Rate limit (sisi DB). Batas bisa diubah tanpa migrasi:
--   update private.rate_limits set max_count = 10 where action = 'post';
-- ---------------------------------------------------------------------------
create table if not exists private.rate_limits (
  action         text primary key,
  max_count      integer not null check (max_count > 0),
  window_seconds integer not null check (window_seconds > 0),
  updated_at     timestamptz not null default now()
);
alter table private.rate_limits enable row level security;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('post',     5,   60),
  ('comment',  20,  60),
  ('message',  30,  60),
  ('reaction', 120, 60),
  ('follow',   60,  60),
  ('report',   10,  3600)
on conflict (action) do nothing;

-- Trigger BEFORE INSERT generik: hitung baris milik user di jendela waktu.
-- Argumen trigger: (nama action, nama kolom user). Hanya berlaku untuk user
-- aplikasi; seed/service_role tidak dibatasi.
create or replace function private.enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action      text := tg_argv[0];
  v_user_column text := tg_argv[1];
  v_limit       private.rate_limits;
  v_user        uuid;
  v_count       integer;
begin
  if not private.is_end_user() then
    return new;
  end if;

  select * into v_limit from private.rate_limits where action = v_action;
  if not found then
    return new;
  end if;

  v_user := (to_jsonb(new) ->> v_user_column)::uuid;
  execute format(
    'select count(*) from %I.%I where %I = $1 and created_at > now() - make_interval(secs => $2)',
    tg_table_schema, tg_table_name, v_user_column
  ) into v_count using v_user, v_limit.window_seconds;

  if v_count >= v_limit.max_count then
    perform private.api_error(429, 'rate_limited',
      format('Batas %s %s per %s detik terlampaui. Coba lagi sebentar.',
             v_limit.max_count, v_action, v_limit.window_seconds));
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Filter kata terlarang
--   action 'mask'  -> kata diganti '*'
--   action 'block' -> konten ditolak (HTTP 422, content_blocked)
-- ---------------------------------------------------------------------------
create table if not exists public.banned_words (
  word       text primary key,
  action     text not null default 'mask',
  created_at timestamptz not null default now(),
  constraint banned_words_format check (
    word = lower(word)
    and word ~ '^[a-z0-9]+( [a-z0-9]+)*$'
    and char_length(word) between 2 and 50
  ),
  constraint banned_words_action check (action in ('mask', 'block'))
);
alter table public.banned_words enable row level security;
revoke all on public.banned_words from anon, authenticated;

create or replace function private.apply_content_policy(p_text text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r        record;
  v_result text := p_text;
  v_regex  text;
begin
  if p_text is null or p_text = '' then
    return p_text;
  end if;

  for r in select word, action from public.banned_words loop
    -- Kata hanya [a-z0-9 ] (lihat constraint), aman disisipkan ke regex.
    v_regex := '\m' || r.word || '\M';
    if v_result ~* v_regex then
      if r.action = 'block' then
        perform private.api_error(422, 'content_blocked',
          'Konten mengandung kata atau frasa yang tidak diizinkan.');
      end if;
      v_result := regexp_replace(v_result, v_regex, repeat('*', char_length(r.word)), 'gi');
    end if;
  end loop;
  return v_result;
end;
$$;

-- Trigger BEFORE INSERT/UPDATE OF body untuk posts, comments, messages.
create or replace function private.enforce_content_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is null then
    new.body := private.apply_content_policy(new.body);
  end if;
  return new;
end;
$$;

-- Arsip konten yang dihapus user (untuk audit moderasi). Tidak bisa dibaca client.
create table if not exists private.content_archive (
  id          bigint generated always as identity primary key,
  target_type text not null,
  target_id   uuid not null,
  author_id   uuid,
  body        text,
  attachments jsonb,
  deleted_by  uuid,
  deleted_at  timestamptz not null default now()
);
alter table private.content_archive enable row level security;
create index if not exists content_archive_target_idx on private.content_archive (target_type, target_id);

-- ---------------------------------------------------------------------------
-- profiles: id = sub JWT (UUID v5 dari olt_user_id, dibuat auth-bridge).
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key,
  olt_user_id     text not null unique,
  username        extensions.citext not null unique,
  display_name    text,
  avatar_url      text,
  bio             text,
  is_verified     boolean not null default false,
  follower_count  integer not null default 0 check (follower_count >= 0),
  following_count integer not null default 0 check (following_count >= 0),
  post_count      integer not null default 0 check (post_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_]{3,30}$'),
  constraint profiles_display_name_length check (char_length(display_name) <= 60),
  constraint profiles_bio_length check (char_length(bio) <= 300),
  constraint profiles_avatar_url_length check (char_length(avatar_url) <= 500)
);
create index if not exists profiles_username_trgm_idx
  on public.profiles using gin ((username::text) extensions.gin_trgm_ops);

create or replace trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Data privat user (email dari OLT). Tidak bisa dibaca client.
create table if not exists private.user_private (
  user_id       uuid primary key references public.profiles(id) on delete cascade,
  email         text,
  last_login_at timestamptz,
  updated_at    timestamptz not null default now()
);
alter table private.user_private enable row level security;

-- ---------------------------------------------------------------------------
-- blocks
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self check (blocker_id <> blocked_id)
);
create index if not exists blocks_blocked_idx on public.blocks (blocked_id);

-- Semua user yang memblokir ATAU diblokir oleh user saat ini.
-- security definer: user hanya boleh membaca baris blocks miliknya sendiri.
create or replace function private.blocked_user_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid();
$$;

create or replace function private.is_blocked_pair(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = p_a and blocked_id = p_b)
       or (blocker_id = p_b and blocked_id = p_a)
  );
$$;

-- ---------------------------------------------------------------------------
-- follows
-- ---------------------------------------------------------------------------
create table if not exists public.follows (
  follower_id  uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id, created_at desc);

create or replace function private.follows_counters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set following_count = following_count + 1 where id = new.follower_id;
    update public.profiles set follower_count  = follower_count + 1  where id = new.following_id;
  elsif tg_op = 'DELETE' then
    update public.profiles set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update public.profiles set follower_count  = greatest(follower_count - 1, 0)  where id = old.following_id;
  end if;
  return null;
end;
$$;

create or replace trigger follows_rate_limit
  before insert on public.follows
  for each row execute function private.enforce_rate_limit('follow', 'follower_id');
create or replace trigger follows_counters
  after insert or delete on public.follows
  for each row execute function private.follows_counters();

-- Blokir memutus follow dua arah.
create or replace function private.blocks_unfollow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return null;
end;
$$;

create or replace trigger blocks_unfollow
  after insert on public.blocks
  for each row execute function private.blocks_unfollow();

-- ---------------------------------------------------------------------------
-- stocks & stock_watchers
-- ---------------------------------------------------------------------------
create table if not exists public.stocks (
  code          text primary key,
  name          text not null,
  type          text not null default 'stock',
  sector        text,
  is_active     boolean not null default true,
  watcher_count integer not null default 0 check (watcher_count >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint stocks_code_format check (code ~ '^[A-Z][A-Z0-9]{1,11}$'),
  constraint stocks_type check (type in ('stock', 'index'))
);
create index if not exists stocks_name_trgm_idx
  on public.stocks using gin (name extensions.gin_trgm_ops);

create or replace trigger stocks_set_updated_at
  before update on public.stocks
  for each row execute function private.set_updated_at();

create table if not exists public.stock_watchers (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  stock_code text not null references public.stocks(code) on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, stock_code)
);
create index if not exists stock_watchers_stock_idx on public.stock_watchers (stock_code);

create or replace function private.stock_watchers_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.stocks set watcher_count = watcher_count + 1 where code = new.stock_code;
  elsif tg_op = 'DELETE' then
    update public.stocks set watcher_count = greatest(watcher_count - 1, 0) where code = old.stock_code;
  end if;
  return null;
end;
$$;

create or replace trigger stock_watchers_counter
  after insert or delete on public.stock_watchers
  for each row execute function private.stock_watchers_counter();

-- ---------------------------------------------------------------------------
-- RLS & hak akses
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.blocks enable row level security;
alter table public.follows enable row level security;
alter table public.stocks enable row level security;
alter table public.stock_watchers enable row level security;

revoke all on public.profiles, public.blocks, public.follows, public.stocks, public.stock_watchers
  from anon, authenticated;

-- olt_user_id sengaja tidak bisa dibaca user lain.
grant select (id, username, display_name, avatar_url, bio, is_verified,
              follower_count, following_count, post_count, created_at, updated_at)
  on public.profiles to authenticated;
grant update (display_name, bio, avatar_url) on public.profiles to authenticated;
grant select, insert, delete on public.blocks to authenticated;
grant select, insert, delete on public.follows to authenticated;
grant select on public.stocks to authenticated;
grant select, insert, delete on public.stock_watchers to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own on public.blocks
  for select to authenticated using (blocker_id = (select auth.uid()));
drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own on public.blocks
  for insert to authenticated with check (blocker_id = (select auth.uid()));
drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own on public.blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

drop policy if exists follows_select on public.follows;
create policy follows_select on public.follows
  for select to authenticated using (true);
drop policy if exists follows_insert_own on public.follows;
create policy follows_insert_own on public.follows
  for insert to authenticated
  with check (
    follower_id = (select auth.uid())
    and not private.is_blocked_pair(follower_id, following_id)
  );
drop policy if exists follows_delete_own on public.follows;
create policy follows_delete_own on public.follows
  for delete to authenticated using (follower_id = (select auth.uid()));

drop policy if exists stocks_select on public.stocks;
create policy stocks_select on public.stocks
  for select to authenticated using (true);

drop policy if exists stock_watchers_select_own on public.stock_watchers;
create policy stock_watchers_select_own on public.stock_watchers
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists stock_watchers_insert_own on public.stock_watchers;
create policy stock_watchers_insert_own on public.stock_watchers
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists stock_watchers_delete_own on public.stock_watchers;
create policy stock_watchers_delete_own on public.stock_watchers
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Dipanggil auth-bridge (service_role) setiap exchange token: buat/perbarui profil.
-- Username OLT disanitasi ke [A-Za-z0-9_]{3,30}; jika sudah dipakai user lain,
-- diberi akhiran unik.
create or replace function public.upsert_olt_profile(
  p_id           uuid,
  p_olt_user_id  text,
  p_username     text,
  p_display_name text default null,
  p_email        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_base     text;
  v_username text;
  v_existing public.profiles;
  v_profile  public.profiles;
  v_attempt  integer := 0;
begin
  if p_id is null or coalesce(btrim(p_olt_user_id), '') = '' then
    perform private.api_error(400, 'invalid_profile', 'id dan olt_user_id wajib diisi');
  end if;

  v_base := regexp_replace(coalesce(p_username, ''), '[^A-Za-z0-9_]', '_', 'g');
  if char_length(v_base) < 3 then
    v_base := 'user_' || v_base;
  end if;
  v_base := left(v_base, 30);

  select * into v_existing from public.profiles where id = p_id;

  if found then
    -- Ikuti username OLT terbaru bila berubah dan masih tersedia.
    if v_existing.username::text <> v_base
       and not exists (
         select 1 from public.profiles
         where username = v_base::extensions.citext and id <> p_id
       ) then
      begin
        update public.profiles set username = v_base where id = p_id;
      exception when unique_violation then
        null; -- diambil user lain secara bersamaan; pertahankan username lama
      end;
    end if;
    update public.profiles
       set display_name = coalesce(display_name, nullif(btrim(p_display_name), ''))
     where id = p_id
     returning * into v_profile;
  else
    loop
      v_username := case
        when v_attempt = 0 then v_base
        else left(v_base, 25) || '_' || substr(md5(p_olt_user_id || v_attempt::text), 1, 4)
      end;
      begin
        insert into public.profiles (id, olt_user_id, username, display_name)
        values (p_id, p_olt_user_id, v_username, nullif(left(btrim(p_display_name), 60), ''))
        returning * into v_profile;
        exit;
      exception when unique_violation then
        -- Bisa karena username terpakai atau insert paralel untuk id yang sama.
        select * into v_profile from public.profiles where id = p_id;
        exit when found;
        v_attempt := v_attempt + 1;
        if v_attempt > 5 then
          perform private.api_error(409, 'username_unavailable', 'Gagal menentukan username unik');
        end if;
      end;
    end loop;
  end if;

  insert into private.user_private (user_id, email, last_login_at, updated_at)
  values (p_id, nullif(btrim(p_email), ''), now(), now())
  on conflict (user_id) do update
    set email = coalesce(excluded.email, private.user_private.email),
        last_login_at = now(),
        updated_at = now();

  return jsonb_build_object(
    'id', v_profile.id,
    'olt_user_id', v_profile.olt_user_id,
    'username', v_profile.username,
    'display_name', v_profile.display_name,
    'avatar_url', v_profile.avatar_url,
    'is_verified', v_profile.is_verified
  );
end;
$$;

-- Sinkronisasi daftar saham dari sistem OLT (service_role).
-- p_stocks: [{"code":"BBCA","name":"Bank Central Asia Tbk","type":"stock","sector":"Finance"}, ...]
create or replace function public.sync_stocks(p_stocks jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_count integer;
begin
  insert into public.stocks (code, name, type, sector, is_active)
  select upper(btrim(s ->> 'code')),
         btrim(s ->> 'name'),
         coalesce(s ->> 'type', 'stock'),
         s ->> 'sector',
         coalesce((s ->> 'is_active')::boolean, true)
  from jsonb_array_elements(p_stocks) as s
  on conflict (code) do update
    set name = excluded.name,
        type = excluded.type,
        sector = excluded.sector,
        is_active = excluded.is_active;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Autocomplete @mention.
create or replace function public.search_profiles(p_query text, p_limit integer default 10)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  is_verified boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified
  from public.profiles p, q
  where q.term <> ''
    and (p.username::text ilike q.term || '%' or p.display_name ilike '%' || q.term || '%')
    and p.id not in (select private.blocked_user_ids())
  order by (lower(p.username::text) = lower(btrim(p_query))) desc,
           p.follower_count desc,
           p.username
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$$;

-- Autocomplete $KODE.
create or replace function public.search_stocks(p_query text, p_limit integer default 10)
returns table (
  code text,
  name text,
  type text
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select s.code, s.name, s.type
  from public.stocks s, q
  where q.term <> ''
    and s.is_active
    and (s.code ilike q.term || '%' or s.name ilike '%' || q.term || '%')
  order by (s.code = upper(btrim(p_query))) desc,
           (s.code ilike q.term || '%') desc,
           s.watcher_count desc,
           s.code
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$$;

-- Profil lengkap + status relasi dengan user saat ini.
create or replace function public.get_profile(p_user_id uuid default null, p_username text default null)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  is_verified boolean,
  follower_count integer,
  following_count integer,
  post_count integer,
  created_at timestamptz,
  is_me boolean,
  is_following boolean,
  follows_me boolean,
  is_blocked boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.username::text, p.display_name, p.avatar_url, p.bio, p.is_verified,
         p.follower_count, p.following_count, p.post_count, p.created_at,
         p.id = auth.uid(),
         exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = p.id),
         exists (select 1 from public.follows f where f.follower_id = p.id and f.following_id = auth.uid()),
         exists (select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = p.id)
  from public.profiles p
  where (p_user_id is not null and p.id = p_user_id)
     or (p_user_id is null and p.username = p_username::extensions.citext)
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Hak eksekusi fungsi
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.blocked_user_ids() to authenticated;
grant execute on function private.is_blocked_pair(uuid, uuid) to authenticated;
grant execute on function private.is_end_user() to authenticated;
grant execute on function private.api_error(integer, text, text) to authenticated;

revoke execute on all functions in schema public from public, anon;
revoke execute on function public.upsert_olt_profile(uuid, text, text, text, text) from authenticated;
revoke execute on function public.sync_stocks(jsonb) from authenticated;
grant execute on function public.upsert_olt_profile(uuid, text, text, text, text) to service_role;
grant execute on function public.sync_stocks(jsonb) to service_role;
grant execute on function public.search_profiles(text, integer) to authenticated;
grant execute on function public.search_stocks(text, integer) to authenticated;
grant execute on function public.get_profile(uuid, text) to authenticated;
