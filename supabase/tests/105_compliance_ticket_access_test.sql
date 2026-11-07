begin;
select plan(23);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

select tests.create_user('ta_dewi') as dewi \gset
select tests.create_user('ta_budi') as budi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2, "complaint": 2, "fraud": 2}') as rina \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Wulan', '{compliance}', '{}') as wulan \gset

select tests.authenticate_as(:'dewi');
select cs_api.open_ticket('account') ->> 'id' as plain_id \gset
select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as complaint_id \gset
select cs_api.request_complaint() ->> 'id' as complaint_again \gset

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as online \gset
select cs_api.claim_ticket(:'plain_id') ->> 'status' as claimed \gset
select cs_api.agent_send_message(:'plain_id', 'Baik, kami cek aplikasinya') ->> 'status' as sent \gset
select cs_api.add_note('Nasabah memakai versi lama', :'plain_id') as note \gset
select throws_ok(format('select cs_api.compliance_case(%L)', :'plain_id'), 'PT403', 'role_forbidden',
  'CS biasa tidak membuka tiket lewat menu Kepatuhan');

reset role;
select room_id as plain_room from cs.tickets where id = :'plain_id' \gset

select tests.authenticate_agent(:'kirana');
select is((select count(*) from cs_api.ticket_messages(:'plain_id'))::integer, 0,
  'Sebelum dibuka, Kepatuhan tidak membaca chat tiket biasa');
select is(cs.can_read_room(:'plain_room'), false, 'Sebelum dibuka, room tiket biasa tertutup untuk Kepatuhan');
select throws_ok(format('select cs_api.compliance_transcript_exported(%L, %L, 1)', :'plain_id', repeat('b2', 32)),
  'PT404', 'ticket_not_found', 'Transkrip tiket biasa tidak bisa diekspor sebelum dibuka');

select is((cs_api.compliance_case(:'plain_id') ->> 'case')::boolean, false, 'Kepatuhan membuka tiket biasa');
select is(jsonb_array_length(cs_api.compliance_case(:'plain_id') -> 'notes'), 1,
  'Detail tiket biasa memuat catatan internal');
select ok((select count(*) from cs_api.ticket_messages(:'plain_id')) >= 1,
  'Setelah dibuka, Kepatuhan membaca chat tiket biasa');
select is(cs.can_read_room(:'plain_room'), true, 'Setelah dibuka, lampiran room tiket bisa dibaca');
select is(cs_api.compliance_transcript_exported(:'plain_id', repeat('b2', 32), 1) ->> 'sha256', repeat('b2', 32),
  'Transkrip tiket biasa bisa diekspor setelah dibuka');
select throws_ok(format('select cs_api.compliance_review(%L, %L, %L)', :'plain_id', 'compliant', 'Sudah sesuai SOP'),
  'PT404', 'ticket_not_found', 'Tinjauan tetap hanya untuk pengaduan dan penipuan');
select throws_ok(format('select cs_api.compliance_extend_deadline(%L, %L)', :'plain_id', 'Butuh data dari bank kustodian'),
  'PT404', 'ticket_not_found', 'Perpanjangan tenggat tetap hanya untuk pengaduan');

select is((cs_api.compliance_case(:'complaint_id') ->> 'case')::boolean, true, 'Detail kasus ditandai sebagai kasus');
select ok(cs_api.compliance_cases('tickets', p_query => 'ta_') -> 'rows' @> format('[{"id": "%s", "case": false}]', :'plain_id')::jsonb,
  'Pilihan semua tiket memuat tiket biasa');
select is(jsonb_array_length(cs_api.compliance_cases('all', p_query => 'ta_') -> 'rows'), 1,
  'Register kasus tetap hanya berisi pengaduan dan penipuan');
select throws_ok($$select cs_api.compliance_cases('everything')$$, 'PT400', 'invalid_kind', 'Jenis yang tidak dikenal ditolak');

select tests.authenticate_agent(:'wulan');
select is((select count(*) from cs_api.ticket_messages(:'plain_id'))::integer, 0,
  'Akses dari membuka tiket berlaku per petugas Kepatuhan');

reset role;
select is((select count(*) from cs.cs_audit_log
           where action = 'compliance.ticket_view' and actor_id = :'kirana' and session_id = :'plain_id')::integer, 2,
  'Setiap pembukaan tiket biasa tercatat di jejak audit');
select is((select count(*) from cs.cs_audit_log
           where action = 'compliance.ticket_view' and session_id = :'complaint_id')::integer, 0,
  'Membuka kasus tetap tercatat sebagai case_view');
select is((select count(*) from cs.compliance_ticket_access where ticket_id = :'complaint_id')::integer, 0,
  'Kasus tidak butuh catatan akses');

update cs.compliance_ticket_access set opened_at = now() - interval '13 hours' where agent_id = :'kirana';
select tests.authenticate_agent(:'kirana');
select is((select count(*) from cs_api.ticket_messages(:'plain_id'))::integer, 0, 'Akses berakhir setelah 12 jam');
select is(cs.can_read_room(:'plain_room'), false, 'Akses lampiran juga berakhir setelah 12 jam');
select lives_ok(format('select cs_api.compliance_case(%L)', :'plain_id'), 'Membuka lagi memperbarui akses');
select ok((select count(*) from cs_api.ticket_messages(:'plain_id')) >= 1, 'Setelah dibuka lagi, chat terbaca kembali');

select * from finish();
rollback;
