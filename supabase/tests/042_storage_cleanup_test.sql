begin;
select plan(30);

delete from private.storage_cleanup_queue;

select tests.create_user('sc_budi') as budi \gset
select tests.create_user('sc_sari') as sari \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'sari') as dm \gset
reset role;
select room_id as support from cs.tickets where id = :'ticket' \gset

insert into storage.objects (bucket_id, name, created_at) values
  ('avatars', :'budi' || '/foto.jpg', now() - interval '1 day'),
  ('attachments', 'posts/' || :'budi' || '/chart.png', now() - interval '1 day'),
  ('attachments', 'posts/' || :'budi' || '/tren.png', now() - interval '1 day'),
  ('attachments', 'posts/' || :'budi' || '-salinan/lain.png', now() - interval '1 day'),
  ('attachments', 'rooms/' || :'dm' || '/' || :'budi' || '/kirim.jpg', now() - interval '1 day'),
  ('attachments', 'rooms/' || :'dm' || '/' || :'sari' || '/balas.jpg', now() - interval '1 day'),
  ('attachments', 'rooms/' || :'support' || '/' || :'budi' || '/layar.png', now() - interval '1 day'),
  ('cs-documents', 'rooms/' || :'support' || '/' || :'budi' || '/ktp.pdf', now() - interval '1 day');

select tests.authenticate_as(:'budi');
select lives_ok('select public.delete_my_account()', 'Nasabah menghapus akunnya');
reset role;

select results_eq(
  format($$select bucket_id, prefix from private.storage_cleanup_queue where prefix like '%%' || %L || '%%'
           order by bucket_id, prefix$$, :'budi'),
  format($$values ('attachments'::text, %L::text), ('attachments', %L), ('attachments', %L),
                  ('avatars', %L), ('cs-documents', %L)$$,
         'posts/' || :'budi' || '/',
         'rooms/' || least(:'dm', :'support') || '/' || :'budi' || '/',
         'rooms/' || greatest(:'dm', :'support') || '/' || :'budi' || '/',
         :'budi' || '/',
         'rooms/' || :'support' || '/' || :'budi' || '/'),
  'Foto, lampiran postingan, lampiran chat, dan dokumen CS milik akun masuk antrean');

insert into storage.objects (bucket_id, name, created_at)
values ('avatars', :'budi' || '/baru.jpg', now() + interval '1 minute');

select tests.authenticate_anon();
select throws_ok($$select public.storage_cleanup_claim('x')$$, '42501', null, 'Anonim tidak bisa mengambil antrean');
reset role;
select tests.authenticate_as(:'sari');
select throws_ok($$select public.storage_cleanup_claim('x')$$, '42501', null, 'Pengguna tidak bisa mengambil antrean');
select throws_ok($$select public.storage_cleanup_report('x', '[]')$$, '42501', null,
  'Pengguna tidak bisa melaporkan hasil pembersihan');
reset role;

select tests.authenticate_service();
select throws_ok($$select public.storage_cleanup_claim('janitor-a', 0)$$, 'PT400', 'invalid_claim',
  'Batas claim di luar rentang ditolak');
select public.storage_cleanup_claim('janitor-a', 20, 1000, 300) as claim \gset
reset role;

select is(jsonb_array_length(:'claim'), 5, 'Semua folder yang menunggu diambil janitor');
select is((select e -> 'objects' from jsonb_array_elements(:'claim') e where e ->> 'bucket' = 'avatars'),
  jsonb_build_array(:'budi' || '/foto.jpg'), 'File baru setelah akun dihapus tidak ikut dihapus');
select is((select e -> 'objects' from jsonb_array_elements(:'claim') e
           where e ->> 'prefix' = 'posts/' || :'budi' || '/'),
  jsonb_build_array('posts/' || :'budi' || '/chart.png', 'posts/' || :'budi' || '/tren.png'),
  'Folder lain dengan awalan nama mirip tidak ikut');
select is((select e -> 'objects' from jsonb_array_elements(:'claim') e
           where e ->> 'prefix' = 'rooms/' || :'dm' || '/' || :'budi' || '/'),
  jsonb_build_array('rooms/' || :'dm' || '/' || :'budi' || '/kirim.jpg'),
  'Lampiran lawan bicara di room yang sama tidak ikut');
select ok((select bool_and(locked_by = 'janitor-a' and locked_until > now()) from private.storage_cleanup_queue),
  'Folder yang diambil dikunci untuk janitor itu');

select tests.authenticate_service();
select is(jsonb_array_length(public.storage_cleanup_claim('janitor-b')), 0,
  'Janitor lain tidak mengambil folder yang sedang dikunci');
reset role;

select id as avatar_entry from private.storage_cleanup_queue where bucket_id = 'avatars' and prefix like :'budi' || '%' \gset
select id as posts_entry from private.storage_cleanup_queue where prefix = 'posts/' || :'budi' || '/' \gset
select id as dm_entry from private.storage_cleanup_queue where prefix = 'rooms/' || :'dm' || '/' || :'budi' || '/' \gset
select id as doc_entry from private.storage_cleanup_queue where bucket_id = 'cs-documents' \gset
select id as support_entry from private.storage_cleanup_queue
 where bucket_id = 'attachments' and prefix = 'rooms/' || :'support' || '/' || :'budi' || '/' \gset

set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'avatars' and name = :'budi' || '/foto.jpg';
delete from storage.objects where name = 'posts/' || :'budi' || '/chart.png';
reset storage.allow_delete_query;

select tests.authenticate_service();
select is(public.storage_cleanup_report('janitor-b', jsonb_build_array(jsonb_build_object('id', :avatar_entry, 'deleted', 1))),
  0, 'Laporan dari janitor yang tidak memegang kunci diabaikan');
select is(public.storage_cleanup_report('janitor-a', jsonb_build_array(
  jsonb_build_object('id', :avatar_entry, 'deleted', 1, 'error', null, 'release', false),
  jsonb_build_object('id', :posts_entry, 'deleted', 1),
  jsonb_build_object('id', :dm_entry, 'deleted', 0, 'error', 'storage delete attachments: status 500: boom'),
  jsonb_build_object('id', :doc_entry, 'deleted', 0, 'release', true),
  jsonb_build_object('id', :support_entry, 'deleted', 0))), 5, 'Janitor melaporkan hasil semua folder');
reset role;

select ok((select done_at is not null and deleted_count = 1 and locked_by is null from private.storage_cleanup_queue
           where id = :avatar_entry), 'Folder yang tinggal berisi file baru dianggap selesai');
select ok((select done_at is null and failures = 0 and error is null and available_at <= now()
           from private.storage_cleanup_queue where id = :posts_entry),
  'Folder yang masih berisi file diambil lagi di putaran berikutnya');
select ok((select done_at is null and failures = 1 and error like 'storage delete attachments%'
                  and available_at > now() + interval '40 seconds'
           from private.storage_cleanup_queue where id = :dm_entry), 'Kegagalan dicoba lagi setelah jeda');
select ok((select done_at is null and failures = 0 and locked_by is null and available_at <= now()
           from private.storage_cleanup_queue where id = :doc_entry), 'Folder yang dilepas kembali ke antrean tanpa dihitung gagal');
select ok((select failures = 1 and error = 'Objek tidak terhapus oleh layanan storage'
           from private.storage_cleanup_queue where id = :support_entry),
  'Laporan sukses tanpa file terhapus padahal file masih ada dihitung gagal');

update private.storage_cleanup_queue set locked_by = 'janitor-a', failures = 9 where id = :dm_entry;
select tests.authenticate_service();
select public.storage_cleanup_report('janitor-a', jsonb_build_array(
  jsonb_build_object('id', :dm_entry, 'deleted', 0, 'error', 'masih gagal'))) as again \gset
reset role;
select ok((select available_at between now() + interval '4 hours' and now() + interval '7.3 hours'
           from private.storage_cleanup_queue where id = :dm_entry), 'Jeda percobaan ulang paling lama sekitar 6 jam');

select tests.authenticate_service();
select is((select count(*)::integer from jsonb_array_elements(public.storage_cleanup_claim('janitor-c')) e
           where (e ->> 'id')::bigint in (:posts_entry, :doc_entry)), 2,
  'Folder yang belum tuntas atau dilepas diambil lagi');
reset role;

insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
values ('care-documents', 'letters/' || gen_random_uuid() || '/', 'care_retention') returning id as empty_entry \gset
select tests.authenticate_service();
select is((select e -> 'objects' from jsonb_array_elements(public.storage_cleanup_claim('janitor-d')) e
           where (e ->> 'id')::bigint = :empty_entry), '[]'::jsonb, 'Folder kosong dikirim tanpa daftar file');
select is(public.storage_cleanup_report('janitor-d', jsonb_build_array(jsonb_build_object('id', :empty_entry, 'deleted', 0))),
  1, 'Janitor melaporkan folder kosong');
reset role;
select ok((select done_at is not null from private.storage_cleanup_queue where id = :empty_entry),
  'Folder kosong langsung selesai');

select throws_ok($$insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values ('avatars', '', 'uji')$$,
  '23514', null, 'Prefix kosong ditolak agar bucket tidak terhapus seluruhnya');
select throws_ok($$insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values ('avatars', 'abc', 'uji')$$,
  '23514', null, 'Prefix harus berupa folder');
select throws_ok($$insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values ('avatars', '/abc/', 'uji')$$,
  '23514', null, 'Prefix tidak boleh diawali garis miring');

update private.storage_cleanup_queue set done_at = now() - interval '91 days' where id = :empty_entry;
select is(private.storage_cleanup_purge(), 1, 'Riwayat pembersihan lebih dari 90 hari dihapus');
select ok(exists (select 1 from cron.job where jobname = 'storage-cleanup-purge'), 'Pembersihan riwayat terjadwal');

select is(private.storage_folder_objects('attachments', 'rooms/' || :'dm' || '/', now(), 10),
  (select array_agg(n order by n collate "C")
   from unnest(array['rooms/' || :'dm' || '/' || :'budi' || '/kirim.jpg', 'rooms/' || :'dm' || '/' || :'sari' || '/balas.jpg']) n),
  'Daftar file folder diurutkan per nama');

select * from finish();
rollback;
