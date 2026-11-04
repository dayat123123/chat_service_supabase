begin;
select plan(60);

update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;
select cs.local_date(now()) as today \gset
select lower(cs.report_range(cs.local_date(now()), cs.local_date(now()))) as day_start \gset

select tests.create_user('self_budi') as budi \gset
select tests.create_user('self_sari') as sari \gset
select tests.create_user('self_tono') as tono \gset
select tests.create_user('self_wati') as wati \gset
select tests.create_user('self_joko') as joko \gset
select tests.create_user('self_lina') as lina \gset
select tests.create_agent('Rina Self', '{cs_agent}', '{"general": 2}', 'general', 4) as rina \gset
select tests.create_agent('Dimas Self', '{cs_agent}') as dimas \gset
select tests.create_agent('Kirana Self', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Sinta Self', '{cs_super_admin}', '{}') as sinta \gset
insert into auth.users (id, email, aud, role) values (:'rina', 'rina.self@cs.test', 'authenticated', 'authenticated');
update cs.agents set community_permissions = '{community.post}', nasabah_permissions = '{online_user.view}'
where user_id = :'rina';

select tests.authenticate_anon();
select throws_ok('select cs_api.agent_my_profile()', '42501', null, 'Anon tidak bisa membuka profil staf');
select throws_ok($$select cs_api.agent_my_stats('today')$$, '42501', null, 'Anon tidak bisa membuka kinerja staf');
select throws_ok('select cs_api.agent_password_changed()', '42501', null, 'Anon tidak bisa mencatat ganti password');
select throws_ok('select cs_api.agent_signed_out_everywhere()', '42501', null,
  'Anon tidak bisa mencatat keluar semua perangkat');

reset role;
select tests.authenticate_as(:'budi');
select throws_ok('select cs_api.agent_my_profile()', 'PT403', 'agent_required', 'Nasabah tidak bisa membuka profil staf');
select throws_ok($$select cs_api.agent_my_stats('7d')$$, 'PT403', 'agent_required', 'Nasabah tidak bisa membuka kinerja staf');
select throws_ok('select cs_api.agent_password_changed()', 'PT403', 'agent_required', 'Nasabah tidak bisa mencatat ganti password');
select throws_ok('select cs_api.agent_signed_out_everywhere()', 'PT403', 'agent_required',
  'Nasabah tidak bisa mencatat keluar semua perangkat');

reset role;
select tests.authenticate_agent(:'rina');
select cs_api.agent_my_profile() as prof \gset
select is(:'prof'::jsonb ->> 'email', 'rina.self@cs.test', 'Profil menampilkan email login');
select is(:'prof'::jsonb ->> 'display_name', 'Rina Self', 'Profil menampilkan nama tampilan');
select is(:'prof'::jsonb -> 'roles', '["cs_agent"]'::jsonb, 'Profil menampilkan peran');
select is(:'prof'::jsonb ->> 'team', 'general', 'Profil menampilkan kode tim');
select ok(:'prof'::jsonb #>> '{team_name,id}' is not null, 'Profil menampilkan nama tim');
select is((:'prof'::jsonb ->> 'max_active_tickets')::integer, 4, 'Profil menampilkan batas tiket');
select is(:'prof'::jsonb -> 'community_permissions', '["community.post"]'::jsonb, 'Profil menampilkan izin Komunitas');
select is(:'prof'::jsonb -> 'nasabah_permissions', '["online_user.view"]'::jsonb, 'Profil menampilkan izin Akun Nasabah');
select ok((:'prof'::jsonb ->> 'created_at')::timestamptz <= now(), 'Profil menampilkan tanggal akun dibuat');
select ok(:'prof'::jsonb -> 'password_changed_at' = 'null'::jsonb, 'Belum ada catatan ganti password');

select cs_api.agent_password_changed() as pw \gset
select ok((:'pw'::jsonb ->> 'password_changed_at')::timestamptz is not null, 'Ganti password mengembalikan waktunya');
select cs_api.agent_password_changed() as pw2 \gset
reset role;
select is((select count(*)::integer from cs.cs_audit_log where actor_id = :'rina' and action = 'agent.password_changed'), 1,
  'Ganti password tercatat sekali walau dipanggil ulang beruntun');
select is((select details from cs.cs_audit_log where actor_id = :'rina' and action = 'agent.password_changed'),
  jsonb_build_object('agent', :'rina'), 'Audit ganti password tanpa isi password');
select is((select actor_type from cs.cs_audit_log where actor_id = :'rina' and action = 'agent.password_changed'), 'agent',
  'Audit ganti password dicatat sebagai agen');
select tests.authenticate_agent(:'rina');
select ok((cs_api.agent_my_profile() ->> 'password_changed_at')::timestamptz is not null,
  'Profil menampilkan kapan password terakhir diganti');

select cs_api.agent_signed_out_everywhere() as so \gset
reset role;
select is((select count(*)::integer from cs.cs_audit_log where actor_id = :'rina' and action = 'agent.signed_out_everywhere'), 1,
  'Keluar dari semua perangkat tercatat di audit');

select tests.authenticate_agent(:'kirana');
select ok(cs_api.agent_my_profile() ->> 'email' is null, 'Profil tetap terbuka walau email login tidak ditemukan');
select is(cs_api.agent_my_profile() ->> 'display_name', 'Kirana Self', 'Staf non-CS bisa membuka profilnya sendiri');
select throws_ok($$select cs_api.agent_my_stats('today')$$, 'PT403', 'role_forbidden',
  'Staf yang tidak menangani tiket tidak punya halaman kinerja');
reset role;
select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.agent_my_stats('today')$$, 'PT403', 'role_forbidden',
  'Super Admin tanpa peran CS tidak punya halaman kinerja');

reset role;
select (cs.open_ticket(:'budi', 'account', 'id', '{}', '{}', null)).id as t1 \gset
select (cs.open_ticket(:'sari', 'account', 'id', '{}', '{}', null)).id as t2 \gset
select (cs.open_ticket(:'tono', 'account', 'id', '{}', '{}', null)).id as t3 \gset
select (cs.open_ticket(:'wati', 'account', 'id', '{}', '{}', null)).id as t4 \gset
select (cs.open_ticket(:'joko', 'account', 'id', '{}', '{}', null)).id as t5 \gset
select (cs.open_ticket(:'lina', 'account', 'id', '{}', '{}', null)).id as t6 \gset

update cs.tickets set created_at = :'day_start'::timestamptz + interval '1 minute' where id in (:'t1', :'t2', :'t5');
update cs.tickets set created_at = :'day_start'::timestamptz - interval '3 days' + interval '1 minute' where id = :'t3';
update cs.tickets set created_at = :'day_start'::timestamptz - interval '20 days' + interval '1 minute' where id = :'t4';
update cs.tickets set created_at = :'day_start'::timestamptz - interval '40 days' where id = :'t6';
update cs.tickets
   set status = 'closed', closed_at = now(), owner_agent_id = null, last_owner_id = :'rina',
       first_claimed_at = created_at + interval '2 minutes', first_response_at = created_at + interval '5 minutes',
       resolved_at = created_at + interval '20 minutes', resolved_by = :'rina', rating = 5
 where id = :'t1';
update cs.tickets
   set status = 'closed', closed_at = now(), owner_agent_id = null, last_owner_id = :'rina',
       first_claimed_at = created_at + interval '1 minute', first_response_at = created_at + interval '2 minutes',
       resolved_at = created_at + interval '30 minutes', resolved_by = :'dimas', rating = 3,
       flags = '{complaint}', complaint_received_at = now()
 where id = :'t2';
update cs.tickets
   set status = 'closed', closed_at = now(), owner_agent_id = null, last_owner_id = :'rina',
       first_claimed_at = created_at + interval '1 minute', first_response_at = created_at + interval '7 minutes',
       resolved_at = created_at + interval '60 minutes', resolved_by = :'rina', rating = 4
 where id = :'t3';
update cs.tickets set status = 'closed', closed_at = now(), owner_agent_id = null, last_owner_id = :'rina' where id = :'t4';
update cs.tickets
   set status = 'closed', closed_at = now(), owner_agent_id = null, last_owner_id = :'dimas',
       first_claimed_at = created_at, first_response_at = created_at + interval '1 minute',
       resolved_at = created_at + interval '2 minutes', resolved_by = :'dimas', rating = 1
 where id = :'t5';
update cs.tickets set status = 'claimed', owner_agent_id = :'rina', last_owner_id = :'rina',
       claimed_at = now(), first_claimed_at = now()
 where id = :'t6';

select tests.authenticate_agent(:'rina');
select cs_api.agent_my_stats('today') as d \gset
select is(:'d'::jsonb ->> 'period', 'today', 'Periode hari ini dikembalikan');
select is((:'d'::jsonb ->> 'from')::date, :'today'::date, 'Hari ini dimulai dari tanggal WIB hari ini');
select is((:'d'::jsonb ->> 'to')::date, :'today'::date, 'Hari ini berakhir di tanggal WIB hari ini');
select is((:'d'::jsonb ->> 'handled')::integer, 2, 'Hari ini: tiket yang ditangani terakhir oleh saya');
select is((:'d'::jsonb ->> 'resolved')::integer, 1, 'Hari ini: hanya tiket yang saya selesaikan');
select is((:'d'::jsonb ->> 'active_tickets')::integer, 1, 'Tiket sedang ditangani tidak bergantung periode');
select is((:'d'::jsonb ->> 'avg_first_response_minutes')::numeric, 2.0, 'Respons pertama dihitung dari tiket diambil');
select is((:'d'::jsonb ->> 'avg_resolution_minutes')::numeric, 20.0, 'Waktu selesai hanya dari tiket yang saya selesaikan');
select is((:'d'::jsonb ->> 'avg_rating')::numeric, 4.00, 'Rating rata-rata hari ini');
select is((:'d'::jsonb ->> 'ratings')::integer, 2, 'Jumlah rating hari ini');
select is(:'d'::jsonb -> 'rating_counts', '{"1": 0, "2": 0, "3": 1, "4": 0, "5": 1}'::jsonb, 'Distribusi rating 1–5');
select is((:'d'::jsonb ->> 'complaints')::integer, 1, 'Pengaduan dari tiket saya');

select cs_api.agent_my_stats('7d') as w \gset
select is((:'w'::jsonb ->> 'from')::date, :'today'::date - 6, '7 hari mencakup hari ini dan 6 hari sebelumnya');
select is((:'w'::jsonb ->> 'handled')::integer, 3, '7 hari: tiket ditangani');
select is((:'w'::jsonb ->> 'resolved')::integer, 2, '7 hari: tiket diselesaikan');
select is((:'w'::jsonb ->> 'avg_first_response_minutes')::numeric, 3.3, '7 hari: rata-rata respons pertama');
select is((:'w'::jsonb ->> 'avg_resolution_minutes')::numeric, 40.0, '7 hari: rata-rata waktu selesai');
select is((:'w'::jsonb ->> 'ratings')::integer, 3, '7 hari: jumlah rating');

select cs_api.agent_my_stats('30d') as m \gset
select is((:'m'::jsonb ->> 'from')::date, :'today'::date - 29, '30 hari mencakup hari ini dan 29 hari sebelumnya');
select is((:'m'::jsonb ->> 'handled')::integer, 4, '30 hari: tiket lama ikut, tiket di luar periode tidak');
select is((:'m'::jsonb ->> 'avg_first_response_minutes')::numeric, 3.3, 'Tiket tanpa respons tidak mengubah rata-rata');

select throws_ok($$select cs_api.agent_my_stats('90d')$$, 'PT400', 'invalid_period', 'Periode lain ditolak');
select throws_ok('select cs_api.agent_my_stats(null)', 'PT400', 'invalid_period', 'Periode kosong ditolak');

reset role;
select tests.authenticate_agent(:'dimas');
select is((cs_api.agent_my_stats('today') ->> 'handled')::integer, 1, 'Agen lain hanya melihat tiketnya sendiri');
select is(cs_api.agent_my_stats('today') -> 'rating_counts' ->> '1', '1', 'Distribusi rating milik agen lain terpisah');

reset role;
select tests.authenticate_agent(:'sinta');
select cs_api.report_summary((:'today'::date - 6)::date, :'today'::date) as rep \gset
select is((select x - 'id' - 'display_name' - 'agent_code' from jsonb_array_elements(:'rep'::jsonb -> 'agents') x where x ->> 'id' = :'rina'),
  jsonb_build_object('handled', (:'w'::jsonb -> 'handled'), 'resolved', (:'w'::jsonb -> 'resolved'),
                     'avg_first_response_minutes', (:'w'::jsonb -> 'avg_first_response_minutes'),
                     'avg_rating', (:'w'::jsonb -> 'avg_rating'), 'ratings', (:'w'::jsonb -> 'ratings')),
  'Angka kinerja saya sama dengan baris saya di laporan Super Admin');

reset role;
insert into auth.sessions (id, user_id) values ('5e1f0000-0000-4000-8000-000000000001', :'rina');
select tests.authenticate_with(:'rina', '{"session_id": "5e1f0000-0000-4000-8000-000000000001"}');
select is(cs_api.agent_me() ->> 'id', :'rina', 'Sesi yang masih ada tetap bisa bekerja');
reset role;
delete from auth.sessions where id = '5e1f0000-0000-4000-8000-000000000001';
select tests.authenticate_with(:'rina', '{"session_id": "5e1f0000-0000-4000-8000-000000000001"}');
select throws_ok('select cs_api.agent_me()', 'PT401', 'session_revoked', 'Sesi yang sudah dikeluarkan langsung ditolak');
select ok(cs.current_agent_id() is null, 'Sesi yang dikeluarkan tidak dianggap agen');
reset role;
select tests.authenticate_with(:'rina', '{"session_id": "bukan-uuid"}');
select throws_ok('select cs_api.agent_me()', 'PT401', 'session_revoked', 'ID sesi tidak sah ditolak');
reset role;
select tests.authenticate_with(:'budi', '{"session_id": "5e1f0000-0000-4000-8000-000000000002"}');
select throws_ok('select cs_api.agent_me()', 'PT403', 'agent_required', 'Nasabah tetap mendapat agent_required');
reset role;
select tests.authenticate_agent(:'rina');
select is(cs_api.agent_me() ->> 'id', :'rina', 'Token tanpa klaim sesi tetap diterima');

select * from finish();
rollback;
