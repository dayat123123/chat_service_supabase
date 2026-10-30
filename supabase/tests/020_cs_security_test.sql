begin;
select plan(70);

select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('sec_budi') as budi \gset
select tests.create_user('sec_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}') as dimas \gset
select tests.create_agent('Sinta', '{cs_supervisor}', '{"general": 3}') as sinta \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Adi', '{cs_admin}', '{}') as adi \gset

select tests.authenticate_as(:'budi');
select cs_api.start_session('account') as s \gset
select (:'s'::jsonb ->> 'id') as s1, (:'s'::jsonb ->> 'room_id') as room \gset
select id as budi_msg from cs_api.send_message(:'room', 'Saya tidak bisa masuk, NIK saya 3174056708900001') \gset
select tests.authenticate_as(:'sari');
select cs_api.start_session('funds') as s \gset
select (:'s'::jsonb ->> 'id') as s2, (:'s'::jsonb ->> 'room_id') as room2 \gset
select id as sari_msg from cs_api.send_message(:'room2', 'Deposit saya belum masuk') \gset

reset role;
select tests.agent_online(:'rina');
select (cs.offer(:'s1', :'rina')).id as offer1 \gset
select tests.authenticate_agent(:'rina');
select cs_api.accept_offer(:'offer1') as acc \gset
select cs_api.add_note('Catatan rahasia: nasabah terindikasi lupa password', :'s1') as n1 \gset
select cs_api.add_note('Catatan rahasia nasabah: lebih nyaman dihubungi sore hari', null, :'budi') as n2 \gset
select cs_api.agent_send_message(:'s1', 'Baik, saya bantu cek akun Anda') as m1 \gset

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from cs.agent_notes), 0, 'Nasabah tidak bisa membaca catatan internal (RLS)');
select throws_ok(format($$select cs_api.notes(%L)$$, :'budi'), 'PT403', 'agent_required',
  'Nasabah tidak bisa memanggil API catatan internal');
select is((select count(*)::integer from public.messages where body ilike '%catatan rahasia%'), 0,
  'Catatan internal tidak pernah masuk tabel pesan');
select is((select count(*)::integer from cs_api.get_messages(:'room'::uuid) m where m.body ilike '%catatan rahasia%'), 0,
  'Catatan internal tidak muncul di riwayat chat nasabah');
select is((select count(*)::integer from cs.support_sessions) + (select count(*)::integer from cs.session_events)
          + (select count(*)::integer from cs.cs_audit_log) + (select count(*)::integer from cs.match_offers)
          + (select count(*)::integer from cs.agents) + (select count(*)::integer from cs.quick_replies), 0,
  'Nasabah tidak bisa membaca tabel internal CS secara langsung');
select is((select count(*)::integer from cs.support_topics), 7, 'Nasabah hanya bisa membaca daftar topik aktif');
select throws_ok(format($$select cs_api.session_detail(%L)$$, :'s1'), 'PT403', 'agent_required',
  'Detail internal sesi hanya untuk CS');
select throws_ok($$select cs_api.agent_inbox()$$, 'PT403', 'agent_required', 'Nasabah tidak bisa memakai API agen');
select is((cs_api.my_support() -> 'session') - '{queued_at,id,room_id,agent,closed_at}'::text[],
  '{"topic": "account", "rating": null, "status": "active", "waiting": false, "can_rate": false, "complaint": null, "queue_position": null}'::jsonb,
  'Status sesi untuk nasabah tidak memuat prioritas, flag, tag, atau catatan');
select ok(private.can_access_topic('cs:room:' || :'room'), 'Nasabah boleh join channel room CS miliknya');
select ok(not private.can_access_topic('cs:room:' || :'room2'), 'Nasabah tidak boleh join channel room CS orang lain');
select ok(not private.can_access_topic('cs:agent:' || :'rina') and not private.can_access_topic('cs:queue'),
  'Nasabah tidak boleh join channel agen dan antrean');
select set_config('realtime.topic', 'cs:room:' || :'room', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{"status": "closed"}', 'session', true)$$,
  '42501', null, 'Client tidak bisa memalsukan event server di channel CS');

select tests.authenticate_as(:'sari');
select throws_ok(format($$select * from cs_api.get_messages(%L)$$, :'room'), 'PT404', 'room_not_found',
  'Nasabah lain tidak bisa membuka room CS');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Pesan room CS nasabah lain tidak terbaca (RLS)');
select throws_ok(format($$select * from cs_api.send_message(%L, 'halo')$$, :'room'), 'PT404', 'room_not_found',
  'Nasabah lain tidak bisa mengirim ke room CS orang lain');
select throws_ok(format($$select cs_api.end_session(%L)$$, :'s1'), 'PT404', 'session_not_found',
  'Nasabah lain tidak bisa menutup sesi orang lain');
select is((select count(*)::integer from public.search_profiles('Rina') where id = :'rina'), 0,
  'Akun CS tidak muncul di pencarian profil sosial');
select throws_ok(format($$select public.get_or_create_direct_room(%L)$$, :'rina'), 'PT403', 'cs_staff_room',
  'Akun CS tidak bisa diajak DM lewat fitur sosial');
select throws_ok(format($$select public.create_group_room('Grup', array[%L]::uuid[])$$, :'rina'), 'PT403', 'cs_staff_room',
  'Akun CS tidak bisa dimasukkan ke grup sosial');

select tests.authenticate_agent(:'dimas');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Agen yang tidak menangani tidak bisa membaca pesan room (RLS)');
select throws_ok(format($$select * from cs_api.get_messages(%L)$$, :'room'), 'PT404', 'room_not_found',
  'Agen yang tidak menangani tidak bisa membuka room');
select is(jsonb_array_length(cs_api.notes(:'budi')), 0, 'Agen yang tidak menangani tidak melihat catatan nasabah');
select is((select count(*)::integer from cs.support_sessions where id = :'s1'), 0,
  'Agen yang tidak menangani tidak melihat sesi');
select throws_ok(format($$select cs_api.add_note('x', %L)$$, :'s1'), 'PT403', 'notes_forbidden',
  'Agen yang tidak menangani tidak bisa menulis catatan');
select throws_ok(format($$select cs_api.agent_customer_access(%L, 'profile')$$, :'s1'), 'PT403', 'customer_data_forbidden',
  'Agen yang tidak menangani tidak bisa membuka data nasabah');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'halo')$$, :'s1'), 'PT403', 'not_handling',
  'Agen yang tidak menangani tidak bisa membalas');
select throws_ok(format($$select cs_api.session_detail(%L)$$, :'s1'), 'PT404', 'session_not_found',
  'Agen yang tidak menangani tidak bisa membuka detail sesi');

select tests.authenticate_agent(:'rina');
select is(jsonb_array_length(cs_api.notes(:'budi')), 2, 'Agen yang menangani melihat catatan sesi dan catatan nasabah');
select is(cs_api.session_detail(:'s1') ->> 'status', 'active', 'Agen yang menangani membuka detail sesi');
select is(jsonb_typeof(cs_api.quick_replies()), 'array', 'Agen membaca daftar quick reply');
select is((select body from public.messages where id = :'budi_msg'), 'Saya tidak bisa masuk, NIK saya 3174********0001',
  'Agen hanya melihat pesan yang sudah disamarkan');
select is(cs_api.agent_customer_access(:'s1', 'profile') ->> 'olt_user_id', 'test:' || :'budi',
  'Agen yang menangani mendapat akses data nasabah untuk adapter');
reset role;
select cs.set_setting('customer_data.profile_views_per_hour', '2', null) as v3 \gset
select tests.authenticate_agent(:'rina');
select cs_api.agent_customer_access(:'s1', 'profile') as access2 \gset
select throws_like(format($$select cs_api.agent_customer_access(%L, 'profile')$$, :'s1'), '%"rate_limited"%',
  'Pembukaan profil nasabah per agen dibatasi per jam');
select throws_ok(format($$select cs_api.agent_reveal_access(%L, 'nik', 'iseng')$$, :'s1'), 'PT400', 'invalid_reason',
  'Membuka data tersamar wajib memilih alasan yang sah');
select is(cs_api.agent_reveal_access(:'s1', 'nik', 'identity_verification') ->> 'valid_seconds', '300',
  'Membuka satu field berlaku sementara');
select ok(private.can_access_topic('cs:agent:' || :'rina') and private.can_access_topic('cs:room:' || :'room')
          and not private.can_access_topic('cs:queue'), 'Agen join channel miliknya dan room yang ditangani, bukan antrean');
select ok(cs.can_read_room_text(:'room') and not cs.can_read_room_text(:'room2'),
  'Lampiran room CS hanya terbaca agen yang menangani');
select set_config('request.method', 'POST', true) as m \gset
select set_config('request.headers', '{"content-profile": "public"}', true) as h \gset
select throws_ok($$select private.check_request()$$, 'PT403', 'cs_staff_social_forbidden',
  'Akun CS tidak bisa memakai API sosial');
select set_config('request.headers', '{"content-profile": "cs_api"}', true) as h \gset
select lives_ok($$select private.check_request()$$, 'Akun CS memakai API CS');
select tests.authenticate_agent(:'rina', 'aal1');
select throws_ok($$select cs_api.agent_inbox()$$, 'PT403', 'agent_required', 'Akun CS tanpa 2FA ditolak');

reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where actor_id = :'rina' and action in ('customer_data.profile', 'customer_data.reveal')), 3,
  'Setiap pembukaan data nasabah tercatat di audit log');
select is((select details ->> 'field' || '/' || (details ->> 'reason') from cs.cs_audit_log
           where actor_id = :'rina' and action = 'customer_data.reveal'), 'nik/identity_verification',
  'Audit mencatat field dan alasan');
update cs.agents set disabled_at = now() where user_id = :'dimas';
select tests.authenticate_agent(:'dimas');
select throws_ok($$select cs_api.agent_me()$$, 'PT403', 'agent_required', 'Agen nonaktif langsung kehilangan akses');

select tests.authenticate_agent(:'sinta');
select ok((select count(*) > 0 from public.messages where room_id = :'room')
          and (select count(*) > 0 from public.messages where room_id = :'room2'), 'Supervisor bisa memantau semua room CS');
select is(jsonb_array_length(cs_api.notes(:'budi')), 2, 'Supervisor melihat catatan internal');
select ok(private.can_access_topic('cs:queue'), 'Supervisor join channel antrean');
select ok(cs_api.session_detail(:'s1') -> 'events' @> '[{"type": "accepted"}]', 'Supervisor memantau perjalanan sesi');
select is(jsonb_array_length(cs_api.customer_history(:'budi')), 1, 'Supervisor melihat riwayat sesi nasabah');
select is((select count(*)::integer from cs.cs_audit_log), 0, 'Audit log hanya untuk admin CS dan kepatuhan');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'halo')$$, :'s1'), 'PT403', 'not_handling',
  'Supervisor yang memantau tidak bisa membalas atas nama agen');

select tests.authenticate_agent(:'kirana');
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Kepatuhan tidak membaca sesi tanpa flag pengaduan/fraud');
reset role;
select cs.flag_session(:'s2', 'complaint') as flagged \gset
select tests.authenticate_agent(:'kirana');
select ok((select count(*) > 0 from public.messages where session_id = :'s2')
          and (select count(*) from cs.support_sessions) = 1, 'Kepatuhan membaca sesi pengaduan saja');
select ok((select count(*) > 0 from cs.cs_audit_log), 'Kepatuhan membaca audit log');

select tests.authenticate_agent(:'adi');
select ok((select count(*) > 0 from cs.cs_audit_log) and (select count(*) = 0 from cs.support_sessions),
  'Admin CS membaca audit log, bukan isi chat');

select tests.authenticate_agent(:'rina');
select cs_api.transfer_session(:'s1', 'Perlu dicek tim teknis', 'technical') as tr \gset
select is((select count(*)::integer from public.messages where room_id = :'room'), 0,
  'Akses agen dicabut setelah sesi ditransfer');

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
  'Pesan CS tetap tersimpan walau dihapus pengirim');
select is((select body || '/' || (deleted_at is null)::text from public.messages where id = :'sari_msg'),
  'Deposit saya belum masuk/true', 'Riwayat chat CS tetap tersimpan saat nasabah menghapus akun');

select is((select count(*)::integer from pg_tables where schemaname = 'cs' and not rowsecurity), 0,
  'RLS aktif di semua tabel schema cs');
select throws_ok($$update cs.session_events set type = 'x'$$, '42501', null, 'Log kejadian sesi tidak bisa diubah');
select throws_ok($$delete from cs.cs_audit_log$$, '42501', null, 'Audit log tidak bisa dihapus');
select throws_ok($$update cs.agent_notes set body = 'x'$$, '42501', null, 'Catatan internal tidak bisa diubah');
select tests.authenticate_anon();
select throws_ok($$select cs_api.topics()$$, '42501', null, 'Anon tidak bisa memanggil API CS');

select * from finish();
rollback;
