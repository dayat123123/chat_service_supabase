begin;
select plan(6);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'maya';
select tests.create_user('pg_budi') as budi \gset
update public.profiles set trust_level = 2 where id = :'budi';

select tests.authenticate_as(:'budi');
select join_stock_room('PGTB') as room \gset
select send_message(:'room', 'Pesan satu', 'c7100000-0000-4000-8000-000000000001');
select send_message(:'room', 'Pesan dua', 'c7100000-0000-4000-8000-000000000002');
select send_message(:'room', 'Pesan tiga', 'c7100000-0000-4000-8000-000000000003');
reset role;
update public.messages set created_at = '2026-11-03 09:00:00+07' where room_id = :'room';

select tests.authenticate_agent(:'maya');
select cs_api.community_room_messages('PGTB', 2) as page1 \gset
select is(jsonb_array_length(:'page1'::jsonb -> 'items'), 2, 'Halaman pertama berisi dua pesan');
select cs_api.community_room_messages('PGTB', 2, '2026-11-03 09:00:00+07',
  (:'page1'::jsonb -> 'items' -> 1 ->> 'id')::uuid) as page2 \gset
select is(jsonb_array_length(:'page2'::jsonb -> 'items'), 1,
  'Halaman berikutnya tetap memuat pesan dengan waktu yang sama');
select is((select count(distinct v) from (
             select jsonb_array_elements(:'page1'::jsonb -> 'items') ->> 'id' as v
             union all
             select jsonb_array_elements(:'page2'::jsonb -> 'items') ->> 'id') u)::integer, 3,
  'Tidak ada pesan yang terlewat atau terulang antarhalaman');
reset role;

insert into private.integration_keys (name, prefix, key_hash, scopes, created_by)
values ('Kunci uji WIB', 'pgwib001', repeat('a', 64), '{notify}', :'sinta')
returning id as key_id \gset
insert into private.integration_daily (key_id, day, received)
values (:'key_id', private.integration_day(), 5),
       (:'key_id', private.integration_day() - 29, 7),
       (:'key_id', private.integration_day() - 30, 9);

select is(private.integration_day(), (now() at time zone 'Asia/Jakarta')::date, 'Hari statistik mengikuti WIB');

select tests.authenticate_agent(:'sinta');
select cs_api.integration_stats_daily(30, :'key_id') as stats \gset
select is(jsonb_array_length(:'stats'::jsonb -> 0 -> 'days'), 2, 'Rentang 30 hari dihitung dari tanggal WIB hari ini');
select is((:'stats'::jsonb -> 0 -> 'days' -> -1 ->> 'day')::date, (now() at time zone 'Asia/Jakarta')::date,
  'Hari terakhir di statistik adalah tanggal WIB');
reset role;

select * from finish();
rollback;
