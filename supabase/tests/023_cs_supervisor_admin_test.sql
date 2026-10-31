begin;
select plan(69);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.tickets set created_at = created_at - interval '400 days';
update cs.ticket_transfers set result = 'cancelled', responded_at = now() where result is null;
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;
select cs.local_date(now()) as today \gset

select tests.create_user('sa_budi') as budi \gset
select tests.create_user('sa_sari') as sari \gset
select tests.create_user('sa_tono') as tono \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}') as dimas \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{"general": 3}') as sinta \gset
select tests.create_agent('Adi', '{cs_super_admin}', '{}') as adi \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
select tests.authenticate_as(:'sari');
select cs_api.open_ticket('funds') ->> 'id' as t2 \gset
reset role;
update cs.tickets set queued_at = now() - interval '15 minutes' where id = :'t1';
update cs.tickets set flags = '{fraud}' where id = :'t2';

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.supervisor_overview()', 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka dashboard supervisor');

reset role;
select tests.authenticate_agent(:'sinta');
select cs_api.supervisor_overview() as ov \gset
select is((:'ov'::jsonb ->> 'open_count')::integer, 2, 'Dashboard menghitung tiket terbuka');
select ok((:'ov'::jsonb ->> 'oldest_open_at')::timestamptz < now() - interval '14 minutes',
  'Waktu tunggu terlama diambil dari tiket paling lama');
select is((select array_agg(x ->> 'id') from jsonb_array_elements(:'ov'::jsonb -> 'overdue') x), array[:'t1'],
  'Tiket terbuka melewati batas alert masuk daftar terlambat');
select is((select array_agg(x ->> 'id') from jsonb_array_elements(:'ov'::jsonb -> 'flagged_open') x), array[:'t2'],
  'Tiket fraud yang belum diambil ditandai');

reset role;
update cs.tickets set priority = 'P1', queued_at = now() - interval '3 minutes' where id = :'t2';
select tests.authenticate_agent(:'sinta');
select is((select count(*)::integer from jsonb_array_elements(cs_api.supervisor_overview() -> 'overdue')), 2,
  'Tiket P1 yang belum diambil lebih dari 2 menit ikut masuk alert');

reset role;
select tests.agent_online(:'rina');
select tests.agent_online(:'dimas');
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') as c1 \gset
select cs_api.agent_set_status('offline') as s1 \gset
reset role;
select tests.authenticate_agent(:'sinta');
select cs_api.supervisor_overview() as ov \gset
select is((select array_agg(x ->> 'id') from jsonb_array_elements(:'ov'::jsonb -> 'offline_owned') x), array[:'t1'],
  'Tiket milik CS yang offline ditandai di dashboard');
select is((select (x ->> 'active_tickets')::integer from jsonb_array_elements(:'ov'::jsonb -> 'agents') x
           where x ->> 'id' = :'rina'), 1, 'Daftar CS menampilkan jumlah tiket aktif');
select is((select x ->> 'status' from jsonb_array_elements(:'ov'::jsonb -> 'agents') x
           where x ->> 'id' = :'dimas'), 'online', 'Daftar CS menampilkan status');
select ok(not exists (select 1 from jsonb_array_elements(:'ov'::jsonb -> 'agents') x where x ->> 'id' = :'adi'),
  'Super admin tidak masuk daftar CS');

reset role;
select tests.authenticate_agent(:'rina');
select throws_ok(format('select cs_api.report_summary(%L, %L)', :'today', :'today'), 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka laporan');

reset role;
select tests.authenticate_agent(:'dimas');
select cs_api.claim_ticket(:'t2') as c2 \gset
select cs_api.agent_send_message(:'t2', 'Halo, saya cek deposit Anda.') as m2 \gset
select cs_api.resolve_ticket(:'t2', 'answered', 'Deposit sudah masuk') as r2 \gset
reset role;
select tests.authenticate_as(:'sari');
select cs_api.rate_ticket(:'t2', 4) as rt \gset

reset role;
select tests.authenticate_agent(:'sinta');
select cs_api.report_summary(:'today', :'today') as rep \gset
select is((:'rep'::jsonb #>> '{totals,created}')::integer, 2, 'Laporan menghitung tiket dalam rentang');
select is((:'rep'::jsonb #>> '{totals,resolved}')::integer, 1, 'Laporan menghitung tiket selesai');
select is((:'rep'::jsonb #>> '{totals,avg_rating}')::numeric, 4.00, 'Laporan menghitung rata-rata rating');
select is(jsonb_array_length(:'rep'::jsonb -> 'daily'), 1, 'Satu baris laporan per hari');
select is((select (x ->> 'avg_rating')::numeric from jsonb_array_elements(:'rep'::jsonb -> 'agents') x
           where x ->> 'id' = :'dimas'), 4.00, 'Laporan menampilkan rating per CS');
select is((select (x ->> 'count')::integer from jsonb_array_elements(:'rep'::jsonb -> 'topics') x
           where x ->> 'topic' = 'funds'), 1, 'Laporan menghitung topik');
select throws_ok(format('select cs_api.report_summary(%L, %L)', :'today', :'today'::date - 1), 'PT400', 'invalid_range',
  'Rentang terbalik ditolak');
select throws_ok(format('select cs_api.report_summary(%L, %L)', :'today'::date - 100, :'today'), 'PT400', 'invalid_range',
  'Rentang lebih dari 93 hari ditolak');
reset role;
select tests.authenticate_agent(:'adi');
select lives_ok(format('select cs_api.report_summary(%L, %L)', :'today', :'today'), 'Admin CS boleh membuka laporan');

reset role;
select tests.authenticate_agent(:'sinta');
select lives_ok('select cs_api.admin_agents()', 'Super admin mengelola akun CS');
reset role;
select tests.authenticate_agent(:'adi');
select ok(exists (select 1 from jsonb_array_elements(cs_api.admin_agents()) x
                  where x ->> 'id' = :'rina' and x -> 'roles' = '["cs_agent"]'), 'Admin melihat daftar akun CS');
select ok(cs_api.admin_options() -> 'teams' @> '[{"code": "general"}]' and cs_api.admin_options() -> 'skills' @> '[{"code": "fraud"}]',
  'Admin mendapat pilihan tim dan skill');

reset role;
select tests.authenticate_as(:'tono');
select cs_api.open_ticket('other') ->> 'id' as t3 \gset
reset role;
select tests.agent_online(:'rina');
select tests.authenticate_agent(:'dimas');
select cs_api.claim_ticket(:'t3') as c3 \gset
select cs_api.request_transfer(:'t3', :'rina', 'Mohon dibantu, saya mau istirahat') as tr \gset
reset role;
select tests.authenticate_agent(:'adi');
select cs_api.admin_update_agent(:'rina', 'Rina', '{cs_agent}', 'general', 3, true) as upd \gset
select ok((:'upd'::jsonb ->> 'disabled_at') is not null, 'Admin menonaktifkan akun CS');
reset role;
select is((select status || '|' || coalesce(owner_agent_id::text, '-') || '|' || returned_reason from cs.tickets where id = :'t1'),
  'open|-|Akun CS dinonaktifkan', 'Tiket aktif CS yang dinonaktifkan kembali open dan diberi tanda');
select is((select result || '|' || reason from cs.ticket_transfers where ticket_id = :'t3'),
  'cancelled|Akun CS dinonaktifkan', 'Transfer ke CS yang dinonaktifkan dibatalkan');
select is((select owner_agent_id from cs.tickets where id = :'t3'), :'dimas'::uuid, 'Tiket pengirim transfer tetap miliknya');
select is((select status from cs.agent_status where agent_id = :'rina'), 'offline', 'CS yang dinonaktifkan menjadi offline');
select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.agent_me()', 'PT403', 'agent_required', 'Akun nonaktif tidak bisa memakai API CS');

reset role;
select tests.authenticate_agent(:'adi');
select is(cs_api.admin_update_agent(:'rina', 'Rina Putri', '{cs_agent}', 'general', 4, false) ->> 'disabled_at',
  null, 'Admin mengaktifkan kembali akun CS');
reset role;
select is((select display_name from public.profiles where id = :'rina'), 'Rina Putri', 'Nama profil CS ikut diperbarui');
select tests.authenticate_agent(:'adi');
select throws_ok(format('select cs_api.admin_update_agent(%L, %L, %L, %L, 3, true)', :'adi', 'Adi', '{cs_super_admin}', 'general'),
  'PT400', 'cannot_change_self', 'Admin tidak bisa menonaktifkan akunnya sendiri');
select throws_ok(format('select cs_api.admin_update_agent(%L, %L, %L, %L, 3, false)', :'adi', 'Adi', '{cs_agent}', 'general'),
  'PT400', 'cannot_change_self', 'Admin tidak bisa melepas peran adminnya sendiri');
select throws_ok(format('select cs_api.admin_update_agent(%L, %L, %L, %L, 3, false)', :'dimas', 'D', '{cs_agent}', 'general'),
  'PT400', 'invalid_name', 'Nama CS terlalu pendek ditolak');
select throws_ok(format('select cs_api.admin_update_agent(%L, %L, %L, %L, 3, false)', :'dimas', 'Dimas', '{root}', 'general'),
  'PT400', 'invalid_roles', 'Peran tidak dikenal ditolak');
select throws_ok(format('select cs_api.admin_update_agent(%L, %L, %L, %L, 0, false)', :'dimas', 'Dimas', '{cs_agent}', 'general'),
  'PT400', 'invalid_limit', 'Batas tiket aktif 0 ditolak');
reset role;
select ok(exists (select 1 from cs.cs_audit_log where action = 'agent.update' and actor_id = :'adi' and details ->> 'agent' = :'rina'),
  'Perubahan akun CS tercatat di audit log');

select tests.authenticate_agent(:'adi');
select throws_ok(format('select cs_api.service_create_agent(%L, %L, %L, %L, 3, %L)', gen_random_uuid(), 'Baru', '{cs_agent}', 'general', :'adi'),
  '42501', null, 'Admin tidak bisa memanggil fungsi khusus layanan secara langsung');
reset role;
select gen_random_uuid() as newbie \gset
select tests.authenticate_service();
select is(cs_api.service_create_agent(:'newbie', 'Fajar', '{cs_agent}', 'general', 5, :'adi') ->> 'display_name', 'Fajar',
  'Layanan admin membuat akun CS baru');
select throws_ok(format('select cs_api.service_create_agent(%L, %L, %L, %L, 3, %L)', gen_random_uuid(), 'Gita', '{cs_agent}', 'general', :'dimas'),
  'PT403', 'admin_required', 'Pembuat akun harus admin CS aktif');
reset role;
select ok((select agent_code ~ '^CS-[0-9]{4,}$' from cs.agents where user_id = :'newbie'), 'Akun baru mendapat kode CS');
select ok(exists (select 1 from cs.cs_audit_log where action = 'agent.create' and actor_id = :'adi' and details ->> 'agent' = :'newbie'),
  'Pembuatan akun tercatat atas nama admin');

select tests.authenticate_agent(:'adi');
select throws_ok($$select cs_api.admin_save_topic('Bad Code', 'Topik', 'Topic', 'general', 'P3', null, 10, true)$$,
  'PT400', 'invalid_code', 'Kode topik tidak valid ditolak');
select throws_ok($$select cs_api.admin_save_topic('ipo', 'IPO', 'IPO', 'trading', 'P3', 'https://evil.example.com/ipo', 10, true)$$,
  'PT400', 'invalid_help_link', 'Tautan bantuan di luar situs resmi ditolak');
select ok(exists (select 1 from jsonb_array_elements(
                    cs_api.admin_save_topic('ipo', 'Penawaran umum', 'IPO', 'trading', 'P3', 'https://help.olt.co.id/ipo', 15, true)) x
                  where x ->> 'code' = 'ipo' and x ->> 'help_url' = 'https://help.olt.co.id/ipo'), 'Admin menambah topik');
select throws_ok($$select cs_api.admin_save_topic('other', 'Lainnya', 'Other', 'general', 'P4', null, 90, false)$$,
  'PT400', 'default_topic', 'Topik bawaan tidak bisa dinonaktifkan');

select throws_ok($$select cs_api.admin_save_quick_reply(null, 'otp', 'Minta OTP', 'Mohon sebutkan kode OTP Anda', 'id', true)$$,
  'PT400', 'secret_request_blocked', 'Quick reply yang meminta OTP ditolak');
select ok(exists (select 1 from jsonb_array_elements(
                    cs_api.admin_save_quick_reply(null, 'tes-salam', 'Salam', 'Halo {nama}, ada yang bisa dibantu?', 'id', true)) x
                  where x ->> 'shortcut' = 'tes-salam'), 'Admin menambah quick reply global');
select throws_ok($$select cs_api.admin_save_quick_reply(null, 'tes-salam', 'Salam 2', 'Halo', 'id', true)$$,
  'PT409', 'duplicate_shortcut', 'Pintasan ganda ditolak');
select throws_ok($$select cs_api.admin_save_quick_reply(null, 'Bad Shortcut', 'X', 'Y', 'id', true)$$,
  'PT400', 'invalid_shortcut', 'Pintasan tidak valid ditolak');

select throws_ok($$select cs_api.admin_set_setting('retention.chat_years', '5')$$,
  'PT403', 'setting_locked', 'Masa retensi tidak bisa diubah dari console');
select throws_ok($$select cs_api.admin_set_setting('assignment.mode', '"random"')$$,
  'PT400', 'invalid_setting', 'Mode penugasan tidak dikenal ditolak');
select is(cs_api.admin_set_setting('ticket.auto_release_offline_minutes', '30') -> 'value', '30'::jsonb,
  'Admin mengaktifkan lepas otomatis');
select throws_ok($$select cs_api.admin_set_setting('ticket.auto_release_offline_minutes', '-5')$$,
  'PT400', 'invalid_setting', 'Menit negatif ditolak');
select throws_ok($$select cs_api.admin_set_setting('messages.agent_away', '{"id": "CS {agent} pergi {foo}", "en": "{agent} away"}')$$,
  'PT400', 'invalid_setting', 'Variabel pesan yang tidak dikenal ditolak');
select is(cs_api.admin_set_setting('messages.agent_away',
  '{"id": "CS {agent} sedang istirahat sebentar. Pesan Anda aman dan akan dibalas.", "en": "{agent} is on a short break. Your messages are safe and will be answered."}') #>> '{value,id}',
  'CS {agent} sedang istirahat sebentar. Pesan Anda aman dan akan dibalas.', 'Admin mengubah pesan otomatis');
select throws_ok($$select cs_api.admin_set_setting('service.hours', '{"1": ["08:00", "22:00"]}')$$,
  'PT400', 'invalid_setting', 'Jam layanan harus lengkap 7 hari');
select throws_ok($$select cs_api.admin_set_setting('service.hours', '{"1": ["22:00", "08:00"], "2": null, "3": null, "4": null, "5": null, "6": null, "7": null}')$$,
  'PT400', 'invalid_setting', 'Jam buka setelah jam tutup ditolak');
select lives_ok($$select cs_api.admin_set_setting('service.hours', '{"1": ["08:00", "24:00"], "2": ["08:00", "22:00"], "3": ["08:00", "22:00"], "4": ["08:00", "22:00"], "5": ["08:00", "22:00"], "6": null, "7": null}')$$,
  'Admin mengatur jam layanan, akhir pekan tutup');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.admin_settings()) x where x ->> 'key' = 'retention.chat_years'),
  'Daftar pengaturan hanya berisi yang boleh diubah admin');
reset role;
select is((select changed_by from cs.cs_settings_history where key = 'ticket.auto_release_offline_minutes' order by version desc limit 1),
  :'adi'::uuid, 'Riwayat pengaturan mencatat admin yang mengubah');

select tests.authenticate_agent(:'adi');
select is(jsonb_array_length(cs_api.admin_save_holiday('2027-03-20', 'Hari Raya Nyepi', 'national')), 1, 'Admin menambah hari libur');
select throws_ok($$select cs_api.admin_save_holiday('2027-03-21', 'Libur', 'weekend')$$,
  'PT400', 'invalid_kind', 'Jenis hari libur tidak dikenal ditolak');
select is(jsonb_array_length(cs_api.admin_delete_holiday('2027-03-20')), 0, 'Admin menghapus hari libur');
select throws_ok($$select cs_api.admin_delete_holiday('2027-03-20')$$,
  'PT404', 'holiday_not_found', 'Menghapus hari libur yang tidak ada ditolak');

reset role;
select tests.authenticate_anon();
select throws_ok('select cs_api.supervisor_overview()', '42501', null, 'Anon tidak bisa membuka dashboard');
select throws_ok($$select cs_api.admin_set_setting('assignment.mode', '"claim"')$$, '42501', null, 'Anon tidak bisa mengubah pengaturan');
reset role;
select tests.authenticate_as(:'budi');
select throws_ok('select cs_api.admin_agents()', 'PT403', 'agent_required', 'Nasabah tidak bisa membuka pengaturan admin');
reset role;
select tests.authenticate_agent(:'adi', 'aal1');
select lives_ok('select cs_api.admin_settings()', 'Super admin cukup login email + password, tanpa 2FA');

select * from finish();
rollback;
