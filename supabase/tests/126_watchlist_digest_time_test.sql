begin;
select plan(19);

select tests.create_user('wd_budi') as budi \gset
select tests.create_agent('Sinta Jadwal', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Andi Jadwal', '{cs_agent}', '{"general": 1}') as andi \gset

select is(cs.setting('notifications.watchlist_digest_time'), '"17:05"'::jsonb, 'Jam ringkasan bawaan 17:05 WIB');
select ok(cs.admin_editable('notifications.watchlist_digest_time'), 'Jam ringkasan bisa diubah dari Hub');
select is((select schedule from cron.job where jobname = 'social-watchlist-digest'), '5 10 * * *',
  'Job ringkasan tetap 10.05 UTC (17.05 WIB) setelah migrasi');

select is(private.watchlist_digest_cron('00:00'), '0 17 * * *', '00:00 WIB = 17:00 UTC hari sebelumnya');
select is(private.watchlist_digest_cron('06:59'), '59 23 * * *', '06:59 WIB = 23:59 UTC');
select is(private.watchlist_digest_cron('07:00'), '0 0 * * *', '07:00 WIB = 00:00 UTC');
select is(private.watchlist_digest_cron('23:59'), '59 16 * * *', '23:59 WIB = 16:59 UTC');

select tests.authenticate_agent(:'andi');
select throws_ok($$select cs_api.admin_set_setting('notifications.watchlist_digest_time', '"08:00"')$$, 'PT403', null,
  'Agen biasa tidak bisa mengubah jam ringkasan');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_set_setting('notifications.watchlist_digest_time', '"6:30"')$$, 'PT400', 'invalid_setting',
  'Jam tanpa nol di depan ditolak');
select throws_ok($$select cs_api.admin_set_setting('notifications.watchlist_digest_time', '"24:00"')$$, 'PT400', 'invalid_setting',
  'Jam 24:00 ditolak');
select throws_ok($$select cs_api.admin_set_setting('notifications.watchlist_digest_time', '"06:30:00"')$$, 'PT400', 'invalid_setting',
  'Jam dengan detik ditolak');
select throws_ok($$select cs_api.admin_set_setting('notifications.watchlist_digest_time', '630')$$, 'PT400', 'invalid_setting',
  'Jam harus teks HH:MM');
select is(cs_api.admin_set_setting('notifications.watchlist_digest_time', '"06:30"') -> 'value', '"06:30"'::jsonb,
  'Super Admin mengubah jam ringkasan');
reset role;

select is((select schedule from cron.job where jobname = 'social-watchlist-digest'), '30 23 * * *',
  'Job dijadwalkan ulang ke 23.30 UTC (06.30 WIB)');
select is((select count(*)::integer from cron.job where jobname = 'social-watchlist-digest'), 1,
  'Penjadwalan ulang tidak membuat job ganda');
select is((select command from cron.job where jobname = 'social-watchlist-digest'), 'select private.watchlist_digest()',
  'Perintah job tidak berubah');
select ok(exists (select 1 from cs.cs_audit_log a where a.action = 'setting.update' and a.actor_id = :'sinta'
                    and a.details ->> 'key' = 'notifications.watchlist_digest_time'),
  'Perubahan jam ringkasan tercatat di jejak audit');
select ok(exists (select 1 from cs.cs_settings_history h where h.key = 'notifications.watchlist_digest_time'
                    and h.old_value = '"17:05"' and h.new_value = '"06:30"' and h.changed_by = :'sinta'),
  'Riwayat pengaturan menyimpan jam lama dan baru');

select tests.authenticate_as(:'budi');
select is(public.get_notification_prefs() -> 'watchlist_digest', '{"time": "06:30", "timezone": "Asia/Jakarta"}'::jsonb,
  'Preferensi notifikasi memberi tahu jam ringkasan ke aplikasi');
reset role;

select * from finish();
rollback;
