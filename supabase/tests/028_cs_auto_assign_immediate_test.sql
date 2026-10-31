begin;
select plan(11);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

create function pg_temp.commit_point()
returns void
language plpgsql
as $$
begin
  set constraints all immediate;
  set constraints all deferred;
end;
$$;

create function pg_temp.owner(p_ticket uuid)
returns text
language sql
as $$
  select t.status || '/' || coalesce(cs.agent_name(t.owner_agent_id), '-') from cs.tickets t where t.id = p_ticket;
$$;

create function pg_temp.assigned_by(p_ticket uuid)
returns text
language sql
as $$
  select string_agg(e.actor_type || ':' || coalesce(e.actor_id::text, '-'), ',')
  from cs.session_events e where e.session_id = p_ticket and e.type = 'assigned';
$$;

select tests.create_user('aa_budi') as budi \gset
select tests.create_user('aa_sari') as sari \gset
select tests.create_user('aa_tono') as tono \gset
select tests.create_user('aa_andi') as andi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}', 'general', 1) as rina \gset

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as online1 \gset
select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'open/-', 'Mode claim: tiket baru menunggu diambil CS');

select cs.set_setting('assignment.mode', '"auto_assign"', null) as auto_mode \gset
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'claimed/Rina', 'Mengubah mode ke otomatis langsung membagikan tiket yang menunggu');

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('account') ->> 'id' as t2 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t2'), 'open/-', 'Semua CS penuh: tiket tetap di antrean');

select tests.authenticate_agent(:'rina');
select cs_api.resolve_ticket(:'t1', 'answered', 'Pertanyaan akun sudah dijawab') ->> 'status' as r1 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t2'), 'claimed/Rina', 'Slot CS kosong: tiket antrean berikutnya langsung ditugaskan');
select is(pg_temp.assigned_by(:'t2'), 'system:-', 'Penugasan tercatat oleh sistem, bukan CS yang menyelesaikan tiket');

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('offline') as offline1 \gset
select cs_api.resolve_ticket(:'t2', 'answered', 'Pertanyaan dana sudah dijawab') ->> 'status' as r2 \gset
select tests.authenticate_as(:'tono');
select cs_api.open_ticket('account') ->> 'id' as t3 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t3'), 'open/-', 'CS offline tidak menerima tiket');

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as online2 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t3'), 'claimed/Rina', 'CS kembali Online: tiket antrean langsung ditugaskan');

select tests.authenticate_agent(:'rina');
select cs_api.resolve_ticket(:'t3', 'answered', 'Pertanyaan ketiga sudah dijawab') ->> 'status' as r3 \gset
reset role;
select pg_temp.commit_point();
select tests.authenticate_as(:'andi');
select cs_api.open_ticket('account') ->> 'id' as t4 \gset
select pg_temp.commit_point();
select is(auth.uid(), :'andi'::uuid, 'Identitas pemanggil dipulihkan setelah penugasan otomatis');
reset role;
select is(pg_temp.owner(:'t4'), 'claimed/Rina', 'Mode otomatis: tiket baru langsung ditugaskan tanpa menunggu sweep');
select is(pg_temp.assigned_by(:'t4'), 'system:-', 'Penugasan dari transaksi nasabah tetap tercatat oleh sistem');

select cs.set_setting('assignment.mode', '"claim"', null) as claim_again \gset
select tests.authenticate_agent(:'rina');
select cs_api.release_ticket(:'t4', 'Perlu dicek tim lain') ->> 'status' as released \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t4'), 'open/-', 'Mode claim: tiket yang dilepas kembali menunggu di antrean');

select * from finish();
rollback;
