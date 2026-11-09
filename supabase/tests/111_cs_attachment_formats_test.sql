begin;
select plan(23);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update cs.cs_settings set value = '"claim"' where key = 'assignment.mode';

select tests.create_user('att_budi') as budi \gset
select tests.create_user('att_sari') as sari \gset
select tests.create_agent('Sinta Lampiran', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Lampiran', '{cs_agent}', '{"general": 1, "account": 1}') as rina \gset

select results_eq(
  $$select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'cs-videos'$$,
  $$values (false, 26214400::bigint, array['video/mp4', 'video/quicktime', 'video/webm', 'image/jpeg'])$$,
  'Bucket video chat CS: privat, MP4/MOV/WebM dan thumbnail JPEG, maksimal 25 MB');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'sari') as dm \gset
select ok(cs_api.attachment_policy() -> 'documents' -> 'formats' @> '[{"code": "docx", "ext": "docx"}]',
  'Nasabah membaca daftar format lampiran dari server');
select is((cs_api.attachment_policy() -> 'videos' ->> 'max_seconds')::integer, 120, 'Video bawaan maksimal 2 menit');
reset role;
select room_id as room from cs.tickets where id = :'ticket' \gset

select tests.authenticate_anon();
select throws_ok($$select cs_api.attachment_policy()$$, '42501', null, 'Anon tidak bisa membaca kebijakan lampiran');
reset role;

select tests.authenticate_with(:'budi', '{"media_verified": true}');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-videos', 'rooms/%s/%s/layar.mp4', %L)$$,
                       :'room', :'budi', :'budi'), 'Nasabah mengunggah video ke room layanan miliknya');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-videos', 'rooms/%s/%s/x.mp4', %L)$$,
                        :'dm', :'budi', :'budi'), '42501', null, 'Video tidak bisa diunggah ke chat global');
reset role;
select tests.authenticate_as(:'budi');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('cs-videos', 'rooms/%s/%s/y.mp4', %L)$$,
                        :'room', :'budi', :'budi'), '42501', null, 'Video harus lewat layanan media');

select lives_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/laporan.docx", "mime": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "name": "Laporan.docx", "size": 120000}]')$$,
  :'room', :'room', :'budi'), 'Nasabah mengirim dokumen Word ke CS');
select lives_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/mutasi.csv", "mime": "text/csv", "name": "mutasi.csv", "size": 4000}]')$$,
  :'room', :'room', :'budi'), 'Nasabah mengirim CSV ke CS');
select lives_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/layar.mp4", "mime": "video/mp4", "size": 9000000, "duration": 42.5, "thumbnail": "rooms/%s/%s/layar.jpg"}]')$$,
  :'room', :'room', :'budi', :'room', :'budi'), 'Nasabah mengirim rekaman layar ke CS');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/panjang.mp4", "mime": "video/mp4", "size": 9000000, "duration": 121}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_too_long', 'Video lebih dari 2 menit ditolak');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/x.mp4", "mime": "video/mp4", "size": 9000000}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_too_long', 'Video tanpa durasi ditolak');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/besar.mp4", "mime": "video/mp4", "size": 30000000, "duration": 10}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_too_large', 'Video lebih dari 25 MB ditolak');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/makro.docm", "mime": "application/vnd.ms-word.document.macroenabled.12"}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_not_allowed', 'Dokumen bermakro ditolak');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/palsu.pdf", "mime": "text/plain"}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_not_allowed', 'Ekstensi yang tidak cocok dengan jenis file ditolak');
select throws_ok(format($$select send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/x.mp4", "mime": "video/mp4", "duration": 5}]')$$,
  :'dm', :'dm', :'budi'), 'PT400', 'attachment_not_allowed', 'Chat global tetap hanya gambar');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_attachment_policy()$$, 'PT403', null, 'Agen biasa tidak bisa mengatur format lampiran');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_set_attachment_policy('{"documents": {"enabled": true, "max_mb": 11, "formats": ["pdf"]}, "images": {"enabled": true, "max_mb": 5, "formats": ["png"]}, "videos": {"enabled": true, "max_mb": 25, "max_seconds": 60, "formats": ["mp4"]}}')$$,
  'PT400', 'invalid_attachment_policy', 'Batas di atas plafon ditolak');
select throws_ok($$select cs_api.admin_set_attachment_policy('{"documents": {"enabled": true, "max_mb": 10, "formats": ["doc"]}, "images": {"enabled": true, "max_mb": 5, "formats": ["png"]}, "videos": {"enabled": true, "max_mb": 25, "max_seconds": 60, "formats": ["mp4"]}}')$$,
  'PT400', 'invalid_attachment_policy', 'Format di luar katalog ditolak');
select is(cs_api.admin_set_attachment_policy('{"documents": {"enabled": true, "max_mb": 5, "formats": ["pdf", "pdf"]}, "images": {"enabled": true, "max_mb": 5, "formats": ["jpeg", "png"]}, "videos": {"enabled": false, "max_mb": 25, "max_seconds": 60, "formats": ["mp4"]}}')
          -> 'policy' -> 'documents', '{"enabled": true, "max_mb": 5, "formats": ["pdf"]}'::jsonb,
  'Super Admin mematikan video dan mempersempit dokumen');
reset role;

select ok(exists (select 1 from cs.cs_audit_log where actor_id = :'sinta' and action = 'attachments.policy'),
  'Perubahan format lampiran tercatat di jejak audit');

select tests.authenticate_as(:'budi');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-videos", "path": "rooms/%s/%s/layar2.mp4", "mime": "video/mp4", "size": 1000, "duration": 5}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_not_allowed', 'Video ditolak setelah dimatikan dari Hub');
select throws_ok(format($$select cs_api.send_message(%L, '', gen_random_uuid(), null,
  '[{"bucket": "cs-documents", "path": "rooms/%s/%s/l2.docx", "mime": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "size": 1000}]')$$,
  :'room', :'room', :'budi'), 'PT400', 'attachment_not_allowed', 'Format yang dicabut ditolak');
reset role;

select * from finish();
rollback;
