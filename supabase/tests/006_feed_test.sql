-- Test posts get a future created_at so they always sort first (the dev database also holds seed data).
begin;
select plan(13);

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset
insert into follows (follower_id, following_id) values (:'alice', :'bob');

insert into posts (id, author_id, body, created_at) values
  ('a4000000-0000-4000-8000-000000000001', :'bob',   'Bob satu $BBCA',  now() + interval '10 minutes'),
  ('a4000000-0000-4000-8000-000000000002', :'carol', 'Carol satu',      now() + interval '20 minutes'),
  ('a4000000-0000-4000-8000-000000000003', :'bob',   'Bob dua',         now() + interval '30 minutes'),
  ('a4000000-0000-4000-8000-000000000004', :'alice', 'Alice satu $BBCA', now() + interval '40 minutes'),
  ('a4000000-0000-4000-8000-000000000005', :'carol', 'Carol dua $BBCA', now() + interval '50 minutes');

select tests.authenticate_as(:'alice');

select results_eq(
  $$select id from get_feed('global', null, null, 3)$$,
  $$values ('a4000000-0000-4000-8000-000000000005'::uuid),
           ('a4000000-0000-4000-8000-000000000004'::uuid),
           ('a4000000-0000-4000-8000-000000000003'::uuid)$$,
  'Feed global terbaru lebih dulu');
select results_eq(
  $$select id from get_feed('global', null,
      (select cursor from get_feed('global', null, null, 2) offset 1 limit 1), 2)$$,
  $$values ('a4000000-0000-4000-8000-000000000003'::uuid),
           ('a4000000-0000-4000-8000-000000000002'::uuid)$$,
  'Halaman berikutnya dimulai tepat setelah cursor (keyset)');
select results_eq(
  $$select id from get_feed('following', null, null, 3)$$,
  $$values ('a4000000-0000-4000-8000-000000000004'::uuid),
           ('a4000000-0000-4000-8000-000000000003'::uuid),
           ('a4000000-0000-4000-8000-000000000001'::uuid)$$,
  'Feed following berisi post sendiri & user yang di-follow');
select results_eq(
  $$select id from get_feed('stock', 'bbca', null, 3)$$,
  $$values ('a4000000-0000-4000-8000-000000000005'::uuid),
           ('a4000000-0000-4000-8000-000000000004'::uuid),
           ('a4000000-0000-4000-8000-000000000001'::uuid)$$,
  'Feed saham berisi post bertag $BBCA');
select results_eq(
  format($$select id from get_feed('user', null, null, 5, %L)$$, :'bob'),
  $$values ('a4000000-0000-4000-8000-000000000003'::uuid),
           ('a4000000-0000-4000-8000-000000000001'::uuid)$$,
  'Feed user berisi post milik user tersebut');
select results_eq(
  $$select author_username, stock_codes, liked_by_me
    from get_feed('global', null, null, 1)$$,
  $$values ('carol'::text, array['BBCA']::text[], false)$$,
  'Item feed berisi profil penulis, tag saham, dan status like');

insert into blocks (blocker_id, blocked_id) values (auth.uid(), :'carol');
select results_eq(
  $$select id from get_feed('global', null, null, 2)$$,
  $$values ('a4000000-0000-4000-8000-000000000004'::uuid),
           ('a4000000-0000-4000-8000-000000000003'::uuid)$$,
  'Post user yang diblokir dikecualikan dari feed');

select tests.authenticate_as(:'carol');
select is(
  (select count(*)::int from get_feed('user', null, null, 10, :'alice')), 0,
  'User yang diblokir tidak melihat feed pemblokir');

select throws_ok($$select * from get_feed('trending')$$, 'PT400', 'invalid_scope', 'Scope tidak dikenal ditolak');
select throws_ok($$select * from get_feed('global', null, 'bukan-cursor')$$, 'PT400', 'invalid_cursor', 'Cursor rusak ditolak');
select throws_ok($$select * from get_feed('stock')$$, 'PT400', 'stock_code_required', 'Scope stock wajib kode saham');

reset role;
select tests.authenticate_anon();
select throws_ok($$select * from get_feed('global')$$, '42501', null, 'anon tidak bisa memanggil get_feed');

reset role;
select set_config('request.jwt.claims', '', true);
select throws_ok($$select * from get_feed('global')$$, 'PT401', 'not_authenticated', 'get_feed butuh JWT user');

select * from finish();
rollback;
