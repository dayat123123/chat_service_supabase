alter table cs.agents
  add column nasabah_permissions text[] not null default '{}',
  add constraint agents_nasabah_permissions_check check (
    nasabah_permissions <@ array['online_user.view', 'online_user.manage', 'online_user.demo',
                                 'online_user.approve', 'opening_account.send']);

create or replace function cs.nasabah_permission_codes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['online_user.view', 'online_user.manage', 'online_user.demo', 'online_user.approve', 'opening_account.send'];
$$;

create or replace function cs.agent_admin_view(p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.user_id,
    'agent_code', a.agent_code,
    'display_name', a.display_name,
    'email', u.email,
    'roles', to_jsonb(a.roles),
    'team', tm.code,
    'max_active_tickets', a.max_active_tickets,
    'disabled_at', a.disabled_at,
    'status', coalesce(st.status, 'offline'),
    'active_tickets', cs.active_ticket_count(a.user_id),
    'totp', exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'),
    'nasabah_permissions', to_jsonb(a.nasabah_permissions),
    'created_at', a.created_at)
  from cs.agents a
  left join cs.agent_status st on st.agent_id = a.user_id
  left join cs.teams tm on tm.id = a.team_id
  left join auth.users u on u.id = a.user_id
  where a.user_id = p_agent;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
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
      'nasabah_permissions', to_jsonb(a.nasabah_permissions),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes')))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.admin_set_nasabah_permissions(p_agent_id uuid, p_permissions text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_perms text[] := coalesce((select array_agg(distinct p order by p) from unnest(coalesce(p_permissions, '{}')) p), '{}');
begin
  if not (v_perms <@ cs.nasabah_permission_codes()) then
    perform private.api_error(400, 'invalid_permission', 'Permission Nasabah tidak dikenal');
  end if;
  update cs.agents set nasabah_permissions = v_perms where user_id = p_agent_id;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  perform cs.audit('agent.nasabah_permissions', null, null,
                   jsonb_build_object('agent', p_agent_id, 'permissions', to_jsonb(v_perms)));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

create or replace function cs_api.nasabah_access(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('agent_id', a.user_id, 'agent_code', a.agent_code, 'display_name', a.display_name,
                            'permissions', to_jsonb(a.nasabah_permissions))
  from cs.agents a
  where a.user_id = p_user_id and a.disabled_at is null and cardinality(a.nasabah_permissions) > 0;
$$;

create or replace function cs_api.nasabah_audit(p_user_id uuid, p_action text, p_details jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_action is null or p_action !~ '^nasabah\.[a-z_]+(\.[a-z_]+)*$' or char_length(p_action) > 80 then
    perform private.api_error(400, 'invalid_action', 'Aksi audit Nasabah tidak valid');
  end if;
  if p_details is not null and (jsonb_typeof(p_details) <> 'object' or octet_length(p_details::text) > 4096) then
    perform private.api_error(400, 'invalid_details', 'Detail audit Nasabah harus objek maksimal 4 KB');
  end if;
  insert into cs.cs_audit_log (actor_id, actor_type, actor_roles, action, details)
  select a.user_id, 'agent', a.roles, p_action,
         coalesce(p_details, '{}') || jsonb_build_object('via', 'nasabah-gateway')
  from cs.agents a
  where a.user_id = p_user_id;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
end;
$$;

revoke execute on function cs.nasabah_permission_codes() from public;
revoke execute on function cs_api.admin_set_nasabah_permissions(uuid, text[]) from public;
revoke execute on function cs_api.nasabah_access(uuid) from public;
revoke execute on function cs_api.nasabah_audit(uuid, text, jsonb) from public;

grant execute on function cs_api.admin_set_nasabah_permissions(uuid, text[]) to authenticated;
grant execute on function cs_api.nasabah_access(uuid) to service_role;
grant execute on function cs_api.nasabah_audit(uuid, text, jsonb) to service_role;
