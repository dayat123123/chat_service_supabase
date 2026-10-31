begin;
select plan(8);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": null, "2": null, "3": null, "4": null, "5": null, "6": null, "7": null}', null) as closed_hours \gset
select cs.set_setting('assignment.mode', '"auto_assign"', null) as auto_mode \gset

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

create function pg_temp.out_of_hours_notice(p_ticket uuid)
returns boolean
language sql
as $$
  select exists (select 1 from public.messages m
                 where m.session_id = p_ticket and m.kind = 'system' and m.body like '%di luar jam layanan%');
$$;

create function pg_temp.heartbeat(p_agent uuid, p_seconds integer)
returns void
language sql
as $$
  update cs.agent_status set last_heartbeat_at = now() - make_interval(secs => p_seconds) where agent_id = p_agent;
$$;

select tests.create_user('ar_budi') as budi \gset
select tests.create_user('ar_sari') as sari \gset
select tests.create_user('ar_tono') as tono \gset
select tests.create_user('ar_andi') as andi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}', 'general', 5) as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1, "account": 2}', 'general', 5) as dimas \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'open/-', 'Di luar jam layanan tanpa CS Online: tiket menunggu di antrean');
select ok(pg_temp.out_of_hours_notice(:'t1'), 'Tanpa CS Online, nasabah diberi tahu jam layanan berikutnya');

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as rina_online \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'claimed/Rina', 'CS yang Online di luar jam layanan langsung mendapat tiket yang menunggu');

select tests.authenticate_agent(:'dimas');
select cs_api.agent_set_status('online') as dimas_online \gset
reset role;
select tests.authenticate_as(:'sari');
select cs_api.open_ticket('account') ->> 'id' as t2 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t2'), 'claimed/Dimas', 'Dua CS Online di luar jam layanan: tiket baru ke CS yang paling senggang');
select ok(not pg_temp.out_of_hours_notice(:'t2'), 'Ada CS Online: nasabah tidak diberi pesan di luar jam layanan');

select pg_temp.heartbeat(:'rina', 60);
select pg_temp.heartbeat(:'dimas', 600);
select tests.authenticate_as(:'tono');
select cs_api.open_ticket('account') ->> 'id' as t3 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t3'), 'claimed/Rina',
  'Heartbeat tab latar belakang yang tertunda 60 detik tetap dianggap terhubung, heartbeat 10 menit tidak');

select pg_temp.heartbeat(:'rina', 600);
select tests.authenticate_as(:'andi');
select cs_api.open_ticket('account') ->> 'id' as t4 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t4'), 'open/-', 'CS Online tanpa heartbeat lama tidak diberi tiket');

select pg_temp.heartbeat(:'dimas', 0);
select is((cs.run_sweep() ->> 'tickets_assigned')::integer, 1, 'cs-sweep di luar jam layanan membagikan tiket ke CS yang tersambung lagi');

select * from finish();
rollback;
