begin;
select plan(45);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;
select set_config('cs.retention', 'on', true) as retention_on \gset
delete from cs.policy_confirmations;
select set_config('cs.retention', 'off', true) as retention_off \gset
select count(*) as secret_before from cs.cs_audit_log
  where action = 'message.secret_request_blocked' and created_at >= now() - interval '30 days' \gset

select tests.create_user('kp_budi') as budi \gset
select tests.create_user('kp_sari') as sari \gset
select tests.create_user('kp_dewi') as dewi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2, "complaint": 2, "fraud": 2}') as rina \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as complaint_id \gset
select cs_api.request_complaint() ->> 'id' as complaint_again \gset
select tests.authenticate_as(:'sari');
select cs_api.report_fake_cs('Ada yang mengaku CS meminta OTP saya') ->> 'id' as fraud_id \gset
select tests.authenticate_as(:'dewi');
select cs_api.open_ticket('account') ->> 'id' as plain_id \gset

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as online1 \gset
select cs_api.claim_ticket(:'complaint_id') ->> 'status' as claimed \gset
select cs_api.agent_send_message(:'complaint_id', 'Baik, pengaduan Anda kami proses') ->> 'status' as sent \gset
select cs_api.agent_send_message(:'complaint_id', 'Mohon sebutkan kode OTP Anda') ->> 'status' as blocked \gset
select cs_api.add_note('Nasabah minta dihubungi sore', :'complaint_id') as note1 \gset

select is(:'blocked'::text, 'blocked', 'Permintaan OTP dari CS diblokir');

select tests.authenticate_agent(:'kirana');
select lives_ok('select cs_api.compliance_overview()', 'Kepatuhan membuka ringkasan');
select is(jsonb_array_length(cs_api.compliance_cases(p_query => 'kp_') -> 'rows'), 2,
  'Register kasus hanya berisi tiket pengaduan dan penipuan');
select is((cs_api.compliance_cases('fraud', p_query => 'kp_') -> 'rows' -> 0 ->> 'id'), :'fraud_id', 'Filter jenis penipuan');
select is((cs_api.compliance_cases('fraud', p_query => 'kp_') -> 'rows' -> 0 ->> 'fake_cs')::boolean, true,
  'Laporan CS palsu ditandai di register');
select ok(cs_api.compliance_overview() -> 'secret_agents' @> '[{"display_name": "Rina", "count": 1}]',
  'Ringkasan menyebut CS yang mencoba meminta data rahasia');
select is((cs_api.compliance_overview() ->> 'secret_blocked')::integer, :secret_before + 1,
  'Ringkasan menghitung permintaan data rahasia yang diblokir');

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.compliance_overview()', 'PT403', 'role_forbidden', 'CS biasa tidak membuka menu Kepatuhan');
select tests.authenticate_agent(:'sinta');
select throws_ok('select cs_api.compliance_cases()', 'PT403', 'role_forbidden',
  'Super admin tidak membuka register Kepatuhan');
select throws_ok($$select cs_api.admin_set_setting('complaint.days', '7')$$, 'PT403', 'setting_locked',
  'Super admin tidak bisa mengubah tenggat pengaduan');

reset role;
update cs.tickets set complaint_due_at = now() + interval '14 days' where id = :'complaint_id';
select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_cases('complaint', p_query => 'kp_') -> 'rows' -> 0 -> 'deadline' ->> 'state', 'running',
  'Pengaduan dengan sisa waktu panjang berstatus berjalan');
select is(jsonb_array_length(cs_api.compliance_cases('all', 'attention', p_query => 'kp_') -> 'rows'), 0,
  'Belum ada kasus yang perlu perhatian');

reset role;
update cs.tickets set complaint_due_at = now() - interval '1 hour' where id = :'complaint_id';
select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_cases('complaint', p_query => 'kp_') -> 'rows' -> 0 -> 'deadline' ->> 'state', 'overdue',
  'Pengaduan aktif yang melewati tenggat berstatus terlambat');
select is((cs_api.compliance_cases('all', 'attention', p_query => 'kp_') -> 'rows' -> 0 ->> 'id'), :'complaint_id',
  'Pengaduan terlambat masuk daftar perlu perhatian');
select is((cs_api.compliance_overview() ->> 'overdue')::integer, 1, 'Ringkasan menghitung pengaduan terlambat');
select throws_ok(format('select cs_api.compliance_extend_deadline(%L, %L)', :'complaint_id', 'Butuh data dari bank kustodian'),
  'PT409', 'deadline_passed', 'Tenggat yang sudah lewat tidak bisa diperpanjang');

select throws_ok(format('select cs_api.compliance_case(%L)', :'plain_id'), 'PT404', 'ticket_not_found',
  'Kepatuhan tidak membuka tiket tanpa tanda');
select is(jsonb_array_length(cs_api.compliance_case(:'complaint_id') -> 'notes'), 1,
  'Detail kasus memuat catatan internal tiket');
select ok(jsonb_array_length(cs_api.compliance_case(:'complaint_id') -> 'events') > 0,
  'Detail kasus memuat riwayat kejadian');
select ok((select count(*) from cs_api.ticket_messages(:'complaint_id')) >= 2, 'Kepatuhan membaca transkrip kasus');

reset role;
select ok((select count(*) from cs.cs_audit_log
           where action = 'compliance.case_view' and actor_id = :'kirana' and session_id = :'complaint_id') >= 1,
  'Membuka detail kasus tercatat di audit log');

select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.compliance_review(%L, %L, %L)', :'complaint_id', 'ok', 'Sudah sesuai'),
  'PT400', 'invalid_verdict', 'Putusan tinjauan harus dikenal');
select throws_ok(format('select cs_api.compliance_review(%L, %L, %L)', :'complaint_id', 'compliant', 'ok'),
  'PT400', 'invalid_note', 'Catatan tinjauan minimal 5 karakter');
select is(cs_api.compliance_review(:'complaint_id', 'needs_action', 'Tenggat terlewat, minta penjelasan tim') ->> 'verdict',
  'needs_action', 'Kepatuhan menambah tinjauan');
select is(cs_api.compliance_cases('complaint', p_query => 'kp_') -> 'rows' -> 0 -> 'review' ->> 'verdict', 'needs_action',
  'Tinjauan terbaru tampil di register');
reset role;
select throws_ok(format($$update cs.compliance_reviews set verdict = 'compliant' where ticket_id = %L$$, :'complaint_id'),
  '42501', null, 'Tinjauan tidak bisa diubah');

update cs.tickets set complaint_due_at = now() + interval '3 days' where id = :'complaint_id';
select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.compliance_extend_deadline(%L, %L)', :'complaint_id', 'Singkat'),
  'PT400', 'invalid_reason', 'Alasan perpanjangan minimal 10 karakter');
select throws_ok(format('select cs_api.compliance_extend_deadline(%L, %L)', :'fraud_id', 'Butuh data dari bank kustodian'),
  'PT409', 'not_complaint', 'Hanya pengaduan yang bisa diperpanjang');
select ok((cs_api.compliance_extend_deadline(:'complaint_id', 'Butuh data dari bank kustodian') ->> 'complaint_due_at')::timestamptz
            > now() + interval '3 days', 'Tenggat pengaduan diperpanjang');
select throws_ok(format('select cs_api.compliance_extend_deadline(%L, %L)', :'complaint_id', 'Butuh data tambahan lagi'),
  'PT409', 'already_extended', 'Tenggat hanya bisa diperpanjang satu kali');
reset role;
select is((select count(*)::integer from public.messages
           where session_id = :'complaint_id' and kind = 'system' and body like '%membutuhkan waktu lebih lama%'), 1,
  'Nasabah menerima pesan perpanjangan tenggat');
select is((select count(*)::integer from cs.session_events where session_id = :'complaint_id' and type = 'complaint_extended'), 1,
  'Perpanjangan tercatat di riwayat tiket');

select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.compliance_transcript_exported(%L, %L, 3)', :'complaint_id', 'abc'),
  'PT400', 'invalid_hash', 'Sidik transkrip harus SHA-256 hex');
select is(cs_api.compliance_transcript_exported(:'complaint_id', repeat('a1', 32), 3) ->> 'sha256', repeat('a1', 32),
  'Unduhan transkrip mencatat sidiknya');
select ok(cs_api.compliance_audit((now() at time zone 'Asia/Jakarta')::date, (now() at time zone 'Asia/Jakarta')::date) -> 'actions' @> '[{"action": "compliance.transcript_export"}]',
  'Jejak audit memuat unduhan transkrip');
select throws_ok(format('select cs_api.compliance_audit(%L, %L)', (now() at time zone 'Asia/Jakarta')::date - 400, (now() at time zone 'Asia/Jakarta')::date),
  'PT400', 'invalid_range', 'Rentang jejak audit maksimal 366 hari');
select is((cs_api.compliance_audit((now() at time zone 'Asia/Jakarta')::date, (now() at time zone 'Asia/Jakarta')::date, 'compliance.review') -> 'rows' -> 0 -> 'actor' ->> 'display_name'),
  'Kirana', 'Jejak audit bisa difilter per aksi');

select is((select count(*)::integer from jsonb_array_elements(cs_api.compliance_policies() -> 'policies') p
           where (p ->> 'confirmed')::boolean), 0, 'Kebijakan awal belum dikonfirmasi');
select is(cs_api.compliance_confirm_policy('complaint.days', '5', 'Sesuai POJK') ->> 'confirmed', 'true',
  'Kepatuhan mengonfirmasi tenggat pengaduan');
select throws_ok($$select cs_api.compliance_confirm_policy('complaint.days', '30')$$, 'PT400', 'invalid_policy',
  'Tenggat pengaduan di luar 1–20 hari kerja ditolak');
select throws_ok($$select cs_api.compliance_confirm_policy('assignment.mode', '"claim"')$$, 'PT403', 'policy_locked',
  'Kepatuhan hanya mengubah kebijakan kepatuhan');
select is(cs_api.compliance_confirm_policy('retention.chat_years', '7') ->> 'value', '7',
  'Kepatuhan mengubah retensi chat');
select is((cs_api.compliance_overview() ->> 'policies_unconfirmed')::integer, 1,
  'Ringkasan menghitung kebijakan yang belum dikonfirmasi');

select tests.authenticate_agent(:'rina');
select cs_api.resolve_ticket(:'complaint_id', 'complaint', 'Dana dikembalikan ke rekening nasabah') ->> 'status' as resolved \gset
select tests.authenticate_as(:'sari');
select cs_api.close_ticket(:'fraud_id') as closed \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_cases('complaint', 'done', p_query => 'kp_') -> 'rows' -> 0 -> 'deadline' ->> 'state', 'met',
  'Pengaduan yang selesai sebelum tenggat berstatus tepat waktu');
select is((cs_api.compliance_cases('all', 'unreviewed', p_query => 'kp_') -> 'rows' -> 0 ->> 'id'), :'fraud_id',
  'Kasus selesai tanpa tinjauan masuk daftar belum ditinjau');

select * from finish();
rollback;
