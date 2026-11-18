begin;
select plan(20);

select tests.create_user('rj_ani') as ani \gset
select tests.create_user('rj_budi') as budi \gset
select tests.create_user('rj_cici') as cici \gset
select tests.create_agent('Kirana RJ', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Rina RJ', '{cs_agent}', '{"general": 1}') as rina \gset
select cs.set_setting('compliance.policy_four_eyes', 'false', null) as four_eyes_off \gset

select is(private.setting_num('account.rejoin_cooldown_hours', 0), 72::numeric, 'Jeda bawaan 72 jam');
select is((public.get_client_config() -> 'config' ->> 'account_rejoin_cooldown_hours')::int, 72,
  'Konfigurasi klien memuat jeda bergabung lagi');

select tests.authenticate_as(:'ani');
select public.delete_my_account() as deleted \gset
reset role;

select public.upsert_olt_profile(:'ani', 'test:' || :'ani', 'rj_ani', 'Ani', 'ani@contoh.id') as again \gset
select ok(:'again'::jsonb ? 'rejoin_at', 'Login dalam masa tunggu mengembalikan rejoin_at');
select is((:'again'::jsonb ->> 'rejoin_at')::timestamptz,
          (select deleted_at + interval '72 hours' from public.profiles where id = :'ani'),
  'rejoin_at = waktu hapus + 72 jam');
select ok((select deleted_at is not null and username::text like 'deleted\_%' from public.profiles where id = :'ani'),
  'Profil tetap terhapus selama masa tunggu');
select is((select count(*)::int from private.user_private where user_id = :'ani'), 0,
  'Email tidak disimpan ulang selama masa tunggu');
select is((:'again'::jsonb ->> 'banned')::boolean, false, 'Status ban tetap dilaporkan');

update public.profiles set deleted_at = now() - interval '73 hours' where id = :'ani';
select public.upsert_olt_profile(:'ani', 'test:' || :'ani', 'rj_ani', 'Ani') as later \gset
select ok(not (:'later'::jsonb ? 'rejoin_at'), 'Setelah masa tunggu, login berjalan biasa');
select ok((select deleted_at is null and trust_level = 0 and username::text = 'rj_ani' from public.profiles where id = :'ani'),
  'Setelah masa tunggu, profil aktif lagi sebagai akun baru');

select tests.authenticate_as(:'budi');
select public.delete_my_account() as deleted \gset
reset role;
insert into private.user_sanctions (user_id, kind, reason) values (:'budi', 'ban', 'uji');
select public.upsert_olt_profile(:'budi', 'test:' || :'budi', 'rj_budi') as banned \gset
select ok((:'banned'::jsonb ->> 'banned')::boolean and :'banned'::jsonb ? 'rejoin_at',
  'Akun yang di-ban dan baru dihapus melaporkan keduanya');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.compliance_set_rejoin_cooldown_hours(24)$$, 'PT403', 'role_forbidden',
  'CS biasa tidak bisa mengatur jeda');
reset role;
select tests.authenticate_agent(:'kirana');
select is((cs_api.compliance_content_rules() ->> 'rejoin_cooldown_hours')::int, 72, 'Hub melihat jeda saat ini');
select throws_ok($$select cs_api.compliance_set_rejoin_cooldown_hours(721)$$, 'PT400', 'invalid_setting', 'Jeda maksimal 720 jam');
select throws_ok($$select cs_api.compliance_set_rejoin_cooldown_hours(-1)$$, 'PT400', 'invalid_setting', 'Jeda tidak boleh negatif');
select is((cs_api.compliance_set_rejoin_cooldown_hours(0) ->> 'rejoin_cooldown_hours')::int, 0, 'Jeda bisa dimatikan');
select cs_api.compliance_policy_call('compliance_set_rejoin_cooldown_hours', '{"p_hours": 24}') ->> 'policy_draft' as ignore \gset
select is(cs_api.compliance_policy_submit('Jeda bergabung lagi satu hari') ->> 'status', 'approved',
  'Jeda bisa diubah lewat draf kebijakan');
reset role;
select is(private.setting_num('account.rejoin_cooldown_hours', 0), 24::numeric, 'Draf yang disetujui mengubah jeda');
select is((select snapshot -> 'settings' -> 'account.rejoin_cooldown_hours' from cs.policy_versions
           order by version desc limit 1), '24'::jsonb, 'Jeda tercatat di riwayat versi kebijakan');
select is((select count(*)::int from cs.cs_audit_log where action = 'content_rule.rejoin_cooldown_hours'), 1,
  'Perubahan jeda langsung tercatat di audit');

update private.settings set value = '0' where key = 'account.rejoin_cooldown_hours';
select tests.authenticate_as(:'cici');
select public.delete_my_account() as deleted \gset
reset role;
select ok(not (public.upsert_olt_profile(:'cici', 'test:' || :'cici', 'rj_cici') ? 'rejoin_at'),
  'Jeda 0: login langsung aktif lagi');

select * from finish();
rollback;
