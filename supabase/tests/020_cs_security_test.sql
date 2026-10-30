begin;
select plan(67);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('sec_budi') as budi \gset
select tests.create_user('sec_sari') as sari \gset
select tests.create_user('sec_tono') as tono \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}') as dimas \gset
select tests.create_agent('Sinta', '{cs_supervisor}', '{"general": 3}') as sinta \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Adi', '{cs_admin}', '{}') as adi \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room \gset
select id as budi_msg from cs_api.send_message(:'room', 'Saya tidak bisa masuk, NIK saya 3174056708900001') \gset

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('funds') ->> 'id' as t0 \gset
select id as sari_old_msg from cs_api.send_message((cs_api.support_home() ->> 'room_id')::uuid, 'Pertanyaan lama soal RDN') \gset
select cs_api.close_ticket(:'t0') as c0 \gset
select cs_api.open_ticket('funds') as j \gset
select (:'j'::jsonb ->> 'id') as t2, (:'j'::jsonb ->> 'room_id') as room2 \gset
select id as sari_msg from cs_api.send_message(:'room2', 'Deposit saya belum masuk') \gset

select tests.authenticate_as(:'tono');
select cs_api.open_ticket('other') ->> 'id' as t3 \gset
select (cs_api.support_home() ->> 'room_id') as room3 \gset
select cs_api.close_ticket(:'t3') as c3 \gset

select tests.agent_online(:'rina');
select tests.agent_online(:'dimas');
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'id' as claimed \gset
select cs_api.add_note('Catatan rahasia: nasabah terindikasi lupa password', :'t1') as n1 \gset
select cs_api.add_note('Catatan rahasia nasabah: lebih nyaman dihubungi sore hari', null, :'budi') as n2 \gset
select cs_api.agent_send_message(:'t1', 'Baik, saya bantu cek akun Anda') as m1 \gset

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from cs.agent_notes), 0, 'Nasabah tidak bisa membaca catatan internal (RLS)');
select throws_ok(format($$select cs_api.notes(%L)$$, :'budi'), 'PT403', 'agent_required',
  'Nasabah tidak bisa memanggil API catatan internal');
select is((select count(*)::integer from public.messages where body ilike '%catatan rahasia%'), 0,
  'Catatan internal tidak pernah masuk tabel pesan');
select is((select count(*)::integer from cs_api.get_messages(:'room'::uuid) m where m.body ilike '%catatan rahasia%'), 0,
  'Catatan internal tidak muncul di riwayat chat nasabah');
select is((select count(*)::integer from cs.tickets) + (select count(*)::integer from cs.session_events)
          + (select count(*)::integer from cs.cs_audit_log) + (select count(*)::integer from cs.ticket_transfers)
          + (select count(*)::integer from cs.agents) + (select count(*)::integer from cs.quick_replies), 0,
  'Nasabah tidak bisa membaca tabel internal CS secara langsung');
select is((select count(*)::integer from cs.support_topics), 7, 'Nasabah hanya bisa membaca daftar topik aktif');
select throws_ok(format($$select cs_api.ticket_detail(%L)$$, :'t1'), 'PT403', 'agent_required',
  'Detail internal tiket hanya untuk CS');
select throws_ok($$select cs_api.ticket_lists()$$, 'PT403', 'agent_required', 'Nasabah tidak bisa memakai API CS');
select ok(not ((cs_api.support_home() -> 'ticket') ?| array['priority', 'flags', 'owner', 'resolution_summary', 'returned_reason', 'version']),
  'Status tiket untuk nasabah tidak memuat prioritas, flag, ringkasan, atau data internal');
select ok(private.can_access_topic('cs:room:' || :'room'), 'Nasabah boleh join channel room CS miliknya');
select ok(not private.can_access_topic('cs:room:' || :'room2'), 'Nasabah tidak boleh join channel room CS orang lain');
select ok(not private.can_access_topic('cs:agent:' || :'rina') and not private.can_access_topic('cs:queue'),
  'Nasabah tidak boleh join channel agen dan antrean');
select set_config('realtime.topic', 'cs:room:' || :'room', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{"status": "closed"}', 'ticket', true)$$,
  '42501', null, 'Client tidak bisa memalsukan event server di channel CS');

select tests.authenticate_as(:'sari');
select throws_ok(format($$select * from cs_api.get_messages(%L)$$, :'room'), 'PT404', 'room_not_found',
  'Nasabah lain tidak bisa membuka room CS');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Pesan room CS nasabah lain tidak terbaca (RLS)');
select throws_ok(format($$select * from cs_api.send_message(%L, 'halo')$$, :'room'), 'PT404', 'room_not_found',
  'Nasabah lain tidak bisa mengirim ke room CS orang lain');
select throws_ok(format($$select cs_api.close_ticket(%L)$$, :'t1'), 'PT404', 'ticket_not_found',
  'Nasabah lain tidak bisa menutup tiket orang lain');
select is((select count(*)::integer from public.search_profiles('Rina') where id = :'rina'), 0,
  'Akun CS tidak muncul di pencarian profil sosial');
select throws_ok(format($$select public.get_or_create_direct_room(%L)$$, :'rina'), 'PT403', 'cs_staff_room',
  'Akun CS tidak bisa diajak DM lewat fitur sosial');
select throws_ok(format($$select public.create_group_room('Grup', array[%L]::uuid[])$$, :'rina'), 'PT403', 'cs_staff_room',
  'Akun CS tidak bisa dimasukkan ke grup sosial');

select tests.authenticate_agent(:'dimas');
select ok((select count(*) > 0 from public.messages where session_id = :'t2'),
  'Semua CS bisa pratinjau pesan tiket open');
select is((select count(*)::integer from public.messages where session_id = :'t0'), 0,
  'Pratinjau tidak membuka riwayat tiket lama nasabah');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'CS non-pemilik tidak bisa membaca tiket yang sudah diambil CS lain');
select throws_ok(format($$select * from cs_api.get_messages(%L)$$, :'room'), 'PT404', 'room_not_found',
  'CS non-pemilik tidak bisa membuka room tiket milik CS lain');
select is(jsonb_array_length(cs_api.notes(:'budi')), 0, 'CS non-pemilik tidak melihat catatan nasabah');
select is((select count(*)::integer from cs.tickets where id in (:'t1', :'t2')), 1,
  'CS non-pemilik hanya melihat tiket open, bukan tiket milik CS lain');
select throws_ok(format($$select cs_api.add_note('x', %L)$$, :'t1'), 'PT403', 'notes_forbidden',
  'CS non-pemilik tidak bisa menulis catatan');
select throws_ok(format($$select cs_api.agent_customer_access(%L, 'profile')$$, :'t1'), 'PT403', 'customer_data_forbidden',
  'CS non-pemilik tidak bisa membuka data nasabah');
select throws_ok(format($$select cs_api.agent_customer_access(%L, 'profile')$$, :'t2'), 'PT403', 'customer_data_forbidden',
  'Pratinjau tiket open tidak membuka data OLT nasabah');

select tests.authenticate_agent(:'rina');
select is(jsonb_array_length(cs_api.notes(:'budi')), 2, 'Pemilik melihat catatan tiket dan catatan nasabah');
select is((select body from public.messages where id = :'budi_msg'), 'Saya tidak bisa masuk, NIK saya 3174********0001',
  'CS hanya melihat pesan yang sudah disamarkan');
select is(cs_api.agent_customer_access(:'t1', 'profile') ->> 'olt_user_id', 'test:' || :'budi',
  'Pemilik tiket mendapat akses data nasabah untuk adapter');
reset role;
select cs.set_setting('customer_data.profile_views_per_hour', '2', null) as v3 \gset
select tests.authenticate_agent(:'rina');
select cs_api.agent_customer_access(:'t1', 'profile') as access2 \gset
select throws_like(format($$select cs_api.agent_customer_access(%L, 'profile')$$, :'t1'), '%"rate_limited"%',
  'Pembukaan profil nasabah per CS dibatasi per jam');
select throws_ok(format($$select cs_api.agent_reveal_access(%L, 'nik', 'iseng')$$, :'t1'), 'PT400', 'invalid_reason',
  'Membuka data tersamar wajib memilih alasan yang sah');
select is(cs_api.agent_reveal_access(:'t1', 'nik', 'identity_verification') ->> 'valid_seconds', '300',
  'Membuka satu field berlaku sementara');
select ok(private.can_access_topic('cs:agent:' || :'rina') and private.can_access_topic('cs:room:' || :'room')
          and private.can_access_topic('cs:queue'), 'CS join channel miliknya, room tiketnya, dan daftar tiket terbuka');
select ok(cs.can_read_room_text(:'room') and cs.can_read_room_text(:'room2') and not cs.can_read_room_text(:'room3'),
  'Lampiran terbaca untuk tiket milik sendiri dan pratinjau tiket open saja');
select set_config('request.method', 'POST', true) as m \gset
select set_config('request.headers', '{"content-profile": "public"}', true) as h \gset
select throws_ok($$select private.check_request()$$, 'PT403', 'cs_staff_social_forbidden',
  'Akun CS tidak bisa memakai API sosial');
select set_config('request.headers', '{"content-profile": "cs_api"}', true) as h \gset
select lives_ok($$select private.check_request()$$, 'Akun CS memakai API CS');
select tests.authenticate_agent(:'rina', 'aal1');
select throws_ok($$select cs_api.ticket_lists()$$, 'PT403', 'agent_required', 'Akun CS tanpa 2FA ditolak');

reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where actor_id = :'rina' and action in ('customer_data.profile', 'customer_data.reveal')), 3,
  'Setiap pembukaan data nasabah tercatat di audit log');
select is((select details ->> 'field' || '/' || (details ->> 'reason') from cs.cs_audit_log
           where actor_id = :'rina' and action = 'customer_data.reveal'), 'nik/identity_verification',
  'Audit mencatat field dan alasan');

select tests.authenticate_agent(:'sinta');
select ok((select count(*) > 0 from public.messages where room_id = :'room')
          and (select count(*) > 0 from public.messages where session_id = :'t0'), 'Supervisor bisa memantau semua room CS');
select is(jsonb_array_length(cs_api.notes(:'budi')), 2, 'Supervisor melihat catatan internal');
select ok(private.can_access_topic('cs:queue'), 'Supervisor join channel antrean');
select is((select count(*)::integer from cs.cs_audit_log), 0, 'Audit log hanya untuk admin CS dan kepatuhan');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'halo')$$, :'t1'), 'PT403', 'not_ticket_owner',
  'Supervisor yang belum bergabung tidak bisa membalas');

select tests.authenticate_agent(:'kirana');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Kepatuhan tidak membaca tiket tanpa flag pengaduan/fraud');
reset role;
select cs.flag_ticket(:'t2', 'complaint') as flagged \gset
select tests.authenticate_agent(:'kirana');
select ok((select count(*) > 0 from public.messages where session_id = :'t2')
          and (select count(*) from cs.tickets where id in (:'t0', :'t1', :'t2', :'t3')) = 1,
  'Kepatuhan membaca tiket pengaduan saja');
select ok((select count(*) > 0 from cs.cs_audit_log), 'Kepatuhan membaca audit log');

select tests.authenticate_agent(:'adi');
select ok((select count(*) > 0 from cs.cs_audit_log) and (select count(*) = 0 from cs.tickets),
  'Admin CS membaca audit log, bukan isi chat');

select tests.authenticate_agent(:'rina');
select cs_api.request_transfer(:'t1', :'dimas', 'Mohon dilanjutkan') ->> 'id' as x1 \gset
select tests.authenticate_agent(:'dimas');
select cs_api.respond_transfer(:'x1', true) ->> 'id' as accepted \gset
select tests.authenticate_agent(:'rina');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Akses CS lama dicabut setelah tiket ditransfer');
select is(jsonb_array_length(cs_api.notes(:'budi')), 0, 'Catatan nasabah tidak lagi terbaca CS lama');

select tests.authenticate_as(:'budi');
select throws_ok(format($$update public.messages set body = 'diubah' where id = %L$$, :'budi_msg'),
  'PT409', 'support_message_locked', 'Pesan di chat CS tidak bisa diedit');
select throws_ok(format($$select public.delete_message(%L)$$, :'budi_msg'), 'PT409', 'support_message_locked',
  'Pesan di chat CS tidak bisa dihapus nasabah');
reset role;
insert into private.user_sanctions (user_id, kind, reason) values (:'budi', 'ban', 'uji');
select tests.authenticate_as(:'budi');
select set_config('request.headers', '{"content-profile": "public"}', true) as h \gset
select throws_ok($$select private.check_request()$$, 'PT403', 'user_banned', 'Nasabah yang di-ban tidak bisa memakai fitur sosial');
select set_config('request.headers', '{"content-profile": "cs_api"}', true) as h \gset
select lives_ok($$select private.check_request()$$, 'Nasabah yang di-ban tetap bisa menghubungi CS');
select is((select body from cs_api.send_message(:'room', 'Kenapa akun saya diblokir?')), 'Kenapa akun saya diblokir?',
  'Nasabah yang di-ban tetap bisa mengirim pesan ke CS');
select ok(private.can_access_topic('room:' || :'room') and private.can_access_topic('cs:room:' || :'room')
          and not private.can_access_topic('online'), 'Nasabah yang di-ban tetap bisa realtime di room CS saja');
select ok(cs.is_support_owner_text(:'room'), 'Nasabah yang di-ban tetap bisa mengunggah lampiran ke room CS');

select tests.authenticate_as(:'sari');
select public.delete_my_account() as deleted \gset
reset role;
select is((select body from public.messages where id = :'budi_msg'), 'Saya tidak bisa masuk, NIK saya 3174********0001',
  'Pesan CS tetap tersimpan');
select is((select body || '/' || (deleted_at is null)::text from public.messages where id = :'sari_msg'),
  'Deposit saya belum masuk/true', 'Riwayat chat CS tetap tersimpan saat nasabah menghapus akun');

select is((select count(*)::integer from pg_tables where schemaname = 'cs' and not rowsecurity), 0,
  'RLS aktif di semua tabel schema cs');
select throws_ok($$update cs.session_events set type = 'x'$$, '42501', null, 'Log kejadian tiket tidak bisa diubah');
select throws_ok($$delete from cs.cs_audit_log$$, '42501', null, 'Audit log tidak bisa dihapus');
select throws_ok($$update cs.agent_notes set body = 'x'$$, '42501', null, 'Catatan internal tidak bisa diubah');
select tests.authenticate_anon();
select throws_ok($$select cs_api.topics()$$, '42501', null, 'Anon tidak bisa memanggil API CS');

select * from finish();
rollback;
