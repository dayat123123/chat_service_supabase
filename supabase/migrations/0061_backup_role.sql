-- olt:run-as=supabase_admin
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'olt_backup') then
    create role olt_backup with nologin replication noinherit connection limit 6;
  end if;
end;
$$;

alter role olt_backup set statement_timeout = 0;
alter role olt_backup set idle_in_transaction_session_timeout = 0;
revoke all on database postgres from olt_backup;
