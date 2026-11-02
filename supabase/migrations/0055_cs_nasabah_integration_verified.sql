insert into cs.cs_settings (key, value, description) values
  ('nasabah.csadmin_connected', '{}',
   'Waktu integrasi API Nasabah terakhir disimpan setelah tes koneksi berhasil. Kosong berarti belum aktif')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes')
      or p_key like 'messages.%';
$$;

create or replace function cs.nasabah_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(cs.setting('nasabah.csadmin_url') #>> '{}', '') <> ''
     and coalesce(cs.setting('nasabah.csadmin_client_id') #>> '{}', '') <> ''
     and coalesce(cs.setting('nasabah.csadmin_connected') ? 'at', false);
$$;

create or replace function cs.nasabah_integration_audit(p_user_id uuid, p_action text, p_details jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into cs.cs_audit_log (actor_id, actor_type, actor_roles, action, details)
  select a.user_id, 'agent', a.roles, p_action, p_details || jsonb_build_object('via', 'nasabah-gateway')
  from cs.agents a
  where a.user_id = p_user_id;
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
    'configured', cs.nasabah_ready(),
    'connected_at', case when cs.nasabah_ready() then s.value ->> 'at' end,
    'connected_by', case when cs.nasabah_ready() then a.display_name end)
  from cs.cs_settings s
  left join cs.agents a on a.user_id = s.updated_by
  where s.key = 'nasabah.csadmin_connected';
$$;

create or replace function cs_api.nasabah_save_integration(p_user_id uuid, p_url text, p_client_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text := btrim(coalesce(p_url, ''));
  v_client text := btrim(coalesce(p_client_id, ''));
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
  perform cs.set_setting('nasabah.csadmin_url', to_jsonb(v_url), p_user_id);
  perform cs.set_setting('nasabah.csadmin_client_id', to_jsonb(v_client), p_user_id);
  perform cs.set_setting('nasabah.csadmin_connected', jsonb_build_object('at', now()), p_user_id);
  perform cs.nasabah_integration_audit(p_user_id, 'setting.nasabah_integration',
                                       jsonb_build_object('url', v_url, 'client_id', v_client));
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
  perform cs.set_setting('nasabah.csadmin_connected', '{}', p_user_id);
  perform cs.nasabah_integration_audit(p_user_id, 'setting.nasabah_integration_cleared', '{}');
  return cs_api.nasabah_integration();
end;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent();
  v_ready boolean := cs.nasabah_ready();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'nasabah_permissions', case when v_ready then to_jsonb(a.nasabah_permissions) else '[]'::jsonb end,
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes'),
        'nasabah_ready', v_ready))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

revoke execute on function cs.nasabah_ready() from public;
revoke execute on function cs.nasabah_integration_audit(uuid, text, jsonb) from public;
revoke execute on function cs_api.nasabah_save_integration(uuid, text, text) from public;
revoke execute on function cs_api.nasabah_clear_integration(uuid) from public;

grant execute on function cs_api.nasabah_save_integration(uuid, text, text) to service_role;
grant execute on function cs_api.nasabah_clear_integration(uuid) to service_role;
