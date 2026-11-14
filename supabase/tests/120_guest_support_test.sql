begin;
select plan(34);

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
select is(cs_api.ticket_customer_login(:'ticket'), '{"login_id": null, "source": "guest"}'::jsonb,
  'Panel Akun Nasabah tidak memuat data akun untuk tiket tamu');
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
select is(cs_api.guest_end(:'second') -> 'ticket' ->> 'status', 'closed', 'Tamu mengakhiri pengaduan yang masih di antrean');
select throws_ok(format($$select cs_api.guest_poll(%L)$$, :'second'), 'PT401', 'guest_session_expired',
  'Sesi yang diakhiri tidak bisa dipakai lagi');
reset role;
select ok(not exists (select 1 from cs.tickets t join cs.guest_sessions g on g.ticket_id = t.id
                      where g.token_hash = encode(extensions.digest(:'second', 'sha256'), 'hex') and t.status = 'open'),
  'Pengaduan yang diakhiri keluar dari antrean CS');

select is((select active_tickets from cs.agent_status where agent_id = :'rina'), 1, 'CS memegang tiket tamu');
select tests.authenticate_anon();
select cs_api.guest_end(:'token') as ended \gset
select is((:'ended'::jsonb) -> 'ticket' ->> 'status', 'closed', 'guest_end mengembalikan tiket yang sudah ditutup');
select throws_ok(format($$select cs_api.guest_poll(%L)$$, :'token'), 'PT401', 'guest_session_expired',
  'Token lama tidak bisa dipakai setelah pengaduan diakhiri');
reset role;
select is((select status || '/' || close_reason || '/' || outcome from cs.tickets where id = :'ticket'),
  'closed/customer/customer_ended', 'Mengakhiri pengaduan menutup tiket seperti nasabah menutup tiketnya');
select ok((select closed_by = customer_id from cs.tickets where id = :'ticket'), 'Penutup tiket tercatat sebagai tamu');
select is((select active_tickets from cs.agent_status where agent_id = :'rina'), 0, 'Beban CS berkurang setelah tamu mengakhiri pengaduan');
select ok(not exists (select 1 from public.chat_members m join cs.tickets t on t.room_id = m.room_id
                      where t.id = :'ticket' and m.user_id = :'rina'), 'CS keluar dari room tamu');
select is((select count(*)::integer from public.messages where session_id = :'ticket' and payload ->> 'code' = 'ticket_closed'), 1,
  'Pesan sistem tiket ditutup muncul di chat');

select set_config('request.headers', '{"x-forwarded-for": "198.51.100.20"}', true);
select tests.authenticate_anon();
select cs_api.guest_start('Pengadu Selesai', 'BUDI04', 'locked', 'Akun saya terkunci setelah salah PIN') as resolved_start \gset
select ((:'resolved_start'::jsonb) ->> 'token') as token_r, ((:'resolved_start'::jsonb) -> 'ticket' ->> 'id') as ticket_r \gset
select cs_api.guest_start('Pengadu Tanpa Tiket', 'BUDI05', 'other', 'Sesi ini kehilangan tiketnya') ->> 'token' as token_n \gset
reset role;
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'ticket_r') ->> 'status' as claimed_r \gset
select cs_api.resolve_ticket(:'ticket_r', 'answered', 'Akun dibuka') ->> 'status' as resolved_r \gset
reset role;
update cs.guest_sessions set ticket_id = null where token_hash = encode(extensions.digest(:'token_n', 'sha256'), 'hex');
select tests.authenticate_anon();
select is(cs_api.guest_end(:'token_r') -> 'ticket' ->> 'status', 'closed', 'Tiket yang sudah selesai ikut ditutup saat tamu mengakhiri');
select is(cs_api.guest_end(:'token_n'), '{"ticket": null}'::jsonb, 'Sesi tanpa tiket diakhiri tanpa error');
reset role;
select is((select status || '/' || close_reason from cs.tickets where id = :'ticket_r'), 'closed/customer',
  'Alasan tutup tiket selesai: diakhiri tamu');

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
