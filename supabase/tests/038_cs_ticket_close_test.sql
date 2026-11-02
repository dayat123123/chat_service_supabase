begin;
select plan(35);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as hours \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

select (now() at time zone 'Asia/Jakarta')::date as today \gset
select tests.create_user('tc_budi') as budi \gset
select tests.create_user('tc_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{"general": 3}') as sinta \gset
select tests.agent_online(:'rina');

select is(cs.setting_int('ticket.auto_close_days'), 3, 'Tiket selesai tanpa rating ditutup otomatis setelah 3 hari secara default');
select ok(not exists (select 1 from cs.cs_settings where key = 'ticket.reopen_hours'), 'Pengaturan masa buka kembali dalam jam sudah tidak dipakai');

select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_set_setting('ticket.auto_close_days', '5') ->> 'value', '5', 'Super Admin mengatur batas hari tutup otomatis');
select throws_ok($$select cs_api.admin_set_setting('ticket.auto_close_days', '0')$$, 'PT400', 'invalid_setting',
  'Batas tutup otomatis minimal 1 hari');
select throws_ok($$select cs_api.admin_set_setting('ticket.auto_close_days', '31')$$, 'PT400', 'invalid_setting',
  'Batas tutup otomatis maksimal 30 hari');
select throws_ok($$select cs_api.admin_set_setting('ticket.auto_close_days', '"5"')$$, 'PT400', 'invalid_setting',
  'Batas tutup otomatis harus angka');
reset role;

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'status' as c1 \gset
select cs_api.agent_send_message(:'t1', 'Halo, saya bantu cek') ->> 'status' as m1 \gset
select cs_api.resolve_ticket(:'t1', 'answered', 'Password direset') ->> 'status' as r1 \gset
select tests.authenticate_as(:'budi');
select cs_api.support_home() -> 'ticket' ->> 'reopen_until' as until1 \gset
reset role;
select is(:'until1'::timestamptz, (select resolved_at + interval '5 days' from cs.tickets where id = :'t1'),
  'Tiket selesai masih bisa dibalas sampai batas hari tutup otomatis');

select tests.authenticate_as(:'budi');
select cs_api.rate_ticket(:'t1', 5, 'Cepat') as rated \gset
select is(:'rated'::jsonb ->> 'status', 'closed', 'Tiket langsung ditutup setelah dinilai nasabah');
select is(:'rated'::jsonb -> 'reopen_until', 'null'::jsonb, 'Tiket yang sudah dinilai tidak bisa dibuka kembali');
select is(:'rated'::jsonb ->> 'close_reason', 'rated', 'Nasabah melihat alasan tiket ditutup');
select throws_ok(format($$select cs_api.send_message(%L, 'Satu pertanyaan lagi')$$, :'room'), 'PT409', 'ticket_closed',
  'Nasabah tidak bisa chat lagi di tiket yang sudah dinilai');
select is(tests.error_detail(format($$select cs_api.send_message(%L, 'Halo')$$, :'room')),
  'Tiket #' || (:'j'::jsonb ->> 'ticket_number') || ' sudah ditutup. Buat tiket baru untuk chat lagi',
  'Penolakan menyebut nomor tiket dan cara melanjutkan');
reset role;
select is((select close_reason || '/' || (closed_by = :'budi')::text from cs.tickets where id = :'t1'), 'rated/true',
  'Alasan tutup dicatat: dinilai nasabah');
select is((select count(*)::integer from public.messages where session_id = :'t1' and payload ->> 'code' = 'ticket_closed'), 1,
  'Pesan sistem tiket ditutup muncul di chat');
select is((select array_agg(type order by created_at, id) from cs.session_events where session_id = :'t1' and type in ('rated', 'closed')),
  '{rated,closed}'::text[], 'Jejak tiket: dinilai lalu ditutup');
select is((select count(*)::integer from public.messages where room_id = :'room' and body like 'Satu pertanyaan lagi%'), 0,
  'Pesan yang ditolak tidak tersimpan');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('other') ->> 'id' as t2 \gset
select isnt(:'t2'::uuid, :'t1'::uuid, 'Nasabah membuat tiket baru untuk chat lagi');
select is((select body from cs_api.send_message(:'room', 'Ada masalah baru')), 'Ada masalah baru', 'Chat berlanjut di tiket baru');
reset role;
select is((select session_id::text from public.messages where room_id = :'room' and body = 'Ada masalah baru'), :'t2',
  'Pesan masuk ke tiket baru');

select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t2') ->> 'status' as c2 \gset
select cs_api.resolve_ticket(:'t2', 'answered', 'Dijawab') ->> 'status' as r2 \gset
reset role;
update cs.tickets set resolved_at = now() - interval '5 days 1 minute' where id = :'t2';
select tests.authenticate_as(:'budi');
select throws_ok(format($$select cs_api.send_message(%L, 'Halo?')$$, :'room'), 'PT409', 'ticket_closed',
  'Lewat batas hari, nasabah tidak bisa membalas walau sweep belum berjalan');
reset role;
select is((cs.run_sweep() ->> 'tickets_closed')::integer, 1, 'Sweep menutup tiket selesai yang belum dinilai setelah batas hari');
select is((select status || '/' || close_reason from cs.tickets where id = :'t2'), 'closed/reopen_window_passed',
  'Alasan tutup: tidak dinilai sampai batas hari');
select tests.authenticate_as(:'budi');
select is(cs_api.rate_ticket(:'t2', 4) ->> 'rating', '4', 'Tiket yang ditutup otomatis masih bisa dinilai');
reset role;
select is((select status || '/' || close_reason from cs.tickets where id = :'t2'), 'closed/reopen_window_passed',
  'Menilai tiket yang sudah ditutup tidak mengubah alasan tutup');

select tests.authenticate_as(:'sari');
select cs_api.open_ticket('other') ->> 'id' as t3 \gset
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t3') ->> 'status' as c3 \gset
select cs_api.resolve_ticket(:'t3', 'answered', 'Dijawab') ->> 'status' as r3 \gset
reset role;
update cs.tickets set rating = 3, rated_at = now() where id = :'t3';
select cs.run_sweep() ->> 'tickets_closed' as swept \gset
select is((select status || '/' || close_reason from cs.tickets where id = :'t3'), 'closed/rated',
  'Tiket selesai yang sudah dinilai sebelum pembaruan ikut ditutup sweep');

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.report_customers(%L, %L)$$, :'today', :'today'), 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka laporan per nasabah');
select throws_ok(format($$select cs_api.report_customer_trail(%L, %L, %L)$$, :'budi', :'today', :'today'), 'PT403',
  'role_forbidden', 'CS biasa tidak bisa membuka jejak layanan nasabah');
select tests.authenticate_agent(:'sinta');
select cs_api.report_customers(:'today', :'today', 'tc_budi') as rc \gset
select is(jsonb_array_length(:'rc'::jsonb), 1, 'Super Admin mencari nasabah di laporan');
select is((:'rc'::jsonb -> 0) - 'id' - 'last_ticket_at' - 'avg_first_response_minutes' - 'avg_resolution_minutes',
  jsonb_build_object('display_name', 'Tc Budi', 'username', 'tc_budi', 'tickets', 2, 'resolved', 2, 'reopened', 0,
                     'complaints', 0, 'avg_rating', 4.50, 'ratings', 2, 'closed_unrated', 1),
  'Ringkasan performa per nasabah');
select is(jsonb_array_length(cs_api.report_customers(:'today', :'today', '%')), 0, 'Tanda % dicari apa adanya');
select throws_ok(format($$select cs_api.report_customers(%L, %L)$$, :'today', (:'today'::date - 1)), 'PT400', 'invalid_range',
  'Rentang laporan harus valid');

select cs_api.report_customer_trail(:'budi', :'today', :'today') as trail \gset
select is((select array_agg(x ->> 'close_reason' order by x ->> 'close_reason') from jsonb_array_elements(:'trail'::jsonb -> 'tickets') x),
  '{rated,reopen_window_passed}'::text[], 'Jejak layanan berisi semua tiket nasabah beserta alasan tutup');
select ok((select (x ->> 'first_response_minutes') is not null and x ->> 'agent' = 'Rina'
           and (select bool_or(e ->> 'type' = 'rated') from jsonb_array_elements(x -> 'events') e)
           from jsonb_array_elements(:'trail'::jsonb -> 'tickets') x where x ->> 'id' = :'t1'),
  'Jejak tiket memuat waktu respons, CS penangan, dan event penilaian');
select throws_ok(format($$select cs_api.report_customer_trail(%L, %L, %L)$$, gen_random_uuid(), :'today', :'today'), 'PT404',
  'customer_not_found', 'Nasabah tanpa tiket tidak bisa dibuka');
reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'report.customer_trail' and customer_id = :'budi' and actor_id = :'sinta'), 1,
  'Membuka jejak layanan nasabah tercatat di audit log');

select * from finish();
rollback;
