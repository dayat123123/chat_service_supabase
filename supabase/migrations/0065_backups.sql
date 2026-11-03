create table private.backup_config (
  singleton            boolean primary key default true check (singleton),
  revision             bigint not null default 0,
  endpoint             text check (endpoint ~ '^https?://[A-Za-z0-9.-]{1,253}(:[0-9]{1,5})?$'),
  bucket               text check (bucket ~ '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$'),
  prefix               text check (prefix ~ '^[A-Za-z0-9._-]{1,64}(/[A-Za-z0-9._-]{1,64}){0,4}$'),
  region               text check (region ~ '^[a-z0-9-]{2,40}$'),
  access_key_id        text check (char_length(access_key_id) between 3 and 200),
  secret_id            uuid,
  password_secret_id   uuid,
  password_set_at      timestamptz,
  configured_at        timestamptz,
  base_time            text not null default '02:00' check (base_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  offsite_minutes      integer not null default 5 check (offsite_minutes between 1 and 60),
  retention_daily      integer not null default 7 check (retention_daily between 1 and 60),
  retention_weekly     integer not null default 4 check (retention_weekly between 0 and 52),
  retention_monthly    integer not null default 6 check (retention_monthly between 0 and 36),
  wal_days             integer not null default 7 check (wal_days between 1 and 35),
  restore_test         boolean not null default true,
  restore_test_weekday integer not null default 0 check (restore_test_weekday between 0 and 6),
  restore_test_time    text not null default '04:00' check (restore_test_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  updated_by           uuid,
  updated_at           timestamptz not null default now()
);
insert into private.backup_config (singleton) values (true);
alter table private.backup_config enable row level security;

create table private.backup_state (
  instance        text primary key check (char_length(instance) between 1 and 200),
  version         text,
  started_at      timestamptz,
  last_seen_at    timestamptz not null default now(),
  config_revision bigint,
  state           jsonb not null default '{}'
);
alter table private.backup_state enable row level security;

create table private.backup_runs (
  id          bigint generated always as identity primary key,
  instance    text not null,
  kind        text not null check (kind in ('base', 'files', 'wal', 'prune', 'check', 'restore_test')),
  status      text not null check (status in ('ok', 'failed')),
  started_at  timestamptz,
  finished_at timestamptz not null default now(),
  bytes       bigint,
  snapshot_id text,
  detail      jsonb not null default '{}',
  error       text,
  created_at  timestamptz not null default now()
);
create index backup_runs_kind_idx on private.backup_runs (kind, finished_at desc);
alter table private.backup_runs enable row level security;

create table private.backup_requests (
  id           bigint generated always as identity primary key,
  kind         text not null check (kind in ('base', 'restore_test')),
  requested_by uuid not null,
  requested_at timestamptz not null default now(),
  taken_at     timestamptz,
  taken_by     text
);
create unique index backup_requests_pending on private.backup_requests (kind) where taken_at is null;
alter table private.backup_requests enable row level security;

create or replace function cs.backup_configured(p_c private.backup_config)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_c.endpoint is not null and p_c.bucket is not null and p_c.access_key_id is not null
     and p_c.secret_id is not null and p_c.password_secret_id is not null;
$$;

create or replace function cs.backup_repository(p_c private.backup_config)
returns text
language sql
immutable
set search_path = ''
as $$
  select 's3:' || p_c.endpoint || '/' || p_c.bucket || coalesce('/' || p_c.prefix, '');
$$;

create or replace function public.backup_config(p_revision bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c private.backup_config;
begin
  select * into v_c from private.backup_config c where c.singleton;
  if p_revision is not null and p_revision = v_c.revision then
    return jsonb_build_object('revision', v_c.revision, 'unchanged', true);
  end if;
  if not cs.backup_configured(v_c) then
    return jsonb_build_object('revision', v_c.revision, 'configured', false);
  end if;
  return jsonb_build_object(
    'revision', v_c.revision,
    'configured', true,
    'repository', cs.backup_repository(v_c),
    's3', jsonb_build_object(
      'access_key_id', v_c.access_key_id,
      'secret_access_key', (select s.decrypted_secret from vault.decrypted_secrets s where s.id = v_c.secret_id),
      'region', v_c.region),
    'password', (select s.decrypted_secret from vault.decrypted_secrets s where s.id = v_c.password_secret_id),
    'schedule', jsonb_build_object(
      'base_time', v_c.base_time, 'timezone', 'Asia/Jakarta', 'offsite_minutes', v_c.offsite_minutes,
      'restore_test_weekday', v_c.restore_test_weekday, 'restore_test_time', v_c.restore_test_time),
    'retention', jsonb_build_object(
      'daily', v_c.retention_daily, 'weekly', v_c.retention_weekly, 'monthly', v_c.retention_monthly,
      'wal_days', v_c.wal_days),
    'restore_test', v_c.restore_test);
end;
$$;

create or replace function public.backup_heartbeat(
  p_instance text, p_version text, p_started_at timestamptz, p_config_revision bigint, p_state jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state    jsonb := case when jsonb_typeof(p_state) = 'object' and pg_column_size(p_state) <= 16384
                           then p_state else '{}' end;
  v_error    text := coalesce(v_state ->> 'error', v_state #>> '{wal,error}');
  v_requests jsonb;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 200 then
    perform private.api_error(400, 'invalid_instance', 'Instance tidak valid');
  end if;
  insert into private.backup_state as b (instance, version, started_at, last_seen_at, config_revision, state)
  values (p_instance, left(p_version, 40), p_started_at, now(), p_config_revision, v_state)
  on conflict (instance) do update
     set version = excluded.version, started_at = excluded.started_at, last_seen_at = now(),
         config_revision = excluded.config_revision, state = excluded.state;
  perform public.service_heartbeat('backup', p_instance, p_version, p_started_at,
    case when v_error is not null then 'error' else 'ok' end, v_error,
    jsonb_build_object('busy', v_state ->> 'busy', 'streaming', coalesce((v_state #>> '{wal,streaming}')::boolean, false),
                       'repository_ready', coalesce((v_state ->> 'repository_ready')::boolean, false)));
  with taken as (
    update private.backup_requests r set taken_at = now(), taken_by = p_instance
     where r.taken_at is null
    returning r.kind
  )
  select coalesce(jsonb_agg(distinct kind), '[]') into v_requests from taken;
  delete from private.backup_state b where b.last_seen_at < now() - interval '1 day';
  return jsonb_build_object('requests', v_requests);
end;
$$;

create or replace function public.backup_record(p_instance text, p_run jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_run) is distinct from 'object'
     or coalesce(p_run ->> 'kind', '') not in ('base', 'files', 'wal', 'prune', 'check', 'restore_test')
     or coalesce(p_run ->> 'status', '') not in ('ok', 'failed') then
    perform private.api_error(400, 'invalid_backup_run', 'Jenis atau status backup tidak valid');
  end if;
  insert into private.backup_runs (instance, kind, status, started_at, finished_at, bytes, snapshot_id, detail, error)
  values (left(p_instance, 200), p_run ->> 'kind', p_run ->> 'status', (p_run ->> 'started_at')::timestamptz,
          coalesce((p_run ->> 'finished_at')::timestamptz, now()), (p_run ->> 'bytes')::bigint,
          left(p_run ->> 'snapshot_id', 100),
          case when jsonb_typeof(p_run -> 'detail') = 'object' and pg_column_size(p_run -> 'detail') <= 8192
               then p_run -> 'detail' else '{}' end,
          left(nullif(btrim(p_run ->> 'error'), ''), 1000));
end;
$$;

create or replace function cs.backup_last_run(p_kind text, p_status text default null)
returns private.backup_runs
language sql
stable
security definer
set search_path = ''
as $$
  select r.* from private.backup_runs r
  where r.kind = p_kind and (p_status is null or r.status = p_status)
  order by r.finished_at desc
  limit 1;
$$;

create or replace function cs.backup_live_state()
returns private.backup_state
language sql
stable
security definer
set search_path = ''
as $$
  select b.* from private.backup_state b
  where b.last_seen_at > now() - interval '90 seconds'
  order by b.last_seen_at desc
  limit 1;
$$;

create or replace function cs.backup_run_view(p_run private.backup_runs)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when p_run.id is null then null else jsonb_strip_nulls(jsonb_build_object(
    'id', p_run.id, 'kind', p_run.kind, 'status', p_run.status, 'started_at', p_run.started_at,
    'finished_at', p_run.finished_at, 'bytes', p_run.bytes, 'snapshot_id', p_run.snapshot_id,
    'detail', p_run.detail, 'error', p_run.error)) end;
$$;

create or replace function cs.backup_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c     private.backup_config;
  v_state private.backup_state;
begin
  select * into v_c from private.backup_config c where c.singleton;
  v_state := cs.backup_live_state();
  return jsonb_build_object(
    'configured', cs.backup_configured(v_c),
    'target', case when v_c.endpoint is not null then v_c.endpoint || '/' || v_c.bucket || coalesce('/' || v_c.prefix, '') end,
    'live', v_state.instance is not null,
    'state', v_state.state,
    'last_base', cs.backup_run_view(cs.backup_last_run('base', 'ok')),
    'last_files', cs.backup_run_view(cs.backup_last_run('files', 'ok')),
    'last_restore_test', cs.backup_run_view(cs.backup_last_run('restore_test')));
end;
$$;

create or replace function private.health_checks_backup()
returns table (key text, severity text, title text, detail text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c       private.backup_config;
  v_state   private.backup_state;
  v_s       jsonb;
  v_base    private.backup_runs;
  v_last    private.backup_runs;
  v_test    private.backup_runs;
  v_test_ok private.backup_runs;
  v_offsite timestamptz;
  v_lag     interval;
begin
  select * into v_c from private.backup_config c where c.singleton;
  if not cs.backup_configured(v_c) then
    return query select 'backup:config', 'warning', 'Backup belum diatur',
                        'Atur tujuan backup S3 dan password enkripsi di Kesehatan sistem → Backup';
    return;
  end if;
  v_state := cs.backup_live_state();
  if v_state.instance is null then
    return;
  end if;
  v_s := v_state.state;

  if not coalesce((v_s ->> 'repository_ready')::boolean, false) then
    if v_c.configured_at < now() - interval '5 minutes' then
      return query select 'backup:repository', 'critical', 'Repositori backup tidak bisa dibuka',
                          coalesce(v_s ->> 'error', 'Periksa alamat S3, kunci akses, dan password enkripsi');
    end if;
    return;
  end if;

  if coalesce((v_s #>> '{wal,slot_lost}')::boolean, false) then
    return query select 'backup:slot', 'critical', 'Slot WAL backup hilang',
                        'Backup penuh baru dibuat otomatis; titik pemulihan sebelum ini terputus';
  elsif not coalesce((v_s #>> '{wal,streaming}')::boolean, false) then
    return query select 'backup:wal', 'critical', 'Streaming WAL backup berhenti',
                        coalesce(v_s #>> '{wal,error}', 'pg_receivewal tidak berjalan');
  end if;

  v_base := cs.backup_last_run('base', 'ok');
  v_last := cs.backup_last_run('base');
  if v_base.id is null then
    if v_c.configured_at < now() - interval '2 hours' then
      return query select 'backup:base', 'critical', 'Belum ada backup penuh yang berhasil',
                          coalesce(v_last.error, 'Backup penuh pertama belum selesai');
    end if;
  elsif v_base.finished_at < now() - interval '26 hours' then
    return query select 'backup:base', 'critical', 'Backup penuh terakhir lebih dari 26 jam lalu',
                        'Terakhir berhasil ' || private.health_fmt_time(v_base.finished_at)
                          || coalesce('. Gagal terakhir: ' || v_last.error, '');
  elsif v_last.status = 'failed' then
    return query select 'backup:base_failed', 'warning', 'Backup penuh terakhir gagal', coalesce(v_last.error, 'Gagal');
  end if;

  v_offsite := (v_s #>> '{offsite,last_ok_at}')::timestamptz;
  v_lag := greatest(interval '30 minutes', make_interval(mins => v_c.offsite_minutes * 3));
  if (v_offsite is null and v_c.configured_at < now() - v_lag) or v_offsite < now() - v_lag then
    return query select 'backup:offsite', 'critical', 'Backup WAL ke luar server tertunda',
                        coalesce(v_s #>> '{offsite,last_error}',
                                 'Terakhir terkirim ' || coalesce(private.health_fmt_time(v_offsite), 'belum pernah'));
  end if;

  if v_c.restore_test then
    v_test := cs.backup_last_run('restore_test');
    v_test_ok := cs.backup_last_run('restore_test', 'ok');
    if v_test.status = 'failed' then
      return query select 'backup:restore_test', 'warning', 'Uji restore backup gagal', coalesce(v_test.error, 'Gagal');
    elsif coalesce(v_test_ok.finished_at, v_c.configured_at) < now() - interval '8 days' then
      return query select 'backup:restore_test', 'warning', 'Uji restore belum berjalan lebih dari seminggu',
                          'Jalankan uji restore dari Kesehatan sistem → Backup';
    end if;
  end if;

  if (v_s #>> '{disk,total_bytes}')::numeric > 0
     and (v_s #>> '{disk,avail_bytes}')::numeric / (v_s #>> '{disk,total_bytes}')::numeric < 0.1 then
    return query select 'backup:disk', 'warning', 'Disk staging backup hampir penuh',
                        'Sisa ' || pg_catalog.pg_size_pretty((v_s #>> '{disk,avail_bytes}')::bigint);
  end if;
end;
$$;

create or replace function cs.backup_config_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'configured', cs.backup_configured(c), 'revision', c.revision,
    'endpoint', c.endpoint, 'bucket', c.bucket, 'prefix', c.prefix, 'region', c.region,
    'access_key_id', c.access_key_id, 'secret_set', c.secret_id is not null,
    'password_set', c.password_secret_id is not null, 'password_set_at', c.password_set_at,
    'configured_at', c.configured_at,
    'base_time', c.base_time, 'offsite_minutes', c.offsite_minutes,
    'retention_daily', c.retention_daily, 'retention_weekly', c.retention_weekly,
    'retention_monthly', c.retention_monthly, 'wal_days', c.wal_days,
    'restore_test', c.restore_test, 'restore_test_weekday', c.restore_test_weekday,
    'restore_test_time', c.restore_test_time,
    'updated_at', c.updated_at, 'updated_by', cs.agent_name(c.updated_by))
  from private.backup_config c
  where c.singleton;
$$;

create or replace function cs_api.backup_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return jsonb_build_object(
    'config', cs.backup_config_view(),
    'summary', cs.backup_summary(),
    'requests', coalesce((select jsonb_agg(jsonb_build_object('kind', r.kind, 'requested_at', r.requested_at,
                                                              'requested_by', cs.agent_name(r.requested_by)))
                          from private.backup_requests r where r.taken_at is null), '[]'),
    'runs', coalesce((select jsonb_agg(cs.backup_run_view(r) order by r.finished_at desc)
                      from private.backup_runs r
                      where r.id in (select x.id from private.backup_runs x order by x.finished_at desc limit 40)), '[]'));
end;
$$;

create or replace function cs_api.backup_set_target(
  p_endpoint text, p_bucket text, p_prefix text, p_region text, p_access_key_id text,
  p_secret_access_key text default null, p_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_c        private.backup_config;
  v_endpoint text := nullif(rtrim(btrim(coalesce(p_endpoint, '')), '/'), '');
  v_bucket   text := nullif(lower(btrim(coalesce(p_bucket, ''))), '');
  v_prefix   text := nullif(trim(both '/' from btrim(coalesce(p_prefix, ''))), '');
  v_region   text := nullif(lower(btrim(coalesce(p_region, ''))), '');
  v_key_id   text := nullif(btrim(coalesce(p_access_key_id, '')), '');
  v_secret   text := nullif(p_secret_access_key, '');
  v_password text := nullif(p_password, '');
  v_moved    boolean;
begin
  if v_endpoint is null or v_endpoint !~ '^https?://[A-Za-z0-9.-]{1,253}(:[0-9]{1,5})?$' then
    perform private.api_error(400, 'invalid_backup_endpoint', 'Endpoint S3 harus berupa https://host[:port]');
  end if;
  if v_bucket is null or v_bucket !~ '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$' then
    perform private.api_error(400, 'invalid_backup_bucket', 'Nama bucket tidak valid');
  end if;
  if v_prefix is not null and v_prefix !~ '^[A-Za-z0-9._-]{1,64}(/[A-Za-z0-9._-]{1,64}){0,4}$' then
    perform private.api_error(400, 'invalid_backup_prefix', 'Folder (prefix) tidak valid');
  end if;
  if v_region is not null and v_region !~ '^[a-z0-9-]{2,40}$' then
    perform private.api_error(400, 'invalid_backup_region', 'Region tidak valid');
  end if;
  if v_key_id is null or char_length(v_key_id) not between 3 and 200 or char_length(coalesce(v_secret, '')) > 500 then
    perform private.api_error(400, 'invalid_backup_credentials', 'Access key tidak valid');
  end if;
  if v_password is not null and char_length(v_password) not between 16 and 200 then
    perform private.api_error(400, 'weak_backup_password', 'Password enkripsi minimal 16 karakter');
  end if;

  select * into v_c from private.backup_config c where c.singleton for update;
  v_moved := v_c.endpoint is distinct from v_endpoint or v_c.bucket is distinct from v_bucket
             or v_c.prefix is distinct from v_prefix;
  if v_secret is null and v_c.secret_id is null then
    perform private.api_error(400, 'invalid_backup_credentials', 'Isi secret access key');
  end if;
  if v_password is null and v_c.password_secret_id is null then
    perform private.api_error(400, 'weak_backup_password', 'Isi password enkripsi backup');
  end if;
  if v_password is not null and v_c.password_secret_id is not null and not v_moved then
    perform private.api_error(409, 'backup_password_locked',
                              'Password enkripsi repositori yang sudah ada tidak bisa diganti. Pakai folder atau bucket baru.');
  end if;
  if v_moved and v_c.password_secret_id is not null and v_password is null then
    perform private.api_error(400, 'weak_backup_password', 'Repositori baru butuh password enkripsi baru');
  end if;

  if v_secret is not null then
    v_c.secret_id := cs.vault_store_secret(v_c.secret_id, v_secret, 'backup.s3_secret_access_key',
                                           'Secret access key S3 untuk backup');
  end if;
  if v_password is not null then
    v_c.password_secret_id := cs.vault_store_secret(v_c.password_secret_id, v_password, 'backup.restic_password',
                                                    'Password enkripsi repositori backup (restic)');
  end if;
  update private.backup_config c
     set endpoint = v_endpoint, bucket = v_bucket, prefix = v_prefix, region = v_region, access_key_id = v_key_id,
         secret_id = v_c.secret_id, password_secret_id = v_c.password_secret_id,
         password_set_at = case when v_password is not null then now() else c.password_set_at end,
         configured_at = case when v_moved or c.configured_at is null then now() else c.configured_at end,
         revision = c.revision + 1, updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('backup.target_set', null, null, jsonb_build_object(
    'endpoint', v_endpoint, 'bucket', v_bucket, 'prefix', v_prefix, 'region', v_region, 'access_key_id', v_key_id,
    'secret_changed', v_secret is not null, 'password_changed', v_password is not null, 'moved', v_moved));
  return cs.backup_config_view();
end;
$$;

create or replace function cs_api.backup_set_schedule(
  p_base_time text, p_offsite_minutes integer, p_retention_daily integer, p_retention_weekly integer,
  p_retention_monthly integer, p_wal_days integer, p_restore_test boolean, p_restore_test_weekday integer,
  p_restore_test_time text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old jsonb := cs.backup_config_view();
begin
  begin
    update private.backup_config c
       set base_time = p_base_time, offsite_minutes = p_offsite_minutes, retention_daily = p_retention_daily,
           retention_weekly = p_retention_weekly, retention_monthly = p_retention_monthly, wal_days = p_wal_days,
           restore_test = coalesce(p_restore_test, true), restore_test_weekday = p_restore_test_weekday,
           restore_test_time = p_restore_test_time, revision = c.revision + 1, updated_by = v_me, updated_at = now()
     where c.singleton;
  exception when check_violation or not_null_violation then
    perform private.api_error(400, 'invalid_backup_schedule', 'Jadwal atau retensi di luar batas');
  end;
  perform cs.audit('backup.schedule_set', null, null, jsonb_build_object(
    'old', v_old - array['updated_at', 'updated_by', 'revision'],
    'new', cs.backup_config_view() - array['updated_at', 'updated_by', 'revision']));
  return cs.backup_config_view();
end;
$$;

create or replace function cs_api.backup_request(p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
  v_c  private.backup_config;
begin
  if p_kind not in ('base', 'restore_test') then
    perform private.api_error(400, 'invalid_backup_request', 'Permintaan harus base atau restore_test');
  end if;
  select * into v_c from private.backup_config c where c.singleton;
  if not cs.backup_configured(v_c) then
    perform private.api_error(409, 'backup_not_configured', 'Atur tujuan backup dulu');
  end if;
  insert into private.backup_requests (kind, requested_by) values (p_kind, v_me)
  on conflict (kind) where taken_at is null do nothing;
  perform cs.audit('backup.requested', null, null, jsonb_build_object('kind', p_kind));
  return cs_api.backup_overview();
end;
$$;

create or replace function private.backup_purge()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.backup_runs r where r.finished_at < now() - interval '180 days';
  delete from private.backup_requests r where r.taken_at < now() - interval '30 days';
$$;

select cron.schedule('backup-purge', '47 3 * * *', 'select private.backup_purge()');

revoke execute on function cs.backup_configured(private.backup_config) from public;
revoke execute on function cs.backup_repository(private.backup_config) from public;
revoke execute on function cs.backup_last_run(text, text) from public;
revoke execute on function cs.backup_live_state() from public;
revoke execute on function cs.backup_run_view(private.backup_runs) from public;
revoke execute on function cs.backup_config_view() from public;
revoke execute on function private.backup_purge() from public;
revoke execute on function public.backup_config(bigint) from public, anon, authenticated;
revoke execute on function public.backup_heartbeat(text, text, timestamptz, bigint, jsonb) from public, anon, authenticated;
revoke execute on function public.backup_record(text, jsonb) from public, anon, authenticated;
revoke execute on function cs_api.backup_overview() from public;
revoke execute on function cs_api.backup_set_target(text, text, text, text, text, text, text) from public;
revoke execute on function cs_api.backup_set_schedule(text, integer, integer, integer, integer, integer, boolean, integer, text)
  from public;
revoke execute on function cs_api.backup_request(text) from public;

grant execute on function public.backup_config(bigint) to service_role;
grant execute on function public.backup_heartbeat(text, text, timestamptz, bigint, jsonb) to service_role;
grant execute on function public.backup_record(text, jsonb) to service_role;
grant execute on function cs_api.backup_overview() to authenticated;
grant execute on function cs_api.backup_set_target(text, text, text, text, text, text, text) to authenticated;
grant execute on function cs_api.backup_set_schedule(text, integer, integer, integer, integer, integer, boolean, integer, text)
  to authenticated;
grant execute on function cs_api.backup_request(text) to authenticated;
