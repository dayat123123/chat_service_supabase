begin;
select plan(82);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('tk_budi') as budi \gset
select tests.create_user('tk_sari') as sari \gset
select tests.create_user('tk_tono') as tono \gset
select tests.create_user('tk_andi') as andi \gset
select tests.create_user('tk_ratna') as ratna \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"trading": 3, "general": 1}', 'trading') as dimas \gset
select tests.create_agent('Joko', '{cs_agent}', '{"complaint": 3, "general": 1}', 'complaints') as joko \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{"general": 3}') as sinta \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account', 'id', 'help') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room, (:'j'::jsonb ->> 'ticket_number') as num1 \gset
select ok(:'num1' ~ '^CS-[0-9]{8}-[0-9]{4,}$', 'Nomor tiket mudah dibaca: CS-YYYYMMDD-NNNN');
select is(:'j'::jsonb ->> 'status', 'open', 'Tiket baru berstatus open');
select is(cs_api.open_ticket('orders') ->> 'id', :'t1', 'Menekan Chat CS lagi membuka tiket aktif yang sama');
select is((select array_agg(m.payload ->> 'code') from cs_api.get_messages(:'room'::uuid) m), '{ticket_opened}'::text[],
  'Hanya satu pesan sistem saat tiket dibuat');
select ok((select bool_and(m.body like 'Tiket #' || :'num1' || ' dibuka. Halo%CS kami tidak pernah meminta PIN, password, atau OTP.')
           from cs_api.get_messages(:'room'::uuid) m), 'Salam dan pengingat keamanan digabung dalam satu pesan');
select is((select body from cs_api.send_message(:'room', 'Saya tidak bisa login, OTP saya 123456', 'd1000000-0000-4000-8000-000000000001')),
  'Saya tidak bisa login, OTP saya ******', 'Data sensitif tetap disamarkan');

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.claim_ticket(%L)$$, :'t1'), 'PT409', 'agent_not_online',
  'CS harus Online untuk mengambil tiket');
select tests.agent_online(:'rina');
select is(cs_api.claim_ticket(:'t1') ->> 'status', 'claimed', 'CS Online mengambil tiket');
select tests.agent_online(:'dimas');
select tests.authenticate_agent(:'dimas');
select throws_ok(format($$select cs_api.claim_ticket(%L)$$, :'t1'), 'PT409', 'ticket_taken',
  'CS lain tidak bisa mengambil tiket yang sudah diambil');
select is(tests.error_detail(format($$select cs_api.claim_ticket(%L)$$, :'t1')), 'Tiket sudah diambil oleh Rina',
  'Pesan penolakan menyebut CS pengambil');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Saya bantu ya')$$, :'t1'), 'PT403', 'not_ticket_owner',
  'CS non-pemilik tidak bisa membalas lewat API');
select throws_ok(format($$select cs_api.resolve_ticket(%L, 'answered', 'Sudah dijawab')$$, :'t1'), 'PT403', 'not_ticket_owner',
  'CS non-pemilik tidak bisa menyelesaikan tiket');
select throws_ok(format($$select cs_api.release_ticket(%L, 'Bukan bagian saya')$$, :'t1'), 'PT403', 'not_ticket_owner',
  'CS non-pemilik tidak bisa melepas tiket');
reset role;
select throws_ok(format($$insert into public.messages (room_id, sender_id, body, session_id, sender_role)
                           values (%L, %L, 'menyusup', %L, 'agent')$$, :'room', :'dimas', :'t1'),
  'PT403', 'not_ticket_owner', 'Trigger menolak pesan CS non-pemilik walaupun API dilewati');

select tests.authenticate_as(:'budi');
select is(cs_api.support_home() -> 'ticket' -> 'agent' ->> 'display_name', 'Rina', 'Nasabah melihat CS yang menangani');
select is((select m.body from cs_api.get_messages(:'room'::uuid) m where m.payload ->> 'code' = 'ticket_claimed'),
  'Tiket diambil oleh Rina – CS Resmi.', 'Satu pesan sistem saat tiket diambil');

select tests.authenticate_agent(:'rina');
select is(cs_api.agent_send_message(:'t1', 'Halo Pak Budi, saya cek dulu ya') ->> 'status', 'sent', 'Pemilik membalas');
select is(cs_api.wait_customer(:'t1') ->> 'status', 'waiting_customer', 'Pemilik menandai menunggu balasan nasabah');
select tests.authenticate_as(:'budi');
select ok((cs_api.support_home() ->> 'unread_count')::integer >= 1, 'Badge menghitung balasan CS yang belum dibaca');
select is((select body from cs_api.send_message(:'room', 'Sudah saya coba lagi')), 'Sudah saya coba lagi', 'Nasabah membalas');
reset role;
select is((select status from cs.tickets where id = :'t1'), 'claimed', 'Balasan nasabah mengembalikan tiket ke claimed');

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.release_ticket(%L, 'Perlu tim lain', 1)$$, :'t1'), 'PT409', 'stale_ticket',
  'Versi tiket lama ditolak (optimistic concurrency)');
select throws_ok(format($$select cs_api.release_ticket(%L, '')$$, :'t1'), 'PT400', 'reason_required',
  'Melepas tiket wajib alasan');
select is(cs_api.release_ticket(:'t1', 'Perlu dicek tim transaksi') ->> 'status', 'open', 'Pemilik melepas tiket ke antrean');
reset role;
select is((select coalesce(owner_agent_id::text, '-') || '/' || returned_reason from cs.tickets where id = :'t1'),
  '-/Perlu dicek tim transaksi', 'Tiket kembali open tanpa pemilik, alasan tercatat');
select is((select count(*)::integer from public.chat_members where room_id = :'room' and user_id = :'rina'), 0,
  'Akses chat pemilik lama dicabut');
select is((select m.body from public.messages m where m.session_id = :'t1' and m.payload ->> 'code' = 'ticket_released'),
  'Tiket dikembalikan ke antrean. CS lain akan segera membantu.', 'Nasabah diberi tahu tiket kembali ke antrean');

select tests.authenticate_agent(:'dimas');
select is(cs_api.claim_ticket(:'t1') -> 'owner' ->> 'display_name', 'Dimas', 'CS lain mengambil tiket yang dilepas');
select throws_ok(format($$select cs_api.request_transfer(%L, %L, 'Mohon dibantu')$$, :'t1', :'joko'), 'PT409', 'agent_unavailable',
  'Transfer hanya ke CS yang Online');
select cs_api.request_transfer(:'t1', :'rina', 'Nasabah perlu bantuan akun') ->> 'id' as x1 \gset
reset role;
select is((select owner_agent_id::text from cs.tickets where id = :'t1'), :'dimas',
  'Selama transfer belum diterima, tiket tetap milik pengirim');
select tests.authenticate_agent(:'rina');
select is(cs_api.respond_transfer(:'x1', false, 'Sedang penuh') -> 'owner' ->> 'display_name', 'Dimas',
  'Transfer ditolak, pemilik tidak berubah');
select tests.authenticate_agent(:'dimas');
select cs_api.request_transfer(:'t1', :'rina', 'Nasabah perlu bantuan akun') ->> 'id' as x2 \gset
select tests.authenticate_agent(:'rina');
select is(cs_api.respond_transfer(:'x2', true) -> 'owner' ->> 'display_name', 'Rina', 'Transfer diterima, pemilik berpindah');
reset role;
select is((select kind || ': ' || body from cs.agent_notes where session_id = :'t1' and kind = 'handover'),
  'handover: Nasabah perlu bantuan akun', 'Catatan serah terima tersimpan sebagai catatan internal');
select is((select m.body from public.messages m where m.session_id = :'t1' and m.payload ->> 'code' = 'ticket_transferred'),
  'Tiket dialihkan ke Rina – CS Resmi.', 'Nasabah diberi tahu tiket dialihkan');

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.reassign_ticket(%L, %L, '')$$, :'t1', :'joko'), 'PT400', 'reason_required',
  'Pemindahan oleh supervisor wajib alasan');
select is(cs_api.reassign_ticket(:'t1', :'joko', 'Nasabah mengajukan pengaduan') -> 'owner' ->> 'display_name', 'Joko',
  'Supervisor memindahkan tiket');
reset role;
select is((select details ->> 'reason' from cs.cs_audit_log where action = 'ticket.reassign' and session_id = :'t1'),
  'Nasabah mengajukan pengaduan', 'Pemindahan tercatat di audit log beserta alasannya');
select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Masih saya bantu')$$, :'t1'), 'PT403', 'not_ticket_owner',
  'Pemilik lama tidak bisa membalas lagi');
select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Halo')$$, :'t1'), 'PT403', 'role_forbidden',
  'Supervisor hanya memantau, tidak membalas nasabah');

select tests.authenticate_agent(:'joko');
select throws_ok(format($$select cs_api.resolve_ticket(%L, 'answered', '')$$, :'t1'), 'PT400', 'summary_required',
  'Menyelesaikan tiket wajib ringkasan');
select throws_ok(format($$select cs_api.resolve_ticket(%L, 'beres', 'Sudah dibantu reset')$$, :'t1'), 'PT400', 'invalid_outcome',
  'Hasil penyelesaian wajib dari daftar');
select is(cs_api.resolve_ticket(:'t1', 'answered', 'Akun berhasil dibuka kembali') ->> 'status', 'resolved',
  'Pemilik menyelesaikan tiket');
select is(jsonb_array_length(cs_api.ticket_lists() -> 'resolved_today'), 1, 'Tiket tercatat di Selesai hari ini');
reset role;
select is((select count(*)::integer from public.chat_members m where m.room_id = :'room' and cs.is_staff(m.user_id)), 0,
  'Semua CS keluar dari room saat tiket selesai');
select is((select kind from public.messages where session_id = :'t1' and payload ->> 'code' = 'ticket_resolved'), 'csat',
  'Pesan selesai sekaligus permintaan rating');

select tests.authenticate_as(:'budi');
select is(cs_api.rate_ticket(:'t1', 5, 'Cepat, password saya Rahasia123!') ->> 'rating', '5', 'Nasabah memberi rating');
select throws_ok(format($$select cs_api.rate_ticket(%L, 4)$$, :'t1'), 'PT409', 'cannot_rate', 'Rating hanya sekali');

select tests.agent_online(:'joko');
select is((select body from cs_api.send_message(:'room', 'Maaf, satu pertanyaan lagi')), 'Maaf, satu pertanyaan lagi',
  'Nasabah mengetik setelah tiket selesai');
reset role;
select is((select status || '/' || cs.agent_name(owner_agent_id) from cs.tickets where id = :'t1'), 'claimed/Joko',
  'Dalam 24 jam tiket dibuka kembali ke CS pemilik');
select is((select m.body from public.messages m where m.session_id = :'t1' and m.payload ->> 'code' = 'ticket_reopened_owner'),
  'Tiket #' || :'num1' || ' dibuka kembali dan ditangani Joko – CS Resmi.', 'Satu pesan saat tiket dibuka kembali');

select tests.authenticate_agent(:'joko');
select cs_api.resolve_ticket(:'t1', 'answered', 'Pertanyaan tambahan dijawab') ->> 'status' as r2 \gset
reset role;
update cs.agent_status set status = 'offline', status_changed_at = now() - interval '30 minutes' where agent_id = :'joko';
select tests.authenticate_as(:'budi');
select is((select body from cs_api.send_message(:'room', 'Halo, masih ada kendala')), 'Halo, masih ada kendala',
  'Nasabah mengetik lagi');
reset role;
select is((select status || '/' || coalesce(owner_agent_id::text, '-') from cs.tickets where id = :'t1'), 'open/-',
  'Pemilik offline lebih dari 10 menit: tiket dibuka kembali ke antrean');

select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'status' as c3 \gset
select cs_api.resolve_ticket(:'t1', 'answered', 'Selesai dibantu') ->> 'status' as r3 \gset
reset role;
update cs.tickets set resolved_at = now() - interval '25 hours' where id = :'t1';
select ok((cs.run_sweep() ->> 'tickets_closed')::integer >= 1, 'Sweep menutup tiket setelah masa buka kembali habis');
select is((select status from cs.tickets where id = :'t1'), 'closed', 'Tiket menjadi final');

select tests.authenticate_as(:'budi');
select is((select body from cs_api.send_message(:'room', 'Saya ada masalah baru')), 'Saya ada masalah baru',
  'Nasabah mengetik setelah tiket ditutup');
reset role;
select is((select count(*)::integer from cs.tickets where customer_id = :'budi'), 2, 'Pesan setelah tiket ditutup membuat tiket baru');
select id as t2 from cs.tickets where customer_id = :'budi' and status = 'open' \gset
select is((select topic || '/' || priority from cs.tickets where id = :'t2'), 'other/P4', 'Tiket baru memakai topik default');

select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t2') ->> 'status' as c4 \gset
select cs_api.agent_set_status('offline') ->> 'status' as off1 \gset
reset role;
select is((select status || '/' || cs.agent_name(owner_agent_id) from cs.tickets where id = :'t2'), 'claimed/Rina',
  'CS yang offline tetap menjadi pemilik tiketnya');
select is((select m.body from public.messages m where m.session_id = :'t2' and m.payload ->> 'code' = 'agent_away'),
  'CS Rina sedang tidak aktif. Pesan Anda tetap tersimpan dan akan dibalas.', 'Nasabah diberi tahu CS sedang tidak aktif');
select is((cs.run_sweep() ->> 'tickets_released')::integer, 0, 'Lepas otomatis mati secara default');
select cs.set_setting('ticket.auto_release_offline_minutes', '5', null) as v2 \gset
update cs.agent_status set status_changed_at = now() - interval '6 minutes' where agent_id = :'rina';
select cs.run_sweep() as sweep2 \gset
select is((select status from cs.tickets where id = :'t2'), 'open', 'Bila diaktifkan, tiket milik CS yang lama offline dilepas');
select cs.set_setting('ticket.auto_release_offline_minutes', '0', null) as v3 \gset

select tests.authenticate_as(:'budi');
select is(cs_api.close_ticket(:'t2') ->> 'status', 'closed', 'Nasabah mengakhiri chat');
reset role;
select is((select outcome from cs.tickets where id = :'t2'), 'customer_ended', 'Tiket yang diakhiri nasabah tercatat');

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('funds') ->> 'id' as t3 \gset
select tests.authenticate_as(:'tono');
select cs_api.open_ticket('orders') ->> 'id' as t4 \gset
reset role;
update cs.agents set max_active_tickets = 1 where user_id = :'dimas';
select tests.authenticate_agent(:'dimas');
select cs_api.claim_ticket(:'t3') ->> 'status' as c5 \gset
select throws_ok(format($$select cs_api.claim_ticket(%L)$$, :'t4'), 'PT409', 'ticket_limit', 'Batas tiket aktif per CS ditegakkan');
select is(tests.error_detail(format($$select cs_api.claim_ticket(%L)$$, :'t4')), 'Batas tiket aktif Anda sudah penuh (1/1)',
  'Pesan batas tiket jelas');
select is(jsonb_array_length(cs_api.ticket_lists() -> 'mine'), 1, 'Tab Tiket saya berisi tiket milik CS');
select ok(cs_api.ticket_lists() -> 'open' @> jsonb_build_array(jsonb_build_object('id', :'t4')),
  'Tab Terbuka berisi tiket yang belum diambil');
select is(jsonb_array_length(cs_api.search_tickets((select ticket_number from cs.tickets where id = :'t4'))), 1,
  'Cari tiket berdasarkan nomor');

reset role;
select cs.set_setting('assignment.mode', '"auto_assign"', null) as v4 \gset
select tests.agent_online(:'joko');
select cs.run_sweep() as sweep3 \gset
select is((select status || '/' || cs.agent_name(owner_agent_id) from cs.tickets where id = :'t4'), 'claimed/Joko',
  'Mode auto_assign menugaskan tiket terbuka ke CS Online yang tersedia');
select cs.set_setting('assignment.mode', '"claim"', null) as v5 \gset

select throws_ok(format($$select cs.set_status(%L, 'claimed', 'x')$$, :'t2'), 'PT409', 'invalid_transition',
  'State machine menolak transisi tidak sah');
select throws_ok(format($$update cs.tickets set owner_agent_id = null where id = %L$$, :'t4'), '23514', null,
  'Constraint: tiket yang sedang ditangani wajib punya pemilik');
select throws_ok(format($$insert into cs.tickets (room_id, customer_id, topic, priority, required_skill, ticket_number)
                           select room_id, customer_id, 'other', 'P4', 'general', 'CS-X' from cs.tickets where id = %L$$, :'t3'),
  '23505', null, 'Satu tiket aktif per nasabah (partial unique index)');

select tests.authenticate_as(:'sari');
select ok(cs_api.request_complaint() -> 'complaint' ->> 'due_at' is not null, 'Nasabah mengajukan pengaduan pada tiket aktif');
reset role;
select is((select priority || '/' || array_to_string(flags, ',') from cs.tickets where id = :'t3'), 'P2/complaint',
  'Pengaduan menaikkan prioritas ke P2');
select tests.authenticate_as(:'ratna');
select is(cs_api.report_fake_cs('Ada yang mengaku CS meminta OTP') ->> 'status', 'open', 'Laporan CS palsu membuat tiket');
reset role;
select is((select priority || '/' || array_to_string(flags, ',') from cs.tickets where customer_id = :'ratna'), 'P1/fraud',
  'Laporan CS palsu menjadi tiket P1 fraud');

select tests.authenticate_as(:'ratna');
select cs_api.close_ticket((cs_api.support_home() -> 'ticket' ->> 'id')::uuid) as e0 \gset
select cs_api.open_ticket('other') ->> 'id' as r1 \gset
select cs_api.close_ticket(:'r1') as e1 \gset
select cs_api.open_ticket('other') ->> 'id' as r2 \gset
select cs_api.close_ticket(:'r2') as e2 \gset
select cs_api.open_ticket('other') ->> 'id' as r3 \gset
select cs_api.close_ticket(:'r3') as e3 \gset
select cs_api.open_ticket('other') ->> 'id' as r4 \gset
select cs_api.close_ticket(:'r4') as e4 \gset
select throws_like($$select cs_api.open_ticket('other')$$, '%"rate_limited"%Batas 5 cs_ticket per 3600 detik%',
  'Nasabah dibatasi 5 tiket baru per jam');

reset role;
select cs.set_setting('service.hours',
  (select jsonb_object_agg(d::text, '["08:00", "20:00"]'::jsonb) from generate_series(1, 7) d
   where d <> extract(isodow from now() at time zone 'Asia/Jakarta')), null) as v6 \gset
select tests.authenticate_as(:'andi');
select cs_api.open_ticket('technical', 'en') ->> 'room_id' as room3 \gset
select ok((select bool_and(m.body like '%We are currently closed. An agent will reply from %')
           from cs_api.get_messages(:'room3'::uuid) m), 'Di luar jam layanan, info jam buka digabung dalam pesan tiket dibuka');

reset role;
select ok((select array_agg(distinct type) from cs.session_events where session_id = :'t1')
          @> '{opened,claimed,released,transfer_requested,transfer_rejected,transferred,reassigned,waiting_customer,customer_replied,resolved,reopened,closed}'::text[],
  'Semua kejadian tiket tercatat dengan siapa dan kapan');
select is((select count(*)::integer from cs.cs_audit_log where action = 'ticket.claim' and session_id = :'t1'), 3,
  'Setiap pengambilan tiket tercatat di audit log');
select tests.authenticate_as(:'budi');
select is(jsonb_array_length(cs_api.my_tickets()), 2, 'Nasabah melihat riwayat tiketnya');
select is((select count(*)::integer from cs_api.ticket_messages(:'t1') m where m.session_id <> :'t1'), 0,
  'Pesan per tiket bisa dibuka terpisah dari riwayat room');

select * from finish();
rollback;
