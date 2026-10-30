begin;
select plan(76);

select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('cs_budi') as budi \gset
select tests.create_user('cs_sari') as sari \gset
select tests.create_user('cs_tono') as tono \gset
select tests.create_user('cs_andi') as andi \gset
select tests.create_user('cs_ratna') as ratna \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"trading": 3, "general": 1}', 'trading') as dimas \gset
select tests.create_agent('Joko', '{cs_agent}', '{"complaint": 3, "general": 1}', 'complaints') as joko \gset

select tests.authenticate_as(:'budi');
select is(jsonb_array_length(cs_api.topics()), 7, 'Tujuh topik singkat untuk nasabah');
select cs_api.start_session('account', 'id', 'help') as s1 \gset
select (:'s1'::jsonb ->> 'id') as s1_id, (:'s1'::jsonb ->> 'room_id') as room \gset
select is(:'s1'::jsonb ->> 'status', 'queued', 'Sesi baru masuk antrean');
select is(cs_api.start_session('orders') ->> 'id', :'s1_id', 'Satu sesi terbuka per nasabah: memulai lagi mengembalikan sesi yang sama');
select is(cs_api.my_support() ->> 'room_id', :'room', 'Room CS permanen milik nasabah');
select is((select array_agg(m.payload ->> 'code' order by m.created_at) from cs_api.get_messages(:'room'::uuid) m),
  '{greeting,security_reminder,queued}'::text[], 'Pesan otomatis: salam, pengingat keamanan, info antrean');
select is((select m.body from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'security_reminder'),
  'CS kami tidak pernah meminta PIN, password, atau OTP.', 'Pengingat keamanan sesuai pengaturan');
select is((select body from cs_api.send_message(:'room', 'Halo, OTP saya 123456 tidak masuk', 'c1000000-0000-4000-8000-000000000001')),
  'Halo, OTP saya ****** tidak masuk', 'OTP di pesan nasabah disamarkan sebelum disimpan');
select is((select body from cs_api.send_message(:'room', 'kirim ulang', 'c1000000-0000-4000-8000-000000000001')),
  'Halo, OTP saya ****** tidak masuk', 'Kirim ulang dengan client_id sama tidak membuat pesan baru');
select is((select m.payload -> 'masked' from public.messages m where m.client_id = 'c1000000-0000-4000-8000-000000000001'),
  '["otp"]'::jsonb, 'Jenis data yang disamarkan dicatat di pesan');
select is((select m.sender_role || '/' || m.kind from public.messages m where m.client_id = 'c1000000-0000-4000-8000-000000000001'),
  'customer/text', 'Pesan nasabah ditandai sender_role customer');
select is((select count(*)::integer from public.get_my_rooms() where type = 'support'), 0,
  'Room CS tidak muncul di daftar chat sosial');
select throws_ok(format($$select public.leave_room(%L)$$, :'room'), 'PT400', 'cannot_leave_support',
  'Nasabah tidak bisa meninggalkan room CS');

reset role;
select throws_ok(format($$select cs.offer(%L, %L)$$, :'s1_id', :'rina'), 'PT409', 'agent_unavailable',
  'Agen offline tidak bisa ditawari sesi');
select tests.agent_online(:'rina');
select (cs.offer(:'s1_id', :'rina')).id as offer1 \gset
select is((select status from cs.support_sessions where id = :'s1_id'), 'offered', 'Sesi ditawarkan ke agen');
select is((select active_sessions from cs.agent_status where agent_id = :'rina'), 1, 'Penawaran dihitung ke kapasitas agen');
select throws_ok(format($$select cs.offer(%L, %L)$$, :'s1_id', :'rina'), 'PT409', 'session_not_waiting',
  'Satu sesi tidak pernah ditawarkan ke dua agen sekaligus');

select tests.authenticate_agent(:'rina');
select is(cs_api.agent_inbox() -> 'offers' -> 0 ->> 'preview', 'Halo, OTP saya ****** tidak masuk',
  'Penawaran menampilkan cuplikan pesan nasabah yang sudah disamarkan');
select throws_ok(format($$select * from cs_api.get_messages(%L)$$, :'room'), 'PT404', 'room_not_found',
  'Agen belum bisa membaca chat sebelum menerima penawaran');
select tests.authenticate_agent(:'dimas');
select throws_ok(format($$select cs_api.accept_offer(%L)$$, :'offer1'), 'PT404', 'offer_not_found',
  'Agen lain tidak bisa menerima penawaran milik agen ini');
select tests.authenticate_agent(:'rina');
select is(cs_api.accept_offer(:'offer1') ->> 'status', 'active', 'Agen menerima penawaran, sesi aktif');
select ok((select count(*) > 0 from cs_api.get_messages(:'room'::uuid)), 'Agen yang menangani membaca seluruh riwayat room');
select cs_api.agent_send_message(:'s1_id', 'Baik Pak Budi, saya bantu cek ya', 'a1000000-0000-4000-8000-000000000001') as m1 \gset
select is(:'m1'::jsonb ->> 'status', 'sent', 'Agen mengirim pesan');
select is(:'m1'::jsonb -> 'message' ->> 'sender_role', 'agent', 'Pesan agen ditandai sender_role agent (badge CS Resmi)');
select is(cs_api.agent_send_message(:'s1_id', 'Apakah sudah coba masuk ulang?', null, 'quick_reply',
  '{"options": ["Sudah", "Belum"]}') ->> 'status', 'sent', 'Agen mengirim tombol pilihan cepat');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Panduan', null, 'help_link', '{"url": "https://evil.example.com/x"}')$$, :'s1_id'),
  'PT400', 'invalid_help_link', 'Tautan bantuan hanya ke situs bantuan resmi');
select throws_ok(format($$select * from public.send_message(%L, 'hai')$$, :'room'), 'PT403', 'use_cs_api',
  'Agen tidak bisa mengirim pesan CS lewat API chat sosial');
select throws_ok(format($$select cs_api.close_session(%L, 'beres')$$, :'s1_id'), 'PT400', 'invalid_outcome',
  'Hasil penutupan wajib dari daftar');

reset role;
select is((select role from public.chat_members where room_id = :'room' and user_id = :'rina'), 'member',
  'Agen ditambahkan ke anggota room saat menerima sesi');
select is((select body from public.messages where session_id = :'s1_id' and payload ->> 'code' = 'connected'),
  'Anda terhubung dengan Rina – CS Resmi.', 'Nasabah diberi tahu nama agen');
select ok((select first_response_at is not null and accepted_at is not null from cs.support_sessions where id = :'s1_id'),
  'Waktu diterima dan respons pertama dicatat');
select is((select count(*)::integer from public.notifications
           where user_id = :'budi' and type = 'message' and payload ->> 'room_type' = 'support'), 1,
  'Balasan agen masuk notifikasi nasabah');

select tests.authenticate_as(:'budi');
select is(cs_api.my_support() -> 'session' -> 'agent' ->> 'display_name', 'Rina', 'Nasabah melihat agen yang menangani');
select tests.authenticate_agent(:'rina');
select is(cs_api.close_session(:'s1_id', 'resolved', '{login}', 'Nasabah lupa password, sudah direset') ->> 'status',
  'closed', 'Agen menutup sesi dengan hasil dan tag');
select ok((select count(*) > 0 from cs_api.get_messages(:'room'::uuid)),
  'Agen masih bisa membaca riwayat sesi yang ia tangani selama jendela riwayat');

reset role;
select is((select count(*)::integer from public.chat_members where room_id = :'room' and user_id = :'rina'), 0,
  'Agen dikeluarkan dari anggota room saat sesi ditutup');
select is((select active_sessions from cs.agent_status where agent_id = :'rina'), 0, 'Kapasitas agen dibebaskan');
select is((select array_agg(kind order by created_at) from public.messages
           where session_id = :'s1_id' and payload ->> 'code' in ('closed', 'csat')),
  '{system,csat}'::text[], 'Pesan penutup dan permintaan rating');

select tests.authenticate_as(:'budi');
select is(cs_api.rate_session(:'s1_id', 5, 'Cepat, password saya Rahasia123!') ->> 'rating', '5', 'Nasabah memberi rating 1–5');
select throws_ok(format($$select cs_api.rate_session(%L, 4)$$, :'s1_id'), 'PT409', 'cannot_rate',
  'Rating hanya sekali per sesi');
select is((select body from cs_api.send_message(:'room', 'Maaf, satu pertanyaan lagi'))
  , 'Maaf, satu pertanyaan lagi', 'Nasabah mengetik lagi setelah sesi selesai');

reset role;
select is((select rating_comment from cs.support_sessions where id = :'s1_id'), 'Cepat, password saya ********',
  'Komentar rating juga disamarkan');
select is((select status || '/' || current_agent_id::text || '/' || reopen_count from cs.support_sessions where id = :'s1_id'),
  'active/' || :'rina' || '/1', 'Dalam 30 menit sesi dibuka kembali ke agen yang sama karena masih online');

select tests.authenticate_agent(:'rina');
select cs_api.close_session(:'s1_id', 'resolved') as c2 \gset
reset role;
update cs.support_sessions set closed_at = now() - interval '31 minutes' where id = :'s1_id';
select tests.authenticate_as(:'budi');
select is((select body from cs_api.send_message(:'room', 'Halo lagi, mau tanya hal lain')),
  'Halo lagi, mau tanya hal lain', 'Pesan setelah 30 menit tetap terkirim');
reset role;
select is((select topic || '/' || priority || '/' || status from cs.support_sessions where room_id = :'room' and status <> 'closed'),
  'other/P4/queued', 'Setelah 30 menit pesan baru membuat sesi baru dengan topik default');
select is((select count(*)::integer from cs.support_sessions where customer_id = :'budi'), 2,
  'Riwayat sesi lama tetap tersimpan di room yang sama');

select tests.authenticate_as(:'sari');
select cs_api.start_session('account') as s2 \gset
select (:'s2'::jsonb ->> 'id') as s2_id, (:'s2'::jsonb ->> 'room_id') as room2 \gset
select is((select body from cs_api.send_message(:'room2', 'Tolong, akun saya dibobol orang')), 'Tolong, akun saya dibobol orang',
  'Nasabah melaporkan peretasan');
reset role;
select is((select priority || '/' || array_to_string(flags, ',') || '/' || required_skill from cs.support_sessions where id = :'s2_id'),
  'P1/fraud/fraud', 'Kata kunci di pesan pertama menaikkan prioritas dan menandai fraud');
select is((cs.initial_priority('orders', '{}', 'Saya tidak bisa order dari tadi', '2026-11-02 10:00+07')).priority, 'P1',
  'Tidak bisa transaksi di jam bursa menjadi P1');
select is((cs.initial_priority('orders', '{}', 'Saya tidak bisa order dari tadi', '2026-11-02 20:00+07')).priority, 'P3',
  'Di luar jam bursa prioritas tetap mengikuti topik');

select tests.agent_online(:'dimas');
select (cs.offer(:'s2_id', :'dimas')).id as offer2 \gset
update cs.match_offers set expires_at = now() - interval '1 second' where id = :'offer2';
select is(cs.expire_offers(), 1, 'Penawaran yang habis waktu diproses');
select is((select status from cs.support_sessions where id = :'s2_id'), 'queued', 'Sesi kembali ke antrean setelah penawaran habis waktu');
select (cs.offer(:'s2_id', :'dimas')).id as offer3 \gset
update cs.match_offers set expires_at = now() - interval '1 second' where id = :'offer3';
select cs.expire_offers() as expired \gset
select is((select status || '/' || consecutive_timeouts from cs.agent_status where agent_id = :'dimas'), 'break/2',
  'Dua penawaran berturut-turut habis waktu: agen otomatis istirahat');
select tests.authenticate_agent(:'dimas');
select throws_ok(format($$select cs_api.accept_offer(%L)$$, :'offer3'), 'PT409', 'offer_closed',
  'Penawaran yang sudah habis waktu tidak bisa diterima');

reset role;
select (cs.offer(:'s2_id', :'rina')).id as offer4 \gset
select tests.authenticate_agent(:'rina');
select cs_api.reject_offer(:'offer4', 'Sedang menangani kasus lain') as r \gset
reset role;
select is((select result || '/' || (select status from cs.support_sessions where id = :'s2_id') from cs.match_offers where id = :'offer4'),
  'rejected/queued', 'Penawaran ditolak, sesi kembali ke antrean');

select (cs.offer(:'s2_id', :'rina')).id as offer5 \gset
select tests.authenticate_agent(:'rina');
select cs_api.accept_offer(:'offer5') as acc5 \gset
select throws_ok(format($$select cs_api.transfer_session(%L, '', 'security')$$, :'s2_id'), 'PT400', 'handover_note_required',
  'Transfer wajib disertai catatan serah terima');
select throws_ok(format($$select cs_api.transfer_session(%L, 'Butuh tim trading', null, null, %L)$$, :'s2_id', :'dimas'),
  'PT409', 'agent_unavailable', 'Transfer langsung hanya ke agen yang online');
select is(cs_api.transfer_session(:'s2_id', 'Akun diretas, perlu tim keamanan', 'security') ->> 'status', 'transferring',
  'Agen mentransfer sesi ke tim lain');
reset role;
select is((select transfer_count || '/' || coalesce(current_agent_id::text, '-') from cs.support_sessions where id = :'s2_id'),
  '1/-', 'Transfer dicatat dan agen lama dilepas');
select is((select count(*)::integer from public.chat_members where room_id = :'room2' and user_id = :'rina'), 0,
  'Akses agen lama dicabut saat transfer');
select is((select kind || ': ' || body from cs.agent_notes where session_id = :'s2_id'),
  'handover: Akun diretas, perlu tim keamanan', 'Catatan serah terima tersimpan sebagai catatan internal');
select is((select body from public.messages where session_id = :'s2_id' and payload ->> 'code' = 'transferred'),
  'Anda dialihkan ke tim Keamanan & Fraud. Mohon tunggu sebentar.', 'Nasabah melihat pesan pengalihan');

select tests.agent_online(:'rina');
select (cs.offer(id, :'rina')).id as offer6 from cs.support_sessions where room_id = :'room' and status = 'queued' \gset
select tests.authenticate_agent(:'rina');
select cs_api.accept_offer(:'offer6') ->> 'id' as s3_id \gset
select is(cs_api.flag_session(:'s3_id', 'complaint') ->> 'status', 'transferring',
  'Sesi ditandai pengaduan dialihkan otomatis karena agen tidak punya skill pengaduan');
reset role;
select is((select priority || '/' || required_skill || '/' || (complaint_due_at = cs.regulatory_deadline(complaint_received_at, 5))::text
           from cs.support_sessions where id = :'s3_id'),
  'P2/complaint/true', 'Pengaduan: prioritas P2, skill pengaduan, tenggat 5 hari kerja');
select ok((select body like 'Pengaduan Anda kami terima%' from public.messages where session_id = :'s3_id' and payload ->> 'code' = 'complaint'),
  'Nasabah mendapat konfirmasi waktu pengaduan diterima dan tenggatnya');

select tests.agent_online(:'joko');
select (cs.offer(:'s3_id', :'joko')).id as offer7 \gset
select tests.authenticate_agent(:'joko');
select cs_api.accept_offer(:'offer7') as acc7 \gset
select cs_api.agent_set_status('offline', 'Koneksi putus') as off \gset
reset role;
select is((select status || '/' || priority from cs.support_sessions where id = :'s3_id'), 'queued/P2',
  'Agen offline: sesi aktifnya kembali ke antrean dengan prioritas tinggi');
select ok((select count(*) = 1 from public.messages where session_id = :'s3_id' and payload ->> 'code' = 'reconnecting'),
  'Nasabah diberi tahu sedang dihubungkan ke CS lain');
select throws_ok(format($$select cs.set_status(%L, 'active', 'x')$$, :'s1_id'), 'PT409', 'invalid_transition',
  'State machine menolak transisi yang tidak sah');

select tests.authenticate_as(:'tono');
select is(cs_api.request_complaint() -> 'complaint' ->> 'due_at' is not null, true,
  'Nasabah bisa langsung mengajukan pengaduan');
reset role;
select is((select priority || '/' || array_to_string(flags, ',') from cs.support_sessions where customer_id = :'tono'),
  'P2/complaint', 'Sesi pengaduan nasabah berprioritas P2');

select cs.set_setting('service.hours',
  (select jsonb_object_agg(d::text, '["08:00", "20:00"]'::jsonb) from generate_series(1, 7) d
   where d <> extract(isodow from now() at time zone 'Asia/Jakarta')), null) as v2 \gset
select tests.authenticate_as(:'andi');
select cs_api.start_session('technical', 'en') ->> 'room_id' as room3 \gset
select is((select array_agg(m.payload ->> 'code' order by m.created_at) from cs_api.get_messages(:'room3'::uuid) m),
  '{greeting,security_reminder,out_of_hours}'::text[], 'Di luar jam layanan nasabah tetap bisa membuat sesi dan diberi tahu jam buka');
select ok((select body like 'We are currently closed. An agent will reply from %' from cs_api.get_messages(:'room3'::uuid) m
           where m.payload ->> 'code' = 'out_of_hours'), 'Pesan otomatis mengikuti bahasa nasabah');
select is(cs_api.end_session((cs_api.my_support() -> 'session' ->> 'id')::uuid) ->> 'status', 'closed',
  'Nasabah bisa mengakhiri sesi saat menunggu');
reset role;
select is((select count(*)::integer from public.messages m join cs.support_sessions s on s.id = m.session_id
           where s.customer_id = :'andi' and m.kind = 'csat'), 0, 'Tanpa agen, tidak ada permintaan rating');

select tests.authenticate_as(:'ratna');
select cs_api.start_session('other') ->> 'id' as r1 \gset
select cs_api.end_session(:'r1') as e1 \gset
select cs_api.start_session('other') ->> 'id' as r2 \gset
select cs_api.end_session(:'r2') as e2 \gset
select cs_api.start_session('other') ->> 'id' as r3 \gset
select cs_api.end_session(:'r3') as e3 \gset
select cs_api.start_session('other') ->> 'id' as r4 \gset
select cs_api.end_session(:'r4') as e4 \gset
select cs_api.start_session('other') ->> 'id' as r5 \gset
select cs_api.end_session(:'r5') as e5 \gset
select throws_like($$select cs_api.start_session('other')$$, '%"rate_limited"%Batas 5 cs_session per 3600 detik%',
  'Nasabah dibatasi 5 sesi baru per jam');

reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'session.accept' and actor_id in (:'rina', :'joko')), 4,
  'Setiap penerimaan sesi tercatat di audit log');
select ok((select bool_and(type <> '') from cs.session_events where session_id = :'s1_id')
          and (select array_agg(type order by created_at, id) from cs.session_events where session_id = :'s1_id')
              @> '{queued,offered,accepted,closed,reopened,reassigned}'::text[],
  'Perjalanan sesi tercatat lengkap di session_events');

select * from finish();
rollback;
