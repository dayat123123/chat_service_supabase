begin;
select plan(12);

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset
insert into posts (id, author_id, body) values
  ('a3000000-0000-4000-8000-000000000001', :'alice', 'Post untuk di-like'),
  ('a3000000-0000-4000-8000-000000000002', :'alice', 'Post yang nanti dihapus');
insert into comments (id, post_id, author_id, body)
  values ('c3000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', :'alice', 'Komentar');

select tests.authenticate_as(:'bob');
select lives_ok(
  $$insert into reactions (user_id, target_type, target_id)
    values (auth.uid(), 'post', 'a3000000-0000-4000-8000-000000000001')$$,
  'User bisa like post');
select is((select like_count from posts where id = 'a3000000-0000-4000-8000-000000000001'), 1, 'like_count bertambah');
select is((select liked_by_me from get_post('a3000000-0000-4000-8000-000000000001')), true, 'liked_by_me = true');
select throws_ok(
  $$insert into reactions (user_id, target_type, target_id)
    values (auth.uid(), 'post', 'a3000000-0000-4000-8000-000000000001')$$,
  '23505', null, 'Satu reaksi per user per target');
select throws_ok(
  format($$insert into reactions (user_id, target_type, target_id)
           values (%L, 'post', 'a3000000-0000-4000-8000-000000000001')$$, :'carol'),
  '42501', null, 'Tidak bisa memberi reaksi atas nama orang lain');
select lives_ok(
  $$insert into reactions (user_id, target_type, target_id)
    values (auth.uid(), 'comment', 'c3000000-0000-4000-8000-000000000001')$$,
  'User bisa like komentar');
select is((select like_count from comments where id = 'c3000000-0000-4000-8000-000000000001'), 1,
  'like_count komentar bertambah');

select tests.authenticate_as(:'carol');
insert into reactions (user_id, target_type, target_id)
  values (auth.uid(), 'post', 'a3000000-0000-4000-8000-000000000001');

reset role;
select results_eq(
  format($$select count(*)::int, max(event_count) from notifications
           where user_id = %L and type = 'like' and payload ->> 'target_id' = 'a3000000-0000-4000-8000-000000000001'$$,
         :'alice'),
  $$values (1, 2)$$,
  'Like dari dua user digabung menjadi satu notifikasi belum dibaca');

select tests.authenticate_as(:'bob');
select lives_ok(
  $$delete from reactions where user_id = auth.uid() and target_type = 'post'
      and target_id = 'a3000000-0000-4000-8000-000000000001'$$,
  'User bisa unlike');
select is((select like_count from posts where id = 'a3000000-0000-4000-8000-000000000001'), 1, 'like_count berkurang');

reset role;
update posts set deleted_at = now(), body = '' where id = 'a3000000-0000-4000-8000-000000000002';
select tests.authenticate_as(:'bob');
select throws_ok(
  $$insert into reactions (user_id, target_type, target_id)
    values (auth.uid(), 'post', 'a3000000-0000-4000-8000-000000000002')$$,
  'PT404', 'target_not_found', 'Tidak bisa like post yang sudah dihapus');

reset role;
insert into blocks (blocker_id, blocked_id) values (:'alice', :'bob');
select tests.authenticate_as(:'bob');
select throws_ok(
  $$insert into reactions (user_id, target_type, target_id)
    values (auth.uid(), 'post', 'a3000000-0000-4000-8000-000000000001')$$,
  'PT403', 'blocked', 'User yang diblokir tidak bisa memberi reaksi');

select * from finish();
rollback;
