insert into private.settings (key, value, description) values
  ('finreport.files_per_hour', '120', 'Batas file laporan keuangan per API key integrasi per jam'),
  ('finreport.max_attempts', '5', 'Percobaan maksimal memproses satu file laporan keuangan sebelum ditolak'),
  ('finreport.rejected_keep_days', '30', 'File laporan keuangan yang ditolak disimpan sekian hari untuk diproses ulang')
on conflict (key) do nothing;

alter table private.integration_keys drop constraint integration_keys_scopes_check;
alter table private.integration_keys add constraint integration_keys_scopes_check
  check (cardinality(scopes) between 1 and 5
         and scopes <@ array['notify', 'bot_post', 'notify_broadcast', 'health_read', 'financial_report']
         and (not 'notify_broadcast' = any (scopes) or 'notify' = any (scopes)));

create or replace function cs.integration_scopes(p_scopes text[])
returns text[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_scopes text[];
begin
  select coalesce(array_agg(distinct btrim(s) order by btrim(s)), '{}') into v_scopes
  from unnest(coalesce(p_scopes, '{}')) s
  where btrim(coalesce(s, '')) <> '';
  if cardinality(v_scopes) = 0
     or not v_scopes <@ array['notify', 'bot_post', 'notify_broadcast', 'health_read', 'financial_report'] then
    perform private.api_error(400, 'invalid_scopes',
      'Pilih izin notify, notify_broadcast, bot_post, health_read, financial_report, atau gabungannya');
  end if;
  if 'notify_broadcast' = any (v_scopes) and not 'notify' = any (v_scopes) then
    perform private.api_error(400, 'invalid_scopes', 'Izin notify_broadcast harus disertai izin notify');
  end if;
  return v_scopes;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('financial-reports', 'financial-reports', false, 8388608, array['application/zip'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table private.finreport_config (
  singleton           boolean primary key default true check (singleton),
  official_account_id uuid references cs.official_accounts (profile_id),
  auto_publish        boolean not null default false,
  updated_by          uuid references cs.agents (user_id),
  updated_at          timestamptz not null default now()
);
insert into private.finreport_config (singleton) values (true);

create table private.finreport_reports (
  id                uuid primary key default gen_random_uuid(),
  sha256            text not null unique check (sha256 ~ '^[0-9a-f]{64}$'),
  entity_code       text not null check (entity_code ~ '^[A-Z][A-Z0-9]{1,11}$'),
  entity_name       text not null check (char_length(entity_name) between 1 and 200),
  sector            text check (char_length(sector) <= 120),
  subsector         text check (char_length(subsector) <= 120),
  period            text not null check (period in ('Q1', 'Q2', 'Q3', 'FY')),
  period_start      date not null,
  period_end        date not null,
  audit             text not null check (audit in ('audited', 'unaudited', 'unknown')),
  currency          text not null check (currency ~ '^[A-Z]{3}$'),
  template          text not null check (template in ('bank', 'general', 'basic')),
  facts             jsonb not null check (jsonb_typeof(facts) = 'object'),
  metrics           jsonb not null check (jsonb_typeof(metrics) = 'object'),
  summary           text not null check (char_length(summary) between 1 and 2000),
  warnings          jsonb not null default '[]' check (jsonb_typeof(warnings) = 'array'),
  supersedes        uuid references private.finreport_reports (id),
  superseded_at     timestamptz,
  community_post_id uuid references cs.community_posts (id),
  created_at        timestamptz not null default now(),
  constraint finreport_reports_period check (period_end > period_start)
);
create unique index finreport_reports_current_idx on private.finreport_reports (entity_code, period_start, period_end)
  where superseded_at is null;
create index finreport_reports_entity_idx on private.finreport_reports (entity_code, period_end desc);

create table private.finreport_files (
  id           uuid primary key default gen_random_uuid(),
  source       text not null check (source in ('api', 'hub')),
  key_id       uuid references private.integration_keys (id),
  uploaded_by  uuid references cs.agents (user_id),
  object_name  text not null check (object_name ~ '^(api/[0-9a-f]{64}|hub/[0-9a-f-]{36}/[0-9a-f-]{36})/report\.zip$'),
  sha256       text check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes   integer check (size_bytes between 1 and 8388608),
  status       text not null default 'queued' check (status in ('queued', 'processing', 'done', 'duplicate', 'rejected')),
  attempts     integer not null default 0,
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text check (char_length(locked_by) <= 100),
  error_code   text check (error_code ~ '^[a-z_]{1,40}$'),
  error_detail text check (char_length(error_detail) <= 500),
  report_id    uuid references private.finreport_reports (id),
  created_at   timestamptz not null default now(),
  finished_at  timestamptz,
  constraint finreport_files_origin check ((source = 'api') = (key_id is not null)
                                           and (source = 'hub') = (uploaded_by is not null)),
  constraint finreport_files_api_sha check (source <> 'api' or sha256 is not null),
  constraint finreport_files_result check ((status in ('done', 'duplicate')) = (report_id is not null))
);
create index finreport_files_ready_idx on private.finreport_files (available_at) where status in ('queued', 'processing');
create index finreport_files_key_idx on private.finreport_files (key_id, sha256) where key_id is not null;
create index finreport_files_key_recent_idx on private.finreport_files (key_id, created_at) where key_id is not null;
create index finreport_files_created_idx on private.finreport_files (created_at desc, id desc);
create index finreport_files_object_idx on private.finreport_files (object_name);
create index finreport_files_report_idx on private.finreport_files (report_id) where report_id is not null;

alter table private.finreport_config enable row level security;
alter table private.finreport_reports enable row level security;
alter table private.finreport_files enable row level security;

create or replace function private.can_upload_finreport()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.has_community('{community.post}');
$$;

create policy olt_financial_reports_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'financial-reports'
              and name ~ '^hub/[0-9a-f-]{36}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/report\.zip$'
              and split_part(name, '/', 2) = (select auth.uid())::text
              and (select private.can_upload_finreport()));

create policy olt_financial_reports_read on storage.objects for select to authenticated
  using (bucket_id = 'financial-reports'
         and owner_id = (select auth.uid())::text
         and (select private.can_upload_finreport()));

create or replace function private.health_service_label(p_service text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_service
    when 'media' then 'Upload media'
    when 'sentinel' then 'Pemantau sistem'
    when 'backup' then 'Backup'
    when 'notifier' then 'Notifier push'
    when 'janitor' then 'Pembersih storage'
    when 'auth-bridge' then 'Auth bridge'
    when 'nasabah-gateway' then 'Gateway nasabah'
    when 'rest' then 'API (PostgREST)'
    when 'auth' then 'Login staf (GoTrue)'
    when 'storage' then 'Storage'
    when 'realtime' then 'Realtime'
    when 'functions' then 'Edge Functions'
    when 'imgproxy' then 'Imgproxy'
    when 'kong' then 'Kong'
    when 'valkey' then 'Valkey'
    when 'pgbouncer' then 'PgBouncer'
    when 'db' then 'Database'
    when 'cs-console' then 'Web CS'
    when 'integration' then 'Gateway integrasi'
    when 'link-preview' then 'Pratinjau link'
    when 'classifier' then 'Klasifikasi gambar'
    when 'clamav' then 'Pemindai antivirus'
    when 'finreport' then 'Riset laporan keuangan'
    else p_service
  end;
$$;

update private.settings
   set value = (select jsonb_agg(distinct x order by x)
                from jsonb_array_elements_text(value || '["finreport"]') x)
 where key = 'health.expected_services';

create or replace function private.finreport_post_ref(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', c.id, 'status', c.status, 'post_id', c.post_id, 'published_at', c.published_at)
  from cs.community_posts c
  where c.id = p_id;
$$;

create or replace function private.finreport_report_ref(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id, 'entity_code', r.entity_code, 'entity_name', r.entity_name, 'period', r.period,
    'period_start', r.period_start, 'period_end', r.period_end, 'audit', r.audit, 'currency', r.currency,
    'template', r.template, 'superseded', r.superseded_at is not null,
    'warnings', coalesce((select jsonb_agg(w ->> 'code') from jsonb_array_elements(r.warnings) w), '[]'),
    'post', private.finreport_post_ref(r.community_post_id))
  from private.finreport_reports r
  where r.id = p_id;
$$;

create or replace function private.finreport_file_external(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1, 'id', f.id, 'status', f.status, 'sha256', f.sha256, 'size_bytes', f.size_bytes,
    'received_at', f.created_at, 'finished_at', f.finished_at,
    'retry_at', case when f.status = 'queued' and f.attempts > 0 then f.available_at end,
    'error', case when f.error_code is not null and f.status = 'rejected'
                  then jsonb_build_object('code', f.error_code, 'detail', f.error_detail) end,
    'report', private.finreport_report_ref(f.report_id))
  from private.finreport_files f
  where f.id = p_id;
$$;

create or replace function private.finreport_cleanup(p_object text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prefix text := regexp_replace(p_object, '[^/]+$', '');
begin
  if not exists (select 1 from private.storage_cleanup_queue q
                  where q.bucket_id = 'financial-reports' and q.prefix = v_prefix and q.done_at is null) then
    insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values ('financial-reports', v_prefix, p_reason);
  end if;
end;
$$;

create or replace function public.finreport_submit(p_key_id uuid, p_sha256 text, p_size integer, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k      private.integration_keys := private.integration_key_for(p_key_id, 'financial_report', p_ip);
  v_cap  integer := private.setting_num('finreport.files_per_hour', 120)::integer;
  v_sha  text := lower(btrim(coalesce(p_sha256, '')));
  v_id   uuid;
  v_rep  uuid;
  v_used integer;
begin
  if v_sha !~ '^[0-9a-f]{64}$' then
    perform private.api_error(400, 'invalid_sha256', 'Sidik SHA-256 file tidak valid');
  end if;
  if coalesce(p_size, 0) not between 1 and 8388608 then
    perform private.api_error(400, 'invalid_size', 'Ukuran file 1 byte sampai 8 MiB');
  end if;
  perform private.integration_touch(k.id, p_ip, '{}');

  select f.id into v_id
  from private.finreport_files f
  where f.key_id = k.id and f.sha256 = v_sha and f.status in ('queued', 'processing', 'done', 'duplicate')
  order by f.created_at desc
  limit 1;
  if found then
    return private.finreport_file_external(v_id) || jsonb_build_object('resubmitted', true);
  end if;

  select count(*) into v_used from private.finreport_files f
   where f.key_id = k.id and f.created_at > now() - interval '1 hour';
  if v_used >= v_cap then
    perform private.api_error(429, 'rate_limited', format('Maksimal %s file laporan per jam untuk API key ini', v_cap));
  end if;

  select r.id into v_rep from private.finreport_reports r where r.sha256 = v_sha;
  if found then
    insert into private.finreport_files (source, key_id, object_name, sha256, size_bytes, status, report_id, finished_at)
    values ('api', k.id, 'api/' || v_sha || '/report.zip', v_sha, p_size, 'duplicate', v_rep, now())
    returning id into v_id;
  else
    insert into private.finreport_files (source, key_id, object_name, sha256, size_bytes)
    values ('api', k.id, 'api/' || v_sha || '/report.zip', v_sha, p_size)
    returning id into v_id;
  end if;
  return private.finreport_file_external(v_id) || jsonb_build_object('resubmitted', false);
end;
$$;

create or replace function public.finreport_file(p_key_id uuid, p_id uuid, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k private.integration_keys := private.integration_key_for(p_key_id, 'financial_report', p_ip);
begin
  perform private.integration_touch(k.id, p_ip, '{}');
  if not exists (select 1 from private.finreport_files f where f.id = p_id and f.key_id = k.id) then
    perform private.api_error(404, 'file_not_found', 'File laporan tidak ditemukan untuk API key ini');
  end if;
  return private.finreport_file_external(p_id);
end;
$$;

create or replace function public.finreport_claim(p_instance text, p_lease_seconds integer default 120)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := private.setting_num('finreport.max_attempts', 5)::integer;
  f     private.finreport_files;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Instance worker tidak valid');
  end if;
  loop
    select * into f from private.finreport_files
     where status in ('queued', 'processing') and available_at <= now()
       and (status = 'queued' or locked_until < now())
     order by available_at, created_at
     limit 1
     for update skip locked;
    if not found then
      return null;
    end if;
    if f.attempts >= v_max then
      update private.finreport_files
         set status = 'rejected', error_code = 'too_many_attempts',
             error_detail = left(coalesce(error_detail, 'Worker stopped while processing this file'), 500),
             locked_until = null, locked_by = null, finished_at = now()
       where id = f.id;
      continue;
    end if;
    update private.finreport_files
       set status = 'processing', attempts = attempts + 1, locked_by = p_instance,
           locked_until = now() + make_interval(secs => greatest(30, least(coalesce(p_lease_seconds, 120), 900)))
     where id = f.id
    returning * into f;
    return jsonb_build_object('id', f.id, 'object_name', f.object_name, 'sha256', f.sha256,
                              'size_bytes', f.size_bytes, 'attempts', f.attempts);
  end loop;
end;
$$;

create or replace function private.finreport_claimed(p_file uuid, p_instance text)
returns private.finreport_files
language plpgsql
security definer
set search_path = ''
as $$
declare
  f private.finreport_files;
begin
  select * into f from private.finreport_files where id = p_file for update;
  if not found or f.status <> 'processing' or f.locked_by is distinct from p_instance then
    perform private.api_error(409, 'not_claimed', 'File ini tidak sedang diproses oleh worker ini');
  end if;
  return f;
end;
$$;

create or replace function private.finreport_version(p_entity text, p_start date, p_end date)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', r.id, 'period', r.period, 'period_start', r.period_start, 'period_end', r.period_end,
                            'created_at', r.created_at, 'facts', r.facts)
  from private.finreport_reports r
  where r.entity_code = p_entity and r.period_start = p_start and r.period_end = p_end and r.superseded_at is null;
$$;

create or replace function public.finreport_related(p_entity text, p_period_start date, p_period_end date)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'previous', (
      select private.finreport_version(r.entity_code, r.period_start, r.period_end)
      from private.finreport_reports r
      where r.entity_code = p_entity and r.period_start = p_period_start and r.period_end < p_period_end
        and r.superseded_at is null
      order by r.period_end desc
      limit 1),
    'prior_year', (
      select private.finreport_version(r.entity_code, r.period_start, r.period_end)
      from private.finreport_reports r
      where r.entity_code = p_entity and r.superseded_at is null
        and r.period_end between (p_period_end - interval '1 year')::date - 7 and (p_period_end - interval '1 year')::date + 7
        and (r.period_end - r.period_start) between (p_period_end - p_period_start) - 7 and (p_period_end - p_period_start) + 7
      order by abs(r.period_end - (p_period_end - interval '1 year')::date), r.created_at desc
      limit 1));
$$;

create or replace function private.finreport_make_post(p_report uuid, p_author uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c       private.finreport_config;
  r       private.finreport_reports;
  v_cp    uuid;
  v_state text;
  v_code  text;
begin
  select * into c from private.finreport_config where singleton;
  select * into r from private.finreport_reports where id = p_report for update;
  if c.official_account_id is null or not cs.official_active(c.official_account_id) then
    update private.finreport_reports
       set warnings = warnings || jsonb_build_array(jsonb_build_object('code', 'no_official_account'))
     where id = r.id;
    return;
  end if;
  begin
    perform private.validate_text(r.summary, 'post');
    perform private.apply_content_policy(r.summary);
    insert into cs.community_posts (account_id, kind, body, status, created_by, submitted_at)
    values (c.official_account_id, 'post', r.summary, 'pending', p_author, now())
    returning id into v_cp;
    update private.finreport_reports set community_post_id = v_cp where id = r.id;
    if c.auto_publish and jsonb_array_length(r.warnings) = 0 then
      perform cs.community_publish(v_cp);
    end if;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_code = message_text;
    if v_state !~ '^PT4' then
      raise;
    end if;
    update private.finreport_reports
       set warnings = warnings || jsonb_build_array(jsonb_build_object('code', 'post_rejected', 'reason', v_code))
     where id = r.id;
  end;
end;
$$;

create or replace function private.finreport_text(p_value jsonb, p_max integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_value) = 'string' and char_length(btrim(p_value #>> '{}')) between 1 and p_max
              then btrim(p_value #>> '{}') end;
$$;

create or replace function private.finreport_date(p_value jsonb)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$' then
    return null;
  end if;
  return (p_value #>> '{}')::date;
exception when others then
  return null;
end;
$$;

create or replace function public.finreport_complete(p_file uuid, p_instance text, p_report jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  f        private.finreport_files := private.finreport_claimed(p_file, p_instance);
  v_sha    text := p_report ->> 'sha256';
  v_code   text := private.finreport_text(p_report -> 'entity_code', 12);
  v_name   text := private.finreport_text(p_report -> 'entity_name', 200);
  v_start  date := private.finreport_date(p_report -> 'period_start');
  v_end    date := private.finreport_date(p_report -> 'period_end');
  v_author uuid;
  v_old    private.finreport_reports;
  r        private.finreport_reports;
  v_warn   jsonb := coalesce(p_report -> 'warnings', '[]');
begin
  if coalesce(v_sha, '') !~ '^[0-9a-f]{64}$' or (f.sha256 is not null and f.sha256 <> v_sha) then
    perform private.api_error(400, 'checksum_mismatch', 'Sidik file tidak sama dengan yang diterima');
  end if;

  select * into r from private.finreport_reports where sha256 = v_sha;
  if found then
    update private.finreport_files
       set status = 'duplicate', sha256 = v_sha, report_id = r.id, finished_at = now(), locked_until = null,
           locked_by = null, error_code = null, error_detail = null
     where id = f.id;
    return jsonb_build_object('status', 'duplicate', 'report_id', r.id);
  end if;

  if coalesce(v_code, '') !~ '^[A-Z][A-Z0-9]{1,11}$' or v_name is null or v_start is null or v_end is null
     or v_end <= v_start or coalesce(p_report ->> 'period', '') not in ('Q1', 'Q2', 'Q3', 'FY')
     or coalesce(p_report ->> 'audit', '') not in ('audited', 'unaudited', 'unknown')
     or coalesce(p_report ->> 'currency', '') !~ '^[A-Z]{3}$'
     or coalesce(p_report ->> 'template', '') not in ('bank', 'general', 'basic')
     or jsonb_typeof(p_report -> 'facts') is distinct from 'object' or pg_column_size(p_report -> 'facts') > 1048576
     or jsonb_typeof(p_report -> 'metrics') is distinct from 'object' or pg_column_size(p_report -> 'metrics') > 262144
     or private.finreport_text(p_report -> 'summary', 2000) is null
     or jsonb_typeof(v_warn) is distinct from 'array' or jsonb_array_length(v_warn) > 50 then
    perform private.api_error(400, 'invalid_report', 'Data laporan dari worker tidak lengkap atau tidak valid');
  end if;

  select * into v_old from private.finreport_reports
   where entity_code = v_code and period_start = v_start and period_end = v_end and superseded_at is null
   for update;
  if found then
    update private.finreport_reports set superseded_at = now() where id = v_old.id;
    update cs.community_posts
       set status = 'cancelled', updated_at = now(), version = version + 1
     where id = v_old.community_post_id and status in ('draft', 'pending', 'scheduled');
    v_warn := v_warn || jsonb_build_array(jsonb_build_object('code', 'revision', 'supersedes', v_old.id,
                                                             'received_at', v_old.created_at));
  end if;

  insert into private.finreport_reports (sha256, entity_code, entity_name, sector, subsector, period, period_start,
                                         period_end, audit, currency, template, facts, metrics, summary, warnings,
                                         supersedes)
  values (v_sha, v_code, v_name, private.finreport_text(p_report -> 'sector', 120),
          private.finreport_text(p_report -> 'subsector', 120), p_report ->> 'period', v_start, v_end,
          p_report ->> 'audit', p_report ->> 'currency', p_report ->> 'template', p_report -> 'facts',
          p_report -> 'metrics', private.finreport_text(p_report -> 'summary', 2000), v_warn, v_old.id)
  returning * into r;

  update private.finreport_files
     set status = 'done', sha256 = v_sha, report_id = r.id, finished_at = now(), locked_until = null, locked_by = null,
         error_code = null, error_detail = null
   where id = f.id;

  if f.source = 'api' then
    select k.created_by into v_author from private.integration_keys k where k.id = f.key_id;
  else
    v_author := f.uploaded_by;
  end if;
  perform private.finreport_make_post(r.id, v_author);
  perform cs.audit('finreport.report_ingest', null, null,
                   jsonb_build_object('report', r.id, 'file', f.id, 'entity', r.entity_code, 'period', r.period,
                                      'period_end', r.period_end, 'source', f.source));
  return jsonb_build_object('status', 'done', 'report', private.finreport_report_ref(r.id));
end;
$$;

create or replace function public.finreport_fail(p_file uuid, p_instance text, p_code text, p_detail text,
                                                 p_retry boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  f      private.finreport_files := private.finreport_claimed(p_file, p_instance);
  v_max  integer := private.setting_num('finreport.max_attempts', 5)::integer;
  v_code text := case when coalesce(p_code, '') ~ '^[a-z_]{1,40}$' then p_code else 'internal' end;
  v_note text := left(nullif(btrim(coalesce(p_detail, '')), ''), 500);
begin
  if coalesce(p_retry, false) and f.attempts < v_max then
    update private.finreport_files
       set status = 'queued', available_at = now() + make_interval(mins => f.attempts * f.attempts),
           locked_until = null, locked_by = null, error_code = v_code, error_detail = v_note
     where id = f.id;
    return jsonb_build_object('status', 'queued', 'retry_at', now() + make_interval(mins => f.attempts * f.attempts));
  end if;
  update private.finreport_files
     set status = 'rejected', error_code = case when coalesce(p_retry, false) then 'too_many_attempts' else v_code end,
         error_detail = v_note, locked_until = null, locked_by = null, finished_at = now()
   where id = f.id;
  if v_code = 'infected' then
    perform private.finreport_cleanup(f.object_name, 'finreport_infected');
  end if;
  return jsonb_build_object('status', 'rejected');
end;
$$;

create or replace function private.finreport_maintenance()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_keep  integer := private.setting_num('finreport.rejected_keep_days', 30)::integer;
  v_name  text;
  v_count integer := 0;
begin
  for v_name in
    select o.name
    from storage.objects o
    where o.bucket_id = 'financial-reports' and o.created_at < now() - interval '1 hour'
      and not exists (
        select 1 from private.finreport_files f
        where f.object_name = o.name
          and (f.status in ('queued', 'processing', 'done')
               or (f.status = 'rejected' and f.error_code <> 'infected'
                   and f.finished_at > now() - make_interval(days => v_keep))))
    order by o.created_at
    limit 500
  loop
    perform private.finreport_cleanup(v_name, 'finreport_unused');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.finreport_file_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', f.id, 'source', f.source, 'status', f.status, 'sha256', f.sha256, 'size_bytes', f.size_bytes,
    'key', case when f.key_id is not null then (select jsonb_build_object('id', k.id, 'name', k.name, 'prefix', k.prefix)
                                                from private.integration_keys k where k.id = f.key_id) end,
    'uploaded_by', cs.staff_ref(f.uploaded_by), 'attempts', f.attempts,
    'retry_at', case when f.status = 'queued' and f.attempts > 0 then f.available_at end,
    'error_code', f.error_code, 'error_detail', f.error_detail,
    'received_at', f.created_at, 'finished_at', f.finished_at,
    'retryable', f.status = 'rejected' and coalesce(f.error_code, '') <> 'infected'
                 and exists (select 1 from storage.objects o where o.bucket_id = 'financial-reports' and o.name = f.object_name),
    'report', private.finreport_report_ref(f.report_id))
  from private.finreport_files f
  where f.id = p_id;
$$;

create or replace function cs.finreport_config_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'official_account', case when c.official_account_id is not null
                             then cs.community_account_ref(c.official_account_id) end,
    'official_active', c.official_account_id is not null and cs.official_active(c.official_account_id),
    'auto_publish', c.auto_publish, 'updated_by', cs.staff_ref(c.updated_by), 'updated_at', c.updated_at,
    'max_file_bytes', 8388608)
  from private.finreport_config c
  where c.singleton;
$$;

create or replace function cs_api.finreport_files(p_status text default null, p_entity text default null,
                                                  p_limit integer default 50, p_before timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community(cs.community_permission_codes());
  v_entity text := nullif(upper(btrim(coalesce(p_entity, ''))), '');
  v_limit  integer := greatest(1, least(coalesce(p_limit, 50), 200));
  v_items  jsonb;
  v_last   timestamptz;
  v_count  integer;
begin
  if p_status is not null and p_status not in ('queued', 'processing', 'done', 'duplicate', 'rejected') then
    perform private.api_error(400, 'invalid_status', 'Status tidak dikenal');
  end if;
  select coalesce(jsonb_agg(cs.finreport_file_view(x.id) order by x.created_at desc, x.id desc), '[]'),
         min(x.created_at), count(*)
    into v_items, v_last, v_count
  from (
    select f.id, f.created_at
    from private.finreport_files f
    left join private.finreport_reports r on r.id = f.report_id
    where (p_status is null or f.status = p_status)
      and (v_entity is null or r.entity_code = v_entity)
      and (p_before is null or f.created_at < p_before)
    order by f.created_at desc, f.id desc
    limit v_limit) x;
  return jsonb_build_object('items', v_items, 'next_before', case when v_count = v_limit then v_last end,
                            'config', cs.finreport_config_view(),
                            'counts', coalesce((select jsonb_object_agg(s.status, s.n)
                                                from (select f.status, count(*) as n from private.finreport_files f
                                                      where f.created_at > now() - interval '30 days'
                                                      group by f.status) s), '{}'));
end;
$$;

create or replace function cs_api.finreport_report(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
  r    private.finreport_reports;
begin
  select * into r from private.finreport_reports where id = p_id;
  if not found then
    perform private.api_error(404, 'report_not_found', 'Laporan tidak ditemukan');
  end if;
  return private.finreport_report_ref(r.id) || jsonb_build_object(
    'sector', r.sector, 'subsector', r.subsector, 'metrics', r.metrics, 'summary', r.summary,
    'warnings', r.warnings, 'created_at', r.created_at, 'superseded_at', r.superseded_at,
    'supersedes', private.finreport_report_ref(r.supersedes),
    'superseded_by', (select private.finreport_report_ref(n.id) from private.finreport_reports n where n.supersedes = r.id),
    'post', case when r.community_post_id is not null then cs.community_post_view(r.community_post_id) end,
    'can_create_post', r.superseded_at is null
      and (r.community_post_id is null
           or (select c.status in ('rejected', 'cancelled', 'failed') from cs.community_posts c
               where c.id = r.community_post_id)),
    'files', coalesce((select jsonb_agg(cs.finreport_file_view(f.id) order by f.created_at)
                       from private.finreport_files f where f.report_id = r.id), '[]'),
    'history', coalesce((select jsonb_agg(private.finreport_report_ref(h.id) order by h.period_end desc)
                         from (select x.id, x.period_end from private.finreport_reports x
                               where x.entity_code = r.entity_code and x.superseded_at is null and x.id <> r.id
                               order by x.period_end desc limit 12) h), '[]'));
end;
$$;

create or replace function cs_api.finreport_upload(p_object text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.post}');
  v_name text := btrim(coalesce(p_object, ''));
  v_size bigint;
  v_id   uuid;
begin
  if v_name !~ '^hub/[0-9a-f-]{36}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/report\.zip$'
     or split_part(v_name, '/', 2) <> v_me::text then
    perform private.api_error(400, 'invalid_object', 'Lokasi file unggahan tidak valid');
  end if;
  select (o.metadata ->> 'size')::bigint into v_size
  from storage.objects o
  where o.bucket_id = 'financial-reports' and o.name = v_name and o.owner_id = v_me::text;
  if not found then
    perform private.api_error(404, 'object_not_found', 'File belum terunggah ke storage');
  end if;
  if exists (select 1 from private.finreport_files f where f.object_name = v_name) then
    perform private.api_error(409, 'already_submitted', 'File ini sudah diajukan');
  end if;
  insert into private.finreport_files (source, uploaded_by, object_name, size_bytes)
  values ('hub', v_me, v_name, case when v_size between 1 and 8388608 then v_size::integer end)
  returning id into v_id;
  perform cs.audit('finreport.upload', null, null, jsonb_build_object('file', v_id, 'size', v_size));
  return cs.finreport_file_view(v_id);
end;
$$;

create or replace function cs_api.finreport_retry(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post}');
  f    private.finreport_files;
begin
  select * into f from private.finreport_files where id = p_id for update;
  if not found then
    perform private.api_error(404, 'file_not_found', 'File laporan tidak ditemukan');
  end if;
  if f.status <> 'rejected' or coalesce(f.error_code, '') = 'infected' then
    perform private.api_error(409, 'not_retryable', 'Hanya file yang ditolak dan tidak terinfeksi yang bisa diproses ulang');
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'financial-reports' and o.name = f.object_name) then
    perform private.api_error(410, 'object_gone', 'File aslinya sudah dihapus. Unggah ulang file tersebut');
  end if;
  update private.finreport_files
     set status = 'queued', attempts = 0, available_at = now(), error_code = null, error_detail = null,
         finished_at = null, locked_until = null, locked_by = null
   where id = f.id;
  perform cs.audit('finreport.retry', null, null, jsonb_build_object('file', f.id, 'error', f.error_code));
  return cs.finreport_file_view(f.id);
end;
$$;

create or replace function cs_api.finreport_create_post(p_report uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post}');
  r    private.finreport_reports;
begin
  select * into r from private.finreport_reports where id = p_report for update;
  if not found then
    perform private.api_error(404, 'report_not_found', 'Laporan tidak ditemukan');
  end if;
  if r.superseded_at is not null then
    perform private.api_error(409, 'superseded', 'Laporan ini sudah digantikan revisi yang lebih baru');
  end if;
  if r.community_post_id is not null
     and (select c.status from cs.community_posts c where c.id = r.community_post_id)
         not in ('rejected', 'cancelled', 'failed') then
    perform private.api_error(409, 'post_exists', 'Laporan ini sudah punya postingan yang aktif');
  end if;
  update private.finreport_reports
     set warnings = coalesce((select jsonb_agg(w) from jsonb_array_elements(warnings) w
                              where w ->> 'code' not in ('no_official_account', 'post_rejected')), '[]')
   where id = r.id;
  perform private.finreport_make_post(r.id, v_me);
  perform cs.audit('finreport.post_create', null, null, jsonb_build_object('report', r.id));
  return cs_api.finreport_report(r.id);
end;
$$;

create or replace function cs_api.finreport_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return cs.finreport_config_view();
end;
$$;

create or replace function cs_api.finreport_save_config(p_official_account uuid, p_auto_publish boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  c     private.finreport_config;
begin
  if p_official_account is not null and not cs.official_active(p_official_account) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  select * into c from private.finreport_config where singleton for update;
  update private.finreport_config
     set official_account_id = p_official_account, auto_publish = coalesce(p_auto_publish, false),
         updated_by = v_me, updated_at = now()
   where singleton;
  perform cs.audit('finreport.config', null, null, jsonb_build_object(
    'official_account', jsonb_build_object('from', c.official_account_id, 'to', p_official_account),
    'auto_publish', jsonb_build_object('from', c.auto_publish, 'to', coalesce(p_auto_publish, false))));
  return cs.finreport_config_view();
end;
$$;

select cron.schedule('finreport-maintenance', '23 * * * *', 'select private.finreport_maintenance()');

revoke execute on function private.can_upload_finreport() from public;
revoke execute on function private.finreport_post_ref(uuid) from public;
revoke execute on function private.finreport_report_ref(uuid) from public;
revoke execute on function private.finreport_file_external(uuid) from public;
revoke execute on function private.finreport_cleanup(text, text) from public;
revoke execute on function private.finreport_claimed(uuid, text) from public;
revoke execute on function private.finreport_version(text, date, date) from public;
revoke execute on function private.finreport_make_post(uuid, uuid) from public;
revoke execute on function private.finreport_text(jsonb, integer) from public;
revoke execute on function private.finreport_date(jsonb) from public;
revoke execute on function private.finreport_maintenance() from public;
revoke execute on function cs.finreport_file_view(uuid) from public;
revoke execute on function cs.finreport_config_view() from public;
revoke execute on function public.finreport_submit(uuid, text, integer, text) from public, anon, authenticated;
revoke execute on function public.finreport_file(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.finreport_claim(text, integer) from public, anon, authenticated;
revoke execute on function public.finreport_related(text, date, date) from public, anon, authenticated;
revoke execute on function public.finreport_complete(uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function public.finreport_fail(uuid, text, text, text, boolean) from public, anon, authenticated;
revoke execute on function cs_api.finreport_files(text, text, integer, timestamptz) from public;
revoke execute on function cs_api.finreport_report(uuid) from public;
revoke execute on function cs_api.finreport_upload(text) from public;
revoke execute on function cs_api.finreport_retry(uuid) from public;
revoke execute on function cs_api.finreport_create_post(uuid) from public;
revoke execute on function cs_api.finreport_config() from public;
revoke execute on function cs_api.finreport_save_config(uuid, boolean) from public;

grant execute on function private.can_upload_finreport() to authenticated;
grant execute on function public.finreport_submit(uuid, text, integer, text) to service_role;
grant execute on function public.finreport_file(uuid, uuid, text) to service_role;
grant execute on function public.finreport_claim(text, integer) to service_role;
grant execute on function public.finreport_related(text, date, date) to service_role;
grant execute on function public.finreport_complete(uuid, text, jsonb) to service_role;
grant execute on function public.finreport_fail(uuid, text, text, text, boolean) to service_role;
grant execute on function cs_api.finreport_files(text, text, integer, timestamptz) to authenticated;
grant execute on function cs_api.finreport_report(uuid) to authenticated;
grant execute on function cs_api.finreport_upload(text) to authenticated;
grant execute on function cs_api.finreport_retry(uuid) to authenticated;
grant execute on function cs_api.finreport_create_post(uuid) to authenticated;
grant execute on function cs_api.finreport_config() to authenticated;
grant execute on function cs_api.finreport_save_config(uuid, boolean) to authenticated;
