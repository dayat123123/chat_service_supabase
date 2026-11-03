create or replace function cs.vault_read(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value text;
begin
  if p_id is null then
    return null;
  end if;
  select s.decrypted_secret into v_value from vault.decrypted_secrets s where s.id = p_id;
  return v_value;
exception when others then
  return null;
end;
$$;

create or replace function cs.vault_readable(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.vault_read(p_id) is not null;
$$;

create or replace function cs.vault_store_secret(p_secret_id uuid, p_value text, p_name text, p_description text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_secret_id is not null and cs.vault_readable(p_secret_id) then
    perform vault.update_secret(p_secret_id, p_value);
    return p_secret_id;
  end if;
  delete from vault.secrets s where s.id = p_secret_id or s.name = p_name;
  return vault.create_secret(p_value, p_name, p_description);
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
         'Kunci enkripsi Vault berbeda (mis. database dipulihkan ke server baru). '
           || 'Isi ulang secret access key dan password enkripsi di Kesehatan sistem → Backup'
  from private.backup_config c
  where c.singleton and cs.backup_configured(c)
    and not (cs.vault_readable(c.secret_id) and cs.vault_readable(c.password_secret_id))
  union all
  select 'alerts:secret', 'warning', 'Rahasia kanal alert tidak bisa dibuka',
         'Isi ulang token Telegram atau password SMTP di Kesehatan sistem → Alert'
  from private.alert_channels c
  where c.singleton
    and ((c.telegram_enabled and c.telegram_secret_id is not null and not cs.vault_readable(c.telegram_secret_id))
      or (c.email_enabled and c.smtp_secret_id is not null and not cs.vault_readable(c.smtp_secret_id)));
$$;

create or replace function private.health_current()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (c.key) c.key, c.severity, left(c.title, 200), left(c.detail, 500)
  from (
    select * from private.health_checks_services()
    union all select * from private.health_checks_probes()
    union all select * from private.health_checks_disks()
    union all select * from private.health_checks_database()
    union all select * from private.health_checks_queues()
    union all select * from private.health_checks_backup()
    union all select * from private.health_checks_secrets()
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
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
  if not (cs.vault_readable(v_c.secret_id) and cs.vault_readable(v_c.password_secret_id)) then
    return jsonb_build_object('revision', v_c.revision, 'configured', false, 'problem', 'secret_unreadable');
  end if;
  return jsonb_build_object(
    'revision', v_c.revision,
    'configured', true,
    'repository', cs.backup_repository(v_c),
    's3', jsonb_build_object(
      'access_key_id', v_c.access_key_id,
      'secret_access_key', cs.vault_read(v_c.secret_id),
      'region', v_c.region),
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

create or replace function public.alert_channels(p_revision bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c private.alert_channels;
begin
  select * into v_c from private.alert_channels c where c.singleton;
  if p_revision is not null and p_revision = v_c.revision then
    return jsonb_build_object('revision', v_c.revision, 'unchanged', true);
  end if;
  return jsonb_build_object(
    'revision', v_c.revision,
    'telegram', case when v_c.telegram_enabled and cs.vault_readable(v_c.telegram_secret_id) then jsonb_build_object(
      'bot_token', cs.vault_read(v_c.telegram_secret_id),
      'chat_ids', to_jsonb(v_c.telegram_chat_ids)) end,
    'email', case when v_c.email_enabled and v_c.smtp_host is not null then jsonb_build_object(
      'host', v_c.smtp_host, 'port', v_c.smtp_port, 'security', v_c.smtp_security,
      'username', v_c.smtp_username,
      'password', cs.vault_read(v_c.smtp_secret_id),
      'from', v_c.email_from, 'to', to_jsonb(v_c.email_to)) end);
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
  v_recovered boolean;
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
  if v_secret is null and (v_c.secret_id is null or not cs.vault_readable(v_c.secret_id)) then
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
    'secret_changed', v_secret is not null, 'password_changed', v_password is not null, 'moved', v_moved,
    'password_recovered', v_recovered and v_password is not null));
  return cs.backup_config_view();
end;
$$;

revoke execute on function cs.vault_read(uuid) from public;
revoke execute on function cs.vault_readable(uuid) from public;
revoke execute on function private.health_checks_secrets() from public;
