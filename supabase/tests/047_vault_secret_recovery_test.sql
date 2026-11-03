begin;
select plan(10);

delete from private.backup_runs;
delete from private.backup_state;
delete from vault.secrets where name in ('backup.s3_secret_access_key', 'backup.restic_password',
                                        'alerts.telegram_bot_token', 'alerts.smtp_password');
update private.backup_config
   set revision = 0, endpoint = null, bucket = null, prefix = null, region = null, access_key_id = null,
       secret_id = null, password_secret_id = null, password_set_at = null, configured_at = null;
update private.alert_channels
   set telegram_enabled = false, telegram_secret_id = null, telegram_chat_ids = '{}', email_enabled = false,
       smtp_host = null, smtp_secret_id = null, email_to = '{}';

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset

select tests.authenticate_agent(:'sinta');
select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', 's3-rahasia',
                                'password-backup-panjang');
select cs_api.alert_set_telegram(true, '{-1001234567890}', '123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ');
reset role;

select is((select count(*)::integer from private.health_checks_secrets()), 0, 'Rahasia yang terbaca tidak memunculkan masalah');

delete from vault.secrets where name in ('backup.restic_password', 'alerts.telegram_bot_token');

select is(cs.vault_read((select password_secret_id from private.backup_config)), null,
  'Rahasia yang tidak bisa dibaca dianggap kosong, bukan error');

select tests.authenticate_service();
select is(public.backup_config() - 'revision', '{"configured": false, "problem": "secret_unreadable"}',
  'Layanan backup diberi tahu rahasia tidak bisa dibuka');
select is(public.alert_channels() -> 'telegram', 'null'::jsonb, 'Kanal Telegram dengan token tak terbaca tidak dikirim ke sentinel');
reset role;

select is((select severity from private.health_checks_secrets() where key = 'backup:secret'), 'critical',
  'Rahasia backup yang tidak terbaca menjadi masalah kritis');
select is((select severity from private.health_checks_secrets() where key = 'alerts:secret'), 'warning',
  'Rahasia kanal alert yang tidak terbaca menjadi peringatan');

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', null,
                                                 'password-backup-panjang')$$,
  'Password repositori yang sama boleh diisi ulang bila rahasia lama tidak terbaca');
reset role;

select ok((select (details ->> 'password_recovered')::boolean from cs.cs_audit_log where action = 'backup.target_set'
           order by created_at desc limit 1), 'Audit menandai pemulihan password');

select tests.authenticate_service();
select is(public.backup_config() ->> 'password', 'password-backup-panjang', 'Layanan backup kembali menerima password');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', null,
                                                  'password-lain-yang-panjang')$$,
  'PT409', 'backup_password_locked', 'Setelah terbaca lagi, password tetap terkunci');
reset role;

select * from finish();
rollback;
