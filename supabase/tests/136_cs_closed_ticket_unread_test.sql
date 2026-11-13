begin;
select plan(23);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as hours \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

select tests.create_user('cu_budi') as budi \gset
select tests.create_user('cu_sari') as sari \gset
select tests.create_user('cu_dodi') as dodi \gset
select tests.create_user('cu_fani') as fani \gset
select tests.create_user('cu_eko') as eko \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 3, "account": 3}') as rina \gset
select tests.agent_online(:'rina');

create function pg_temp.unread() returns integer language sql as $$
  select (cs_api.support_home() ->> 'unread_count')::integer
$$;

create function pg_temp.sent_earlier(p_room uuid, p_customer uuid) returns void language sql as $$
  update public.messages set created_at = created_at - interval '1 hour' where room_id = p_room;
  update public.chat_members set last_read_at = now() - interval '2 hours' where room_id = p_room and user_id = p_customer;
$$;

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room_b \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'status' as c1 \gset
select cs_api.agent_send_message(:'t1', 'Sudah kami bantu') ->> 'status' as m1 \gset
select cs_api.resolve_ticket(:'t1', 'answered', 'Selesai') ->> 'status' as r1 \gset
select tests.authenticate_as(:'budi');
select cs_api.rate_ticket(:'t1', 5) ->> 'status' as rated \gset
reset role;
select pg_temp.sent_earlier(:'room_b', :'budi');

select is(:'rated'::text, 'closed', 'Tiket ditutup setelah dinilai nasabah');
select ok(exists (select 1 from public.chat_members where room_id = :'room_b' and user_id = :'budi'),
  'Nasabah tetap anggota room CS setelah tiket ditutup');
select ok(not exists (select 1 from public.chat_members where room_id = :'room_b' and user_id = :'rina'),
  'CS keluar dari room setelah tiket ditutup');

select tests.authenticate_as(:'eko');
select throws_ok(format('select cs_api.mark_read(%L)', :'room_b'), 'PT404', 'not_member',
  'Nasabah lain tidak bisa menandai room CS orang lain');
select tests.authenticate_as(:'budi');
select ok(pg_temp.unread() > 0, 'Badge CS menghitung pesan yang belum dibaca di tiket tertutup');
select is(cs_api.support_home() ->> 'active', 'false', 'Tiket terakhir sudah tidak aktif');
select lives_ok(format('select cs_api.mark_read(%L)', :'room_b'), 'Nasabah menandai room CS dibaca walau tiket tertutup');
select is(pg_temp.unread(), 0, 'Badge CS hilang setelah room dibaca');

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('other') as j \gset
select (:'j'::jsonb ->> 'id') as t2, (:'j'::jsonb ->> 'room_id') as room_s \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t2') ->> 'status' as c2 \gset
select cs_api.agent_send_message(:'t2', 'Ada lagi yang bisa dibantu?') ->> 'status' as m2 \gset
select cs_api.resolve_ticket(:'t2', 'answered', 'Dijawab') ->> 'status' as r2 \gset
reset role;
update cs.tickets set resolved_at = now() - interval '31 days' where id = :'t2';
select cs.run_sweep() ->> 'tickets_closed' as swept \gset
select pg_temp.sent_earlier(:'room_s', :'sari');
select is((select status || '/' || close_reason from cs.tickets where id = :'t2'), 'closed/reopen_window_passed',
  'Sweep menutup tiket otomatis');
select ok(exists (select 1 from public.chat_members where room_id = :'room_s' and user_id = :'sari'),
  'Nasabah tetap anggota room CS setelah tutup otomatis');
select tests.authenticate_as(:'sari');
select ok(pg_temp.unread() > 0, 'Badge CS menghitung pesan di tiket yang ditutup otomatis');
select lives_ok(format('select cs_api.mark_read(%L)', :'room_s'), 'Room CS bisa ditandai dibaca setelah tutup otomatis');
select is(pg_temp.unread(), 0, 'Badge CS hilang setelah tutup otomatis lalu dibaca');

select tests.authenticate_as(:'dodi');
select cs_api.open_ticket('other') as j \gset
select (:'j'::jsonb ->> 'id') as t3, (:'j'::jsonb ->> 'room_id') as room_d \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t3') ->> 'status' as c3 \gset
select cs_api.agent_send_message(:'t3', 'Halo, saya bantu') ->> 'status' as m3 \gset
select tests.authenticate_as(:'dodi');
select cs_api.close_ticket(:'t3') ->> 'status' as closed3 \gset
reset role;
select pg_temp.sent_earlier(:'room_d', :'dodi');
select is(:'closed3'::text, 'closed', 'Nasabah menutup tiketnya sendiri');
select tests.authenticate_as(:'dodi');
select lives_ok(format('select cs_api.mark_read(%L)', :'room_d'), 'Room CS bisa ditandai dibaca setelah nasabah menutup tiket');
select is(pg_temp.unread(), 0, 'Badge CS hilang setelah nasabah menutup tiket lalu membaca');

select tests.authenticate_as(:'fani');
select cs_api.open_ticket('other') as j \gset
select (:'j'::jsonb ->> 'id') as t4, (:'j'::jsonb ->> 'room_id') as room_f \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t4') ->> 'status' as c4 \gset
reset role;
update public.chat_members set last_read_at = clock_timestamp() where room_id = :'room_f' and user_id = :'fani';
select last_read_at as fani_read from public.chat_members where room_id = :'room_f' and user_id = :'fani' \gset

select tests.authenticate_as(:'fani');
select is(pg_temp.unread(), 0, 'Belum ada pesan baru');
select tests.authenticate_agent(:'rina');
select cs_api.agent_send_message(:'t4', 'Pesan normal dari CS') ->> 'status' as m4 \gset
select tests.authenticate_as(:'fani');
select is(pg_temp.unread(), 1, 'Pesan normal dari CS menaikkan badge');

select tests.authenticate_agent(:'rina');
select cs_api.agent_send_message(:'t4', 'Pesan yang disembunyikan') ->> 'status' as m5 \gset
reset role;
update public.messages set moderation_status = 'hidden' where room_id = :'room_f' and body = 'Pesan yang disembunyikan';
select tests.authenticate_as(:'fani');
select is((select count(*)::integer from cs_api.get_messages(:'room_f') where body = 'Pesan yang disembunyikan'), 0,
  'Pesan tersembunyi tidak tampil di percakapan nasabah');
select is(pg_temp.unread(), 1, 'Pesan tersembunyi tidak menaikkan badge');

select is((select body from cs_api.send_message(:'room_f', 'Terima kasih')), 'Terima kasih', 'Nasabah membalas');
reset role;
update public.chat_members set last_read_at = :'fani_read' where room_id = :'room_f' and user_id = :'fani';
select tests.authenticate_as(:'fani');
select is(pg_temp.unread(), 1, 'Pesan nasabah sendiri tidak dihitung');

reset role;
insert into public.blocks (blocker_id, blocked_id) values (:'fani', :'rina');
select tests.authenticate_as(:'fani');
select is(pg_temp.unread(), (select count(*)::integer from cs_api.get_messages(:'room_f') m
                             where m.sender_id is distinct from :'fani' and m.created_at > :'fani_read'),
  'Badge sama dengan pesan dari pihak lain yang tampil di percakapan');

select * from finish();
rollback;
