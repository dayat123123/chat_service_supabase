insert into cs.cs_settings (key, value, description) values
  ('nasabah.csadmin_audience', '"csAdminEL"',
   'Audience (klaim aud) assertion integrasi csAdmin, sama dengan nama layanan csAdmin yang dipakai, mis. csAdminEL atau csAdminOD')
on conflict (key) do nothing;

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
  if p_key = 'nasabah.csadmin_audience' and v_text !~ '^[A-Za-z0-9._-]{1,50}$' then
    perform private.api_error(400, 'invalid_csadmin_audience', 'Audience 1–50 karakter: huruf, angka, titik, _, atau -');
  end if;
end;
$$;

create or replace function cs.csadmin_audience()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(cs.setting('nasabah.csadmin_audience') #>> '{}', ''), 'csAdminEL');
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
    'client_id', coalesce(cs.setting('nasabah.csadmin_client_id') #>> '{}', ''),
    'audience', cs.csadmin_audience(),
    'configured', cs.nasabah_ready(),
    'connected_at', case when cs.nasabah_ready() then s.value ->> 'at' end,
    'connected_by', case when cs.nasabah_ready() then a.display_name end)
  from cs.cs_settings s
  left join cs.agents a on a.user_id = s.updated_by
  where s.key = 'nasabah.csadmin_connected';
$$;

drop function cs_api.nasabah_save_integration(uuid, text, text);

create function cs_api.nasabah_save_integration(p_user_id uuid, p_url text, p_client_id text, p_audience text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url      text := btrim(coalesce(p_url, ''));
  v_client   text := btrim(coalesce(p_client_id, ''));
  v_audience text := coalesce(nullif(btrim(coalesce(p_audience, '')), ''), 'csAdminEL');
begin
  if not cs_api.nasabah_is_super_admin(p_user_id) then
    perform private.api_error(403, 'role_forbidden', 'Hanya Super Admin yang bisa mengatur integrasi API Nasabah');
  end if;
  if v_url = '' then
    perform private.api_error(400, 'invalid_csadmin_url', 'Alamat API Nasabah wajib diisi');
  end if;
  if v_client = '' then
    perform private.api_error(400, 'invalid_csadmin_client_id', 'Client id wajib diisi');
  end if;
  perform cs.check_integration_setting('nasabah.csadmin_url', to_jsonb(v_url));
  perform cs.check_integration_setting('nasabah.csadmin_client_id', to_jsonb(v_client));
  perform cs.check_integration_setting('nasabah.csadmin_audience', to_jsonb(v_audience));
  perform cs.set_setting('nasabah.csadmin_url', to_jsonb(v_url), p_user_id);
  perform cs.set_setting('nasabah.csadmin_client_id', to_jsonb(v_client), p_user_id);
  perform cs.set_setting('nasabah.csadmin_audience', to_jsonb(v_audience), p_user_id);
  perform cs.set_setting('nasabah.csadmin_connected', jsonb_build_object('at', now()), p_user_id);
  perform cs.nasabah_integration_audit(p_user_id, 'setting.nasabah_integration',
                                       jsonb_build_object('url', v_url, 'client_id', v_client, 'audience', v_audience));
  return cs_api.nasabah_integration();
end;
$$;

create or replace function cs_api.nasabah_clear_integration(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not cs_api.nasabah_is_super_admin(p_user_id) then
    perform private.api_error(403, 'role_forbidden', 'Hanya Super Admin yang bisa mengatur integrasi API Nasabah');
  end if;
  perform cs.set_setting('nasabah.csadmin_url', '""', p_user_id);
  perform cs.set_setting('nasabah.csadmin_client_id', '""', p_user_id);
  perform cs.set_setting('nasabah.csadmin_audience', '"csAdminEL"', p_user_id);
  perform cs.set_setting('nasabah.csadmin_connected', '{}', p_user_id);
  perform cs.nasabah_integration_audit(p_user_id, 'setting.nasabah_integration_cleared', '{}');
  return cs_api.nasabah_integration();
end;
$$;

revoke execute on function cs.csadmin_audience() from public;
revoke execute on function cs_api.nasabah_save_integration(uuid, text, text, text) from public;
grant execute on function cs_api.nasabah_save_integration(uuid, text, text, text) to service_role;
