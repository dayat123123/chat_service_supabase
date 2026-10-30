create schema if not exists cs;
create schema if not exists cs_api;
revoke all on schema cs from public;
revoke all on schema cs_api from public;
grant usage on schema cs to authenticated, service_role;
grant usage on schema cs_api to anon, authenticated, service_role;

create or replace function cs.reject_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('cs.retention', true) = 'on' then
    return old;
  end if;
  raise exception '% hanya bisa ditambah, tidak bisa diubah atau dihapus', tg_table_name
    using errcode = '42501';
end;
$$;

create table cs.teams (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  name_id         text not null check (char_length(btrim(name_id)) between 2 and 60),
  name_en         text not null check (char_length(btrim(name_en)) between 2 and 60),
  assignment_mode text not null default 'offer' check (assignment_mode in ('offer', 'auto')),
  active          boolean not null default true,
  created_at      timestamptz not null default now()
);

create table cs.skills (
  code    text primary key check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  name_id text not null,
  name_en text not null
);

create sequence cs.agent_code_seq;

create table cs.agents (
  user_id        uuid primary key references public.profiles (id) on delete restrict,
  agent_code     text not null unique check (agent_code ~ '^CS-[0-9]{4,}$'),
  display_name   text not null check (char_length(btrim(display_name)) between 2 and 40),
  roles          text[] not null default '{cs_agent}' check (
    cardinality(roles) > 0 and roles <@ array['cs_agent', 'cs_supervisor', 'cs_admin', 'compliance']
  ),
  team_id        uuid references cs.teams (id),
  languages      text[] not null default '{id}' check (cardinality(languages) > 0 and languages <@ array['id', 'en']),
  max_concurrent smallint not null default 3 check (max_concurrent between 0 and 10),
  serves_vip     boolean not null default false,
  disabled_at    timestamptz,
  created_at     timestamptz not null default now(),
  created_by     uuid
);
create index agents_team_idx on cs.agents (team_id);

create table cs.agent_skills (
  agent_id uuid not null references cs.agents (user_id) on delete cascade,
  skill    text not null references cs.skills (code) on update cascade,
  level    smallint not null check (level between 1 and 3),
  primary key (agent_id, skill)
);
create index agent_skills_skill_idx on cs.agent_skills (skill, level);

create table cs.agent_status (
  agent_id             uuid primary key references cs.agents (user_id) on delete cascade,
  status               text not null default 'offline' check (status in ('online', 'busy', 'break', 'offline')),
  reason               text check (char_length(reason) <= 120),
  active_sessions      integer not null default 0 check (active_sessions >= 0),
  consecutive_timeouts integer not null default 0 check (consecutive_timeouts >= 0),
  last_assigned_at     timestamptz,
  last_heartbeat_at    timestamptz,
  status_changed_at    timestamptz not null default now()
);

create table cs.support_topics (
  code             text primary key check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  name_id          text not null check (char_length(btrim(name_id)) between 2 and 40),
  name_en          text not null check (char_length(btrim(name_en)) between 2 and 40),
  skill            text not null references cs.skills (code) on update cascade,
  team_id          uuid references cs.teams (id),
  default_priority text not null check (default_priority in ('P1', 'P2', 'P3', 'P4')),
  flags            text[] not null default '{}' check (flags <@ array['complaint', 'fraud']),
  help_url         text check (help_url ~ '^https://'),
  sort_order       smallint not null default 0,
  active           boolean not null default true
);

create table cs.vip_customers (
  customer_id uuid primary key references public.profiles (id) on delete cascade,
  source      text not null default 'manual' check (source in ('olt', 'manual')),
  note        text check (char_length(note) <= 200),
  since       timestamptz not null default now(),
  updated_by  uuid
);

create table cs.holidays (
  day        date primary key,
  name       text not null check (char_length(btrim(name)) between 2 and 120),
  kind       text not null check (kind in ('national', 'collective_leave', 'exchange')),
  verified   boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table cs.cs_settings (
  key         text primary key check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  value       jsonb not null,
  description text not null,
  version     integer not null default 1,
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);

create table cs.cs_settings_history (
  id         bigint generated always as identity primary key,
  key        text not null,
  version    integer not null,
  old_value  jsonb,
  new_value  jsonb not null,
  changed_by uuid,
  changed_at timestamptz not null default now()
);
create index cs_settings_history_key_idx on cs.cs_settings_history (key, version desc);
create trigger cs_settings_history_append_only
  before update or delete on cs.cs_settings_history
  for each row execute function cs.reject_change();

alter table cs.teams enable row level security;
alter table cs.skills enable row level security;
alter table cs.agents enable row level security;
alter table cs.agent_skills enable row level security;
alter table cs.agent_status enable row level security;
alter table cs.support_topics enable row level security;
alter table cs.vip_customers enable row level security;
alter table cs.holidays enable row level security;
alter table cs.cs_settings enable row level security;
alter table cs.cs_settings_history enable row level security;

create or replace function cs.setting(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select s.value from cs.cs_settings s where s.key = p_key;
$$;

create or replace function cs.setting_int(p_key text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select (s.value #>> '{}')::integer from cs.cs_settings s where s.key = p_key;
$$;

create or replace function cs.set_setting(p_key text, p_value jsonb, p_actor uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old cs.cs_settings;
begin
  select * into v_old from cs.cs_settings where key = p_key for update;
  if not found then
    perform private.api_error(404, 'setting_not_found', 'Pengaturan tidak dikenal');
  end if;
  if p_value is null or jsonb_typeof(p_value) <> jsonb_typeof(v_old.value) then
    perform private.api_error(400, 'invalid_setting', 'Tipe nilai pengaturan tidak sesuai');
  end if;
  if p_value = v_old.value then
    return v_old.version;
  end if;
  update cs.cs_settings
     set value = p_value, version = version + 1, updated_at = now(), updated_by = p_actor
   where key = p_key;
  insert into cs.cs_settings_history (key, version, old_value, new_value, changed_by)
  values (p_key, v_old.version + 1, v_old.value, p_value, p_actor);
  return v_old.version + 1;
end;
$$;

create or replace function cs.local_date(p_at timestamptz)
returns date
language sql
stable
set search_path = ''
as $$
  select (p_at at time zone 'Asia/Jakarta')::date;
$$;

create or replace function cs.is_business_day(p_day date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select extract(isodow from p_day) < 6
     and not exists (select 1 from cs.holidays h where h.day = p_day);
$$;

create or replace function cs.business_day_on_or_after(p_day date)
returns date
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day date := p_day;
begin
  if p_day is null then
    return null;
  end if;
  for i in 1 .. 3660 loop
    if cs.is_business_day(v_day) then
      return v_day;
    end if;
    v_day := v_day + 1;
  end loop;
  raise exception 'Kalender tidak memiliki hari kerja setelah %', p_day;
end;
$$;

create or replace function cs.add_business_days(p_day date, p_days integer)
returns date
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day  date := cs.business_day_on_or_after(p_day);
  v_left integer := greatest(coalesce(p_days, 0), 0);
begin
  if v_day is null then
    return null;
  end if;
  while v_left > 0 loop
    v_day := v_day + 1;
    if cs.is_business_day(v_day) then
      v_left := v_left - 1;
    end if;
  end loop;
  return v_day;
end;
$$;

create or replace function cs.business_days_between(p_from date, p_to date)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from generate_series((p_from + 1)::timestamp, p_to::timestamp, interval '1 day') g (day)
  where cs.is_business_day(g.day::date);
$$;

create or replace function cs.end_of_business_day(p_day date)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select ((p_day + 1)::timestamp at time zone 'Asia/Jakarta') - interval '1 microsecond';
$$;

create or replace function cs.regulatory_deadline(p_from timestamptz, p_days integer)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select cs.end_of_business_day(cs.add_business_days(cs.local_date(p_from), p_days));
$$;

create or replace function cs.service_window(p_day date, out opens_at timestamptz, out closes_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_hours jsonb;
begin
  if exists (select 1 from cs.holidays h where h.day = p_day and h.kind in ('national', 'collective_leave')) then
    return;
  end if;
  v_hours := cs.setting('service.hours') -> extract(isodow from p_day)::integer::text;
  if jsonb_typeof(v_hours) = 'array' then
    opens_at := (p_day + (v_hours ->> 0)::time) at time zone 'Asia/Jakarta';
    closes_at := (p_day + (v_hours ->> 1)::time) at time zone 'Asia/Jakarta';
  end if;
end;
$$;

create or replace function cs.is_open(p_at timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(p_at >= w.opens_at and p_at < w.closes_at, false)
  from cs.service_window(cs.local_date(p_at)) w;
$$;

create or replace function cs.next_open_at(p_at timestamptz)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day    date := cs.local_date(p_at);
  v_window record;
begin
  for i in 0 .. 400 loop
    select * into v_window from cs.service_window(v_day + i);
    if v_window.opens_at is not null and v_window.closes_at > p_at then
      return greatest(v_window.opens_at, p_at);
    end if;
  end loop;
  return null;
end;
$$;

create or replace function cs.is_market_hours(p_at timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select cs.is_business_day(cs.local_date(p_at))
     and (p_at at time zone 'Asia/Jakarta')::time >= (cs.setting('market.hours') ->> 'opens')::time
     and (p_at at time zone 'Asia/Jakarta')::time < (cs.setting('market.hours') ->> 'closes')::time;
$$;

create or replace function cs.is_staff(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.agents a where a.user_id = p_user);
$$;

create or replace function cs.current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.user_id
  from cs.agents a
  where a.user_id = auth.uid()
    and a.disabled_at is null
    and coalesce(auth.role(), '') = 'authenticated'
    and coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

create or replace function cs.current_roles()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select a.roles from cs.agents a where a.user_id = cs.current_agent_id()), '{}');
$$;

create or replace function cs.has_role(p_roles text[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select cs.current_roles() && p_roles;
$$;

create or replace function cs.require_agent(p_roles text[] default null)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := cs.current_agent_id();
begin
  if v_id is null then
    perform private.api_error(403, 'agent_required', 'Butuh akun CS aktif dengan 2FA');
  end if;
  if p_roles is not null and not cs.has_role(p_roles) then
    perform private.api_error(403, 'role_forbidden', 'Peran Anda tidak cukup untuk aksi ini');
  end if;
  return v_id;
end;
$$;

create or replace function cs.current_customer_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.id = auth.uid()
    and p.deleted_at is null
    and coalesce(auth.role(), '') = 'authenticated'
    and not cs.is_staff(p.id);
$$;

create or replace function cs.require_customer()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := cs.current_customer_id();
begin
  if v_id is null then
    perform private.api_error(403, 'customer_required', 'Hanya untuk nasabah yang sudah masuk');
  end if;
  return v_id;
end;
$$;

create or replace function cs.create_agent(
  p_user_id        uuid,
  p_display_name   text,
  p_roles          text[] default '{cs_agent}',
  p_team           text default 'general',
  p_skills         jsonb default '{"general": 1}',
  p_languages      text[] default '{id}',
  p_max_concurrent integer default 3,
  p_created_by     uuid default null
)
returns cs.agents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code     text := 'CS-' || lpad(nextval('cs.agent_code_seq')::text, 4, '0');
  v_username text := 'cs_' || lower(replace(v_code, '-', ''));
  v_agent    cs.agents;
begin
  if exists (select 1 from public.profiles p where p.id = p_user_id) then
    perform private.api_error(409, 'profile_exists', 'Akun ini sudah punya profil nasabah, pakai akun staf terpisah');
  end if;
  if exists (select 1 from public.profiles p where p.username = v_username) then
    v_username := left(v_username, 24) || '_' || substr(md5(p_user_id::text), 1, 5);
  end if;
  insert into public.profiles (id, olt_user_id, username, display_name)
  values (p_user_id, 'cs-staff:' || p_user_id, v_username, btrim(p_display_name));

  insert into cs.agents (user_id, agent_code, display_name, roles, team_id, languages, max_concurrent, created_by)
  values (p_user_id, v_code, btrim(p_display_name), p_roles,
          (select t.id from cs.teams t where t.code = p_team), p_languages, p_max_concurrent, p_created_by)
  returning * into v_agent;

  insert into cs.agent_status (agent_id) values (p_user_id);
  insert into cs.agent_skills (agent_id, skill, level)
  select p_user_id, s.key, (s.value #>> '{}')::smallint
  from jsonb_each(coalesce(p_skills, '{}')) s;
  return v_agent;
end;
$$;

create or replace function cs.sync_agent_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set display_name = new.display_name where id = new.user_id;
  return null;
end;
$$;

create trigger agents_sync_profile
  after update of display_name on cs.agents
  for each row execute function cs.sync_agent_profile();

create or replace function cs.luhn_valid(p_digits text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sum    integer := 0;
  v_digit  integer;
  v_double boolean := false;
begin
  if p_digits is null or p_digits !~ '^[0-9]+$' then
    return false;
  end if;
  for i in reverse length(p_digits) .. 1 loop
    v_digit := substr(p_digits, i, 1)::integer;
    if v_double then
      v_digit := v_digit * 2;
      if v_digit > 9 then
        v_digit := v_digit - 9;
      end if;
    end if;
    v_sum := v_sum + v_digit;
    v_double := not v_double;
  end loop;
  return v_sum % 10 = 0;
end;
$$;

create or replace function cs.mask_number(p_kind text, p_candidate text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(p_candidate, '[^0-9]', '', 'g');
begin
  if p_kind = 'card' then
    if length(v_digits) between 13 and 19 and cs.luhn_valid(v_digits) then
      return '**** **** **** ' || right(v_digits, 4);
    end if;
  elsif p_kind = 'nik' then
    return left(v_digits, 4) || '********' || right(v_digits, 4);
  elsif p_kind = 'account' and v_digits !~ '^(08|628)' then
    return repeat('*', length(v_digits) - 4) || right(v_digits, 4);
  end if;
  return p_candidate;
end;
$$;

create or replace function cs.mask_numbers(p_text text, p_kind text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_pattern     text := case p_kind
    when 'card' then '(?<![0-9])[0-9](?:[ -]?[0-9]){12,18}(?![0-9])'
    when 'nik' then '(?<![0-9])[1-9][0-9]{15}(?![0-9])'
    else '(?<![0-9+])[0-9]{9,18}(?![0-9])'
  end;
  v_out         text := p_text;
  v_from        integer := 1;
  v_start       integer;
  v_end         integer;
  v_replacement text;
begin
  loop
    v_start := regexp_instr(v_out, v_pattern, v_from, 1, 0);
    exit when v_start = 0;
    v_end := regexp_instr(v_out, v_pattern, v_from, 1, 1);
    v_replacement := cs.mask_number(p_kind, substr(v_out, v_start, v_end - v_start));
    v_out := overlay(v_out placing v_replacement from v_start for v_end - v_start);
    v_from := v_start + greatest(length(v_replacement), 1);
  end loop;
  return v_out;
end;
$$;

create or replace function cs.mask_sensitive(p_text text, out masked text, out kinds text[])
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_next text;
  v_kind text;
begin
  masked := p_text;
  kinds := '{}';
  if coalesce(p_text, '') = '' then
    return;
  end if;

  v_next := regexp_replace(masked,
    '(\m(?:otp|pin|cvv|cvc|passcode|kode\s+(?:otp|verifikasi|keamanan)|verification\s+code|security\s+code)\M[^0-9\n]{0,24})[0-9](?:\s?[0-9]){2,9}\M',
    '\1******', 'gi');
  if v_next <> masked then
    masked := v_next;
    kinds := kinds || 'otp'::text;
  end if;

  v_next := regexp_replace(masked,
    '(\m(?:password|passwd|pwd|kata\s+sandi|sandi)\M(?:\s+(?:saya|ku|anda|nya|baru|lama|adalah|ini|is|my))*\s*[:=]?\s*)(?=\S*[0-9!@#$%^&*_+=?~.-])\S{6,}',
    '\1********', 'gi');
  if v_next <> masked then
    masked := v_next;
    kinds := kinds || 'password'::text;
  end if;

  foreach v_kind in array array['card', 'nik', 'account'] loop
    v_next := cs.mask_numbers(masked, v_kind);
    if v_next <> masked then
      masked := v_next;
      kinds := kinds || v_kind;
    end if;
  end loop;

  if btrim(masked) ~ '^[0-9]{4,8}$' then
    masked := '******';
    kinds := kinds || 'otp'::text;
  end if;

  kinds := array(select distinct k from unnest(kinds) k order by k);
end;
$$;

create or replace function cs.requests_secret(p_text text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1
    from regexp_split_to_table(coalesce(p_text, ''), '[.!?\n]+') s (sentence)
    where s.sentence ~* '\m(otp|pin|password|passwd|kata\s+sandi|sandi|cvv|cvc|kode\s+(otp|verifikasi|keamanan)|nomor\s+kartu)\M'
      and (s.sentence ~* '\m(kirim|kirimkan|berikan|beritahu|beritahukan|beri\s+tahu|sebutkan|informasikan|bagikan|ketik|ketikkan|tulis|tuliskan|masukkan|input|share|send|give|provide|tell)\M'
           or s.sentence ~* '\m(otp|pin|password|sandi|cvv|kode)\M[^.!?\n]{0,25}\mberapa\M')
      and s.sentence !~* '\m(jangan|tidak\s+pernah|tidak\s+akan|bukan|never|not|don''t)\M'
  );
$$;

create or replace function cs.render_text(p_text text, p_vars jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out text := p_text;
  v_var record;
begin
  for v_var in select key, value #>> '{}' as value from jsonb_each(coalesce(p_vars, '{}')) loop
    v_out := replace(v_out, '{' || v_var.key || '}', coalesce(v_var.value, ''));
  end loop;
  return v_out;
end;
$$;

insert into cs.teams (code, name_id, name_en) values
  ('general', 'Layanan Umum', 'General Support'),
  ('funds', 'Dana & RDN', 'Funds & RDN'),
  ('trading', 'Transaksi', 'Trading'),
  ('technical', 'Teknis', 'Technical'),
  ('security', 'Keamanan & Fraud', 'Security & Fraud'),
  ('complaints', 'Pengaduan', 'Complaints');

insert into cs.skills (code, name_id, name_en) values
  ('general', 'Umum', 'General'),
  ('account', 'Akun & login', 'Account & login'),
  ('funds', 'Dana & RDN', 'Funds & RDN'),
  ('trading', 'Order & transaksi', 'Orders & trading'),
  ('portfolio', 'Portofolio & aksi korporasi', 'Portfolio & corporate actions'),
  ('technical', 'Aplikasi & teknis', 'App & technical'),
  ('fraud', 'Penipuan & peretasan', 'Fraud & account takeover'),
  ('complaint', 'Pengaduan', 'Complaints');

insert into cs.support_topics (code, name_id, name_en, skill, team_id, default_priority, flags, sort_order)
select v.code, v.name_id, v.name_en, v.skill, t.id, v.priority, v.flags, v.sort_order
from (values
  ('account', 'Akun & Login', 'Account & Login', 'account', 'general', 'P3', '{}'::text[], 1),
  ('funds', 'Deposit/Tarik Dana', 'Deposit/Withdrawal', 'funds', 'funds', 'P2', '{}'::text[], 2),
  ('orders', 'Order & Transaksi', 'Orders & Trading', 'trading', 'trading', 'P3', '{}'::text[], 3),
  ('portfolio', 'Portofolio & Aksi Korporasi', 'Portfolio & Corporate Actions', 'portfolio', 'trading', 'P3', '{}'::text[], 4),
  ('technical', 'Aplikasi/Teknis', 'App/Technical', 'technical', 'technical', 'P3', '{}'::text[], 5),
  ('fraud', 'Laporkan Penipuan', 'Report Fraud', 'fraud', 'security', 'P1', '{fraud}'::text[], 6),
  ('other', 'Lainnya', 'Other', 'general', 'general', 'P4', '{}'::text[], 7)
) v (code, name_id, name_en, skill, team, priority, flags, sort_order)
join cs.teams t on t.code = v.team;

insert into cs.cs_settings (key, value, description) values
  ('service.hours',
   '{"1": ["08:00", "22:00"], "2": ["08:00", "22:00"], "3": ["08:00", "22:00"], "4": ["08:00", "22:00"], "5": ["08:00", "22:00"], "6": ["09:00", "18:00"], "7": ["09:00", "18:00"]}',
   'Jam layanan CS per hari ISO (1 = Senin) dalam WIB. Hari tanpa entri = tutup. Libur nasional dan cuti bersama tutup'),
  ('market.hours', '{"opens": "09:00", "closes": "16:00"}', 'Jam bursa (WIB) di hari kerja, untuk prioritas masalah transaksi'),
  ('session.reopen_minutes', '30', 'Pesan nasabah dalam sekian menit setelah sesi ditutup membuka kembali sesi yang sama'),
  ('session.default_topic', '"other"', 'Topik sesi baru yang dibuat dari pesan nasabah tanpa memilih topik'),
  ('agent.history_hours', '24',
   'Agen bisa membaca riwayat room nasabah selama menangani sesinya, dan sekian jam setelah sesi yang ia tangani ditutup'),
  ('agent.heartbeat_fresh_seconds', '30', 'Agen dianggap terhubung bila heartbeat terakhir lebih baru dari ini'),
  ('offer.timeout_seconds', '30', 'Waktu agen untuk menerima penawaran sesi'),
  ('offer.max_consecutive_timeouts', '2', 'Agen otomatis istirahat setelah sekian penawaran berturut-turut habis waktu'),
  ('priority.rules',
   '[{"words": ["dibobol", "diretas", "dihack", "hacked", "tidak dikenal", "tidak saya kenal", "tanpa sepengetahuan", "penipuan", "penipu", "scam", "fraud", "cs palsu"], "priority": "P1", "flag": "fraud"}, {"words": ["tidak bisa order", "tidak bisa beli", "tidak bisa jual", "tidak bisa transaksi", "gagal order", "order gagal", "order ditolak", "cannot trade", "can''t trade", "order rejected"], "priority": "P1", "market_hours_only": true}]',
   'Kata kunci di pesan pertama yang menaikkan prioritas (dan menambah flag)'),
  ('complaint.days', '5',
   'Tenggat penyelesaian pengaduan lewat chat (hari kerja sejak diterima). Usulan default, wajib dikonfirmasi kepatuhan'),
  ('retention.chat_years', '10', 'Lama penyimpanan riwayat chat CS (tahun). Usulan default, wajib dikonfirmasi kepatuhan'),
  ('close.outcomes',
   '{"resolved": {"id": "Selesai", "en": "Resolved"}, "follow_up": {"id": "Perlu tindak lanjut", "en": "Needs follow-up"}, "complaint": {"id": "Pengaduan", "en": "Complaint"}, "no_response": {"id": "Nasabah tidak merespons", "en": "No customer response"}, "customer_ended": {"id": "Diakhiri nasabah", "en": "Ended by customer"}, "other": {"id": "Lainnya", "en": "Other"}}',
   'Hasil yang wajib dipilih saat menutup sesi'),
  ('customer_data.profile_views_per_hour', '30', 'Batas membuka data nasabah per agen per jam (deteksi anomali)'),
  ('customer_data.reveals_per_hour', '10', 'Batas membuka data tersamar per agen per jam'),
  ('customer_data.reveal_reasons',
   '{"identity_verification": {"id": "Verifikasi identitas", "en": "Identity verification"}, "data_correction": {"id": "Permintaan koreksi data", "en": "Data correction request"}, "fraud_investigation": {"id": "Investigasi penipuan", "en": "Fraud investigation"}, "regulatory_request": {"id": "Permintaan regulator", "en": "Regulatory request"}}',
   'Alasan yang boleh dipilih saat membuka data tersamar'),
  ('secure_account.actions', '["logout_all", "lock_trading"]', 'Aksi OLT saat agen menekan "Amankan akun"'),
  ('help.allowed_hosts', '["help.olt.co.id"]', 'Host yang boleh dipakai untuk tautan bantuan dari agen'),
  ('messages.greeting',
   '{"id": "Halo {name}, terima kasih sudah menghubungi CS OLT. Silakan ceritakan kendala Anda.", "en": "Hi {name}, thank you for contacting OLT customer service. Please tell us how we can help."}',
   'Pesan otomatis pertama'),
  ('messages.security_reminder',
   '{"id": "CS kami tidak pernah meminta PIN, password, atau OTP.", "en": "Our customer service never asks for your PIN, password, or OTP."}',
   'Pengingat keamanan di awal sesi'),
  ('messages.help',
   '{"id": "Panduan singkat seputar {topic}", "en": "Quick guide on {topic}"}',
   'Judul tautan bantuan sesuai topik (bila topik punya tautan bantuan)'),
  ('messages.queued',
   '{"id": "Anda masuk antrean. CS kami akan segera membalas.", "en": "You are in the queue. An agent will reply shortly."}',
   'Pesan saat sesi masuk antrean di jam layanan'),
  ('messages.out_of_hours',
   '{"id": "Saat ini di luar jam layanan. CS akan membalas mulai {next_open}.", "en": "We are currently closed. An agent will reply from {next_open}."}',
   'Pesan saat sesi dibuat di luar jam layanan'),
  ('messages.connected',
   '{"id": "Anda terhubung dengan {agent} – CS Resmi.", "en": "You are now connected with {agent} – Official CS."}',
   'Pesan saat agen menerima sesi'),
  ('messages.transferred',
   '{"id": "Anda dialihkan ke tim {team}. Mohon tunggu sebentar.", "en": "You are being transferred to the {team} team. Please wait a moment."}',
   'Pesan saat sesi ditransfer'),
  ('messages.reconnecting',
   '{"id": "Koneksi CS terputus. Anda sedang dihubungkan ke CS lain.", "en": "We lost the connection to your agent. We are connecting you to another agent."}',
   'Pesan saat agen terputus dan sesi kembali ke antrean'),
  ('messages.reopened',
   '{"id": "Sesi dibuka kembali.", "en": "The conversation has been reopened."}',
   'Pesan saat sesi dibuka kembali'),
  ('messages.closed',
   '{"id": "Sesi selesai. Terima kasih sudah menghubungi CS OLT.", "en": "This conversation has ended. Thank you for contacting OLT customer service."}',
   'Pesan penutup'),
  ('messages.csat',
   '{"id": "Bagaimana pelayanan kami? Beri nilai 1–5.", "en": "How did we do? Rate us from 1 to 5."}',
   'Permintaan rating setelah sesi ditutup'),
  ('messages.complaint',
   '{"id": "Pengaduan Anda kami terima dan dicatat pada {received_at}. Kami akan menyelesaikannya paling lambat {due_at}.", "en": "We have recorded your complaint on {received_at}. We will resolve it no later than {due_at}."}',
   'Pesan saat sesi ditandai pengaduan'),
  ('messages.secured',
   '{"id": "Akun Anda sudah kami amankan. Silakan masuk ulang di aplikasi OLT dan ganti password Anda.", "en": "We have secured your account. Please sign in again in the OLT app and change your password."}',
   'Pesan setelah aksi "Amankan akun" berhasil');

insert into cs.holidays (day, name, kind) values
  ('2026-01-01', 'Tahun Baru 2026 Masehi', 'national'),
  ('2026-01-16', 'Isra Mikraj Nabi Muhammad SAW', 'national'),
  ('2026-02-16', 'Cuti bersama Tahun Baru Imlek', 'collective_leave'),
  ('2026-02-17', 'Tahun Baru Imlek 2577 Kongzili', 'national'),
  ('2026-03-18', 'Cuti bersama Hari Suci Nyepi', 'collective_leave'),
  ('2026-03-19', 'Hari Suci Nyepi (Tahun Baru Saka 1948)', 'national'),
  ('2026-03-20', 'Cuti bersama Idulfitri 1447 H', 'collective_leave'),
  ('2026-03-21', 'Idulfitri 1447 H', 'national'),
  ('2026-03-22', 'Idulfitri 1447 H', 'national'),
  ('2026-03-23', 'Cuti bersama Idulfitri 1447 H', 'collective_leave'),
  ('2026-03-24', 'Cuti bersama Idulfitri 1447 H', 'collective_leave'),
  ('2026-04-03', 'Wafat Yesus Kristus', 'national'),
  ('2026-04-05', 'Kebangkitan Yesus Kristus (Paskah)', 'national'),
  ('2026-05-01', 'Hari Buruh Internasional', 'national'),
  ('2026-05-14', 'Kenaikan Yesus Kristus', 'national'),
  ('2026-05-15', 'Cuti bersama Kenaikan Yesus Kristus', 'collective_leave'),
  ('2026-05-27', 'Iduladha 1447 H', 'national'),
  ('2026-05-28', 'Cuti bersama Iduladha 1447 H', 'collective_leave'),
  ('2026-05-31', 'Hari Raya Waisak 2570 BE', 'national'),
  ('2026-06-01', 'Hari Lahir Pancasila', 'national'),
  ('2026-06-16', '1 Muharam Tahun Baru Islam 1448 H', 'national'),
  ('2026-08-17', 'Proklamasi Kemerdekaan', 'national'),
  ('2026-08-25', 'Maulid Nabi Muhammad SAW', 'national'),
  ('2026-12-24', 'Cuti bersama Kelahiran Yesus Kristus', 'collective_leave'),
  ('2026-12-25', 'Kelahiran Yesus Kristus', 'national'),
  ('2026-12-31', 'Libur bursa akhir tahun', 'exchange'),
  ('2027-01-01', 'Tahun Baru 2027 Masehi', 'national'),
  ('2027-01-05', 'Isra Mikraj Nabi Muhammad SAW', 'national'),
  ('2027-02-05', 'Cuti bersama Tahun Baru Imlek', 'collective_leave'),
  ('2027-02-06', 'Tahun Baru Imlek 2578 Kongzili', 'national'),
  ('2027-03-08', 'Hari Suci Nyepi (Tahun Baru Saka 1949)', 'national'),
  ('2027-03-09', 'Cuti bersama Idulfitri 1448 H', 'collective_leave'),
  ('2027-03-10', 'Idulfitri 1448 H', 'national'),
  ('2027-03-11', 'Idulfitri 1448 H', 'national'),
  ('2027-03-12', 'Cuti bersama Idulfitri 1448 H', 'collective_leave'),
  ('2027-03-15', 'Cuti bersama Idulfitri 1448 H', 'collective_leave'),
  ('2027-03-25', 'Cuti bersama Wafat Yesus Kristus', 'collective_leave'),
  ('2027-03-26', 'Wafat Yesus Kristus', 'national'),
  ('2027-03-28', 'Kebangkitan Yesus Kristus (Paskah)', 'national'),
  ('2027-05-01', 'Hari Buruh Internasional', 'national'),
  ('2027-05-06', 'Kenaikan Yesus Kristus', 'national'),
  ('2027-05-17', 'Iduladha 1448 H', 'national'),
  ('2027-05-18', 'Cuti bersama Iduladha 1448 H', 'collective_leave'),
  ('2027-05-19', 'Cuti bersama Hari Raya Waisak', 'collective_leave'),
  ('2027-05-20', 'Hari Raya Waisak 2571 BE', 'national'),
  ('2027-06-01', 'Hari Lahir Pancasila', 'national'),
  ('2027-06-06', '1 Muharam Tahun Baru Islam 1449 H', 'national'),
  ('2027-08-15', 'Maulid Nabi Muhammad SAW', 'national'),
  ('2027-08-17', 'Proklamasi Kemerdekaan', 'national'),
  ('2027-12-24', 'Cuti bersama Kelahiran Yesus Kristus', 'collective_leave'),
  ('2027-12-25', 'Kelahiran Yesus Kristus', 'national'),
  ('2027-12-26', 'Isra Mikraj Nabi Muhammad SAW', 'national'),
  ('2027-12-31', 'Libur bursa akhir tahun', 'exchange');

insert into private.rate_limits (action, max_count, window_seconds) values
  ('cs_session', 5, 3600),
  ('cs_message', 30, 60)
on conflict (action, window_seconds) do nothing;

revoke execute on all functions in schema cs from public;
