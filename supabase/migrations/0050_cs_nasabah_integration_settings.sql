insert into cs.cs_settings (key, value, description) values
  ('nasabah.csadmin_url', '""',
   'Alamat csAdmin untuk menu Akun Nasabah, termasuk prefix path, mis. http://192.168.10.10:8080. Kosong berarti gateway memakai CSADMIN_URL di docker/.env'),
  ('nasabah.csadmin_client_id', '""',
   'Client id integrasi csAdmin, harus sama dengan client_id di blok integration csAdminEL.cfg. Kosong berarti CSADMIN_CLIENT_ID di docker/.env atau web-cs')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes',
                   'nasabah.csadmin_url', 'nasabah.csadmin_client_id')
      or p_key like 'messages.%';
$$;

create or replace function cs.check_integration_setting(p_key text, p_value jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := p_value #>> '{}';
begin
  if jsonb_typeof(p_value) is distinct from 'string' then
    perform private.api_error(400, 'invalid_setting', 'Nilai integrasi csAdmin harus berupa teks');
  end if;
  if v_text = '' then
    return;
  end if;
  if p_key = 'nasabah.csadmin_url'
     and (char_length(v_text) > 200
          or v_text !~ '^https?://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[A-Za-z0-9._~-]+)*/?$') then
    perform private.api_error(400, 'invalid_csadmin_url',
      'Alamat csAdmin harus diawali http:// atau https://, berisi host dan port, tanpa spasi, login, atau query');
  end if;
  if p_key = 'nasabah.csadmin_client_id' and v_text !~ '^[A-Za-z0-9._-]{1,50}$' then
    perform private.api_error(400, 'invalid_csadmin_client_id', 'Client id 1–50 karakter: huruf, angka, titik, _, atau -');
  end if;
end;
$$;

create or replace function cs_api.admin_set_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old jsonb := (select s.value from cs.cs_settings s where s.key = p_key);
begin
  if v_old is null or not cs.admin_editable(p_key) then
    perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end if;
  if p_key like 'nasabah.%' then
    perform cs.check_integration_setting(p_key, p_value);
  else
    perform cs.check_setting_value(p_key, p_value, v_old);
  end if;
  perform cs.set_setting(p_key, p_value, v_me);
  perform cs.audit('setting.update', null, null, jsonb_build_object('key', p_key));
  return (select jsonb_build_object('key', s.key, 'value', s.value, 'version', s.version, 'updated_at', s.updated_at)
          from cs.cs_settings s where s.key = p_key);
end;
$$;

create or replace function cs_api.nasabah_integration()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'url', coalesce(cs.setting('nasabah.csadmin_url') #>> '{}', ''),
    'client_id', coalesce(cs.setting('nasabah.csadmin_client_id') #>> '{}', ''));
$$;

create or replace function cs_api.nasabah_is_super_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.agents a
                 where a.user_id = p_user_id
                   and a.disabled_at is null
                   and 'cs_super_admin' = any (a.roles));
$$;

revoke execute on function cs.check_integration_setting(text, jsonb) from public;
revoke execute on function cs_api.nasabah_integration() from public;
revoke execute on function cs_api.nasabah_is_super_admin(uuid) from public;

grant execute on function cs_api.nasabah_integration() to service_role;
grant execute on function cs_api.nasabah_is_super_admin(uuid) to service_role;
