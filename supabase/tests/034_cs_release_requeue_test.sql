begin;
select plan(8);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
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

create function pg_temp.release(p_agent uuid, p_ticket uuid)
returns void
language plpgsql
as $$
begin
  perform tests.authenticate_agent(p_agent);
  perform cs_api.release_ticket(p_ticket, 'Perlu ditangani CS lain');
  reset role;
  perform pg_temp.commit_point();
end;
$$;

select tests.create_user('rq_budi') as budi \gset
select tests.create_user('rq_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 3}', 'general', 5) as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}', 'general', 5) as dimas \gset
select tests.agent_online(:'rina');
select tests.agent_online(:'dimas');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'claimed/Rina', 'Tiket akun ditugaskan ke CS yang punya keahlian akun');

select pg_temp.release(:'rina', :'t1');
select is(pg_temp.owner(:'t1'), 'claimed/Dimas', 'Tiket yang dilepas diberikan ke CS Online lain, bukan kembali ke CS yang melepas');

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('account') ->> 'id' as t2 \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t2'), 'claimed/Rina', 'CS yang melepas tetap menerima tiket baru lainnya');

select pg_temp.release(:'dimas', :'t1');
select is(pg_temp.owner(:'t1'), 'claimed/Rina', 'Hanya CS yang terakhir melepas yang dilewati');

select tests.authenticate_agent(:'dimas');
select cs_api.agent_set_status('offline') as dimas_offline \gset
reset role;
select pg_temp.release(:'rina', :'t1');
select is(pg_temp.owner(:'t1'), 'open/-', 'Tanpa CS Online lain, tiket yang dilepas menunggu di antrean');

select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'status' as reclaimed \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'claimed/Rina', 'CS yang melepas tetap bisa mengambil kembali tiketnya dari antrean');

select pg_temp.release(:'rina', :'t1');
select is(pg_temp.owner(:'t1'), 'open/-', 'Tiket yang dilepas lagi kembali menunggu di antrean');

select tests.authenticate_agent(:'dimas');
select cs_api.agent_set_status('online') as dimas_online \gset
reset role;
select pg_temp.commit_point();
select is(pg_temp.owner(:'t1'), 'claimed/Dimas', 'Begitu CS lain Online, tiket yang dilepas langsung ditugaskan kepadanya');

select * from finish();
rollback;
