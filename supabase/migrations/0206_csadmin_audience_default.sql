update cs.cs_settings
   set description = 'Audience (klaim aud) assertion integrasi csAdmin, harus sama dengan audience di config CS Admin service'
 where key = 'nasabah.csadmin_audience';

update cs.cs_settings
   set value = '"csAdmin"'
 where key = 'nasabah.csadmin_audience'
   and value = '"csAdminEL"'
   and not cs.nasabah_ready();

create or replace function cs.csadmin_audience()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(cs.setting('nasabah.csadmin_audience') #>> '{}', ''), 'csAdmin');
$$;

create or replace function cs_api.nasabah_save_integration(p_user_id uuid, p_url text, p_client_id text, p_audience text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url      text := btrim(coalesce(p_url, ''));
  v_client   text := btrim(coalesce(p_client_id, ''));
  v_audience text := coalesce(nullif(btrim(coalesce(p_audience, '')), ''), 'csAdmin');
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
  perform cs.set_setting('nasabah.csadmin_audience', '"csAdmin"', p_user_id);
  perform cs.set_setting('nasabah.csadmin_connected', '{}', p_user_id);
  perform cs.nasabah_integration_audit(p_user_id, 'setting.nasabah_integration_cleared', '{}');
  return cs_api.nasabah_integration();
end;
$$;
