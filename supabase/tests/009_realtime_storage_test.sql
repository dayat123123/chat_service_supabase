begin;
select plan(10);

select results_eq(
  $$select tablename::text collate "default" from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' order by 1$$,
  $$values ('comments'), ('notifications'), ('posts'), ('reactions')$$,
  'Publikasi realtime mencakup tabel yang dibutuhkan (pesan lewat broadcast, 0098)');

select results_eq(
  $$select id, public, file_size_limit from storage.buckets where id in ('avatars', 'attachments') order by id$$,
  $$values ('attachments'::text, false, 5242880::bigint), ('avatars'::text, true, 2097152::bigint)$$,
  'Bucket avatars (publik, 2 MB) & attachments (privat, 5 MB)');
select ok(
  (select bool_and(m like 'image/%') from storage.buckets, unnest(allowed_mime_types) m
   where id in ('avatars', 'attachments')),
  'Bucket hanya menerima gambar');
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'storage' and tablename = 'objects' and policyname like 'olt_%'),
  19, 'Policy storage OLT terpasang (termasuk lampiran, dokumen chat CS, media akun resmi, tinjauan gambar, gambar banner, dan gambar FAQ)');
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'realtime' and tablename = 'messages' and policyname like 'olt_%'),
  2, 'Policy otorisasi channel realtime terpasang');

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset

select ok(private.can_access_topic('room:' || :'dm'), 'Anggota boleh join channel room');
select ok(not private.can_access_topic('online'), 'Channel online ditutup (tidak dipakai klien, 0105)');
select ok(not private.can_access_topic('room:bukan-uuid'), 'Topic tidak valid ditolak');

select tests.create_user('carol') as carol \gset
select tests.authenticate_as(:'carol');
select ok(not private.can_access_topic('room:' || :'dm'), 'Non-anggota tidak boleh join channel room');
select ok(not private.is_room_member_text(:'dm'), 'Non-anggota tidak boleh membaca lampiran room');

select * from finish();
rollback;
