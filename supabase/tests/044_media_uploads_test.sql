begin;
select plan(12);

select tests.create_user('mu_budi') as budi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select is(private.upload_verified(), false, 'JWT nasabah biasa belum terverifikasi layanan media');
select throws_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('attachments', %L, %L, %L)$$,
         'posts/' || :'budi' || '/langsung.jpg', :'budi', :'budi'),
  '42501', null, 'Upload langsung ke storage tanpa layanan media ditolak');
select throws_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('avatars', %L, %L, %L)$$,
         :'budi' || '/avatar.jpg', :'budi', :'budi'),
  '42501', null, 'Upload avatar langsung ditolak');
reset role;
select room_id as support from cs.tickets where id = :'ticket' \gset

select tests.authenticate_with(:'budi', '{"media_verified": "false"}');
select is(private.upload_verified(), false, 'Klaim media_verified selain true ditolak');
reset role;

select tests.authenticate_with(:'budi', '{"media_verified": true}');
select is(private.upload_verified(), true, 'JWT dari layanan media terverifikasi');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('attachments', %L, %L, %L)$$,
         'posts/' || :'budi' || '/aman.jpg', :'budi', :'budi'),
  'Lampiran postingan lewat layanan media diterima');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('avatars', %L, %L, %L)$$,
         :'budi' || '/avatar.jpg', :'budi', :'budi'),
  'Avatar lewat layanan media diterima');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('attachments', %L, %L, %L)$$,
         'rooms/' || :'support' || '/' || :'budi' || '/layar.png', :'budi', :'budi'),
  'Gambar chat CS lewat layanan media diterima');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('cs-documents', %L, %L, %L)$$,
         'rooms/' || :'support' || '/' || :'budi' || '/bukti.pdf', :'budi', :'budi'),
  'Dokumen PDF chat CS lewat layanan media diterima');
select throws_ok(
  format($$insert into storage.objects (bucket_id, name, owner, owner_id) values ('attachments', %L, %L, %L)$$,
         'posts/' || gen_random_uuid() || '/orang-lain.jpg', :'budi', :'budi'),
  '42501', null, 'Klaim media tidak membuka folder milik orang lain');
reset role;

select tests.authenticate_agent(:'rina');
select is(private.upload_verified(), true, 'Staf CS boleh upload langsung dari web CS');
reset role;

select tests.authenticate_anon();
select throws_ok('select private.upload_verified()', '42501', null, 'Anonim tidak bisa memanggil fungsi verifikasi');
reset role;

select * from finish();
rollback;
