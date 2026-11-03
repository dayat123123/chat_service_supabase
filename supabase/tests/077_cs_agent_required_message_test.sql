begin;
select plan(5);

create function tests.error_of_077(p_sql text)
returns text
language plpgsql
as $$
declare
  v_state text;
  v_message text;
  v_detail text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_message = message_text, v_detail = pg_exception_detail;
  return v_state || '|' || v_message || '|' || v_detail;
end;
$$;
grant execute on function tests.error_of_077(text) to authenticated;

select tests.create_user('arm_customer') as customer \gset
select tests.create_agent('Arum', '{cs_agent}', '{}') as agent \gset

select tests.authenticate_as(:'customer');
select is(tests.error_of_077('select cs.require_agent()'), 'PT403|agent_required|Butuh akun CS aktif',
  'Nasabah ditolak dengan pesan yang tidak lagi menyebut 2FA');
select is(tests.error_of_077('select cs_api.agent_me()'), 'PT403|agent_required|Butuh akun CS aktif',
  'RPC agen menolak nasabah dengan pesan yang sama');
reset role;

select tests.authenticate_as(:'agent');
select is(tests.error_of_077('select cs.require_agent()'), 'ok', 'Agen aktif tanpa 2FA lolos');
select is(tests.error_of_077($$select cs.require_agent('{cs_super_admin}')$$), 'PT403|role_forbidden|Peran Anda tidak cukup untuk aksi ini',
  'Peran kurang tetap ditolak role_forbidden');
reset role;

select is((select prosrc ~ '2FA' from pg_proc where oid = 'cs.require_agent(text[])'::regprocedure), false,
  'Definisi cs.require_agent tidak lagi menyebut 2FA');

select * from finish();
rollback;
