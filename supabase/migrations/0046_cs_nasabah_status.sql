alter table cs.agents drop constraint agents_nasabah_permissions_check;

alter table cs.agents add constraint agents_nasabah_permissions_check check (
  nasabah_permissions <@ array['online_user.view', 'online_user.manage', 'online_user.demo', 'online_user.approve',
                               'online_user.status', 'opening_account.send', 'cs_user.manage', 'cs_log.view']);

create or replace function cs.nasabah_permission_codes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['online_user.view', 'online_user.manage', 'online_user.demo', 'online_user.approve',
               'online_user.status', 'opening_account.send', 'cs_user.manage', 'cs_log.view'];
$$;
