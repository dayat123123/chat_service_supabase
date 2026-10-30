create schema if not exists care;
revoke all on schema care from public;
create schema if not exists care_api;
revoke all on schema care_api from public;
grant usage on schema care_api to anon, authenticated, service_role;

alter default privileges for role postgres in schema care revoke execute on functions from public;
alter default privileges for role postgres in schema care_api revoke execute on functions from public;

create or replace function care.reject_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('care.retention', true) = 'on' then
    return old;
  end if;
  raise exception '% hanya bisa ditambah, tidak bisa diubah atau dihapus', tg_table_name
    using errcode = '42501';
end;
$$;

create table care.teams (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  name_id    text not null,
  name_en    text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table care.staff (
  user_id      uuid primary key,
  agent_code   text not null unique check (agent_code ~ '^CS-[0-9]{4,}$'),
  display_name text not null check (char_length(btrim(display_name)) between 2 and 60),
  email        text check (email is null or email ~ '^[^@\s]+@[^@\s]+$'),
  max_chats    smallint not null default 3 check (max_chats between 0 and 20),
  max_tickets  smallint not null default 25 check (max_tickets between 0 and 500),
  disabled_at  timestamptz,
  created_at   timestamptz not null default now(),
  created_by   uuid
);

create table care.staff_roles (
  user_id    uuid not null references care.staff (user_id) on delete cascade,
  role       text not null check (
    role in ('agent_l1', 'agent_l2', 'specialist', 'supervisor', 'compliance', 'kb_editor', 'cc_admin')
  ),
  granted_at timestamptz not null default now(),
  granted_by uuid,
  primary key (user_id, role)
);

create table care.team_members (
  team_id uuid not null references care.teams (id) on delete cascade,
  user_id uuid not null references care.staff (user_id) on delete cascade,
  primary key (team_id, user_id)
);
create index team_members_user_idx on care.team_members (user_id);

create table care.settings (
  key         text primary key,
  value       jsonb not null,
  scope       text not null check (scope in ('regulatory', 'operational')),
  description text not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);

create table care.settings_history (
  id         bigint generated always as identity primary key,
  key        text not null,
  old_value  jsonb,
  new_value  jsonb not null,
  changed_by uuid,
  changed_at timestamptz not null default now()
);
create index settings_history_key_idx on care.settings_history (key, changed_at desc);
create trigger settings_history_append_only
  before update or delete on care.settings_history
  for each row execute function care.reject_change();

create table care.holidays (
  day        date primary key,
  name       text not null check (char_length(btrim(name)) between 2 and 120),
  kind       text not null check (kind in ('national', 'collective_leave', 'exchange')),
  verified   boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table care.business_hours (
  isodow smallint primary key check (isodow between 1 and 7),
  opens  time not null,
  closes time not null,
  check (closes > opens)
);

create table care.business_hours_overrides (
  day    date primary key,
  opens  time,
  closes time,
  note   text,
  check ((opens is null) = (closes is null)),
  check (closes is null or closes > opens)
);

create table care.counters (
  series     text not null,
  period     text not null,
  last_value bigint not null,
  primary key (series, period)
);

create table care.category_forms (
  id   uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]{1,47}$'),
  name text not null
);

create table care.form_fields (
  form_id    uuid not null references care.category_forms (id) on delete cascade,
  key        text not null check (key ~ '^[a-z][a-z0-9_]{0,39}$'),
  kind       text not null check (
    kind in ('text', 'textarea', 'number', 'money', 'date', 'datetime', 'select', 'boolean',
             'order', 'cash_transaction', 'stock')
  ),
  label_id   text not null,
  label_en   text not null,
  required   boolean not null default false,
  options    jsonb not null default '[]',
  sort_order smallint not null default 0,
  primary key (form_id, key),
  check (jsonb_typeof(options) = 'array'),
  check (kind <> 'select' or jsonb_array_length(options) > 0)
);

create table care.categories (
  id                  uuid primary key default gen_random_uuid(),
  parent_id           uuid references care.categories (id),
  code                text not null unique check (code ~ '^[a-z][a-z0-9_]{1,47}$'),
  name_id             text not null,
  name_en             text not null,
  default_kind        text check (
    default_kind in ('inquiry', 'request', 'complaint', 'incident_report', 'fraud_report', 'feedback')
  ),
  default_priority    text check (default_priority in ('P1', 'P2', 'P3', 'P4')),
  team_id             uuid references care.teams (id),
  form_id             uuid references care.category_forms (id),
  potential_complaint boolean,
  required_documents  text[],
  sort_order          smallint not null default 0,
  active              boolean not null default true,
  check (
    parent_id is not null
    or (default_kind is not null and default_priority is not null and team_id is not null
        and potential_complaint is not null and required_documents is not null)
  )
);
create index categories_parent_idx on care.categories (parent_id);

create table care.sla_policies (
  priority              text primary key check (priority in ('P1', 'P2', 'P3', 'P4')),
  first_response_amount integer not null check (first_response_amount > 0),
  first_response_unit   text not null check (first_response_unit in ('minutes_wall', 'minutes_service', 'business_days')),
  resolution_amount     integer not null check (resolution_amount > 0),
  resolution_unit       text not null check (resolution_unit in ('minutes_wall', 'minutes_service', 'business_days')),
  updated_at            timestamptz not null default now(),
  updated_by            uuid
);

alter table care.teams enable row level security;
alter table care.staff enable row level security;
alter table care.staff_roles enable row level security;
alter table care.team_members enable row level security;
alter table care.settings enable row level security;
alter table care.settings_history enable row level security;
alter table care.holidays enable row level security;
alter table care.business_hours enable row level security;
alter table care.business_hours_overrides enable row level security;
alter table care.counters enable row level security;
alter table care.category_forms enable row level security;
alter table care.form_fields enable row level security;
alter table care.categories enable row level security;
alter table care.sla_policies enable row level security;

create or replace function care.setting(p_key text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select s.value from care.settings s where s.key = p_key;
$$;

create or replace function care.setting_int(p_key text)
returns integer
language sql
stable
set search_path = ''
as $$
  select (s.value #>> '{}')::integer from care.settings s where s.key = p_key;
$$;

create or replace function care.setting_text(p_key text)
returns text
language sql
stable
set search_path = ''
as $$
  select s.value #>> '{}' from care.settings s where s.key = p_key;
$$;

create or replace function care.local_date(p_at timestamptz)
returns date
language sql
stable
set search_path = ''
as $$
  select (p_at at time zone 'Asia/Jakarta')::date;
$$;

create or replace function care.is_business_day(p_day date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select extract(isodow from p_day) < 6
     and not exists (select 1 from care.holidays h where h.day = p_day);
$$;

create or replace function care.business_day_on_or_after(p_day date)
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
    if care.is_business_day(v_day) then
      return v_day;
    end if;
    v_day := v_day + 1;
  end loop;
  raise exception 'Kalender tidak memiliki hari kerja setelah %', p_day;
end;
$$;

create or replace function care.add_business_days(p_day date, p_days integer)
returns date
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day  date := care.business_day_on_or_after(p_day);
  v_left integer := greatest(coalesce(p_days, 0), 0);
begin
  if v_day is null then
    return null;
  end if;
  while v_left > 0 loop
    v_day := v_day + 1;
    if care.is_business_day(v_day) then
      v_left := v_left - 1;
    end if;
  end loop;
  return v_day;
end;
$$;

create or replace function care.business_days_between(p_from date, p_to date)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from generate_series((p_from + 1)::timestamp, p_to::timestamp, interval '1 day') g (day)
  where care.is_business_day(g.day::date);
$$;

create or replace function care.end_of_business_day(p_day date)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select ((p_day + 1)::timestamp at time zone 'Asia/Jakarta') - interval '1 microsecond';
$$;

create or replace function care.regulatory_deadline(p_from timestamptz, p_days integer)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select care.end_of_business_day(care.add_business_days(care.local_date(p_from), p_days));
$$;

create or replace function care.service_window(p_day date, out opens_at timestamptz, out closes_at timestamptz)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_opens  time;
  v_closes time;
begin
  select o.opens, o.closes into v_opens, v_closes
  from care.business_hours_overrides o
  where o.day = p_day;
  if not found then
    if exists (select 1 from care.holidays h where h.day = p_day and h.kind in ('national', 'collective_leave')) then
      return;
    end if;
    select b.opens, b.closes into v_opens, v_closes
    from care.business_hours b
    where b.isodow = extract(isodow from p_day);
  end if;
  if v_opens is not null then
    opens_at := (p_day + v_opens) at time zone 'Asia/Jakarta';
    closes_at := (p_day + v_closes) at time zone 'Asia/Jakarta';
  end if;
end;
$$;

create or replace function care.add_service_minutes(p_from timestamptz, p_minutes integer)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day       date := care.local_date(p_from);
  v_left      numeric := greatest(coalesce(p_minutes, 0), 0);
  v_window    record;
  v_start     timestamptz;
  v_available numeric;
begin
  if not exists (select 1 from care.business_hours) then
    return p_from + v_left * interval '1 minute';
  end if;
  for i in 1 .. 400 loop
    select * into v_window from care.service_window(v_day);
    if v_window.opens_at is not null then
      v_start := greatest(v_window.opens_at, p_from);
      if v_start < v_window.closes_at then
        v_available := extract(epoch from v_window.closes_at - v_start) / 60;
        if v_available >= v_left then
          return v_start + v_left * interval '1 minute';
        end if;
        v_left := v_left - v_available;
      end if;
    end if;
    v_day := v_day + 1;
  end loop;
  return p_from + greatest(coalesce(p_minutes, 0), 0) * interval '1 minute';
end;
$$;

create or replace function care.service_minutes_between(p_from timestamptz, p_to timestamptz)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
  v_day    date := care.local_date(p_from);
  v_last   date := least(care.local_date(p_to), care.local_date(p_from) + 400);
  v_total  numeric := 0;
  v_window record;
begin
  if p_to is null or p_from is null or p_to <= p_from then
    return 0;
  end if;
  if not exists (select 1 from care.business_hours) then
    return extract(epoch from p_to - p_from) / 60;
  end if;
  while v_day <= v_last loop
    select * into v_window from care.service_window(v_day);
    if v_window.opens_at is not null then
      v_total := v_total + greatest(0,
        extract(epoch from least(v_window.closes_at, p_to) - greatest(v_window.opens_at, p_from)) / 60);
    end if;
    v_day := v_day + 1;
  end loop;
  return v_total;
end;
$$;

create or replace function care.sla_due(p_from timestamptz, p_amount integer, p_unit text)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case p_unit
    when 'minutes_wall' then p_from + p_amount * interval '1 minute'
    when 'minutes_service' then care.add_service_minutes(p_from, p_amount)
    when 'business_days' then care.regulatory_deadline(p_from, p_amount)
  end;
$$;

create or replace function care.sla_shift(
  p_due timestamptz, p_unit text, p_paused_at timestamptz, p_resumed_at timestamptz
)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_minutes numeric;
  v_days    integer;
begin
  if p_due is null or p_paused_at is null or p_resumed_at is null
     or p_resumed_at <= p_paused_at or p_paused_at >= p_due then
    return p_due;
  end if;
  if p_unit = 'minutes_wall' then
    return p_due + (p_resumed_at - p_paused_at);
  elsif p_unit = 'minutes_service' then
    v_minutes := ceil(care.service_minutes_between(p_paused_at, p_resumed_at));
    if v_minutes <= 0 then
      return p_due;
    end if;
    return care.add_service_minutes(p_due, v_minutes::integer);
  end if;
  v_days := care.business_days_between(care.local_date(p_paused_at), care.local_date(p_resumed_at));
  if v_days <= 0 then
    return p_due;
  end if;
  return care.end_of_business_day(care.add_business_days(care.local_date(p_due), v_days));
end;
$$;

create or replace function care.next_number(p_series text, p_period text)
returns bigint
language sql
set search_path = ''
as $$
  insert into care.counters as c (series, period, last_value)
  values (p_series, p_period, 1)
  on conflict (series, period) do update set last_value = c.last_value + 1
  returning c.last_value;
$$;

create or replace function care.format_number(p_prefix text, p_period text, p_value bigint, p_width integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select concat_ws('-', p_prefix, nullif(p_period, ''),
                   lpad(p_value::text, greatest(p_width, length(p_value::text)), '0'));
$$;

create or replace function care.random_code(p_length integer)
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', get_byte(b.bytes, i) % 32 + 1, 1), '')
  from (select extensions.gen_random_bytes(p_length) as bytes) b,
       generate_series(0, p_length - 1) i;
$$;

create or replace function care.current_staff_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select s.user_id
  from care.staff s
  where s.user_id = auth.uid()
    and s.disabled_at is null
    and coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

create or replace function care.current_roles()
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(r.role order by r.role), '{}')
  from care.staff_roles r
  where r.user_id = care.current_staff_id();
$$;

create or replace function care.require_staff(p_roles text[] default null)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := care.current_staff_id();
begin
  if v_id is null then
    perform private.api_error(403, 'staff_required', 'Butuh akun staf aktif dengan 2FA');
  end if;
  if p_roles is not null and not (care.current_roles() && p_roles) then
    perform private.api_error(403, 'staff_forbidden', 'Peran staf tidak cukup untuk aksi ini');
  end if;
  return v_id;
end;
$$;

create or replace function care.current_customer_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.id = auth.uid()
    and p.deleted_at is null
    and coalesce(auth.role(), '') = 'authenticated';
$$;

create or replace function care.require_customer()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := care.current_customer_id();
begin
  if v_id is null then
    perform private.api_error(403, 'customer_required', 'Hanya untuk nasabah yang sudah masuk');
  end if;
  return v_id;
end;
$$;

create or replace function care.category_effective(p_category_id uuid)
returns table (
  id                  uuid,
  code                text,
  name_id             text,
  name_en             text,
  path_id             text,
  path_en             text,
  kind                text,
  priority            text,
  team_id             uuid,
  form_id             uuid,
  potential_complaint boolean,
  required_documents  text[],
  active              boolean,
  is_leaf             boolean
)
language sql
stable
set search_path = ''
as $$
  with recursive chain as (
    select c.*, 0 as depth
    from care.categories c
    where c.id = p_category_id
    union all
    select p.*, chain.depth + 1
    from care.categories p
    join chain on p.id = chain.parent_id
    where chain.depth < 10
  )
  select
    leaf.id,
    leaf.code,
    leaf.name_id,
    leaf.name_en,
    (select string_agg(c.name_id, ' › ' order by c.depth desc) from chain c),
    (select string_agg(c.name_en, ' › ' order by c.depth desc) from chain c),
    (select c.default_kind from chain c where c.default_kind is not null order by c.depth limit 1),
    (select c.default_priority from chain c where c.default_priority is not null order by c.depth limit 1),
    (select c.team_id from chain c where c.team_id is not null order by c.depth limit 1),
    (select c.form_id from chain c where c.form_id is not null order by c.depth limit 1),
    (select c.potential_complaint from chain c where c.potential_complaint is not null order by c.depth limit 1),
    (select c.required_documents from chain c where c.required_documents is not null order by c.depth limit 1),
    (select bool_and(c.active) from chain c),
    not exists (select 1 from care.categories k where k.parent_id = leaf.id and k.active)
  from chain leaf
  where leaf.depth = 0;
$$;

insert into care.teams (code, name_id, name_en) values
  ('general', 'Umum', 'General'),
  ('account', 'Akun', 'Accounts'),
  ('funds', 'Dana', 'Funds'),
  ('trading', 'Transaksi', 'Trading'),
  ('settlement', 'Settlement & Kustodian', 'Settlement & Custody'),
  ('technical', 'Teknis', 'Technical'),
  ('social', 'Fitur Sosial', 'Social Features'),
  ('security', 'Keamanan & Fraud', 'Security & Fraud'),
  ('complaints', 'Pengaduan', 'Complaints');

insert into care.settings (key, value, scope, description) values
  ('complaint.oral_days', '5', 'regulatory',
   'Tenggat pengaduan lisan (hari kerja sejak diterima). Default spesifikasi, wajib dikonfirmasi kepatuhan'),
  ('complaint.written_days', '10', 'regulatory',
   'Tenggat pengaduan tertulis (hari kerja sejak dokumen lengkap)'),
  ('complaint.extension_days', '10', 'regulatory', 'Lama perpanjangan tenggat (hari kerja)'),
  ('complaint.max_extensions', '1', 'regulatory', 'Jumlah perpanjangan maksimal per pengaduan'),
  ('complaint.document_wait_days', '10', 'regulatory', 'Waktu nasabah melengkapi dokumen (hari kerja)'),
  ('complaint.objection_days', '7', 'regulatory', 'Batas menyatakan keberatan setelah tanggapan akhir (hari kerja)'),
  ('complaint.objection_review_days', '5', 'regulatory', 'Tenggat peninjauan keberatan tanpa dokumen baru (hari kerja)'),
  ('complaint.warning_stages', '[3, 1, 0]', 'regulatory', 'Peringatan tenggat: sisa hari kerja (H-3, H-1, hari H)'),
  ('complaint.channel_forms',
   '{"chat": "oral", "phone": "oral", "walk_in": "oral", "app": "written", "email": "written", "letter": "written", "social_media": "written"}',
   'regulatory', 'Jenis pengaduan (lisan/tertulis) menurut kanal sumber'),
  ('complaint.extension_reasons',
   '{"third_party_data": {"id": "membutuhkan data atau konfirmasi dari pihak ketiga (bank, KSEI, BEI)", "en": "it requires data or confirmation from a third party (bank, KSEI, IDX)"}, "complex_investigation": {"id": "membutuhkan penelusuran transaksi yang lebih mendalam", "en": "it requires a more in-depth transaction investigation"}, "other_documented": {"id": "kondisi lain yang terdokumentasi", "en": "other documented circumstances"}}',
   'regulatory', 'Kondisi yang membolehkan perpanjangan (kode: label ID/EN)'),
  ('complaint.team', '"complaints"', 'regulatory', 'Kode tim tujuan saat tiket menjadi pengaduan (kosong = tim tetap)'),
  ('numbering.ticket_prefix', '"CC"', 'regulatory', 'Awalan nomor tiket (CC-YYYY-MM-NNNNNN)'),
  ('numbering.complaint_prefix', '"PGD"', 'regulatory', 'Awalan nomor pengaduan (PGD-YYYY-NNNNNN, urut per tahun tanpa celah)'),
  ('retention.complaint_years', '10', 'regulatory', 'Retensi pengaduan, surat, dan tiket terkait (tahun sejak ditutup)'),
  ('retention.ticket_years', '5', 'regulatory', 'Retensi tiket non-pengaduan (tahun sejak ditutup)'),
  ('retention.audit_years', '10', 'regulatory', 'Retensi audit log customer care (tahun)'),
  ('company.name', '"PT [Nama Sekuritas]"', 'regulatory', 'Nama perusahaan di kop surat resmi (WAJIB diisi kepatuhan)'),
  ('company.address', '"[Alamat kantor pusat]"', 'regulatory', 'Alamat di kop surat resmi'),
  ('company.complaint_contact', '"Unit Layanan Pengaduan: [email] · [telepon]"', 'regulatory',
   'Kontak unit pengaduan di surat resmi'),
  ('ticket.reopen_days', '7', 'operational', 'Nasabah bisa membuka kembali tiket non-pengaduan dalam sekian hari'),
  ('ticket.pending_reminder_business_days', '3', 'operational', 'Pengingat saat menunggu nasabah (hari kerja)'),
  ('ticket.pending_autoresolve_business_days', '7', 'operational',
   'Tiket non-pengaduan yang menunggu nasabah diselesaikan otomatis (hari kerja)'),
  ('ticket.max_backdate_days', '30', 'operational', 'Batas mundur tanggal terima saat staf mencatat tiket manual (hari)'),
  ('ticket.root_causes',
   '{"customer_guidance": {"id": "Panduan untuk nasabah", "en": "Customer guidance"}, "system_issue": {"id": "Masalah sistem", "en": "System issue"}, "third_party": {"id": "Pihak ketiga", "en": "Third party"}, "process_error": {"id": "Kesalahan proses internal", "en": "Internal process error"}, "market_condition": {"id": "Kondisi pasar / aturan bursa", "en": "Market condition / exchange rules"}, "fraud": {"id": "Penipuan", "en": "Fraud"}, "duplicate": {"id": "Duplikat", "en": "Duplicate"}, "no_customer_response": {"id": "Tidak ada tanggapan nasabah", "en": "No customer response"}, "other": {"id": "Lainnya", "en": "Other"}}',
   'operational', 'Kategori akar masalah saat tiket diselesaikan'),
  ('customer_data.profile_views_per_hour', '30', 'operational', 'Batas pembukaan data nasabah per staf per jam (deteksi anomali)'),
  ('customer_data.reveals_per_hour', '10', 'operational', 'Batas membuka data tersamar per staf per jam'),
  ('customer_data.reveal_reasons',
   '{"callback_verification": {"id": "Verifikasi panggilan balik", "en": "Callback verification"}, "data_correction": {"id": "Permintaan koreksi data", "en": "Data correction request"}, "fraud_investigation": {"id": "Investigasi penipuan", "en": "Fraud investigation"}, "regulatory_request": {"id": "Permintaan regulator", "en": "Regulatory request"}}',
   'operational', 'Alasan yang boleh dipilih saat membuka data tersamar'),
  ('secure_account.actions', '["logout_all", "lock_trading"]', 'operational', 'Aksi OLT saat nasabah menekan "Amankan akun saya"');

insert into care.business_hours (isodow, opens, closes) values
  (1, '08:00', '22:00'), (2, '08:00', '22:00'), (3, '08:00', '22:00'), (4, '08:00', '22:00'),
  (5, '08:00', '22:00'), (6, '09:00', '18:00'), (7, '09:00', '18:00');

insert into care.holidays (day, name, kind) values
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

insert into care.sla_policies
  (priority, first_response_amount, first_response_unit, resolution_amount, resolution_unit) values
  ('P1', 15, 'minutes_wall', 240, 'minutes_wall'),
  ('P2', 60, 'minutes_service', 1, 'business_days'),
  ('P3', 240, 'minutes_service', 3, 'business_days'),
  ('P4', 1, 'business_days', 5, 'business_days');

insert into care.category_forms (code, name) values
  ('order', 'Masalah order'),
  ('cash_transaction', 'Transaksi dana RDN'),
  ('stock', 'Saham terkait'),
  ('error_report', 'Laporan error aplikasi'),
  ('contact_report', 'Kontak mencurigakan');

insert into care.form_fields (form_id, key, kind, label_id, label_en, required, options, sort_order)
select f.id, v.key, v.kind, v.label_id, v.label_en, v.required, v.options::jsonb, v.sort_order
from (values
  ('order', 'order_id', 'order', 'Order terkait', 'Related order', true, '[]', 1),
  ('cash_transaction', 'transaction_id', 'cash_transaction', 'Transaksi terkait', 'Related transaction', true, '[]', 1),
  ('stock', 'stock_code', 'stock', 'Kode saham', 'Stock code', true, '[]', 1),
  ('error_report', 'error_code', 'text', 'Kode error (bila ada)', 'Error code (if any)', false, '[]', 1),
  ('error_report', 'occurred_at', 'datetime', 'Waktu kejadian', 'When it happened', false, '[]', 2),
  ('contact_report', 'contact_kind', 'select', 'Jenis kontak', 'Contact type', true,
   '[{"value": "phone", "id": "Telepon / SMS", "en": "Phone / SMS"}, {"value": "whatsapp", "id": "WhatsApp", "en": "WhatsApp"}, {"value": "social_media", "id": "Media sosial", "en": "Social media"}, {"value": "website", "id": "Situs web", "en": "Website"}, {"value": "email", "id": "Email", "en": "Email"}, {"value": "other", "id": "Lainnya", "en": "Other"}]', 1),
  ('contact_report', 'contact_detail', 'text', 'Nomor, akun, atau alamat yang menghubungi', 'Number, account, or address used', true, '[]', 2)
) as v (form_code, key, kind, label_id, label_en, required, options, sort_order)
join care.category_forms f on f.code = v.form_code;

insert into care.categories
  (code, name_id, name_en, default_kind, default_priority, team_id, potential_complaint, required_documents, sort_order)
select v.code, v.name_id, v.name_en, v.kind, v.priority, t.id, v.potential, '{}', v.sort_order
from (values
  ('account', 'Akun & Registrasi', 'Account & Registration', 'inquiry', 'P3', 'account', true, 1),
  ('login_security', 'Login & Keamanan', 'Login & Security', 'inquiry', 'P3', 'account', true, 2),
  ('funds', 'Dana (RDN)', 'Funds (RDN)', 'inquiry', 'P3', 'funds', true, 3),
  ('trading', 'Transaksi / Order', 'Trading / Orders', 'inquiry', 'P3', 'trading', true, 4),
  ('portfolio', 'Portofolio & Settlement', 'Portfolio & Settlement', 'inquiry', 'P3', 'settlement', true, 5),
  ('corporate_action', 'Aksi Korporasi', 'Corporate Actions', 'inquiry', 'P3', 'settlement', true, 6),
  ('fees_reports', 'Biaya, Pajak & Laporan', 'Fees, Tax & Reports', 'inquiry', 'P3', 'general', true, 7),
  ('app_technical', 'Aplikasi & Teknis', 'App & Technical', 'incident_report', 'P3', 'technical', false, 8),
  ('social', 'Fitur Sosial', 'Social Features', 'inquiry', 'P3', 'social', false, 9),
  ('fraud_security', 'Penipuan & Keamanan', 'Fraud & Security', 'fraud_report', 'P1', 'security', true, 10),
  ('feedback', 'Saran & Masukan', 'Suggestions & Feedback', 'feedback', 'P4', 'general', false, 11),
  ('other', 'Lainnya', 'Other', 'inquiry', 'P3', 'general', false, 12)
) as v (code, name_id, name_en, kind, priority, team_code, potential, sort_order)
join care.teams t on t.code = v.team_code;

insert into care.categories
  (parent_id, code, name_id, name_en, default_kind, default_priority, team_id, form_id, required_documents, sort_order)
select p.id, v.code, v.name_id, v.name_en, v.kind, v.priority, t.id, f.id, v.documents::text[], v.sort_order
from (values
  ('account', 'account_opening', 'Pembukaan rekening / KYC', 'Account opening / KYC', null, null, null, null, null, 1),
  ('account', 'data_verification', 'Verifikasi data', 'Data verification', null, null, null, null, null, 2),
  ('account', 'rdn_activation', 'Aktivasi RDN', 'RDN activation', null, null, null, null, null, 3),
  ('account', 'personal_data_change', 'Perubahan data pribadi', 'Personal data change', 'request', null, null, null, null, 4),
  ('account', 'bank_account_change', 'Perubahan rekening bank', 'Bank account change', 'request', null, null, null, null, 5),
  ('account', 'account_closure', 'Penutupan akun', 'Account closure', 'request', null, null, null, null, 6),
  ('account', 'sid_akses', 'SID / AKSes KSEI', 'SID / KSEI AKSes', null, null, null, null, null, 7),
  ('login_security', 'forgot_credentials', 'Lupa password / PIN', 'Forgot password / PIN', null, null, null, null, null, 1),
  ('login_security', 'account_locked', 'Akun terkunci', 'Account locked', null, 'P2', null, null, null, 2),
  ('login_security', 'new_device', 'Perangkat baru', 'New device', null, null, null, null, null, 3),
  ('login_security', 'suspicious_activity', 'Aktivitas mencurigakan', 'Suspicious activity', 'fraud_report', 'P2', 'security', null, null, 4),
  ('login_security', 'otp_not_received', 'OTP tidak masuk', 'OTP not received', 'incident_report', null, 'technical', null, null, 5),
  ('funds', 'deposit_missing', 'Deposit belum masuk', 'Deposit not received', null, null, null, 'cash_transaction', '{Bukti transfer}', 1),
  ('funds', 'withdrawal_delayed', 'Penarikan tertunda / gagal', 'Withdrawal delayed / failed', null, 'P2', null, 'cash_transaction', null, 2),
  ('funds', 'balance_mismatch', 'Saldo tidak sesuai', 'Balance mismatch', null, null, null, 'cash_transaction', null, 3),
  ('funds', 'transfer_fee', 'Biaya transfer', 'Transfer fees', null, null, null, null, null, 4),
  ('trading', 'order_rejected', 'Order ditolak', 'Order rejected', null, null, null, 'order', null, 1),
  ('trading', 'order_not_executed', 'Order tidak tereksekusi', 'Order not executed', null, null, null, 'order', null, 2),
  ('trading', 'price_mismatch', 'Harga tidak sesuai', 'Price mismatch', null, null, null, 'order', null, 3),
  ('trading', 'cancel_amend_failed', 'Order tidak bisa dibatalkan / amend', 'Order cannot be cancelled / amended', null, null, null, 'order', null, 4),
  ('trading', 'insufficient_lot_balance', 'Lot atau saldo tidak cukup', 'Insufficient lots or balance', null, null, null, 'order', null, 5),
  ('trading', 'auto_order', 'Auto order / trailing', 'Auto order / trailing', null, null, null, 'order', null, 6),
  ('trading', 'trade_confirmation', 'Trade confirmation', 'Trade confirmation', null, null, null, null, null, 7),
  ('portfolio', 'shares_missing', 'Saham belum masuk', 'Shares not received', null, null, null, 'stock', null, 1),
  ('portfolio', 'position_mismatch', 'Posisi tidak sesuai', 'Position mismatch', null, null, null, 'stock', null, 2),
  ('portfolio', 'settlement', 'Settlement T+2', 'T+2 settlement', null, null, null, null, null, 3),
  ('portfolio', 'average_price', 'Average price', 'Average price', null, null, null, 'stock', null, 4),
  ('corporate_action', 'dividend', 'Dividen', 'Dividend', null, null, null, 'stock', null, 1),
  ('corporate_action', 'rights_issue', 'Right issue', 'Rights issue', null, null, null, 'stock', null, 2),
  ('corporate_action', 'stock_split', 'Stock split / reverse', 'Stock split / reverse', null, null, null, 'stock', null, 3),
  ('corporate_action', 'tender_offer', 'Tender offer', 'Tender offer', null, null, null, 'stock', null, 4),
  ('corporate_action', 'warrant', 'Waran', 'Warrant', null, null, null, 'stock', null, 5),
  ('corporate_action', 'e_ipo', 'e-IPO', 'e-IPO', null, null, null, null, null, 6),
  ('fees_reports', 'transaction_fee', 'Fee transaksi', 'Transaction fees', null, null, null, null, null, 1),
  ('fees_reports', 'tax', 'Pajak', 'Tax', null, null, null, null, null, 2),
  ('fees_reports', 'tax_slip', 'Bukti potong pajak', 'Tax withholding slip', 'request', null, null, null, null, 3),
  ('fees_reports', 'monthly_statement', 'Laporan bulanan', 'Monthly statement', 'request', null, null, null, null, 4),
  ('fees_reports', 'portfolio_report', 'Laporan portofolio', 'Portfolio report', 'request', null, null, null, null, 5),
  ('fees_reports', 'transaction_confirmation', 'Konfirmasi transaksi', 'Transaction confirmation', 'request', null, null, null, null, 6),
  ('app_technical', 'app_error', 'Aplikasi error atau crash', 'App error or crash', null, null, null, 'error_report', null, 1),
  ('app_technical', 'price_not_updating', 'Data harga tidak update', 'Prices not updating', null, null, null, 'error_report', null, 2),
  ('app_technical', 'chart', 'Chart', 'Charts', null, null, null, 'error_report', null, 3),
  ('app_technical', 'notification', 'Notifikasi', 'Notifications', null, null, null, 'error_report', null, 4),
  ('app_technical', 'app_update', 'Update aplikasi', 'App update', null, null, null, 'error_report', null, 5),
  ('app_technical', 'slow_performance', 'Kinerja lambat', 'Slow performance', null, null, null, 'error_report', null, 6),
  ('social', 'moderation_appeal', 'Banding moderasi', 'Moderation appeal', 'request', null, null, null, null, 1),
  ('social', 'content_report', 'Laporan konten', 'Content report', null, null, null, null, null, 2),
  ('social', 'social_chat', 'Masalah chat sosial', 'Social chat issue', null, null, null, null, null, 3),
  ('fraud_security', 'fake_cs', 'CS palsu', 'Fake customer service', null, null, null, 'contact_report', null, 1),
  ('fraud_security', 'phishing', 'Phishing', 'Phishing', null, null, null, 'contact_report', null, 2),
  ('fraud_security', 'unknown_transaction', 'Transaksi tidak dikenal', 'Unknown transaction', 'complaint', null, null, null, null, 3),
  ('fraud_security', 'account_hacked', 'Peretasan akun', 'Account takeover', 'complaint', null, null, null, null, 4)
) as v (parent_code, code, name_id, name_en, kind, priority, team_code, form_code, documents, sort_order)
join care.categories p on p.code = v.parent_code
left join care.teams t on t.code = v.team_code
left join care.category_forms f on f.code = v.form_code;
