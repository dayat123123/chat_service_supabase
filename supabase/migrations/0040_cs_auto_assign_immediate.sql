create or replace function cs.assign_when_auto()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_role   text := current_setting('request.jwt.claim.role', true);
begin
  if cs.setting('assignment.mode') #>> '{}' = 'auto_assign' and cs.is_open(now()) then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claim.role', '', true);
    perform cs.auto_assign_open();
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
  end if;
  return null;
end;
$$;

revoke execute on function cs.assign_when_auto() from public;

create constraint trigger tickets_assign_when_open
after insert or update of status on cs.tickets
deferrable initially deferred
for each row
when (new.status = 'open')
execute function cs.assign_when_auto();

create constraint trigger agent_status_assign_when_available
after update of status, active_tickets on cs.agent_status
deferrable initially deferred
for each row
when (new.status = 'online' and (old.status is distinct from new.status or new.active_tickets < old.active_tickets))
execute function cs.assign_when_auto();

create constraint trigger cs_settings_assign_when_auto
after update of value on cs.cs_settings
deferrable initially deferred
for each row
when (new.key = 'assignment.mode' and new.value = '"auto_assign"'::jsonb and old.value is distinct from new.value)
execute function cs.assign_when_auto();
