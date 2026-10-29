-- 0012_settings_rate_limits.sql
-- Pengaturan aplikasi (bisa diubah tanpa deploy) dan rate limit berlapis di DB
-- (docs/PROMPT-PRODUCTION.md bagian 3):
--   - beberapa jendela waktu per aksi (mis. post 5/menit + 50/hari);
--   - akun baru (trust_level 0) lebih ketat, akun tepercaya (>= 2) lebih longgar;
--   - aksi baru: buat room (10/jam), upload (50/hari), ekspor data (3/hari);
--   - HTTP 429 membawa header Retry-After; pelanggaran dicatat ke log Postgres.
--
-- Mengubah batas tanpa migrasi:
--   update private.rate_limits set max_count = 10 where action = 'post' and window_seconds = 60;
--   update private.settings set value = '0.25' where key = 'rate_limit.new_account_factor';

-- ---------------------------------------------------------------------------
-- Pengaturan aplikasi
-- ---------------------------------------------------------------------------
create table if not exists private.settings (
  key         text primary key,
  value       jsonb not null,
  description text,
  updated_at  timestamptz not null default now()
);
alter table private.settings enable row level security;

insert into private.settings (key, value, description) values
  ('trust.new_account_hours', '24',
   'Akun baru (trust_level 0) naik ke 1 otomatis setelah sekian jam'),
  ('rate_limit.new_account_factor', '0.5',
   'Pengali batas rate limit untuk trust_level 0 (akun baru / dibatasi)'),
  ('rate_limit.trusted_factor', '2',
   'Pengali batas rate limit untuk trust_level >= 2 (tepercaya / resmi)')
on conflict (key) do nothing;

create or replace function private.setting_json(p_key text, p_default jsonb default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select s.value from private.settings s where s.key = p_key), p_default);
$$;

create or replace function private.setting_num(p_key text, p_default numeric)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select (s.value #>> '{}')::numeric from private.settings s where s.key = p_key), p_default);
$$;

-- ---------------------------------------------------------------------------
-- trust_level: 0 = baru/dibatasi, 1 = normal, 2 = tepercaya, 3 = resmi.
-- Hanya bisa diubah server/admin (tidak ada grant update untuk user).
-- Profil yang sudah ada = 1; profil baru dari auth-bridge mulai dari 0.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists trust_level smallint not null default 1;
alter table public.profiles drop constraint if exists profiles_trust_level;
alter table public.profiles add constraint profiles_trust_level check (trust_level between 0 and 3);

create or replace function private.rate_limit_factor(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when p.trust_level >= 2 then private.setting_num('rate_limit.trusted_factor', 2)
      when p.trust_level = 0  then private.setting_num('rate_limit.new_account_factor', 0.5)
      else 1
    end
    from public.profiles p where p.id = p_user
  ), 1);
$$;

-- ---------------------------------------------------------------------------
-- Batas: beberapa jendela per aksi -> primary key (action, window_seconds)
-- ---------------------------------------------------------------------------
alter table private.rate_limits drop constraint if exists rate_limits_pkey;
alter table private.rate_limits add primary key (action, window_seconds);

-- Sesuaikan default lama dengan addendum (hanya bila belum diubah operator).
update private.rate_limits set max_count = 60, updated_at = now()
 where action = 'reaction' and window_seconds = 60 and max_count = 120;
delete from private.rate_limits
 where action = 'follow' and window_seconds = 60 and max_count = 60;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('post',        50, 86400),
  ('follow',      30, 3600),
  ('room_create', 10, 3600),
  ('upload',      50, 86400),
  ('data_export', 3,  86400)
on conflict (action, window_seconds) do nothing;

-- Aksi tanpa tabel sendiri (upload, ekspor data) dicatat di sini.
create table if not exists private.rate_limit_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null,
  action     text not null,
  created_at timestamptz not null default now()
);
create index if not exists rate_limit_events_user_action_idx
  on private.rate_limit_events (user_id, action, created_at desc);
alter table private.rate_limit_events enable row level security;

-- HTTP 429 + header Retry-After. Body tetap {"code":"PT429","message":"rate_limited"}
-- seperti sebelumnya, sehingga client lama tetap mengenalinya.
create or replace function private.raise_rate_limited(
  p_action text, p_max integer, p_window integer, p_retry_after integer
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_retry integer := greatest(coalesce(p_retry_after, 1), 1);
begin
  raise log 'olt.rate_limited action=% user=% max=% window_s=% retry_after_s=%',
    p_action, auth.uid(), p_max, p_window, v_retry;
  raise sqlstate 'PGRST' using
    message = json_build_object(
      'code', 'PT429',
      'message', 'rate_limited',
      'details', format('Batas %s %s per %s detik terlampaui. Coba lagi dalam %s detik.',
                        p_max, p_action, p_window, v_retry),
      'hint', null)::text,
    detail = json_build_object(
      'status', 429,
      'headers', json_build_object('Retry-After', v_retry::text))::text;
end;
$$;

-- Periksa semua jendela untuk satu aksi. Tanpa p_table: hitung dari
-- private.rate_limit_events; dengan p_table: hitung baris milik user di tabel itu.
create or replace function private.check_rate_limit(
  p_user uuid, p_action text, p_table regclass default null, p_user_column text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r        record;
  v_factor numeric;
  v_max    integer;
  v_count  integer;
  v_oldest timestamptz;
begin
  if p_user is null then
    return;
  end if;
  v_factor := private.rate_limit_factor(p_user);

  for r in
    select l.max_count, l.window_seconds from private.rate_limits l
    where l.action = p_action order by l.window_seconds
  loop
    v_max := greatest(1, floor(r.max_count * v_factor)::integer);
    if p_table is null then
      select count(*), min(e.created_at) into v_count, v_oldest
      from private.rate_limit_events e
      where e.user_id = p_user and e.action = p_action
        and e.created_at > now() - make_interval(secs => r.window_seconds);
    else
      execute format(
        'select count(*), min(created_at) from %s where %I = $1 and created_at > now() - make_interval(secs => $2)',
        p_table, p_user_column)
      into v_count, v_oldest using p_user, r.window_seconds;
    end if;

    if v_count >= v_max then
      perform private.raise_rate_limited(p_action, v_max, r.window_seconds,
        ceil(r.window_seconds - extract(epoch from (now() - v_oldest)))::integer);
    end if;
  end loop;
end;
$$;

-- Untuk aksi berbasis event (dipanggil RPC / Edge Function): periksa lalu catat.
create or replace function private.consume_rate_limit(p_user uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.check_rate_limit(p_user, p_action);
  insert into private.rate_limit_events (user_id, action) values (p_user, p_action);
end;
$$;

-- Kirim ulang dengan client_id yang sama adalah retry idempoten, bukan aksi baru.
create or replace function private.client_id_exists(
  p_table regclass, p_user_column text, p_user uuid, p_client_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exists boolean;
begin
  if p_user is null or p_client_id is null then
    return false;
  end if;
  execute format('select exists (select 1 from %s where %I = $1 and client_id = $2)', p_table, p_user_column)
  into v_exists using p_user, p_client_id;
  return v_exists;
end;
$$;

-- Trigger BEFORE INSERT generik (argumen: nama aksi, kolom user). Signature sama
-- dengan versi 0002, sehingga trigger yang sudah ada otomatis memakai versi ini.
create or replace function private.enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action      text := tg_argv[0];
  v_user_column text := tg_argv[1];
  v_row         jsonb := to_jsonb(new);
  v_user        uuid := (v_row ->> v_user_column)::uuid;
begin
  if not private.is_end_user() then
    return new;
  end if;
  if v_row ? 'client_id'
     and private.client_id_exists(tg_relid::regclass, v_user_column, v_user, (v_row ->> 'client_id')::uuid) then
    return new;
  end if;
  perform private.check_rate_limit(v_user, v_action, tg_relid::regclass, v_user_column);
  return new;
end;
$$;

-- Buat room (direct & grup). Room saham dibuat otomatis, tidak dihitung.
create or replace trigger chat_rooms_10_rate_limit
  before insert on public.chat_rooms
  for each row when (new.type <> 'stock')
  execute function private.enforce_rate_limit('room_create', 'created_by');

-- Upload file (semua bucket). Edge Function upload (Tahap 6) memanggil
-- consume_rate_limit langsung agar bisa membalas 429 yang rapi.
create or replace function private.enforce_upload_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_end_user() and new.owner is not null then
    perform private.consume_rate_limit(new.owner, 'upload');
  end if;
  return new;
end;
$$;

drop trigger if exists olt_upload_rate_limit on storage.objects;
create trigger olt_upload_rate_limit
  before insert on storage.objects
  for each row execute function private.enforce_upload_limit();

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
