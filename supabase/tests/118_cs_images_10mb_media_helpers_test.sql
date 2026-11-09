begin;
select plan(7);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('img_budi') as budi \gset
select tests.create_user('img_sari') as sari \gset

select is((select file_size_limit from storage.buckets where id = 'attachments'), 10485760::bigint,
  'Bucket lampiran gambar menerima sampai 10 MB');
select is((cs.attachment_policy_view() -> 'images' ->> 'max_bytes')::bigint, 10485760::bigint,
  'Gambar chat CS bawaan maksimal 10 MB');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'sari') as dm \gset
reset role;
select room_id as room from cs.tickets where id = :'ticket' \gset

select tests.authenticate_as(:'budi');
select lives_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/foto.jpg", "mime": "image/jpeg", "size": 8000000}]')$$, :'room', :'room', :'budi'),
  'Foto 8 MB diterima di chat CS');
select throws_ok(format($$select send_message(%L, '', gen_random_uuid(), null,
  '[{"path": "rooms/%s/%s/foto.jpg", "mime": "image/jpeg", "size": 8000000}]')$$, :'dm', :'dm', :'budi'),
  'PT400', 'attachment_too_large', 'Chat global tetap maksimal 5 MB per gambar');
reset role;

select tests.authenticate_service();
select is(public.media_room_kind(:'room'), 'support', 'Layanan media mengenali room CS');
select is(public.media_room_kind(:'dm'), 'other', 'Room lain dianggap bukan CS');
reset role;

select tests.authenticate_as(:'budi');
select throws_ok(format($$select public.media_room_kind(%L)$$, :'room'), '42501', null,
  'Nasabah tidak bisa memanggil RPC khusus layanan media');
reset role;

select * from finish();
rollback;
