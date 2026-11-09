begin;
select plan(22);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';
delete from cs.guest_sessions;

select tests.create_user('tamu_cari') as budi \gset
select tests.create_agent('Rina Tamu', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Sinta Tamu', '{cs_super_admin}', '{}') as sinta \gset

select set_config('request.headers', '{"x-forwarded-for": "203.0.113.7, 10.0.0.1"}', true);

select tests.authenticate_anon();
select ok((cs_api.guest_config('id') ->> 'enabled')::boolean, 'Pengaduan tamu aktif secara bawaan');
select throws_ok($$select cs_api.guest_start('B', 'BUDI01', 'password', 'Saya lupa password akun saya')$$,
  'PT400', 'invalid_name', 'Nama terlalu pendek ditolak');
select throws_ok($$select cs_api.guest_start('Budi', 'bad id!', 'password', 'Saya lupa password akun saya')$$,
  'PT400', 'invalid_login_id', 'Login ID tidak valid ditolak');
select throws_ok($$select cs_api.guest_start('Budi', 'BUDI01', 'hack', 'Saya lupa password akun saya')$$,
  'PT400', 'invalid_problem', 'Jenis masalah di luar daftar ditolak');
select cs_api.guest_start('Pengadu Uniqxq', ' budi01 ', 'password', 'Saya lupa password dan tidak bisa login') as started \gset
select ok(char_length((:'started'::jsonb) ->> 'token') >= 40, 'Tamu menerima token sesi acak');
select is((:'started'::jsonb) -> 'ticket' ->> 'status', 'open', 'Pengaduan tamu masuk antrean CS');
select ((:'started'::jsonb) ->> 'token') as token \gset
select ((:'started'::jsonb) -> 'ticket' ->> 'id') as ticket \gset
select ok(cs_api.guest_poll(:'token') -> 'messages' @> '[{"body": "Saya lupa password dan tidak bisa login"}]',
  'Deskripsi masuk sebagai pesan pertama dan bisa dibaca tamu');
select ok(cs_api.guest_send(:'token', 'Login ID saya BUDI01') ? 'id', 'Tamu mengirim pesan lanjutan');
select throws_ok($$select cs_api.guest_poll('token-palsu-yang-cukup-panjang-123')$$, 'PT401', 'guest_session_expired',
  'Token palsu ditolak');
reset role;

select is((select login_id from cs.guest_sessions where ticket_id = :'ticket'), 'BUDI01', 'Login ID klaim disimpan huruf besar');
select is((select count(*)::integer from cs.guest_sessions where token_hash = :'token'), 0, 'Token tidak disimpan apa adanya');
select ok((select is_guest from public.profiles p join cs.tickets t on t.customer_id = p.id where t.id = :'ticket'),
  'Pengadu dibuatkan profil tamu');

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from public.search_profiles('Pengadu Uniqxq') s), 0, 'Profil tamu tidak muncul di pencarian pengguna');
reset role;

select tests.authenticate_agent(:'rina');
select tests.agent_online(:'rina');
select cs_api.claim_ticket(:'ticket') as claimed \gset
select ok((:'claimed'::jsonb) -> 'guest' @> '{"login_id": "BUDI01", "problem": "password", "verified": false, "recent_24h": 1}',
  'CS melihat tiket tamu belum terverifikasi beserta Login ID klaim');
select is(cs_api.ticket_customer_login(:'ticket'), '{"login_id": "BUDI01", "source": "guest"}'::jsonb,
  'Panel Akun Nasabah memakai Login ID klaim');
select lives_ok(format($$select cs_api.agent_send_message(%L, 'Reset password sudah dikirim ke email terdaftar', gen_random_uuid())$$, :'ticket'),
  'CS membalas tamu');
reset role;

select tests.authenticate_anon();
select ok(cs_api.guest_poll(:'token') -> 'messages' @> '[{"body": "Reset password sudah dikirim ke email terdaftar"}]',
  'Tamu melihat balasan CS');
select cs_api.guest_start('Orang Lain', 'BUDI01', 'pin', 'Saya juga mau reset PIN akun ini') ->> 'token' as second \gset
select cs_api.guest_start('Ketiga', 'BUDI02', 'pin', 'Pengaduan ketiga dari perangkat sama') is not null as third \gset
select throws_ok($$select cs_api.guest_start('Keempat', 'BUDI03', 'pin', 'Pengaduan keempat dari perangkat sama')$$,
  'PT429', 'rate_limited', 'Lebih dari 3 pengaduan per jam dari perangkat yang sama ditolak');
select lives_ok(format($$select cs_api.guest_end(%L)$$, :'second'), 'Tamu mengakhiri sesinya');
select throws_ok(format($$select cs_api.guest_poll(%L)$$, :'second'), 'PT401', 'guest_session_expired',
  'Sesi yang diakhiri tidak bisa dipakai lagi');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_set_setting('guest.enabled', 'false') -> 'value', 'false'::jsonb, 'Super Admin mematikan pengaduan tamu');
reset role;
select set_config('request.headers', '{"x-forwarded-for": "198.51.100.9"}', true);
select tests.authenticate_anon();
select throws_ok($$select cs_api.guest_start('Budi', 'BUDI01', 'password', 'Saya lupa password akun saya')$$,
  'PT403', 'guest_disabled', 'Pengaduan tamu ditolak saat dimatikan');
reset role;

select * from finish();
rollback;
