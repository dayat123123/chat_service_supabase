create table private.push_credentials (
  singleton    boolean primary key default true check (singleton),
  revision     bigint not null default 0,
  secret_id    uuid,
  project_id   text,
  client_email text,
  key_id       text,
  updated_by   uuid,
  updated_at   timestamptz not null default now(),
  constraint push_credentials_complete check ((secret_id is null) = (project_id is null)
                                              and (secret_id is null) = (client_email is null))
);
alter table private.push_credentials enable row level security;
insert into private.push_credentials (singleton) values (true);

alter table private.push_instances add column credentials_revision bigint;

create or replace function private.push_credentials_problem(p_credentials jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_key text;
begin
  if jsonb_typeof(p_credentials) is distinct from 'object' then
    return 'not_json';
  elsif p_credentials ? 'project_info' then
    return 'google_services';
  elsif p_credentials ->> 'type' is distinct from 'service_account' then
    return 'not_service_account';
  elsif coalesce(p_credentials ->> 'project_id', '') !~ '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' then
    return 'project_id';
  elsif coalesce(p_credentials ->> 'client_email', '') !~ '^[^@[:space:]]{1,100}@[a-z0-9.-]{1,100}\.gserviceaccount\.com$' then
    return 'client_email';
  elsif p_credentials ? 'private_key_id'
        and coalesce(p_credentials ->> 'private_key_id', '') !~ '^[A-Za-z0-9_-]{1,100}$' then
    return 'private_key_id';
  end if;
  v_key := coalesce(p_credentials ->> 'private_key', '');
  if char_length(v_key) not between 200 and 10000
     or v_key !~ '-----BEGIN (RSA )?PRIVATE KEY-----'
     or v_key !~ '-----END (RSA )?PRIVATE KEY-----' then
    return 'private_key';
  end if;
  return null;
end;
$$;

create or replace function cs.push_credentials_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when c.secret_id is null then null else jsonb_build_object(
    'revision', c.revision, 'project_id', c.project_id, 'client_email', c.client_email, 'key_id', c.key_id,
    'updated_at', c.updated_at, 'updated_by', cs.agent_name(c.updated_by)) end
  from private.push_credentials c
  where c.singleton;
$$;

create or replace function cs_api.push_set_credentials(p_credentials jsonb, p_replace_project boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin}');
  v_problem text := private.push_credentials_problem(p_credentials);
  v_row     private.push_credentials;
  v_project text;
  v_email   text;
  v_key_id  text;
  v_secret  text;
begin
  if v_problem is not null then
    perform private.api_error(400, 'invalid_push_credentials', v_problem);
  end if;
  v_project := p_credentials ->> 'project_id';
  v_email := p_credentials ->> 'client_email';
  v_key_id := nullif(p_credentials ->> 'private_key_id', '');
  select * into v_row from private.push_credentials c where c.singleton for update;
  if v_row.project_id is not null and v_row.project_id <> v_project and not coalesce(p_replace_project, false) then
    perform private.api_error(409, 'push_project_changed', v_row.project_id);
  end if;
  v_secret := jsonb_strip_nulls(jsonb_build_object(
    'type', 'service_account', 'project_id', v_project, 'client_email', v_email,
    'private_key_id', v_key_id, 'private_key', p_credentials ->> 'private_key'))::text;
  if v_row.secret_id is null then
    delete from vault.secrets s where s.name = 'push.firebase_service_account';
    v_row.secret_id := vault.create_secret(v_secret, 'push.firebase_service_account',
                                           'Kunci akun layanan Firebase untuk push notification');
  else
    perform vault.update_secret(v_row.secret_id, v_secret);
  end if;
  update private.push_credentials c
     set revision = c.revision + 1, secret_id = v_row.secret_id, project_id = v_project, client_email = v_email,
         key_id = v_key_id, updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('push.credentials_set', null, null, jsonb_strip_nulls(jsonb_build_object(
    'project_id', v_project, 'client_email', v_email, 'key_id', v_key_id,
    'previous_project_id', nullif(v_row.project_id, v_project),
    'replaced', v_row.project_id is not null)));
  return cs.push_credentials_view();
end;
$$;

create or replace function cs_api.push_remove_credentials()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_row private.push_credentials;
begin
  select * into v_row from private.push_credentials c where c.singleton for update;
  if v_row.secret_id is null then
    perform private.api_error(404, 'push_credentials_missing', 'Belum ada kredensial Firebase');
  end if;
  delete from vault.secrets s where s.id = v_row.secret_id;
  update private.push_credentials c
     set revision = c.revision + 1, secret_id = null, project_id = null, client_email = null, key_id = null,
         updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('push.credentials_removed', null, null, jsonb_strip_nulls(jsonb_build_object(
    'project_id', v_row.project_id, 'client_email', v_row.client_email, 'key_id', v_row.key_id)));
  return jsonb_build_object('removed', true);
end;
$$;

create or replace function public.push_credentials(p_revision bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row    private.push_credentials;
  v_secret jsonb;
begin
  select * into v_row from private.push_credentials c where c.singleton;
  if p_revision is not distinct from v_row.revision then
    return jsonb_build_object('revision', v_row.revision, 'unchanged', true);
  elsif v_row.secret_id is null then
    return jsonb_build_object('revision', v_row.revision, 'configured', false);
  end if;
  begin
    select d.decrypted_secret::jsonb into v_secret from vault.decrypted_secrets d where d.id = v_row.secret_id;
  exception when others then
    v_secret := null;
  end;
  if private.push_credentials_problem(v_secret) is not null then
    return jsonb_build_object('revision', v_row.revision, 'configured', true,
      'error', 'Kredensial Firebase tersimpan tidak bisa dibuka (kunci enkripsi database berubah). '
               'Unggah ulang file JSON di Pengaturan → Push notification.');
  end if;
  return jsonb_build_object('revision', v_row.revision, 'configured', true, 'credentials', v_secret);
end;
$$;

drop function public.push_heartbeat(text, text, boolean, text, text, timestamptz);

create or replace function public.push_heartbeat(p_instance text, p_version text, p_configured boolean,
                                                 p_project_id text default null, p_error text default null,
                                                 p_started_at timestamptz default null,
                                                 p_credentials_revision bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance notifier tidak valid');
  end if;
  insert into private.push_instances (instance_id, version, configured, project_id, error, started_at, seen_at,
                                      credentials_revision)
  values (p_instance, left(p_version, 40), coalesce(p_configured, false), left(nullif(p_project_id, ''), 100),
          left(nullif(btrim(coalesce(p_error, '')), ''), 500), coalesce(p_started_at, now()), now(),
          p_credentials_revision)
  on conflict (instance_id) do update
     set version = excluded.version, configured = excluded.configured, project_id = excluded.project_id,
         error = excluded.error, started_at = excluded.started_at, seen_at = now(),
         credentials_revision = excluded.credentials_revision;
  return jsonb_build_object(
    'queued', (select count(*) from private.push_queue q where q.status = 'queued' and q.expires_at > now()));
end;
$$;

create or replace function cs_api.push_status()
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
    'state', cs.push_state(),
    'credentials', cs.push_credentials_view(),
    'credentials_revision', (select c.revision from private.push_credentials c where c.singleton),
    'instances', coalesce((
      select jsonb_agg(jsonb_build_object(
               'instance', i.instance_id, 'version', i.version, 'configured', i.configured,
               'project_id', i.project_id, 'error', i.error, 'started_at', i.started_at, 'seen_at', i.seen_at,
               'credentials_revision', i.credentials_revision,
               'live', i.seen_at > now() - interval '90 seconds') order by i.seen_at desc)
      from private.push_instances i where i.seen_at > now() - interval '1 hour'), '[]'),
    'devices', (
      select jsonb_build_object(
               'total', count(*), 'users', count(distinct d.user_id),
               'android', count(*) filter (where d.platform = 'android'),
               'ios', count(*) filter (where d.platform = 'ios'),
               'web', count(*) filter (where d.platform = 'web'),
               'active_30d', count(*) filter (where d.last_seen_at > now() - interval '30 days'))
      from private.push_devices d),
    'queue', (
      select jsonb_build_object('queued', count(*), 'oldest_at', min(q.created_at))
      from private.push_queue q where q.status = 'queued' and q.expires_at > now()),
    'last_24h', (
      select jsonb_build_object(
               'sent', count(*) filter (where q.status = 'sent'),
               'failed', count(*) filter (where q.status = 'failed'),
               'invalid', count(*) filter (where q.status = 'invalid'),
               'expired', count(*) filter (where q.status in ('expired', 'cancelled')))
      from private.push_queue q where q.status <> 'queued' and q.finished_at > now() - interval '24 hours'),
    'last_sent_at', (select max(q.finished_at) from private.push_queue q where q.status = 'sent'),
    'last_error', (
      select jsonb_build_object('at', q.finished_at, 'kind', q.kind, 'error', q.error)
      from private.push_queue q
      where q.status = 'failed' and q.error is not null
      order by q.finished_at desc limit 1),
    'ttl_hours', private.setting_num('push.ttl_hours', 24),
    'max_attempts', private.setting_num('push.max_attempts', 6));
end;
$$;

revoke execute on function private.push_credentials_problem(jsonb) from public;
revoke execute on function cs.push_credentials_view() from public;
revoke execute on function cs_api.push_set_credentials(jsonb, boolean) from public;
revoke execute on function cs_api.push_remove_credentials() from public;
revoke execute on function public.push_credentials(bigint) from public, anon, authenticated;
revoke execute on function public.push_heartbeat(text, text, boolean, text, text, timestamptz, bigint)
  from public, anon, authenticated;

grant execute on function cs_api.push_set_credentials(jsonb, boolean) to authenticated;
grant execute on function cs_api.push_remove_credentials() to authenticated;
grant execute on function public.push_credentials(bigint) to service_role;
grant execute on function public.push_heartbeat(text, text, boolean, text, text, timestamptz, bigint) to service_role;
