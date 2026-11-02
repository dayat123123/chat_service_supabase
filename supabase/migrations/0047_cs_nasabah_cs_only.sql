create or replace function cs.nasabah_permission_codes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['online_user.view', 'online_user.manage', 'online_user.demo', 'online_user.approve',
               'online_user.approve_own', 'online_user.status', 'opening_account.send'];
$$;

alter table cs.agents drop constraint agents_nasabah_permissions_check;

update cs.agents
   set nasabah_permissions = coalesce((select array_agg(p order by p)
                                         from unnest(nasabah_permissions) p
                                        where p = any (cs.nasabah_permission_codes())), '{}')
 where not (nasabah_permissions <@ cs.nasabah_permission_codes());

update cs.agents
   set nasabah_permissions = '{}'
 where cardinality(nasabah_permissions) > 0 and not ('cs_agent' = any (roles));

alter table cs.agents add constraint agents_nasabah_permissions_check check (
  nasabah_permissions <@ array['online_user.view', 'online_user.manage', 'online_user.demo', 'online_user.approve',
                               'online_user.approve_own', 'online_user.status', 'opening_account.send']
  and (cardinality(nasabah_permissions) = 0 or 'cs_agent' = any (roles)));

create or replace function cs.agents_nasabah_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not ('cs_agent' = any (new.roles)) then
    new.nasabah_permissions := '{}';
  end if;
  return new;
end;
$$;

create trigger agents_nasabah_scope
  before insert or update of roles, nasabah_permissions on cs.agents
  for each row execute function cs.agents_nasabah_scope();

create or replace function cs_api.admin_set_nasabah_permissions(p_agent_id uuid, p_permissions text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_perms text[] := coalesce((select array_agg(distinct p order by p) from unnest(coalesce(p_permissions, '{}')) p), '{}');
  v_roles text[];
begin
  if not (v_perms <@ cs.nasabah_permission_codes()) then
    perform private.api_error(400, 'invalid_permission', 'Permission Nasabah tidak dikenal');
  end if;
  select roles into v_roles from cs.agents where user_id = p_agent_id;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  if cardinality(v_perms) > 0 and not ('cs_agent' = any (v_roles)) then
    perform private.api_error(400, 'not_cs_agent', 'Akses Nasabah hanya untuk akun yang berperan CS');
  end if;
  update cs.agents set nasabah_permissions = v_perms where user_id = p_agent_id;
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
  where a.user_id = p_user_id and a.disabled_at is null and 'cs_agent' = any (a.roles)
    and cardinality(a.nasabah_permissions) > 0;
$$;

revoke execute on function cs.agents_nasabah_scope() from public;
revoke execute on function cs_api.admin_set_nasabah_permissions(uuid, text[]) from public;
revoke execute on function cs_api.nasabah_access(uuid) from public;
grant execute on function cs_api.admin_set_nasabah_permissions(uuid, text[]) to authenticated;
grant execute on function cs_api.nasabah_access(uuid) to service_role;
