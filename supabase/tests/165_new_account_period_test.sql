begin;
select plan(22);

update private.settings set value = '3' where key = 'safety.new_account_days';
update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message');

insert into public.profiles (id, olt_user_id, username, display_name, trust_level) values
  ('a1870000-0000-4000-8000-000000000001', 'test:nap-fresh', 'nap_fresh', 'Fresh', 0);
insert into public.profiles (id, olt_user_id, username, display_name, trust_level, created_at) values
  ('a1870000-0000-4000-8000-000000000002', 'test:nap-two', 'nap_two', 'Two Days', 0, now() - interval '2 days'),
  ('a1870000-0000-4000-8000-000000000003', 'test:nap-four', 'nap_four', 'Four Days', 0, now() - interval '4 days');
select tests.create_user('nap_recent') as recent \gset
select tests.create_user('nap_old') as old \gset
select tests.create_user('nap_trusted') as trusted \gset
insert into private.account_signups (user_id, signed_up_at) values
  (:'recent', now() - interval '1 day'),
  (:'old', now() - interval '10 days'),
  (:'trusted', now() - interval '1 day');
update public.profiles set trust_level = 2 where id = :'trusted';
update public.profiles set created_at = now() - interval '10 days' where id = :'old';
\set fresh 'a1870000-0000-4000-8000-000000000001'
\set two 'a1870000-0000-4000-8000-000000000002'
\set four 'a1870000-0000-4000-8000-000000000003'

select ok(not exists (select 1 from private.settings where key = 'trust.new_account_hours'),
  'Masa 24 jam terpisah untuk trust 0 sudah tidak ada');
select ok(private.is_new_account(:'fresh'), 'Akun trust 0 yang baru daftar dianggap baru');
select is(private.rate_limit_factor(:'fresh'), 0.5, 'Akun baru memakai pengali batas kecepatan akun baru');
select ok(private.is_new_account(:'recent'), 'Akun trust 1 yang daftar 1 hari lalu dianggap baru');
select is(private.rate_limit_factor(:'recent'), 0.5, 'Batas kecepatan akun trust 1 yang baru ikut dikurangi');
select ok(not private.is_new_account(:'old'), 'Akun yang daftar 10 hari lalu tidak dianggap baru');
select is(private.rate_limit_factor(:'old'), 1::numeric, 'Akun lama memakai batas kecepatan biasa');
select ok(not private.is_new_account(:'trusted'), 'Akun tepercaya tidak pernah dianggap baru');
select is(private.rate_limit_factor(:'trusted'), 2::numeric, 'Akun tepercaya tetap memakai pengali tepercaya');

select private.promote_new_accounts() as promoted \gset
select is((select trust_level from public.profiles where id = :'two'), 0::smallint,
  'Akun trust 0 berumur 2 hari belum naik selama masa akun baru 3 hari');
select ok(private.is_new_account(:'two'), 'Akun trust 0 berumur 2 hari masih dianggap baru');
select is((select trust_level from public.profiles where id = :'four'), 1::smallint,
  'Akun trust 0 berumur 4 hari naik ke trust 1');
select ok(not private.is_new_account(:'four'), 'Akun yang sudah naik tidak lagi dianggap baru');

select tests.authenticate_as(:'fresh');
select is(tests.error_detail(format($$insert into posts (author_id, body, attachments) values (auth.uid(), 'P/L hari ini', %L)$$,
                                    jsonb_build_array(jsonb_build_object('path', 'posts/' || :'fresh' || '/pl.png')))),
  'image', 'Selama masa akun baru, postingan bergambar seperti Share P/L ditolak');
reset role;

update private.settings set value = '0' where key = 'safety.new_account_days';
select ok(not private.is_new_account(:'fresh') and not private.is_new_account(:'recent'),
  'Masa akun baru 0 hari: akun yang baru daftar tidak dibatasi');
select is(private.rate_limit_factor(:'fresh'), 1::numeric, 'Masa akun baru 0 hari: batas kecepatan biasa');

select tests.authenticate_as(:'fresh');
select lives_ok(format($$insert into posts (author_id, body, attachments) values (auth.uid(), 'P/L hari ini', %L)$$,
                       jsonb_build_array(jsonb_build_object('path', 'posts/' || :'fresh' || '/pl.png'))),
  'Masa akun baru 0 hari: Share P/L bergambar langsung bisa');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'baca kontan.co.id/news')$$,
  'Masa akun baru 0 hari: tautan langsung bisa');
reset role;

select private.promote_new_accounts() as promoted \gset
select is((select trust_level from public.profiles where id = :'fresh'), 1::smallint,
  'Masa akun baru 0 hari: akun trust 0 langsung dinaikkan');

update private.settings set value = '3' where key = 'safety.new_account_days';
update public.profiles set trust_level = 0, created_at = now() where id = :'old';
select ok(private.is_new_account(:'old'), 'Akun yang bergabung lagi dihitung sejak bergabung lagi');
select is((select signed_up_at from private.account_signups where user_id = :'old'), now(),
  'Waktu bergabung lagi tercatat sebagai awal masa akun baru');

select ok(not exists (
  select 1 from pg_proc p
  where p.oid in ('private.is_new_account(uuid)'::regprocedure, 'private.rate_limit_factor(uuid)'::regprocedure,
                  'private.promote_new_accounts()'::regprocedure)
    and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))),
  'Fungsi masa akun baru tidak bisa dipanggil langsung oleh klien');

select * from finish();
rollback;
