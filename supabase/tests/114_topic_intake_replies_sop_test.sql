begin;
select plan(16);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('in_budi') as budi \gset
select tests.create_user('in_sari') as sari \gset
select tests.create_agent('Laras Isian', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina Isian', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_set_topic_extras('account', '[]', '[]', null)$$, 'PT403', null,
  'CS biasa tidak bisa mengatur pertanyaan awal');
reset role;

select tests.authenticate_agent(:'laras');
select throws_ok($$select cs_api.admin_set_topic_extras('account', '[{"key": "Bad Key", "type": "text", "label_id": "Nama", "label_en": "Name"}]', '[]', null)$$,
  'PT400', 'invalid_intake', 'Kunci isian yang tidak valid ditolak');
select throws_ok($$select cs_api.admin_set_topic_extras('account', '[{"key": "bank", "type": "choice", "label_id": "Bank", "label_en": "Bank", "options": [{"value": "bca", "label_id": "BCA", "label_en": "BCA"}]}]', '[]', null)$$,
  'PT400', 'invalid_intake', 'Pilihan dengan satu opsi ditolak');
select throws_ok($$select cs_api.admin_set_topic_extras('account', '[]', '[{"id": "Sudah saya coba tapi masih gagal terus menerus ya kak", "en": "Tried"}]', null)$$,
  'PT400', 'invalid_customer_replies', 'Saran balasan lebih dari 40 karakter ditolak');
select ok(cs_api.admin_set_topic_extras('account',
  '[{"key": "login_id", "type": "text", "label_id": "ID login", "label_en": "Login ID", "required": true},
    {"key": "kejadian", "type": "date", "label_id": "Tanggal kejadian", "label_en": "Date", "required": false},
    {"key": "perangkat", "type": "choice", "label_id": "Perangkat", "label_en": "Device", "required": true,
     "options": [{"value": "android", "label_id": "Android", "label_en": "Android"}, {"value": "ios", "label_id": "iPhone", "label_en": "iPhone"}]}]',
  '[{"id": "Sudah saya coba", "en": "I already tried"}, {"id": "Belum bisa", "en": "Still not working"}]',
  'Minta ID login, cek riwayat login, jangan minta OTP.') @> '{"sop": "Minta ID login, cek riwayat login, jangan minta OTP."}',
  'Konten Layanan menyimpan isian, saran balasan, dan SOP');
reset role;

select ok(exists (select 1 from cs.cs_audit_log where actor_id = :'laras' and action = 'topic.extras'),
  'Perubahan isian topik tercatat di jejak audit');

select tests.authenticate_as(:'budi');
select ok((select x from jsonb_array_elements(cs_api.topics('en')) x where x ->> 'code' = 'account')
          -> 'intake' @> '[{"key": "perangkat", "label": "Device", "required": true, "options": [{"value": "ios", "label": "iPhone"}]}]',
  'Isian topik dikirim ke aplikasi sesuai bahasa');
select throws_ok($$select cs_api.open_ticket('account', 'id', null, false, '{"perangkat": "android"}')$$,
  'PT400', 'intake_required', 'Isian wajib harus diisi');
select throws_ok($$select cs_api.open_ticket('account', 'id', null, false, '{"login_id": "budi01", "perangkat": "nokia"}')$$,
  'PT400', 'invalid_intake_answers', 'Opsi di luar daftar ditolak');
select throws_ok($$select cs_api.open_ticket('account', 'id', null, false, '{"login_id": "budi01", "perangkat": "ios", "kejadian": "2026-02-30"}')$$,
  'PT400', 'invalid_intake_answers', 'Tanggal yang tidak ada ditolak');
select cs_api.open_ticket('account', 'id', 'home', false, '{"login_id": " budi01 ", "perangkat": "ios", "kejadian": "2026-11-08"}') as opened \gset
select is((:'opened'::jsonb) -> 'quick_replies', '["Sudah saya coba", "Belum bisa"]'::jsonb,
  'Nasabah menerima saran balasan topik');
select ok((:'opened'::jsonb) ? 'eta_minutes', 'Tiket antre memuat perkiraan waktu tunggu');
select is(cs_api.open_ticket('account', 'id', null, false, null) ->> 'id', (:'opened'::jsonb) ->> 'id',
  'Membuka lagi tiket aktif tidak meminta isian ulang');
reset role;

select ((:'opened'::jsonb) ->> 'id') as ticket \gset
select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'ticket') as claimed \gset
select is((:'claimed'::jsonb) -> 'intake',
  '[{"key": "login_id", "type": "text", "label": "ID login", "value": "budi01", "display": "budi01"},
    {"key": "kejadian", "type": "date", "label": "Tanggal kejadian", "value": "2026-11-08", "display": "2026-11-08"},
    {"key": "perangkat", "type": "choice", "label": "Perangkat", "value": "ios", "display": "iPhone"}]'::jsonb,
  'CS melihat jawaban pertanyaan awal di tiket');
select is((:'claimed'::jsonb) ->> 'topic_sop', 'Minta ID login, cek riwayat login, jangan minta OTP.',
  'CS melihat SOP topik di tiket');
reset role;

select tests.authenticate_as(:'sari');
select ok(not (cs_api.open_ticket('account', 'id', null, false, '{"login_id": "sari", "perangkat": "android"}') ? 'topic_sop'),
  'SOP internal tidak dikirim ke nasabah');
reset role;

select * from finish();
rollback;
