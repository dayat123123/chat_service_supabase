alter table private.backup_config
  add column kind text not null default 's3' check (kind in ('s3', 'local'));

create or replace function cs.backup_local_repository()
returns text
language sql
immutable
set search_path = ''
as $$
  select '/var/lib/olt-backup-repo'::text;
$$;

create or replace function cs.backup_configured(p_c private.backup_config)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_c.password_secret_id is not null
     and (p_c.kind = 'local'
          or (p_c.endpoint is not null and p_c.bucket is not null and p_c.access_key_id is not null
              and p_c.secret_id is not null));
$$;

create or replace function cs.backup_repository(p_c private.backup_config)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_c.kind = 'local' then cs.backup_local_repository()
              else 's3:' || p_c.endpoint || '/' || p_c.bucket || coalesce('/' || p_c.prefix, '') end;
$$;

create or replace function cs.backup_secrets_readable(p_c private.backup_config)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.vault_readable(p_c.password_secret_id) and (p_c.kind = 'local' or cs.vault_readable(p_c.secret_id));
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
  if not cs.backup_secrets_readable(v_c) then
    return jsonb_build_object('revision', v_c.revision, 'configured', false, 'problem', 'secret_unreadable');
  end if;
  return jsonb_build_object(
    'revision', v_c.revision,
    'configured', true,
    'kind', v_c.kind,
    'repository', cs.backup_repository(v_c),
    's3', case when v_c.kind = 's3' then jsonb_build_object(
      'access_key_id', v_c.access_key_id,
      'secret_access_key', cs.vault_read(v_c.secret_id),
      'region', v_c.region) end,
    'password', cs.vault_read(v_c.password_secret_id),
    'schedule', jsonb_build_object(
      'base_time', v_c.base_time, 'timezone', 'Asia/Jakarta', 'offsite_minutes', v_c.offsite_minutes,
      'restore_test_weekday', v_c.restore_test_weekday, 'restore_test_time', v_c.restore_test_time),
    'retention', jsonb_build_object(
      'daily', v_c.retention_daily, 'weekly', v_c.retention_weekly, 'monthly', v_c.retention_monthly,
      'wal_days', v_c.wal_days),
    'restore_test', v_c.restore_test);
end;
$$;

create or replace function private.health_checks_secrets()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'backup:secret', 'critical', 'Rahasia backup tidak bisa dibuka',
         'Kunci enkripsi Vault berbeda (mis. database dipulihkan ke server baru). Isi ulang '
           || case when c.kind = 'local' then 'password enkripsi' else 'secret access key dan password enkripsi' end
           || ' di Kesehatan sistem → Backup'
  from private.backup_config c
  where c.singleton and cs.backup_configured(c) and not cs.backup_secrets_readable(c)
  union all
  select 'alerts:secret', 'warning', 'Rahasia kanal alert tidak bisa dibuka',
         'Isi ulang token Telegram atau password SMTP di Kesehatan sistem → Alert'
  from private.alert_channels c
  where c.singleton
    and ((c.telegram_enabled and c.telegram_secret_id is not null and not cs.vault_readable(c.telegram_secret_id))
      or (c.email_enabled and c.smtp_secret_id is not null and not cs.vault_readable(c.smtp_secret_id)));
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
    'kind', v_c.kind,
    'target', case when v_c.kind = 'local' then cs.backup_local_repository()
                   when v_c.endpoint is not null then v_c.endpoint || '/' || v_c.bucket || coalesce('/' || v_c.prefix, '') end,
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
  v_ratio   numeric;
begin
  select * into v_c from private.backup_config c where c.singleton;
  if not cs.backup_configured(v_c) then
    return query select 'backup:config', 'warning', 'Backup belum diatur',
                        'Atur tujuan backup (S3 atau folder lokal di server) dan password enkripsi di Kesehatan sistem → Backup';
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
                          coalesce(v_s ->> 'error',
                                   case when v_c.kind = 'local'
                                        then 'Periksa folder repositori lokal (mount BACKUP_LOCAL_REPO_DIR, izin tulis) dan password enkripsi'
                                        else 'Periksa alamat S3, kunci akses, dan password enkripsi' end);
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
    return query select 'backup:offsite', 'critical', 'Pengiriman WAL ke repositori backup tertunda',
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

  if v_c.kind = 'local' and (v_s #>> '{repository_disk,total_bytes}')::numeric > 0 then
    v_ratio := (v_s #>> '{repository_disk,avail_bytes}')::numeric / (v_s #>> '{repository_disk,total_bytes}')::numeric;
    if v_ratio < 0.1 then
      return query select 'backup:repository_disk', case when v_ratio < 0.05 then 'critical' else 'warning' end,
                          'Disk repositori backup lokal hampir penuh',
                          'Sisa ' || pg_catalog.pg_size_pretty((v_s #>> '{repository_disk,avail_bytes}')::bigint)
                            || '. Kurangi retensi atau pindahkan BACKUP_LOCAL_REPO_DIR ke disk yang lebih besar';
    end if;
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
    'configured', cs.backup_configured(c), 'revision', c.revision, 'kind', c.kind,
    'local_repository', cs.backup_local_repository(),
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

drop function if exists cs_api.backup_set_target(text, text, text, text, text, text, text);

create function cs_api.backup_set_target(
  p_endpoint text default null, p_bucket text default null, p_prefix text default null, p_region text default null,
  p_access_key_id text default null, p_secret_access_key text default null, p_password text default null,
  p_kind text default 's3'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin}');
  v_c         private.backup_config;
  v_kind      text := lower(btrim(coalesce(p_kind, 's3')));
  v_endpoint  text := nullif(rtrim(btrim(coalesce(p_endpoint, '')), '/'), '');
  v_bucket    text := nullif(lower(btrim(coalesce(p_bucket, ''))), '');
  v_prefix    text := nullif(trim(both '/' from btrim(coalesce(p_prefix, ''))), '');
  v_region    text := nullif(lower(btrim(coalesce(p_region, ''))), '');
  v_key_id    text := nullif(btrim(coalesce(p_access_key_id, '')), '');
  v_secret    text := nullif(p_secret_access_key, '');
  v_password  text := nullif(p_password, '');
  v_moved     boolean;
  v_recovered boolean;
  v_dropped   uuid;
begin
  if v_kind not in ('s3', 'local') then
    perform private.api_error(400, 'invalid_backup_kind', 'Jenis tujuan backup harus s3 atau local');
  end if;
  if v_kind = 'local' then
    v_endpoint := null;
    v_bucket := null;
    v_prefix := null;
    v_region := null;
    v_key_id := null;
    v_secret := null;
  else
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
  end if;
  if v_password is not null and char_length(v_password) not between 16 and 200 then
    perform private.api_error(400, 'weak_backup_password', 'Password enkripsi minimal 16 karakter');
  end if;

  select * into v_c from private.backup_config c where c.singleton for update;
  v_moved := v_c.kind is distinct from v_kind or v_c.endpoint is distinct from v_endpoint
             or v_c.bucket is distinct from v_bucket or v_c.prefix is distinct from v_prefix;
  if v_kind = 's3' and v_secret is null
     and (v_c.kind is distinct from 's3' or v_c.secret_id is null or not cs.vault_readable(v_c.secret_id)) then
    perform private.api_error(400, 'invalid_backup_credentials', 'Isi secret access key');
  end if;
  if v_password is null and (v_c.password_secret_id is null or not cs.vault_readable(v_c.password_secret_id)) then
    perform private.api_error(400, 'weak_backup_password', 'Isi password enkripsi backup');
  end if;
  v_recovered := v_c.password_secret_id is not null and not cs.vault_readable(v_c.password_secret_id);
  if v_password is not null and v_c.password_secret_id is not null and not v_moved and not v_recovered then
    perform private.api_error(409, 'backup_password_locked',
                              'Password enkripsi repositori yang sudah ada tidak bisa diganti. Pakai folder atau bucket baru.');
  end if;
  if v_moved and v_c.password_secret_id is not null and v_password is null then
    perform private.api_error(400, 'weak_backup_password', 'Repositori baru butuh password enkripsi baru');
  end if;

  if v_kind = 'local' and v_c.secret_id is not null then
    v_dropped := v_c.secret_id;
    v_c.secret_id := null;
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
     set kind = v_kind, endpoint = v_endpoint, bucket = v_bucket, prefix = v_prefix, region = v_region,
         access_key_id = v_key_id, secret_id = v_c.secret_id, password_secret_id = v_c.password_secret_id,
         password_set_at = case when v_password is not null then now() else c.password_set_at end,
         configured_at = case when v_moved or c.configured_at is null then now() else c.configured_at end,
         revision = c.revision + 1, updated_by = v_me, updated_at = now()
   where c.singleton;
  if v_dropped is not null then
    delete from vault.secrets s where s.id = v_dropped;
  end if;
  perform cs.audit('backup.target_set', null, null, jsonb_build_object(
    'kind', v_kind, 'endpoint', v_endpoint, 'bucket', v_bucket, 'prefix', v_prefix, 'region', v_region,
    'access_key_id', v_key_id, 'secret_changed', v_secret is not null or v_dropped is not null,
    'password_changed', v_password is not null, 'moved', v_moved,
    'password_recovered', v_recovered and v_password is not null));
  return cs.backup_config_view();
end;
$$;

revoke execute on function cs.backup_local_repository() from public;
revoke execute on function cs.backup_secrets_readable(private.backup_config) from public;
revoke execute on function cs_api.backup_set_target(text, text, text, text, text, text, text, text) from public;
grant execute on function cs_api.backup_set_target(text, text, text, text, text, text, text, text) to authenticated;
