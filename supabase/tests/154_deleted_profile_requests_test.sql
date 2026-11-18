begin;
select plan(6);

select tests.create_user('dp_ani') as ani \gset
select tests.create_user('dp_budi') as budi \gset

create function pg_temp.as_fresh(p_user uuid) returns void language sql as $$
  select tests.authenticate_with(p_user, jsonb_build_object('iat', extract(epoch from now())::bigint + 1));
$$;

select pg_temp.as_fresh(:'ani');
select lives_ok($$select private.check_request()$$, 'Akun aktif diterima');
select public.delete_my_account() as deleted \gset
reset role;

select pg_temp.as_fresh(:'ani');
select throws_ok($$select private.check_request()$$, 'PT403', 'account_rejoin_cooldown',
  'JWT baru untuk akun yang sudah dihapus (mis. dari cache auth-bridge) tetap ditolak');
select set_config('request.headers', '{"content-profile": "cs_api"}', true);
select lives_ok($$select private.check_request()$$, 'Jalur cs_api tidak memakai pemeriksaan profil komunitas');
select set_config('request.headers', '{}', true);
reset role;

select pg_temp.as_fresh(:'budi');
select lives_ok($$select private.check_request()$$, 'Akun lain tidak terpengaruh');
reset role;

update private.settings set value = '0' where key = 'account.rejoin_cooldown_hours';
select ok(not (public.upsert_olt_profile(:'ani', 'test:' || :'ani', 'dp_ani') ? 'rejoin_at'),
  'Setelah jeda, login lewat auth-bridge mengaktifkan akun lagi');
select pg_temp.as_fresh(:'ani');
select lives_ok($$select private.check_request()$$, 'Akun yang aktif lagi diterima');
reset role;

select * from finish();
rollback;
