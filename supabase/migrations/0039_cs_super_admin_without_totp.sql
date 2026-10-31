alter table cs.agents drop constraint agents_roles_check;

update cs.agents
   set roles = array(select distinct case when r in ('cs_supervisor', 'cs_admin') then 'cs_super_admin' else r end
                     from unnest(roles) as r order by 1)
 where roles && '{cs_supervisor,cs_admin}';

alter table cs.agents add constraint agents_roles_check
  check (cardinality(roles) > 0 and roles <@ array['cs_agent', 'cs_super_admin', 'compliance']);

do $$
declare
  r     record;
  v_def text;
begin
  for r in
    select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('cs', 'cs_api') and p.prosrc ~ 'cs_supervisor|cs_admin'
  loop
    v_def := pg_get_functiondef(r.oid);
    v_def := replace(v_def, '{cs_agent,cs_supervisor,cs_admin,compliance}', '{cs_agent,cs_super_admin,compliance}');
    v_def := replace(v_def, 'cs_agent, cs_supervisor, cs_admin, atau compliance', 'cs_agent, cs_super_admin, atau compliance');
    v_def := replace(v_def, '{cs_supervisor,cs_admin}', '{cs_super_admin}');
    v_def := replace(v_def, 'cs_supervisor', 'cs_super_admin');
    v_def := replace(v_def, 'cs_admin', 'cs_super_admin');
    execute v_def;
  end loop;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname in ('cs', 'cs_api') and p.prosrc ~ 'cs_supervisor|''cs_admin''|[{,]cs_admin[,}]') then
    raise exception 'Masih ada fungsi CS yang memakai peran lama';
  end if;
end;
$$;

alter policy cs_settings_history_select on cs.cs_settings_history
  using ((select cs.has_role('{cs_super_admin,compliance}')));

alter policy cs_audit_log_select on cs.cs_audit_log
  using ((select cs.has_role('{cs_super_admin,compliance}')));

alter policy ticket_transfers_select on cs.ticket_transfers
  using (from_agent_id = (select cs.current_agent_id())
         or to_agent_id = (select cs.current_agent_id())
         or (select cs.has_role('{cs_super_admin}')));

alter policy quick_replies_select on cs.quick_replies
  using ((select cs.current_agent_id()) is not null
         and (scope = 'global'
              or (scope = 'personal' and owner_id = (select cs.current_agent_id()))
              or (scope = 'team' and ((select cs.has_role('{cs_super_admin}'))
                                      or team_id = (select a.team_id from cs.agents a
                                                    where a.user_id = (select cs.current_agent_id()))))));

create or replace function cs.current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.user_id
  from cs.agents a
  where a.user_id = auth.uid()
    and a.disabled_at is null
    and coalesce(auth.role(), '') = 'authenticated';
$$;

create function cs_api.admin_reset_password(p_agent_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
  a    cs.agents;
begin
  select * into a from cs.agents where user_id = p_agent_id;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  if a.disabled_at is not null then
    perform private.api_error(409, 'agent_disabled', 'Aktifkan akun dulu sebelum mereset password');
  end if;
  perform cs.audit('agent.reset_password', null, null, jsonb_build_object('agent', p_agent_id, 'by', v_me));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

revoke execute on function cs_api.admin_reset_password(uuid) from public;
grant execute on function cs_api.admin_reset_password(uuid) to authenticated;
