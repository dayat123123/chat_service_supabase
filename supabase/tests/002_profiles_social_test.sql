-- Profil, follow, block.
begin;
select plan(15);

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset

select tests.authenticate_as(:'alice');

select lives_ok(
  $$update profiles set display_name = 'Alice A', bio = 'Halo' where id = auth.uid()$$,
  'User bisa mengubah profil sendiri');
select is((select display_name from profiles where id = :'alice'), 'Alice A', 'Perubahan profil tersimpan');
select is_empty(
  format('update profiles set display_name = %L where id = %L returning id', 'hack', :'bob'),
  'Tidak bisa mengubah profil user lain');
select throws_ok(
  $$update profiles set username = 'alice_baru' where id = auth.uid()$$,
  '42501', null, 'Username tidak bisa diubah sendiri');
select throws_ok($$select olt_user_id from profiles$$, '42501', null, 'olt_user_id tidak bisa dibaca');

select lives_ok(
  format('insert into follows (follower_id, following_id) values (%L, %L)', :'alice', :'bob'),
  'User bisa follow user lain');
select throws_ok(
  format('insert into follows (follower_id, following_id) values (%L, %L)', :'alice', :'alice'),
  '23514', null, 'Tidak bisa follow diri sendiri');
select throws_ok(
  format('insert into follows (follower_id, following_id) values (%L, %L)', :'bob', :'carol'),
  '42501', null, 'Tidak bisa follow atas nama user lain');

reset role;
select is((select follower_count from profiles where id = :'bob'), 1, 'follower_count bertambah');
select is((select following_count from profiles where id = :'alice'), 1, 'following_count bertambah');
select is(
  (select count(*)::int from notifications where user_id = :'bob' and type = 'follow' and actor_id = :'alice'),
  1, 'Notifikasi follow dibuat');

select tests.authenticate_as(:'bob');
select lives_ok(
  format('insert into blocks (blocker_id, blocked_id) values (%L, %L)', :'bob', :'alice'),
  'User bisa memblokir');

reset role;
select is(
  (select count(*)::int from follows where follower_id = :'alice' and following_id = :'bob'),
  0, 'Blokir memutus follow');

select tests.authenticate_as(:'alice');
select throws_ok(
  format('insert into follows (follower_id, following_id) values (%L, %L)', :'alice', :'bob'),
  '42501', null, 'User yang diblokir tidak bisa follow pemblokirnya');
select is((select count(*)::int from blocks), 0, 'Daftar blokir orang lain tidak terlihat');

select * from finish();
rollback;
