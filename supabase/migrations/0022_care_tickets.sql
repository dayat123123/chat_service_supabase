create table care.tickets (
  id                    uuid primary key default gen_random_uuid(),
  number                text not null unique,
  kind                  text not null check (
    kind in ('inquiry', 'request', 'complaint', 'incident_report', 'fraud_report', 'feedback')
  ),
  channel               text not null check (
    channel in ('chat', 'app', 'phone', 'email', 'letter', 'walk_in', 'social_media')
  ),
  customer_id           uuid not null references public.profiles (id),
  language              text not null default 'id' check (language in ('id', 'en')),
  category_id           uuid not null references care.categories (id),
  subject               text not null check (char_length(subject) between 1 and 300),
  description           text not null default '' check (char_length(description) <= 5000),
  status                text not null default 'new' check (
    status in ('new', 'open', 'pending_customer', 'pending_internal', 'pending_third_party',
               'escalated', 'extended', 'resolved', 'closed', 'cancelled')
  ),
  priority              text not null check (priority in ('P1', 'P2', 'P3', 'P4')),
  team_id               uuid not null references care.teams (id),
  assignee_id           uuid references care.staff (user_id),
  created_by            uuid not null,
  client_id             uuid,
  received_at           timestamptz not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  status_changed_at     timestamptz not null default now(),
  first_response_due_at timestamptz,
  first_response_at     timestamptz,
  resolution_due_at     timestamptz,
  sla_paused_at         timestamptz,
  resolved_at           timestamptz,
  closed_at             timestamptz,
  cancelled_at          timestamptz,
  root_cause            text,
  resolution_summary    text check (char_length(resolution_summary) <= 5000),
  masked_kinds          text[] not null default '{}',
  legal_hold            boolean not null default false,
  retain_until          timestamptz,
  unique (created_by, client_id)
);
create index tickets_customer_idx on care.tickets (customer_id, created_at desc);
create index tickets_created_by_idx on care.tickets (created_by, created_at desc);
create index tickets_team_active_idx on care.tickets (team_id, updated_at desc)
  where status not in ('closed', 'cancelled');
create index tickets_assignee_active_idx on care.tickets (assignee_id, updated_at desc)
  where status not in ('closed', 'cancelled');
create index tickets_pending_customer_idx on care.tickets (status_changed_at) where status = 'pending_customer';
create index tickets_resolved_idx on care.tickets (resolved_at) where status = 'resolved';
create index tickets_open_sla_idx on care.tickets (resolution_due_at)
  where status not in ('resolved', 'closed', 'cancelled');
create index tickets_retention_idx on care.tickets (retain_until) where retain_until is not null;
create trigger tickets_updated_at
  before update on care.tickets
  for each row execute function private.set_updated_at();

create table care.complaints (
  ticket_id              uuid primary key references care.tickets (id) on delete cascade,
  number                 text not null unique,
  form                   text not null check (form in ('oral', 'written')),
  received_at            timestamptz not null,
  documents_required     text[] not null default '{}',
  documents_requested_at timestamptz,
  documents_due_at       timestamptz,
  documents_complete_at  timestamptz,
  conversion_requested_at timestamptz,
  clock_paused_at        timestamptz,
  due_at                 timestamptz,
  original_due_at        timestamptz,
  extension_count        smallint not null default 0,
  extended_at            timestamptz,
  extension_reason       text,
  final_response_at      timestamptz,
  objection_count        smallint not null default 0,
  last_objection_at      timestamptz,
  reclassified_at        timestamptz,
  reclassified_to        text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index complaints_due_idx on care.complaints (due_at) where reclassified_at is null and due_at is not null;
create trigger complaints_updated_at
  before update on care.complaints
  for each row execute function private.set_updated_at();

create table care.ticket_events (
  id          bigint generated always as identity,
  ticket_id   uuid not null references care.tickets (id) on delete cascade,
  created_at  timestamptz not null default now(),
  actor_type  text not null check (actor_type in ('customer', 'staff', 'system')),
  actor_id    uuid,
  type        text not null,
  visibility  text not null check (visibility in ('public', 'internal')),
  data        jsonb not null default '{}',
  primary key (id, created_at)
) partition by range (created_at);
create index ticket_events_ticket_idx on care.ticket_events (ticket_id, created_at);
create table care.ticket_events_default partition of care.ticket_events default;

create table care.ticket_messages (
  id           bigint generated always as identity,
  ticket_id    uuid not null references care.tickets (id) on delete cascade,
  created_at   timestamptz not null default now(),
  author_type  text not null check (author_type in ('customer', 'staff', 'system')),
  author_id    uuid,
  visibility   text not null check (visibility in ('public', 'internal')),
  status       text not null default 'sent' check (status in ('sent', 'held')),
  body         text not null check (char_length(body) between 1 and 5000),
  masked_kinds text[] not null default '{}',
  client_id    uuid,
  primary key (id, created_at)
) partition by range (created_at);
create index ticket_messages_ticket_idx on care.ticket_messages (ticket_id, created_at);
create index ticket_messages_author_idx on care.ticket_messages (author_id, created_at desc);
create table care.ticket_messages_default partition of care.ticket_messages default;

create table care.audit_log (
  id          bigint generated always as identity,
  created_at  timestamptz not null default now(),
  actor_id    uuid,
  actor_type  text not null check (actor_type in ('staff', 'customer', 'service', 'system')),
  actor_roles text[] not null default '{}',
  action      text not null,
  ticket_id   uuid,
  target_type text,
  target_id   text,
  details     jsonb not null default '{}',
  primary key (id, created_at)
) partition by range (created_at);
create index audit_log_actor_idx on care.audit_log (actor_id, action, created_at desc);
create index audit_log_ticket_idx on care.audit_log (ticket_id, created_at desc);
create table care.audit_log_default partition of care.audit_log default;

create table care.ticket_field_values (
  ticket_id uuid not null references care.tickets (id) on delete cascade,
  field_key text not null,
  kind      text not null,
  label_id  text not null,
  label_en  text not null,
  value     jsonb not null,
  primary key (ticket_id, field_key)
);

create table care.ticket_context (
  ticket_id    uuid primary key references care.tickets (id) on delete cascade,
  app_version  text,
  platform     text,
  os           text,
  device_model text,
  locale       text,
  connection   text,
  last_screen  text,
  error_code   text,
  occurred_at  timestamptz,
  logs         text,
  created_at   timestamptz not null default now()
);

create table care.ticket_related_items (
  id         uuid primary key default gen_random_uuid(),
  ticket_id  uuid not null references care.tickets (id) on delete cascade,
  kind       text not null check (kind in ('order', 'cash_transaction')),
  ref        text not null check (ref ~ '^[A-Za-z0-9._:-]{1,64}$'),
  status     text not null default 'pending' check (status in ('pending', 'ok', 'not_found', 'unavailable')),
  snapshot   jsonb,
  fetched_at timestamptz,
  created_at timestamptz not null default now(),
  unique (ticket_id, kind, ref)
);

create table care.reclassification_requests (
  id            uuid primary key default gen_random_uuid(),
  ticket_id     uuid not null references care.tickets (id) on delete cascade,
  from_kind     text not null,
  to_kind       text not null,
  reason        text not null,
  requested_by  uuid not null,
  requested_at  timestamptz not null default now(),
  decision      text check (decision in ('approved', 'rejected')),
  decided_by    uuid,
  decided_at    timestamptz,
  decision_note text
);
create unique index reclassification_pending_idx on care.reclassification_requests (ticket_id) where decision is null;

create table care.ticket_sla_pauses (
  id         bigint generated always as identity primary key,
  ticket_id  uuid not null references care.tickets (id) on delete cascade,
  paused_at  timestamptz not null,
  resumed_at timestamptz,
  check (resumed_at is null or resumed_at >= paused_at)
);
create unique index ticket_sla_pauses_open_idx on care.ticket_sla_pauses (ticket_id) where resumed_at is null;

create table care.staff_notifications (
  id         bigint generated always as identity primary key,
  staff_id   uuid not null references care.staff (user_id) on delete cascade,
  kind       text not null,
  ticket_id  uuid references care.tickets (id) on delete cascade,
  data       jsonb not null default '{}',
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index staff_notifications_staff_idx on care.staff_notifications (staff_id, created_at desc);
create index staff_notifications_unread_idx on care.staff_notifications (staff_id) where read_at is null;

create table care.sla_alerts (
  ticket_id  uuid not null references care.tickets (id) on delete cascade,
  kind       text not null,
  stage      text not null,
  due_at     timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (ticket_id, kind, stage, due_at)
);

create table care.message_templates (
  id            uuid primary key default gen_random_uuid(),
  code          text not null check (code in ('complaint_receipt', 'extension_notice', 'final_response')),
  language      text not null check (language in ('id', 'en')),
  version       integer not null check (version > 0),
  status        text not null default 'draft' check (status in ('draft', 'active', 'retired')),
  reviewed      boolean not null default false,
  title         text not null,
  body          text not null,
  email_subject text not null,
  email_body    text not null,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  approved_by   uuid,
  approved_at   timestamptz,
  unique (code, language, version)
);
create unique index message_templates_active_idx on care.message_templates (code, language) where status = 'active';

create table care.official_letters (
  id                uuid primary key default gen_random_uuid(),
  ticket_id         uuid not null references care.tickets (id) on delete cascade,
  kind              text not null check (kind in ('complaint_receipt', 'extension_notice', 'final_response')),
  number            text not null unique,
  verification_code text not null unique check (verification_code ~ '^[A-Z2-9]{10}$'),
  template_id       uuid not null references care.message_templates (id),
  language          text not null,
  content           jsonb not null,
  storage_path      text not null unique,
  status            text not null default 'pending' check (status in ('pending', 'ready', 'failed')),
  sha256            text check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes        integer check (size_bytes > 0),
  email_status      text not null default 'pending' check (email_status in ('pending', 'sent', 'no_address', 'failed')),
  emailed_at        timestamptz,
  issued_at         timestamptz not null default now(),
  rendered_at       timestamptz
);
create index official_letters_ticket_idx on care.official_letters (ticket_id, issued_at);

create table care.outbox (
  id           bigint generated always as identity primary key,
  kind         text not null check (kind in ('render_letter', 'email_letter', 'fetch_snapshot', 'secure_account')),
  ticket_id    uuid references care.tickets (id) on delete cascade,
  payload      jsonb not null default '{}',
  status       text not null default 'pending' check (status in ('pending', 'done', 'dead')),
  attempts     integer not null default 0,
  max_attempts integer not null default 8 check (max_attempts > 0),
  run_after    timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text,
  last_error   text,
  created_at   timestamptz not null default now(),
  finished_at  timestamptz
);
create index outbox_ready_idx on care.outbox (kind, run_after) where status = 'pending';
create index outbox_finished_idx on care.outbox (finished_at) where status <> 'pending';

alter table care.tickets enable row level security;
alter table care.complaints enable row level security;
alter table care.ticket_events enable row level security;
alter table care.ticket_events_default enable row level security;
alter table care.ticket_messages enable row level security;
alter table care.ticket_messages_default enable row level security;
alter table care.audit_log enable row level security;
alter table care.audit_log_default enable row level security;
alter table care.ticket_field_values enable row level security;
alter table care.ticket_context enable row level security;
alter table care.ticket_related_items enable row level security;
alter table care.reclassification_requests enable row level security;
alter table care.ticket_sla_pauses enable row level security;
alter table care.staff_notifications enable row level security;
alter table care.sla_alerts enable row level security;
alter table care.message_templates enable row level security;
alter table care.official_letters enable row level security;
alter table care.outbox enable row level security;

create trigger ticket_events_append_only
  before update or delete on care.ticket_events
  for each row execute function care.reject_change();
create trigger ticket_events_no_truncate
  before truncate on care.ticket_events
  for each statement execute function care.reject_change();
create trigger ticket_messages_append_only
  before update or delete on care.ticket_messages
  for each row execute function care.reject_change();
create trigger ticket_messages_no_truncate
  before truncate on care.ticket_messages
  for each statement execute function care.reject_change();
create trigger audit_log_append_only
  before update or delete on care.audit_log
  for each row execute function care.reject_change();
create trigger audit_log_no_truncate
  before truncate on care.audit_log
  for each statement execute function care.reject_change();

create or replace function care.official_letters_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if current_setting('care.retention', true) = 'on' then
      return old;
    end if;
    raise exception 'Surat resmi tidak bisa dihapus' using errcode = '42501';
  end if;
  if (new.ticket_id, new.kind, new.number, new.verification_code, new.template_id, new.language,
      new.content, new.storage_path, new.issued_at)
     is distinct from
     (old.ticket_id, old.kind, old.number, old.verification_code, old.template_id, old.language,
      old.content, old.storage_path, old.issued_at)
     or (old.sha256 is not null and new.sha256 is distinct from old.sha256) then
    raise exception 'Isi surat resmi tidak bisa diubah' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger official_letters_guard
  before update or delete on care.official_letters
  for each row execute function care.official_letters_guard();

create or replace function care.ensure_partitions(p_months_ahead integer default 3)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_table   text;
  v_start   timestamp;
  v_name    text;
  v_created integer := 0;
begin
  foreach v_table in array array['ticket_events', 'ticket_messages', 'audit_log'] loop
    for i in 0 .. greatest(coalesce(p_months_ahead, 3), 0) loop
      v_start := date_trunc('month', now() at time zone 'UTC') + make_interval(months => i);
      v_name := format('%s_p%s', v_table, to_char(v_start, 'YYYYMM'));
      continue when to_regclass('care.' || v_name) is not null;
      begin
        execute format('create table care.%I partition of care.%I for values from (%L) to (%L)',
                       v_name, v_table, v_start at time zone 'UTC',
                       (v_start + interval '1 month') at time zone 'UTC');
        execute format('alter table care.%I enable row level security', v_name);
        v_created := v_created + 1;
      exception when check_violation then
        raise warning 'care.ensure_partitions: partisi % dilewati, partisi default sudah berisi data bulan itu', v_name;
      end;
    end loop;
  end loop;
  return v_created;
end;
$$;

select care.ensure_partitions(3);

create or replace function care.luhn_valid(p_digits text)
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

create or replace function care.mask_number(p_kind text, p_candidate text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(p_candidate, '[^0-9]', '', 'g');
begin
  if p_kind = 'card' then
    if length(v_digits) between 13 and 19 and care.luhn_valid(v_digits) then
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

create or replace function care.mask_numbers(p_text text, p_kind text)
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
    v_replacement := care.mask_number(p_kind, substr(v_out, v_start, v_end - v_start));
    v_out := overlay(v_out placing v_replacement from v_start for v_end - v_start);
    v_from := v_start + greatest(length(v_replacement), 1);
  end loop;
  return v_out;
end;
$$;

create or replace function care.mask_sensitive(p_text text, out masked text, out kinds text[])
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
    v_next := care.mask_numbers(masked, v_kind);
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

create or replace function care.requests_secret(p_text text)
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

create or replace function care.mask_message()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_masked record;
begin
  select * into v_masked from care.mask_sensitive(new.body);
  new.body := v_masked.masked;
  new.masked_kinds := v_masked.kinds;
  return new;
end;
$$;

create trigger ticket_messages_mask
  before insert on care.ticket_messages
  for each row execute function care.mask_message();

create or replace function care.label(p_group text, p_code text, p_language text)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce('{
    "channel": {
      "chat": {"id": "Live chat aplikasi", "en": "In-app live chat"},
      "app": {"id": "Formulir aplikasi", "en": "In-app form"},
      "phone": {"id": "Telepon", "en": "Phone"},
      "email": {"id": "Email", "en": "Email"},
      "letter": {"id": "Surat", "en": "Letter"},
      "walk_in": {"id": "Datang langsung", "en": "Walk-in"},
      "social_media": {"id": "Media sosial", "en": "Social media"}
    },
    "form": {
      "oral": {"id": "Lisan", "en": "Oral"},
      "written": {"id": "Tertulis", "en": "Written"}
    },
    "kind": {
      "inquiry": {"id": "Pertanyaan", "en": "Inquiry"},
      "request": {"id": "Permintaan", "en": "Request"},
      "complaint": {"id": "Pengaduan", "en": "Complaint"},
      "incident_report": {"id": "Laporan masalah", "en": "Incident report"},
      "fraud_report": {"id": "Laporan penipuan", "en": "Fraud report"},
      "feedback": {"id": "Saran", "en": "Feedback"}
    }
  }'::jsonb -> p_group -> p_code ->> coalesce(p_language, 'id'), p_code);
$$;

create or replace function care.status_label(p_status text, p_extended boolean, p_language text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_status = 'new' then case when p_language = 'en' then 'Received' else 'Diterima' end
    when p_status = 'pending_customer' then case when p_language = 'en' then 'Awaiting your reply' else 'Menunggu tanggapan Anda' end
    when p_status = 'resolved' then case when p_language = 'en' then 'Resolved' else 'Selesai' end
    when p_status = 'closed' then case when p_language = 'en' then 'Closed' else 'Ditutup' end
    when p_status = 'cancelled' then case when p_language = 'en' then 'Cancelled' else 'Dibatalkan' end
    when p_status = 'extended' or coalesce(p_extended, false) then
      case when p_language = 'en' then 'In progress (extended)' else 'Diproses (diperpanjang)' end
    else case when p_language = 'en' then 'In progress' else 'Sedang diproses' end
  end;
$$;

create or replace function care.format_date(p_at timestamptz, p_language text, p_with_time boolean default false)
returns text
language sql
stable
set search_path = ''
as $$
  select case when p_at is null then null else
    to_char(x.local, 'FMDD') || ' '
    || (case when p_language = 'en'
             then array['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
                        'September', 'October', 'November', 'December']
             else array['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus',
                        'September', 'Oktober', 'November', 'Desember'] end)[extract(month from x.local)::integer]
    || ' ' || to_char(x.local, 'YYYY')
    || case when not coalesce(p_with_time, false) then ''
            when p_language = 'en' then to_char(x.local, ' HH24:MI') || ' WIB'
            else ' pukul ' || to_char(x.local, 'HH24.MI') || ' WIB' end
  end
  from (select p_at at time zone 'Asia/Jakarta' as local) x;
$$;

create or replace function care.actor_type()
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when care.current_staff_id() is not null then 'staff'
    when care.current_customer_id() is not null then 'customer'
    else 'system'
  end;
$$;

create or replace function care.add_event(p_ticket_id uuid, p_type text, p_visibility text, p_data jsonb default '{}')
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_actor text := care.actor_type();
  v_id    bigint;
begin
  insert into care.ticket_events (ticket_id, actor_type, actor_id, type, visibility, data)
  values (p_ticket_id, v_actor, case when v_actor = 'system' then null else auth.uid() end,
          p_type, p_visibility, coalesce(p_data, '{}'))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function care.audit(
  p_action      text,
  p_ticket_id   uuid default null,
  p_target_type text default null,
  p_target_id   text default null,
  p_details     jsonb default '{}'
)
returns void
language sql
set search_path = ''
as $$
  insert into care.audit_log (actor_id, actor_type, actor_roles, action, ticket_id, target_type, target_id, details)
  values (
    auth.uid(),
    case
      when care.current_staff_id() is not null then 'staff'
      when coalesce(auth.role(), '') = 'service_role' then 'service'
      when care.current_customer_id() is not null then 'customer'
      else 'system'
    end,
    care.current_roles(), p_action, p_ticket_id, p_target_type, p_target_id, coalesce(p_details, '{}'));
$$;

create or replace function care.team_staff(p_team_id uuid, p_roles text[])
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct tm.user_id), '{}')
  from care.team_members tm
  join care.staff s on s.user_id = tm.user_id and s.disabled_at is null
  join care.staff_roles r on r.user_id = tm.user_id and r.role = any (p_roles)
  where tm.team_id = p_team_id;
$$;

create or replace function care.role_staff(p_roles text[])
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct s.user_id), '{}')
  from care.staff s
  join care.staff_roles r on r.user_id = s.user_id and r.role = any (p_roles)
  where s.disabled_at is null;
$$;

create or replace function care.notify_staff(p_staff_ids uuid[], p_kind text, p_ticket_id uuid, p_data jsonb default '{}')
returns integer
language sql
set search_path = ''
as $$
  with inserted as (
    insert into care.staff_notifications (staff_id, kind, ticket_id, data)
    select s.user_id, p_kind, p_ticket_id, coalesce(p_data, '{}')
    from care.staff s
    where s.user_id = any (coalesce(p_staff_ids, '{}')) and s.disabled_at is null
    returning 1
  )
  select count(*)::integer from inserted;
$$;

create or replace function care.broadcast_ticket_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload  jsonb := jsonb_build_object('ticket_id', new.ticket_id, 'event_id', new.id, 'type', new.type);
  v_customer uuid;
begin
  perform realtime.send(v_payload, 'ticket_event', 'care:ticket:' || new.ticket_id::text || ':staff', true);
  if new.visibility = 'public' then
    perform realtime.send(v_payload, 'ticket_event', 'care:ticket:' || new.ticket_id::text, true);
    select t.customer_id into v_customer from care.tickets t where t.id = new.ticket_id;
    perform realtime.send(jsonb_build_object('ticket_id', new.ticket_id), 'ticket_updated',
                          'care:customer:' || v_customer::text, true);
  end if;
  return null;
end;
$$;

create trigger ticket_events_broadcast
  after insert on care.ticket_events
  for each row execute function care.broadcast_ticket_event();

create or replace function care.broadcast_ticket_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload  jsonb := jsonb_build_object('ticket_id', new.ticket_id, 'message_id', new.id, 'type', 'message');
  v_customer uuid;
begin
  perform realtime.send(v_payload, 'ticket_event', 'care:ticket:' || new.ticket_id::text || ':staff', true);
  if new.visibility = 'public' and new.status = 'sent' then
    perform realtime.send(v_payload, 'ticket_event', 'care:ticket:' || new.ticket_id::text, true);
    select t.customer_id into v_customer from care.tickets t where t.id = new.ticket_id;
    perform realtime.send(jsonb_build_object('ticket_id', new.ticket_id), 'ticket_updated',
                          'care:customer:' || v_customer::text, true);
  end if;
  return null;
end;
$$;

create trigger ticket_messages_broadcast
  after insert on care.ticket_messages
  for each row execute function care.broadcast_ticket_message();

create or replace function care.broadcast_staff_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(jsonb_build_object('id', new.id, 'kind', new.kind, 'ticket_id', new.ticket_id),
                        'notification', 'care:agent:' || new.staff_id::text, true);
  return null;
end;
$$;

create trigger staff_notifications_broadcast
  after insert on care.staff_notifications
  for each row execute function care.broadcast_staff_notification();

create or replace function care.staff_can_view(p_team_id uuid, p_assignee_id uuid, p_customer_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    me.id is not null and (
      'compliance' = any (me.roles)
      or (
        me.roles && array['agent_l1', 'agent_l2', 'specialist', 'supervisor']
        and exists (select 1 from public.profiles p where p.id = p_customer_id and p.deleted_at is null)
        and (
          p_assignee_id = me.id
          or exists (select 1 from care.team_members tm where tm.team_id = p_team_id and tm.user_id = me.id)
        )
      )
    ), false)
  from (select care.current_staff_id() as id, care.current_roles() as roles) me;
$$;

create or replace function care.can_view_ticket(p_ticket_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from care.tickets t
    where t.id = p_ticket_id
      and (t.customer_id = care.current_customer_id()
           or care.staff_can_view(t.team_id, t.assignee_id, t.customer_id))
  );
$$;

create or replace function care.staff_can_act(p_ticket_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select care.current_roles() && array['agent_l1', 'agent_l2', 'specialist', 'supervisor', 'compliance']
     and exists (
       select 1 from care.tickets t
       where t.id = p_ticket_id and care.staff_can_view(t.team_id, t.assignee_id, t.customer_id)
     );
$$;

create or replace function care.is_team_supervisor(p_team_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select 'compliance' = any (care.current_roles())
      or ('supervisor' = any (care.current_roles())
          and exists (select 1 from care.team_members tm
                      where tm.team_id = p_team_id and tm.user_id = care.current_staff_id()));
$$;

create or replace function care.staff_can_access_customer(p_ticket_id uuid, p_kind text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(me.id is not null and exists (
    select 1
    from care.tickets t
    join public.profiles p on p.id = t.customer_id
    where t.id = p_ticket_id
      and (
        'compliance' = any (me.roles)
        or (p.deleted_at is null and (
          ('supervisor' = any (me.roles)
           and exists (select 1 from care.team_members tm where tm.team_id = t.team_id and tm.user_id = me.id))
          or (t.assignee_id = me.id
              and me.roles && array['agent_l1', 'agent_l2', 'specialist']
              and (p_kind <> 'portfolio' or me.roles && array['agent_l2', 'specialist']))
        ))
      )
  ), false)
  from (select care.current_staff_id() as id, care.current_roles() as roles) me;
$$;

create or replace function care.transition_allowed(p_from text, p_to text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1
    from (values
      ('new', 'open'), ('new', 'cancelled'),
      ('open', 'pending_customer'), ('open', 'pending_internal'), ('open', 'pending_third_party'),
      ('open', 'escalated'), ('open', 'extended'), ('open', 'resolved'), ('open', 'cancelled'),
      ('pending_customer', 'open'), ('pending_customer', 'pending_internal'),
      ('pending_customer', 'pending_third_party'), ('pending_customer', 'escalated'),
      ('pending_customer', 'extended'), ('pending_customer', 'resolved'), ('pending_customer', 'cancelled'),
      ('pending_internal', 'open'), ('pending_internal', 'pending_customer'),
      ('pending_internal', 'pending_third_party'), ('pending_internal', 'escalated'),
      ('pending_internal', 'extended'), ('pending_internal', 'resolved'), ('pending_internal', 'cancelled'),
      ('pending_third_party', 'open'), ('pending_third_party', 'pending_customer'),
      ('pending_third_party', 'pending_internal'), ('pending_third_party', 'escalated'),
      ('pending_third_party', 'extended'), ('pending_third_party', 'resolved'), ('pending_third_party', 'cancelled'),
      ('escalated', 'open'), ('escalated', 'pending_customer'), ('escalated', 'pending_internal'),
      ('escalated', 'pending_third_party'), ('escalated', 'extended'), ('escalated', 'resolved'),
      ('escalated', 'cancelled'),
      ('extended', 'open'), ('extended', 'pending_customer'), ('extended', 'pending_internal'),
      ('extended', 'pending_third_party'), ('extended', 'escalated'), ('extended', 'resolved'),
      ('extended', 'cancelled'),
      ('resolved', 'open'), ('resolved', 'closed')
    ) as v (from_status, to_status)
    where v.from_status = p_from and v.to_status = p_to
  );
$$;

create or replace function care.retention_until(p_ticket_id uuid, p_at timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select p_at + make_interval(years => case
    when exists (select 1 from care.complaints c where c.ticket_id = p_ticket_id)
      then care.setting_int('retention.complaint_years')
    else care.setting_int('retention.ticket_years')
  end);
$$;

create or replace function care.refresh_sla(p_ticket_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  t            care.tickets;
  p            care.sla_policies;
  r            record;
  v_first      timestamptz;
  v_resolution timestamptz;
begin
  select * into t from care.tickets where id = p_ticket_id;
  select * into p from care.sla_policies where priority = t.priority;
  if p.priority is null then
    return;
  end if;
  v_first := care.sla_due(t.received_at, p.first_response_amount, p.first_response_unit);
  v_resolution := care.sla_due(t.received_at, p.resolution_amount, p.resolution_unit);
  for r in
    select s.paused_at, s.resumed_at from care.ticket_sla_pauses s
    where s.ticket_id = p_ticket_id and s.resumed_at is not null
    order by s.paused_at
  loop
    v_first := care.sla_shift(v_first, p.first_response_unit, r.paused_at, r.resumed_at);
    v_resolution := care.sla_shift(v_resolution, p.resolution_unit, r.paused_at, r.resumed_at);
  end loop;
  update care.tickets
     set first_response_due_at = v_first, resolution_due_at = v_resolution
   where id = p_ticket_id;
end;
$$;

create or replace function care.set_status(p_ticket_id uuid, p_to text, p_data jsonb default '{}')
returns void
language plpgsql
set search_path = ''
as $$
declare
  t          care.tickets;
  v_extended boolean;
  v_from     text;
  v_to       text;
begin
  select * into t from care.tickets where id = p_ticket_id for update;
  if t.id is null then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not care.transition_allowed(t.status, p_to) then
    perform private.api_error(409, 'invalid_transition',
      format('Status tiket tidak bisa diubah dari %s ke %s', t.status, p_to));
  end if;
  if p_to = 'extended' and t.kind <> 'complaint' then
    perform private.api_error(409, 'invalid_transition', 'Hanya pengaduan yang bisa diperpanjang');
  end if;

  if p_to = 'pending_customer' then
    insert into care.ticket_sla_pauses (ticket_id, paused_at) values (p_ticket_id, now())
    on conflict do nothing;
  elsif t.status = 'pending_customer' then
    update care.ticket_sla_pauses set resumed_at = now()
     where ticket_id = p_ticket_id and resumed_at is null;
  end if;

  update care.tickets set
    status = p_to,
    status_changed_at = now(),
    sla_paused_at = case when p_to = 'pending_customer' then now() end,
    resolved_at = case when p_to = 'resolved' then now() when p_to = 'closed' then resolved_at end,
    closed_at = case when p_to = 'closed' then now() end,
    cancelled_at = case when p_to = 'cancelled' then now() end,
    retain_until = case when p_to in ('closed', 'cancelled') then care.retention_until(p_ticket_id, now()) end
  where id = p_ticket_id;

  if t.status = 'pending_customer' then
    perform care.refresh_sla(p_ticket_id);
  end if;

  select coalesce(c.extension_count > 0, false) into v_extended
  from care.complaints c where c.ticket_id = p_ticket_id and c.reclassified_at is null;
  v_from := care.status_label(t.status, v_extended, 'id');
  v_to := care.status_label(p_to, v_extended, 'id');
  perform care.add_event(p_ticket_id, 'status_changed',
    case when v_from <> v_to then 'public' else 'internal' end,
    jsonb_build_object('from', t.status, 'to', p_to) || coalesce(p_data, '{}'));
end;
$$;

create or replace function care.render_text(p_text text, p_vars jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(string_agg(
           p.part || coalesce(case when k.key is null then '' else coalesce(p_vars ->> k.key, '{' || k.key || '}') end, ''),
           '' order by p.n), '')
  from unnest(regexp_split_to_array(coalesce(p_text, ''), '\{[a-z_]+\}')) with ordinality p (part, n)
  left join (
    select m.match[1] as key, m.n
    from regexp_matches(coalesce(p_text, ''), '\{([a-z_]+)\}', 'g') with ordinality m (match, n)
  ) k on k.n = p.n;
$$;

create or replace function care.letter_vars(p_ticket_id uuid, p_language text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'customer_name', coalesce(nullif(btrim(p.display_name), ''), p.username::text),
    'ticket_number', t.number,
    'complaint_number', c.number,
    'received_at', care.format_date(c.received_at, p_language, true),
    'channel', care.label('channel', t.channel, p_language),
    'complaint_form', care.label('form', c.form, p_language),
    'category', case when p_language = 'en' then e.path_en else e.path_id end,
    'summary', t.subject,
    'due_date', coalesce(care.format_date(c.due_at, p_language, true), ''),
    'documents', array_to_string(c.documents_required, ', '),
    'documents_due_date', coalesce(care.format_date(c.documents_due_at, p_language, true), ''),
    'documents_status', case
      when c.documents_complete_at is not null or cardinality(c.documents_required) = 0
        then case when p_language = 'en' then 'Complete' else 'Lengkap' end
      else case when p_language = 'en' then 'Incomplete: ' else 'Belum lengkap: ' end
           || array_to_string(c.documents_required, ', ')
    end,
    'deadline_text', case
      when c.due_at is not null then care.format_date(c.due_at, p_language, true)
      when p_language = 'en' then 'Starts once all documents are received'
      else 'Dihitung sejak dokumen diterima lengkap'
    end,
    'due_note', case
      when c.due_at is not null and p_language = 'en' then
        'We will respond to this complaint no later than ' || care.format_date(c.due_at, p_language, true) || '.'
      when c.due_at is not null then
        'Kami akan menyampaikan tanggapan atas pengaduan ini paling lambat ' || care.format_date(c.due_at, p_language, true) || '.'
      when p_language = 'en' then
        'Please submit the following documents by ' || care.format_date(c.documents_due_at, p_language, true) || ': '
        || array_to_string(c.documents_required, ', ') || '. The handling deadline starts once all documents are received.'
      else
        'Mohon lengkapi dokumen berikut paling lambat ' || care.format_date(c.documents_due_at, p_language, true) || ': '
        || array_to_string(c.documents_required, ', ') || '. Batas waktu penanganan dihitung sejak dokumen diterima lengkap.'
    end,
    'company_name', coalesce(care.setting_text('company.name'), ''),
    'company_address', coalesce(care.setting_text('company.address'), ''),
    'company_contact', coalesce(care.setting_text('company.complaint_contact'), ''))
  from care.tickets t
  join care.complaints c on c.ticket_id = t.id
  join public.profiles p on p.id = t.customer_id
  cross join lateral care.category_effective(t.category_id) e
  where t.id = p_ticket_id;
$$;

create or replace function care.letter_fields(p_kind text, p_language text, p_vars jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'label', case when p_language = 'en' then v.label_en else v.label_id end,
           'value', coalesce(p_vars ->> v.key, '')) order by v.n), '[]')
  from (values
    ('complaint_receipt', 1, 'complaint_number', 'Nomor pengaduan', 'Complaint number'),
    ('complaint_receipt', 2, 'ticket_number', 'Nomor tiket', 'Ticket number'),
    ('complaint_receipt', 3, 'received_at', 'Diterima', 'Received'),
    ('complaint_receipt', 4, 'channel', 'Kanal', 'Channel'),
    ('complaint_receipt', 5, 'complaint_form', 'Jenis pengaduan', 'Complaint type'),
    ('complaint_receipt', 6, 'category', 'Kategori', 'Category'),
    ('complaint_receipt', 7, 'summary', 'Ringkasan', 'Summary'),
    ('complaint_receipt', 8, 'documents_status', 'Dokumen pendukung', 'Supporting documents'),
    ('complaint_receipt', 9, 'deadline_text', 'Batas waktu penanganan', 'Handling deadline'),
    ('extension_notice', 1, 'complaint_number', 'Nomor pengaduan', 'Complaint number'),
    ('extension_notice', 2, 'ticket_number', 'Nomor tiket', 'Ticket number'),
    ('extension_notice', 3, 'original_due_date', 'Batas waktu semula', 'Original deadline'),
    ('extension_notice', 4, 'new_due_date', 'Batas waktu baru', 'New deadline'),
    ('extension_notice', 5, 'extension_reason', 'Alasan perpanjangan', 'Reason for extension'),
    ('final_response', 1, 'complaint_number', 'Nomor pengaduan', 'Complaint number'),
    ('final_response', 2, 'ticket_number', 'Nomor tiket', 'Ticket number'),
    ('final_response', 3, 'received_at', 'Diterima', 'Received'),
    ('final_response', 4, 'resolved_at', 'Tanggal tanggapan', 'Response date'),
    ('final_response', 5, 'objection_deadline', 'Batas pengajuan keberatan', 'Objection deadline')
  ) as v (kind, n, key, label_id, label_en)
  where v.kind = p_kind;
$$;

create or replace function care.enqueue_job(p_kind text, p_ticket_id uuid, p_payload jsonb, p_max_attempts integer default 8)
returns bigint
language sql
set search_path = ''
as $$
  insert into care.outbox (kind, ticket_id, payload, max_attempts)
  values (p_kind, p_ticket_id, coalesce(p_payload, '{}'), p_max_attempts)
  returning id;
$$;

create or replace function care.issue_letter(p_ticket_id uuid, p_kind text, p_extra jsonb default '{}')
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  c          care.complaints;
  v_language text;
  v_template care.message_templates;
  v_vars     jsonb;
  v_id       uuid := gen_random_uuid();
  v_code     text := care.random_code(10);
  v_number   text;
begin
  select * into c from care.complaints where ticket_id = p_ticket_id;
  if c.ticket_id is null then
    perform private.api_error(409, 'not_a_complaint', 'Surat resmi hanya untuk pengaduan');
  end if;
  select t.language into v_language from care.tickets t where t.id = p_ticket_id;
  select * into v_template
  from care.message_templates m
  where m.code = p_kind and m.status = 'active'
  order by (m.language = v_language) desc, (m.language = 'id') desc
  limit 1;
  if v_template.id is null then
    perform private.api_error(500, 'template_missing', 'Template surat resmi belum tersedia');
  end if;

  v_vars := care.letter_vars(p_ticket_id, v_template.language) || coalesce(p_extra, '{}');
  v_number := c.number || '/'
    || case p_kind when 'complaint_receipt' then 'BT' when 'extension_notice' then 'PP' else 'TA' end || '/'
    || ((select count(*) from care.official_letters l where l.ticket_id = p_ticket_id and l.kind = p_kind) + 1);

  insert into care.official_letters
    (id, ticket_id, kind, number, verification_code, template_id, language, content, storage_path)
  values (
    v_id, p_ticket_id, p_kind, v_number, v_code, v_template.id, v_template.language,
    jsonb_build_object(
      'title', care.render_text(v_template.title, v_vars),
      'number', v_number,
      'verification_code', substr(v_code, 1, 5) || '-' || substr(v_code, 6, 5),
      'language', v_template.language,
      'issued_at', now(),
      'issued_at_text', care.format_date(now(), v_template.language, true),
      'draft', not v_template.reviewed,
      'company', jsonb_build_object(
        'name', v_vars ->> 'company_name',
        'address', v_vars ->> 'company_address',
        'contact', v_vars ->> 'company_contact'),
      'fields', care.letter_fields(p_kind, v_template.language, v_vars),
      'paragraphs', (
        select coalesce(jsonb_agg(care.render_text(btrim(x.paragraph), v_vars) order by x.n), '[]')
        from unnest(regexp_split_to_array(btrim(v_template.body), '\n\s*\n')) with ordinality x (paragraph, n)),
      'email', jsonb_build_object(
        'subject', care.render_text(v_template.email_subject, v_vars),
        'body', care.render_text(v_template.email_body, v_vars))),
    'letters/' || p_ticket_id::text || '/' || v_id::text || '.pdf');

  perform care.enqueue_job('render_letter', p_ticket_id, jsonb_build_object('letter_id', v_id));
  perform care.add_event(p_ticket_id, 'letter_issued', 'public',
    jsonb_build_object('letter_id', v_id, 'kind', p_kind, 'number', v_number));
  return v_id;
end;
$$;

create or replace function care.complaint_team(p_ticket_id uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select case
    when t.priority = 'P1' then t.team_id
    else coalesce(
      (select tm.id from care.teams tm where tm.code = care.setting_text('complaint.team') and tm.active),
      t.team_id)
  end
  from care.tickets t
  where t.id = p_ticket_id;
$$;

create or replace function care.register_complaint(p_ticket_id uuid, p_received_at timestamptz)
returns care.complaints
language plpgsql
set search_path = ''
as $$
declare
  t           care.tickets;
  c           care.complaints;
  v_form      text;
  v_documents text[];
  v_due       timestamptz;
  v_doc_due   timestamptz;
  v_complete  timestamptz;
  v_team      uuid;
  v_year      text := to_char(care.local_date(now()), 'YYYY');
begin
  select * into t from care.tickets where id = p_ticket_id for update;
  select * into c from care.complaints where ticket_id = p_ticket_id for update;
  if c.ticket_id is not null and c.reclassified_at is null then
    return c;
  end if;

  v_form := coalesce(care.setting('complaint.channel_forms') ->> t.channel, 'written');
  select coalesce(e.required_documents, '{}') into v_documents from care.category_effective(t.category_id) e;
  if v_form = 'oral' then
    v_due := care.regulatory_deadline(p_received_at, care.setting_int('complaint.oral_days'));
  elsif cardinality(v_documents) = 0 then
    v_complete := p_received_at;
    v_due := care.regulatory_deadline(p_received_at, care.setting_int('complaint.written_days'));
  else
    v_doc_due := care.regulatory_deadline(p_received_at, care.setting_int('complaint.document_wait_days'));
  end if;

  if c.ticket_id is null then
    insert into care.complaints
      (ticket_id, number, form, received_at, documents_required, documents_requested_at,
       documents_due_at, documents_complete_at, due_at)
    values (
      p_ticket_id,
      care.format_number(care.setting_text('numbering.complaint_prefix'), v_year, care.next_number('complaint', v_year), 6),
      v_form, p_received_at, v_documents, case when v_doc_due is not null then p_received_at end,
      v_doc_due, v_complete, v_due)
    returning * into c;
  else
    update care.complaints set
      form = v_form, received_at = p_received_at, documents_required = v_documents,
      documents_requested_at = case when v_doc_due is not null then p_received_at end,
      documents_due_at = v_doc_due, documents_complete_at = v_complete, conversion_requested_at = null,
      clock_paused_at = null, due_at = v_due, original_due_at = null, extension_count = 0,
      extended_at = null, extension_reason = null, final_response_at = null,
      reclassified_at = null, reclassified_to = null
    where ticket_id = p_ticket_id
    returning * into c;
  end if;

  v_team := care.complaint_team(p_ticket_id);
  update care.tickets set
    kind = 'complaint',
    priority = case when priority in ('P3', 'P4') then 'P2' else priority end,
    team_id = v_team,
    assignee_id = case
      when v_team = t.team_id
        or exists (select 1 from care.team_members tm where tm.team_id = v_team and tm.user_id = t.assignee_id)
      then assignee_id
    end
  where id = p_ticket_id;
  if t.priority in ('P3', 'P4') then
    perform care.refresh_sla(p_ticket_id);
  end if;

  perform care.add_event(p_ticket_id, 'complaint_registered', 'public', jsonb_build_object(
    'number', c.number, 'form', c.form, 'received_at', c.received_at, 'due_at', c.due_at,
    'documents_required', c.documents_required, 'documents_due_at', c.documents_due_at));
  perform care.issue_letter(p_ticket_id, 'complaint_receipt');
  perform care.notify_staff(care.team_staff(v_team, '{supervisor}'), 'complaint_registered', p_ticket_id,
    jsonb_build_object('number', c.number, 'due_at', c.due_at));
  return c;
end;
$$;

create or replace function care.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_parts text[] := regexp_match(coalesce(p_topic, ''), '^care:(ticket|customer|agent|queue):([0-9a-z_-]+)(:staff)?$');
  v_uuid  text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  if v_parts is null then
    return false;
  end if;
  if v_parts[1] = 'ticket' and v_parts[2] ~ v_uuid then
    if v_parts[3] is null then
      return care.can_view_ticket(v_parts[2]::uuid);
    end if;
    return exists (
      select 1 from care.tickets t
      where t.id = v_parts[2]::uuid and care.staff_can_view(t.team_id, t.assignee_id, t.customer_id));
  end if;
  if v_parts[3] is not null then
    return false;
  end if;
  if v_parts[1] = 'customer' then
    return v_parts[2] = care.current_customer_id()::text;
  end if;
  if v_parts[1] = 'agent' then
    return v_parts[2] = care.current_staff_id()::text;
  end if;
  if v_parts[1] = 'queue' then
    return exists (
      select 1 from care.teams tm
      where tm.code = v_parts[2]
        and (care.is_team_supervisor(tm.id)
             or (care.current_roles() && array['agent_l1', 'agent_l2', 'specialist']
                 and exists (select 1 from care.team_members m
                             where m.team_id = tm.id and m.user_id = care.current_staff_id()))));
  end if;
  return false;
end;
$$;

create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_topic is null then
    return false;
  end if;
  if p_topic like 'care:%' then
    return care.can_access_topic(p_topic);
  end if;
  if private.is_banned(auth.uid()) then
    return false;
  end if;
  if p_topic = 'online' then
    return true;
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return exists (
      select 1 from public.chat_members
      where room_id = substring(p_topic from 6)::uuid and user_id = auth.uid()
    );
  end if;
  return false;
end;
$$;

create or replace function private.check_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid;
  v_revoked timestamptz;
  v_iat     numeric;
  v_headers jsonb;
  v_profile text;
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  v_headers := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  v_profile := case when current_setting('request.method', true) in ('GET', 'HEAD')
                    then v_headers ->> 'accept-profile'
                    else v_headers ->> 'content-profile' end;
  if coalesce(v_profile, '') <> 'care_api' and private.is_banned(v_uid) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
  end if;
  select s.revoked_before into v_revoked from private.user_sessions s where s.user_id = v_uid;
  if v_revoked is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::numeric;
    if v_iat is null or to_timestamp(v_iat) < v_revoked then
      perform private.api_error(401, 'session_revoked', 'Sesi sudah dicabut, silakan masuk ulang');
    end if;
  end if;
end;
$$;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('care_ticket', 5, 3600),
  ('care_message', 30, 60)
on conflict (action, window_seconds) do nothing;

create or replace function care.check_rate_limit(p_user uuid, p_action text, p_table regclass, p_user_column text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  r        record;
  v_count  integer;
  v_oldest timestamptz;
begin
  for r in
    select l.max_count, l.window_seconds from private.rate_limits l
    where l.action = p_action order by l.window_seconds
  loop
    execute format(
      'select count(*), min(created_at) from %s where %I = $1 and created_at > now() - make_interval(secs => $2)',
      p_table, p_user_column)
    into v_count, v_oldest using p_user, r.window_seconds;
    if v_count >= r.max_count then
      perform private.raise_rate_limited(p_action, r.max_count, r.window_seconds,
        ceil(r.window_seconds - extract(epoch from (now() - v_oldest)))::integer);
    end if;
  end loop;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('care-documents', 'care-documents', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.can_read_care_document(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from care.official_letters l
    where l.storage_path = p_name and l.status = 'ready' and care.can_view_ticket(l.ticket_id)
  );
$$;
revoke all on function private.can_read_care_document(text) from public;
grant execute on function private.can_read_care_document(text) to authenticated;

drop policy if exists olt_care_documents_select on storage.objects;
create policy olt_care_documents_select on storage.objects
  for select to authenticated
  using (bucket_id = 'care-documents' and private.can_read_care_document(name));

insert into care.message_templates
  (code, language, version, status, title, body, email_subject, email_body)
values
  ('complaint_receipt', 'id', 1, 'active', 'Bukti Penerimaan Pengaduan',
   E'Yth. {customer_name},\n\nTerima kasih telah menyampaikan pengaduan kepada {company_name}. Pengaduan Anda telah kami terima dan dicatat dengan nomor {complaint_number}, dengan rincian seperti tercantum di atas.\n\n{due_note}\n\nPerkembangan penanganan dapat Anda pantau melalui menu Bantuan di aplikasi OLT. Simpan dokumen ini sebagai bukti penerimaan resmi.\n\nPENTING: petugas kami tidak pernah meminta PIN, password, OTP, atau transfer dana ke rekening pribadi. Abaikan pihak yang mengaku petugas kami dan meminta data tersebut, lalu laporkan melalui menu "Laporkan CS palsu" di aplikasi.',
   '[{ticket_number}] Bukti Penerimaan Pengaduan {complaint_number}',
   E'Yth. {customer_name},\n\nPengaduan Anda telah kami terima dengan nomor {complaint_number} (tiket {ticket_number}). Bukti penerimaan resmi terlampir dalam format PDF.\n\n{due_note}\n\nHormat kami,\n{company_name}\n{company_contact}\n\nPetugas kami tidak pernah meminta PIN, password, OTP, atau transfer dana ke rekening pribadi.'),
  ('complaint_receipt', 'en', 1, 'active', 'Complaint Acknowledgement',
   E'Dear {customer_name},\n\nThank you for submitting a complaint to {company_name}. We have received your complaint and registered it under number {complaint_number}, with the details listed above.\n\n{due_note}\n\nYou can follow its progress in the Help menu of the OLT app. Please keep this document as the official acknowledgement.\n\nIMPORTANT: our staff never ask for your PIN, password, OTP, or a transfer to a personal account. Ignore anyone claiming to be our staff who asks for them, and report it via "Report fake CS" in the app.',
   '[{ticket_number}] Complaint Acknowledgement {complaint_number}',
   E'Dear {customer_name},\n\nWe have received your complaint under number {complaint_number} (ticket {ticket_number}). The official acknowledgement is attached as a PDF.\n\n{due_note}\n\nKind regards,\n{company_name}\n{company_contact}\n\nOur staff never ask for your PIN, password, OTP, or a transfer to a personal account.'),
  ('extension_notice', 'id', 1, 'active', 'Pemberitahuan Perpanjangan Waktu Penyelesaian Pengaduan',
   E'Yth. {customer_name},\n\nSehubungan dengan pengaduan Anda nomor {complaint_number}, kami memerlukan tambahan waktu penyelesaian karena {extension_reason}.\n\n{extension_explanation}\n\nBatas waktu penyelesaian pengaduan Anda diperpanjang dari {original_due_date} menjadi {new_due_date}. Kami mohon maaf atas ketidaknyamanan ini dan akan menyampaikan perkembangannya melalui aplikasi OLT.',
   '[{ticket_number}] Perpanjangan Waktu Penyelesaian Pengaduan {complaint_number}',
   E'Yth. {customer_name},\n\nBatas waktu penyelesaian pengaduan Anda nomor {complaint_number} diperpanjang menjadi {new_due_date}. Surat pemberitahuan resmi terlampir dalam format PDF.\n\nHormat kami,\n{company_name}\n{company_contact}'),
  ('extension_notice', 'en', 1, 'active', 'Notice of Extended Complaint Resolution Period',
   E'Dear {customer_name},\n\nRegarding your complaint number {complaint_number}, we need additional time to resolve it because {extension_reason}.\n\n{extension_explanation}\n\nThe resolution deadline has been extended from {original_due_date} to {new_due_date}. We apologise for the inconvenience and will keep you updated in the OLT app.',
   '[{ticket_number}] Complaint Resolution Period Extended {complaint_number}',
   E'Dear {customer_name},\n\nThe resolution deadline for your complaint number {complaint_number} has been extended to {new_due_date}. The official notice is attached as a PDF.\n\nKind regards,\n{company_name}\n{company_contact}'),
  ('final_response', 'id', 1, 'active', 'Tanggapan atas Pengaduan',
   E'Yth. {customer_name},\n\nBerikut kami sampaikan tanggapan atas pengaduan Anda nomor {complaint_number}:\n\n{resolution}\n\nApabila Anda tidak sependapat dengan tanggapan ini, Anda dapat mengajukan keberatan melalui aplikasi OLT paling lambat {objection_deadline}. Anda juga dapat menempuh penyelesaian sengketa melalui Lembaga Alternatif Penyelesaian Sengketa Sektor Jasa Keuangan (LAPS SJK) atau menyampaikan pengaduan kepada Otoritas Jasa Keuangan sesuai ketentuan yang berlaku.',
   '[{ticket_number}] Tanggapan atas Pengaduan {complaint_number}',
   E'Yth. {customer_name},\n\nTanggapan resmi atas pengaduan Anda nomor {complaint_number} terlampir dalam format PDF. Keberatan dapat diajukan melalui aplikasi OLT paling lambat {objection_deadline}.\n\nHormat kami,\n{company_name}\n{company_contact}'),
  ('final_response', 'en', 1, 'active', 'Response to Your Complaint',
   E'Dear {customer_name},\n\nPlease find below our response to your complaint number {complaint_number}:\n\n{resolution}\n\nIf you disagree with this response, you may file an objection in the OLT app no later than {objection_deadline}. You may also pursue dispute resolution through the Financial Services Alternative Dispute Resolution Institution (LAPS SJK) or file a complaint with the Financial Services Authority (OJK) in accordance with applicable regulations.',
   '[{ticket_number}] Response to Your Complaint {complaint_number}',
   E'Dear {customer_name},\n\nOur official response to your complaint number {complaint_number} is attached as a PDF. You may file an objection in the OLT app no later than {objection_deadline}.\n\nKind regards,\n{company_name}\n{company_contact}');
