create or replace function cs.require_agent(p_roles text[] default null)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := cs.current_agent_id();
begin
  if v_id is null then
    perform private.api_error(403, 'agent_required', 'Butuh akun CS aktif');
  end if;
  if p_roles is not null and not cs.has_role(p_roles) then
    perform private.api_error(403, 'role_forbidden', 'Peran Anda tidak cukup untuk aksi ini');
  end if;
  return v_id;
end;
$$;
