begin;
select plan(19);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('media_budi') as budi \gset
select tests.create_user('media_sari') as sari \gset
select tests.create_agent('Laras', '{cs_agent}', '{"general": 2, "account": 2}') as laras \gset

select results_eq(
  $$select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'cs-documents'$$,
  $$values (false, 10485760::bigint, array['application/pdf'])$$,
  'Bucket dokumen chat CS: privat, PDF saja, maksimal 10 MB');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'sari') as dm \gset
reset role;
select room_id as room from cs.tickets where id = :'ticket' \gset

select tests.authenticate_as(:'budi');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-documents', 'rooms/%s/%s/bukti.pdf', %L)$$,
                       :'room', :'budi', :'budi'),
  'Nasabah boleh mengunggah PDF ke room layanan miliknya');
reset role;
insert into private.user_sanctions (user_id, kind, reason, ends_at) values (:'budi', 'ban', 'uji', null);
select tests.authenticate_as(:'budi');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-documents', 'rooms/%s/%s/ktp.pdf', %L)$$,
                       :'room', :'budi', :'budi'),
  'Nasabah yang di-ban dari fitur sosial tetap bisa mengirim dokumen ke CS');
reset role;
delete from private.user_sanctions where user_id = :'budi';
select tests.authenticate_as(:'budi');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-documents', 'rooms/%s/%s/x.pdf', %L)$$,
                        :'dm', :'budi', :'budi'),
  '42501', null, 'PDF tidak bisa diunggah ke chat global');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-documents', 'rooms/%s/%s/x.pdf', %L)$$,
                        :'room', :'sari', :'budi'),
  '42501', null, 'Nasabah tidak bisa mengunggah atas nama orang lain');

select lives_ok(format($$select cs_api.send_message(%L, 'Bukti transfer', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/bukti.pdf", "mime": "application/pdf", "name": "Bukti Transfer.pdf", "size": 182000}]')$$,
  :'room', :'room', :'budi'),
  'Nasabah mengirim PDF ke CS');
select lives_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/layar.png", "mime": "image/png", "width": 1080, "height": 2340}]')$$,
  :'room', :'room', :'budi'),
  'Nasabah mengirim screenshot ke CS');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/rekaman.mp4", "mime": "video/mp4"}]')$$,
  :'room', :'room', :'budi'),
  'PT400', 'attachment_not_allowed', 'Video tidak diterima di chat CS');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/data.xlsx", "mime": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}]')$$,
  :'room', :'room', :'budi'),
  'PT400', 'attachment_not_allowed', 'File Office tidak diterima');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/bukti.pdf", "mime": "application/pdf", "size": 20971520}]')$$,
  :'room', :'room', :'budi'),
  'PT400', 'attachment_too_large', 'PDF lebih dari 10 MB ditolak');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "avatars", "path": "rooms/%s/%s/a.png", "mime": "image/png"}]')$$,
  :'room', :'room', :'budi'),
  'PT400', 'attachment_not_allowed', 'Bucket lain tidak bisa dipakai sebagai lampiran');

select throws_ok(format($$select send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/x.pdf", "mime": "application/pdf"}]')$$,
  :'dm', :'dm', :'budi'),
  'PT400', 'attachment_not_allowed', 'Chat global menolak PDF');
select throws_ok(format($$select send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/x.heic", "mime": "image/heic"}]')$$,
  :'dm', :'dm', :'budi'),
  'PT400', 'attachment_not_allowed', 'Chat global hanya menerima JPEG, PNG, WebP, atau GIF');
select lives_ok(format($$select send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/meme.gif", "mime": "image/gif", "width": 480, "height": 480}]')$$,
  :'dm', :'dm', :'budi'),
  'Chat global tetap menerima gambar');

reset role;
select tests.agent_online(:'laras');
select tests.authenticate_agent(:'laras');
select cs_api.claim_ticket(:'ticket') ->> 'id' as claimed \gset
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-documents', 'rooms/%s/%s/formulir.pdf', %L)$$,
                       :'room', :'laras', :'laras'),
  'CS yang menangani tiket boleh mengunggah PDF');
select is(cs_api.agent_send_message(:'ticket', 'Silakan isi formulir ini', gen_random_uuid(), 'text', '{}', null,
  format('[{"bucket": "cs-documents", "path": "rooms/%s/%s/formulir.pdf", "mime": "application/pdf", "name": "Formulir.pdf", "size": 52000}]',
         :'room', :'laras')::jsonb) ->> 'status', 'sent',
  'CS mengirim PDF ke nasabah');
select ok(exists (select 1 from storage.objects where bucket_id = 'cs-documents' and name like 'rooms/' || :'room' || '/%'),
  'CS bisa membaca dokumen di room yang ditanganinya');

select tests.authenticate_as(:'sari');
select ok(not exists (select 1 from storage.objects where bucket_id = 'cs-documents'),
  'User lain tidak bisa membaca dokumen chat CS');
select tests.authenticate_as(:'budi');
select is((select count(*)::integer from storage.objects where bucket_id = 'cs-documents'), 3,
  'Nasabah bisa membaca dokumen di room layanannya');

select * from finish();
rollback;
