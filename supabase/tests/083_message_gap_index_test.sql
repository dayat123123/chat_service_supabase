begin;
select plan(22);

select tests.create_user('gi_alice') as alice \gset
select tests.create_user('gi_bob') as bob \gset
select tests.create_user('gi_dina') as dina \gset
select tests.create_user('gi_eko') as eko \gset

select tests.authenticate_as(:'alice');
select create_group_room('Grup Celah', array[:'bob', :'dina']::uuid[]) as grp \gset
select create_group_room('Grup Lain', array[:'bob']::uuid[]) as other \gset
reset role;

insert into public.messages (id, room_id, sender_id, body, created_at) values
  ('00000000-0000-4000-8000-000000000001', :'grp', :'alice', 'satu', '2026-11-04 01:00:01+00'),
  ('00000000-0000-4000-8000-000000000002', :'grp', :'bob', 'dua', '2026-11-04 01:00:02+00'),
  ('00000000-0000-4000-8000-000000000004', :'grp', :'bob', 'tiga b', '2026-11-04 01:00:03+00'),
  ('00000000-0000-4000-8000-000000000003', :'grp', :'alice', 'tiga a', '2026-11-04 01:00:03+00'),
  ('00000000-0000-4000-8000-000000000005', :'grp', :'bob', 'lima', '2026-11-04 01:00:05+00'),
  ('00000000-0000-4000-8000-000000000009', :'other', :'bob', 'room lain', '2026-11-04 01:00:04+00');
insert into public.messages (id, room_id, sender_id, body, created_at, moderation_status) values
  ('00000000-0000-4000-8000-000000000006', :'grp', :'bob', 'disembunyikan', '2026-11-04 01:00:06+00', 'hidden');
insert into blocks (blocker_id, blocked_id) values (:'dina', :'alice');

select tests.authenticate_as(:'bob');
select get_message_ids(:'grp', '2026-11-04T01:00:00.000000Z|00000000-0000-0000-0000-000000000000') as full_page \gset
select is(:'full_page'::jsonb -> 'ids',
  '["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002",
    "00000000-0000-4000-8000-000000000003", "00000000-0000-4000-8000-000000000004",
    "00000000-0000-4000-8000-000000000005", "00000000-0000-4000-8000-000000000006"]'::jsonb,
  'Id pesan urut maju (created_at, id), hanya room ini, pesan tersembunyi milik sendiri tetap terlihat');
select is(:'full_page'::jsonb ->> 'more', 'false', 'Halaman pendek berarti tidak ada lanjutan');
select is(:'full_page'::jsonb ->> 'last',
  private.make_cursor('2026-11-04 01:00:06+00', '00000000-0000-4000-8000-000000000006'),
  'Kursor terakhir memakai format kursor pesan');

select get_message_ids(:'grp', '2026-11-04T01:00:00.000000Z|00000000-0000-0000-0000-000000000000', 3) as first_page \gset
select is(:'first_page'::jsonb -> 'ids',
  '["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002",
    "00000000-0000-4000-8000-000000000003"]'::jsonb, 'Batas halaman dihormati');
select is(:'first_page'::jsonb ->> 'more', 'true', 'Halaman penuh menandai ada lanjutan');
select get_message_ids(:'grp', :'first_page'::jsonb ->> 'last', 3) as second_page \gset
select is(:'second_page'::jsonb -> 'ids',
  '["00000000-0000-4000-8000-000000000004", "00000000-0000-4000-8000-000000000005",
    "00000000-0000-4000-8000-000000000006"]'::jsonb,
  'Halaman berikut mulai tepat setelah kursor, termasuk pesan dengan waktu sama dan id lebih besar');

select is(get_message_ids(:'grp', '2026-11-04T01:00:00.000000Z|00000000-0000-0000-0000-000000000000', 0) -> 'ids',
  '["00000000-0000-4000-8000-000000000001"]'::jsonb, 'Batas di bawah 1 dinaikkan ke 1');
select is(get_message_ids(:'grp', '2026-11-04T02:00:00.000000Z|00000000-0000-0000-0000-000000000000'),
  '{"ids": [], "last": null, "more": false}'::jsonb, 'Tanpa pesan baru: daftar kosong dan kursor kosong');

select throws_ok(format($$select get_message_ids(%L, null)$$, :'grp'),
  'PT400', 'invalid_cursor', 'Kursor wajib diisi');
select throws_ok(format($$select get_message_ids(%L, 'bukan-kursor')$$, :'grp'),
  'PT400', 'invalid_cursor', 'Kursor rusak ditolak');

select tests.authenticate_as(:'dina');
select is(get_message_ids(:'grp', '2026-11-04T01:00:00.000000Z|00000000-0000-0000-0000-000000000000') -> 'ids',
  '["00000000-0000-4000-8000-000000000002", "00000000-0000-4000-8000-000000000004",
    "00000000-0000-4000-8000-000000000005"]'::jsonb,
  'Pesan dari pengguna yang diblokir dan pesan tersembunyi orang lain tidak terlihat');

select tests.authenticate_as(:'eko');
select throws_ok(
  format($$select get_message_ids(%L, '2026-11-04T01:00:00.000000Z|00000000-0000-0000-0000-000000000000')$$, :'grp'),
  'PT403', 'not_member', 'Non-anggota tidak bisa membaca indeks pesan');
select throws_ok(
  format($$select * from get_messages_by_ids(%L, array['00000000-0000-4000-8000-000000000001']::uuid[])$$, :'grp'),
  'PT403', 'not_member', 'Non-anggota tidak bisa mengambil pesan berdasarkan id');

select tests.authenticate_as(:'bob');
select results_eq(
  format($$select id, body, cursor from get_messages_by_ids(%L, array[
    '00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000009', '00000000-0000-4000-8000-0000000000ff']::uuid[])$$, :'grp'),
  $$values
    ('00000000-0000-4000-8000-000000000005'::uuid, 'lima'::text,
     private.make_cursor('2026-11-04 01:00:05+00', '00000000-0000-4000-8000-000000000005')),
    ('00000000-0000-4000-8000-000000000002'::uuid, 'dua'::text,
     private.make_cursor('2026-11-04 01:00:02+00', '00000000-0000-4000-8000-000000000002'))$$,
  'Pesan diambil per id dalam bentuk chat_message, terbaru dulu; id room lain dan id tak dikenal diabaikan');
select is((select count(*)::int from get_messages_by_ids(:'grp', '{}'::uuid[])), 0, 'Daftar id kosong menghasilkan 0 baris');
select is((select count(*)::int from get_messages_by_ids(:'grp', null)), 0, 'Daftar id null menghasilkan 0 baris');
select throws_ok(
  format($$select * from get_messages_by_ids(%L, (select array_agg(gen_random_uuid()) from generate_series(1, 101)))$$, :'grp'),
  'PT400', 'too_many_ids', 'Lebih dari 100 id sekaligus ditolak');

select tests.authenticate_as(:'dina');
select is(
  (select array_agg(id order by id) from get_messages_by_ids(:'grp', array[
    '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000006']::uuid[])),
  array['00000000-0000-4000-8000-000000000002']::uuid[],
  'RLS tetap menyaring: pesan pengguna yang diblokir dan pesan tersembunyi tidak bisa diambil lewat id');
reset role;

select ok(not has_function_privilege('anon', 'public.get_message_ids(uuid,text,integer)', 'EXECUTE'),
  'anon tidak bisa memanggil get_message_ids');
select ok(not has_function_privilege('anon', 'public.get_messages_by_ids(uuid,uuid[])', 'EXECUTE'),
  'anon tidak bisa memanggil get_messages_by_ids');
select ok(has_function_privilege('authenticated', 'public.get_message_ids(uuid,text,integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_messages_by_ids(uuid,uuid[])', 'EXECUTE'),
  'User login bisa memanggil kedua RPC');
select ok(
  (select bool_and(not p.prosecdef) from pg_proc p
   where p.oid in ('public.get_message_ids(uuid,text,integer)'::regprocedure,
                   'public.get_messages_by_ids(uuid,uuid[])'::regprocedure)),
  'Kedua RPC berjalan sebagai pemanggil sehingga RLS pesan berlaku');

select * from finish();
rollback;
