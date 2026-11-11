begin;
select plan(22);

select tests.create_user('fl_ani') as ani \gset
select tests.create_user('fl_budi') as budi \gset
select tests.create_user('fl_cici') as cici \gset
select tests.create_user('fl_dodi') as dodi \gset
select tests.create_user('fl_eko') as eko \gset
select tests.create_user('fl_tamu') as tamu \gset
select tests.create_user('fl_hapus') as hapus \gset
select tests.create_user('fl_ban') as banned \gset
select tests.create_user('fl_resmi') as resmi \gset
select tests.create_agent('Staf Ikut', '{cs_agent}', '{"general": 1}') as staf \gset

update public.profiles set is_guest = true where id = :'tamu';
update public.profiles set deleted_at = now() where id = :'hapus';
insert into private.user_sanctions (user_id, kind, reason) values (:'banned', 'ban', 'uji');
insert into cs.official_accounts (profile_id) values (:'resmi');

insert into public.follows (follower_id, following_id, created_at) values
  (:'budi', :'ani', now() - interval '5 minutes'),
  (:'cici', :'ani', now() - interval '4 minutes'),
  (:'dodi', :'ani', now() - interval '3 minutes'),
  (:'eko', :'ani', now() - interval '2 minutes'),
  (:'resmi', :'ani', now() - interval '1 minute'),
  (:'tamu', :'ani', now() - interval '6 minutes'),
  (:'hapus', :'ani', now() - interval '7 minutes'),
  (:'banned', :'ani', now() - interval '8 minutes'),
  (:'staf', :'ani', now() - interval '9 minutes'),
  (:'ani', :'budi', now() - interval '10 minutes'),
  (:'ani', :'resmi', now() - interval '11 minutes'),
  (:'cici', :'budi', now() - interval '12 minutes');
insert into public.blocks (blocker_id, blocked_id) values (:'cici', :'eko');

select tests.authenticate_as(:'cici');
select is(array(select username from public.get_follow_list(:'ani', 'followers')),
  array['fl_resmi', 'fl_dodi', 'fl_cici', 'fl_budi'],
  'Pengikut terbaru dulu; tamu, akun terhapus, akun di-ban, staf, dan yang saling blokir disembunyikan');
select is((select row(is_me, is_following, follows_me)::text from public.get_follow_list(:'ani', 'followers') where id = :'cici'),
  '(t,f,f)', 'Baris diri sendiri ditandai is_me');
select is((select row(is_following, follows_me)::text from public.get_follow_list(:'ani', 'followers') where id = :'budi'),
  '(t,f)', 'is_following = saya mengikuti orang ini');
select ok((select is_official from public.get_follow_list(:'ani', 'followers') where id = :'resmi'),
  'Akun resmi ditandai is_official');
select is(array(select username from public.get_follow_list(:'ani', 'following')),
  array['fl_budi', 'fl_resmi'], 'Daftar yang diikuti terbaru dulu');
select is((select follows_me from public.get_follow_list(:'budi', 'followers') where id = :'ani'), false,
  'follows_me dari sudut pandang pembaca');
reset role;

select tests.authenticate_as(:'budi');
select is((select follows_me from public.get_follow_list(:'budi', 'followers') where id = :'ani'), true,
  'follows_me = orang ini mengikuti saya');
select is((select is_following from public.get_follow_list(:'budi', 'followers') where id = :'ani'), true,
  'Saling mengikuti terlihat dari dua penanda');
select is(array(select username from public.get_follow_list(:'ani', 'followers')),
  array['fl_resmi', 'fl_eko', 'fl_dodi', 'fl_cici', 'fl_budi'],
  'Pembaca lain melihat akun yang tidak memblokir dirinya');

select is(array(select username from public.get_follow_list(:'ani', 'followers', null, 2)),
  array['fl_resmi', 'fl_eko'], 'Batas per halaman dipatuhi');
select (select cursor from public.get_follow_list(:'ani', 'followers', null, 2) offset 1) as page1 \gset
select is(array(select username from public.get_follow_list(:'ani', 'followers', :'page1', 2)),
  array['fl_dodi', 'fl_cici'], 'Halaman berikutnya lanjut dari kursor');
select (select cursor from public.get_follow_list(:'ani', 'followers', :'page1', 2) offset 1) as page2 \gset
select is(array(select username from public.get_follow_list(:'ani', 'followers', :'page2', 2)),
  array['fl_budi'], 'Halaman terakhir');
select is((select count(*)::integer from public.get_follow_list(:'ani', 'followers', null, 500)), 5,
  'Batas maksimal dibatasi server');

select throws_ok($$select * from public.get_follow_list(null, 'followers')$$, 'PT404', 'user_not_found',
  'Tanpa pengguna ditolak');
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'tamu', 'followers'), 'PT404', 'user_not_found',
  'Daftar milik tamu tidak bisa dibuka');
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'hapus', 'following'), 'PT404', 'user_not_found',
  'Daftar milik akun terhapus tidak bisa dibuka');
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'ani', 'teman'), 'PT400', 'invalid_kind',
  'Jenis daftar tidak dikenal ditolak');
select throws_ok(format('select * from public.get_follow_list(%L, %L, %L)', :'ani', 'followers', 'bukan-kursor'),
  'PT400', 'invalid_cursor', 'Kursor rusak ditolak');
reset role;

select tests.authenticate_as(:'eko');
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'cici', 'following'), 'PT404', 'user_not_found',
  'Daftar milik orang yang memblokir saya tidak bisa dibuka');
reset role;

select tests.authenticate_as(:'cici');
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'eko', 'followers'), 'PT404', 'user_not_found',
  'Daftar milik orang yang saya blokir tidak bisa dibuka');
reset role;

select tests.authenticate_anon();
select throws_ok(format('select * from public.get_follow_list(%L, %L)', :'ani', 'followers'), '42501', null,
  'Anon tidak bisa membaca daftar pengikut');
reset role;
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'follows_follower_created_idx'),
  'Indeks daftar yang diikuti tersedia');

select * from finish();
rollback;
