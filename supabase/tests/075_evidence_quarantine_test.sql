begin;
select plan(68);

select tests.create_user('ev_budi') as budi \gset
select tests.create_user('ev_sari') as sari \gset
select tests.create_user('ev_tono') as tono \gset
select tests.create_user('ev_wati') as wati \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset

select 'posts/' || :'budi' || '/bukti.png' as post_path \gset
select :'budi' || '/avatar-1.png' as avatar_path \gset

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('attachments', :'post_path', :'budi', '{"size": 11}'),
  ('avatars', :'avatar_path', :'budi', '{"size": 5}');
update public.profiles
   set avatar_url = 'http://localhost:8000/storage/v1/object/public/avatars/' || :'avatar_path', bio = 'Bio asli Budi'
 where id = :'budi';
insert into public.posts (author_id, body, attachments)
values (:'budi', 'Saham ABCD pasti naik 300%, transfer ke saya',
        jsonb_build_array(jsonb_build_object('path', :'post_path', 'mime', 'image/png')))
returning id as post \gset

select tests.authenticate_as(:'sari');
insert into public.reports (reporter_id, target_type, target_id, reason, details)
values (:'sari', 'post', :'post', 'pump_and_dump', 'Ajakan goreng saham') returning id as report1 \gset
reset role;

select id as ev, seq as ev_seq from private.evidence where target_type = 'post' and target_id = :'post' \gset
select id as file_id, object_name as obj from private.evidence_files where evidence_id = :'ev' \gset

select is((select source from private.evidence where id = :'ev'), 'report', 'Laporan merekam bukti postingan');
select is((select content ->> 'body' from private.evidence where id = :'ev'),
  'Saham ABCD pasti naik 300%, transfer ke saya', 'Teks asli tersimpan utuh');
select is((select content_sha256 from private.evidence where id = :'ev'),
  (select encode(sha256(convert_to(content::text, 'UTF8')), 'hex') from private.evidence where id = :'ev'),
  'Sidik SHA-256 isi bukti tercatat');
select is((select body_sha256 from private.evidence where id = :'ev'),
  encode(sha256(convert_to('Saham ABCD pasti naik 300%, transfer ke saya', 'UTF8')), 'hex'),
  'Sidik SHA-256 teks tercatat');
select is((select context -> 'author' ->> 'username' from private.evidence where id = :'ev'), 'ev_budi',
  'Identitas penulis saat direkam ikut tersimpan');
select is((select status from private.evidence_files where evidence_id = :'ev'), 'pending',
  'Lampiran menunggu disalin ke bucket evidence');
select ok(:'obj' like :'ev' || '/01-bukti.png', 'Salinan diberi nama per bukti');
select ok((select retain_until between now() + interval '729 days' and now() + interval '731 days'
           from private.evidence where id = :'ev'), 'Masa simpan bawaan 730 hari');
select is((select details ->> 'report_id' from private.evidence_custody where evidence_id = :'ev' and action = 'captured'),
  :'report1', 'Jejak penanganan mencatat laporan pemicu');

select tests.authenticate_as(:'tono');
insert into public.reports (reporter_id, target_type, target_id, reason) values (:'tono', 'post', :'post', 'scam')
returning id as report2 \gset
reset role;
select is((select count(*)::integer from private.evidence where target_type = 'post' and target_id = :'post'), 1,
  'Laporan kedua atas isi yang sama tidak menggandakan bukti');
select is((select count(*)::integer from private.evidence_custody where evidence_id = :'ev' and action = 'linked'), 1,
  'Laporan kedua ditautkan di jejak penanganan');

select set_config('storage.allow_delete_query', 'true', true) as allow_delete \gset
select tests.authenticate_as(:'budi');
select throws_ok(format($$delete from storage.objects where bucket_id = 'attachments' and name = %L$$, :'post_path'),
  'PT409', 'evidence_pending', 'Pemilik tidak bisa menghapus file sumber sebelum salinan bukti selesai');
reset role;

select tests.authenticate_as(:'budi');
select lives_ok('select public.delete_my_account()', 'Akun penulis tetap bisa dihapus');
reset role;
select is((select count(*)::integer from private.evidence where id = :'ev'), 1, 'Bukti tidak ikut terhapus bersama akun');

select tests.authenticate_service();
select public.storage_cleanup_claim('janitor-ev', 100, 1000, 300) as cleanup1 \gset
reset role;
select ok(not exists (select 1 from jsonb_array_elements(:'cleanup1'::jsonb) e
                      where e ->> 'prefix' = 'posts/' || :'budi' || '/'),
  'Folder lampiran menunggu salinan bukti sebelum dibersihkan');
select ok(exists (select 1 from jsonb_array_elements(:'cleanup1'::jsonb) e where e ->> 'bucket' = 'avatars'),
  'Folder tanpa bukti tetap dibersihkan seperti biasa');

select tests.authenticate_as(:'sari');
select throws_ok($$select public.evidence_copy_claim('x')$$, '42501', null, 'Nasabah tidak bisa mengambil antrean salinan');
reset role;

select tests.authenticate_service();
select public.evidence_copy_claim('janitor-ev', 100, 300) as copy1 \gset
select is((select e ->> 'source_name' from jsonb_array_elements(:'copy1'::jsonb) e
           where (e ->> 'id')::bigint = :'file_id'::bigint),
  :'post_path', 'Janitor menerima file sumber yang harus disalin');
select is(public.evidence_copy_report('janitor-ev', jsonb_build_array(jsonb_build_object(
  'id', :'file_id',
  'sha256', repeat('a', 64), 'size', 11))), 1, 'Laporan salinan diterima');
reset role;
select is((select error from private.evidence_files where evidence_id = :'ev'), 'Salinan bukti tidak ditemukan di storage',
  'Salinan yang tidak ada di storage tidak dianggap selesai');

insert into storage.objects (bucket_id, name, metadata) values ('evidence', :'obj', '{"size": 11}');
update private.evidence_files set available_at = now() - interval '1 second' where evidence_id = :'ev';
select encode(sha256(convert_to('isi-gambar!', 'UTF8')), 'hex') as file_hash \gset
select tests.authenticate_service();
select public.evidence_copy_claim('janitor-ev', 100, 300) as copy2 \gset
select public.evidence_copy_report('janitor-ev', jsonb_build_array(jsonb_build_object(
  'id', :'file_id', 'sha256', :'file_hash', 'size', 11)))
  as reported \gset
reset role;
select results_eq(format($$select status, sha256, size from private.evidence_files where evidence_id = %L$$, :'ev'),
  format($$values ('copied'::text, %L::text, 11::bigint)$$, :'file_hash'), 'Salinan tercatat beserta SHA-256 dan ukurannya');
select is((select details ->> 'sha256' from private.evidence_custody where evidence_id = :'ev' and action = 'file_copied'),
  :'file_hash', 'Penyalinan masuk jejak penanganan');

select tests.authenticate_service();
select public.storage_cleanup_claim('janitor-ev2', 100, 1000, 300) as cleanup2 \gset
reset role;
select ok(exists (select 1 from jsonb_array_elements(:'cleanup2'::jsonb) e where e ->> 'prefix' = 'posts/' || :'budi' || '/'),
  'Setelah tersalin, file asli dibersihkan seperti biasa');

select throws_ok(format($$update private.evidence set content = '{}' where id = %L$$, :'ev'),
  'PT409', 'evidence_immutable', 'Isi bukti tidak bisa diubah');
select throws_ok(format($$delete from private.evidence where id = %L$$, :'ev'),
  'PT409', 'evidence_retained', 'Bukti dalam masa simpan tidak bisa dihapus');
select throws_ok(format($$update private.evidence_files set sha256 = %L where evidence_id = %L$$, repeat('b', 64), :'ev'),
  'PT409', 'evidence_immutable', 'File bukti yang sudah tersalin tidak bisa diubah');
select throws_ok(format($$update private.evidence_custody set action = 'viewed' where evidence_id = %L$$, :'ev'),
  'PT409', 'evidence_immutable', 'Jejak penanganan tidak bisa diubah');
select throws_ok(format($$delete from private.evidence_custody where evidence_id = %L$$, :'ev'),
  'PT409', 'evidence_immutable', 'Jejak penanganan tidak bisa dihapus');
select throws_ok('truncate private.evidence_custody', 'PT409', 'evidence_immutable', 'Jejak penanganan tidak bisa dikosongkan');
select throws_ok(format($$delete from storage.objects where bucket_id = 'evidence' and name = %L$$, :'obj'),
  'PT409', 'evidence_retained', 'Salinan bukti di storage tidak bisa dihapus');
select throws_ok(format($$insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values ('evidence', %L, 'account_delete')$$,
                        :'ev' || '/'),
  'PT403', 'evidence_protected', 'Folder bukti tidak bisa masuk antrean pembersihan biasa');

select tests.authenticate_as(:'sari');
select throws_ok('select cs_api.evidence_list()', 'PT403', 'agent_required', 'Nasabah tidak bisa membuka daftar bukti');
reset role;
select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.evidence_list()', 'PT403', 'role_forbidden', 'CS biasa tidak bisa membuka daftar bukti');
select is((select count(*)::integer from storage.objects where bucket_id = 'evidence'), 0,
  'CS biasa tidak bisa membaca file bukti');
reset role;

select tests.authenticate_agent(:'sinta');
select is((select count(*)::integer from storage.objects where bucket_id = 'evidence' and name = :'obj'), 0,
  'Super Admin belum bisa membaca file sebelum membuka bukti');
select ok(cs_api.evidence_list(:'report1') -> 'rows' @> jsonb_build_array(jsonb_build_object('id', :'ev')),
  'Super Admin mencari bukti lewat ID laporan');
select is(cs_api.evidence_list() ->> 'can_manage', 'false', 'Super Admin hanya membaca');
select is(cs_api.evidence_detail(:'ev') -> 'content' ->> 'body', 'Saham ABCD pasti naik 300%, transfer ke saya',
  'Super Admin membuka isi bukti');
select is((select count(*)::integer from storage.objects where bucket_id = 'evidence' and name = :'obj'), 1,
  'Setelah dibuka (tercatat), Super Admin bisa membaca file bukti');
select throws_ok(format($$select cs_api.evidence_set_hold(%L, true, 'Permintaan penyidik nomor 12')$$, :'ev'),
  'PT403', 'role_forbidden', 'Super Admin tidak bisa memasang legal hold');
select throws_ok(format($$select cs_api.evidence_export(%L, 'Permintaan OJK')$$, :'ev'),
  'PT403', 'role_forbidden', 'Super Admin tidak bisa mengekspor bukti');
reset role;

select tests.authenticate_agent(:'kirana');
select ok(cs_api.evidence_list('EV-' || :'ev_seq') -> 'rows' -> 0 ->> 'id' = :'ev', 'Kepatuhan mencari bukti lewat kode');
select is((cs_api.evidence_list() -> 'summary' ->> 'retention_days')::integer, 730, 'Ringkasan memuat masa simpan');
select cs_api.evidence_detail(:'ev') as detail \gset
select is(:'detail'::jsonb -> 'files_detail' -> 0 ->> 'sha256', :'file_hash', 'Detail memuat sidik file');
select is(jsonb_array_length(:'detail'::jsonb -> 'reports'), 2, 'Detail memuat kedua laporan');
select is(:'detail'::jsonb -> 'custody' -> 0 ->> 'action', 'viewed', 'Membuka bukti tercatat di jejak penanganan');
select cs_api.evidence_verify(:'ev') as verify1 \gset
select results_eq(format($$select (%L::jsonb ->> 'ok')::boolean, (%L::jsonb ->> 'custody_ok')::boolean,
                                  (%L::jsonb ->> 'files_ok')::boolean$$, :'verify1', :'verify1', :'verify1'),
  $$values (true, true, true)$$, 'Pemeriksaan integritas lolos');
select is(cs_api.evidence_file_checked(:'file_id'::bigint, upper(:'file_hash'))
  ->> 'match', 'true', 'Sidik file yang dihitung ulang cocok');
select is(cs_api.evidence_file_checked(:'file_id'::bigint, repeat('c', 64))
  ->> 'match', 'false', 'Sidik yang berbeda terdeteksi');
select throws_ok(format($$select cs_api.evidence_set_hold(%L, true, 'pendek')$$, :'ev'),
  'PT400', 'reason_required', 'Legal hold wajib beralasan');
select is(cs_api.evidence_set_hold(:'ev', true, 'Permintaan penyidik nomor 12/2026') ->> 'legal_hold', 'true',
  'Kepatuhan memasang legal hold');
select throws_ok(format($$select cs_api.evidence_set_hold(%L, true, 'Permintaan penyidik nomor 12/2026')$$, :'ev'),
  'PT409', 'hold_unchanged', 'Legal hold tidak dipasang dua kali');
select throws_ok(format($$select cs_api.evidence_export(%L, 'abc')$$, :'ev'),
  'PT400', 'purpose_required', 'Ekspor wajib menyebut tujuan');
select cs_api.evidence_export(:'ev', 'Permintaan OJK nomor S-12/2026') as bundle \gset
reset role;

select is(:'bundle'::jsonb ->> 'format', 'olt-evidence-bundle/1', 'Paket ekspor berformat manifest');
select is(:'bundle'::jsonb ->> 'manifest_sha256',
  encode(sha256(convert_to((:'bundle'::jsonb - 'manifest_sha256')::text, 'UTF8')), 'hex'),
  'Manifest bersidik SHA-256');
select is((select details ->> 'manifest_sha256' from private.evidence_custody where evidence_id = :'ev' and action = 'exported'),
  :'bundle'::jsonb ->> 'manifest_sha256', 'Ekspor tercatat dengan sidik manifest');
select ok((select count(*) from cs.cs_audit_log where action in ('evidence.view', 'evidence.verify', 'evidence.export',
                                                                 'evidence.legal_hold', 'evidence.file_verify')
             and details ->> 'evidence_id' = :'ev') >= 7, 'Setiap akses bukti tercatat di audit log CS');

alter table private.evidence disable trigger evidence_20_guard;
update private.evidence set content = jsonb_set(content, '{body}', '"diubah"'), retain_until = now() - interval '1 day'
 where id = :'ev';
alter table private.evidence enable trigger evidence_20_guard;
select tests.authenticate_agent(:'kirana');
select results_eq(format($$select (v ->> 'ok')::boolean, (v ->> 'content_ok')::boolean, (v ->> 'body_ok')::boolean
                           from (select cs_api.evidence_verify(%L) as v) x$$, :'ev'),
  $$values (false, false, false)$$, 'Isi yang diubah langsung di database terdeteksi');
reset role;

select is(private.evidence_purge(), 0, 'Bukti dalam legal hold tidak dihapus walau masa simpan habis');
select tests.authenticate_agent(:'kirana');
select is(cs_api.evidence_set_hold(:'ev', false, 'Perkara sudah berkekuatan hukum tetap') ->> 'legal_hold', 'false',
  'Kepatuhan melepas legal hold');
reset role;
select ok((select retain_until > now() + interval '29 days' from private.evidence where id = :'ev'),
  'Melepas legal hold memberi tenggang 30 hari');
alter table private.evidence disable trigger evidence_20_guard;
update private.evidence set retain_until = now() - interval '1 day' where id = :'ev';
alter table private.evidence enable trigger evidence_20_guard;
select ok(private.evidence_purge() >= 1, 'Bukti yang lewat masa simpan dihapus job retensi');
select is((select count(*)::integer from private.evidence_files where evidence_id = :'ev'), 0, 'File bukti ikut terhapus');
select is((select reason from private.storage_cleanup_queue where bucket_id = 'evidence' and prefix = :'ev' || '/'),
  'evidence_expired', 'Salinan file masuk antrean janitor');

insert into public.posts (author_id, body, attachments) values (:'wati', 'Postingan Wati', '[]') returning id as wpost \gset
insert into public.comments (post_id, author_id, body) values (:'wpost', :'tono', 'Komentar kasar untuk dihapus')
returning id as comment \gset
insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
values ('comment', :'comment', :'tono', 'Komentar kasar untuk dihapus', :'kirana', 'moderator_remove');
select results_eq(format($$select source, content ->> 'body', captured_by from private.evidence
                           where target_type = 'comment' and target_id = %L$$, :'comment'),
  format($$values ('moderator_remove'::text, 'Komentar kasar untuk dihapus'::text, %L::uuid)$$, :'kirana'),
  'Penghapusan moderator merekam bukti');

select tests.authenticate_as(:'sari');
insert into public.reports (reporter_id, target_type, target_id, reason) values (:'sari', 'user', :'wati', 'abuse');
reset role;
select is((select content ->> 'username' from private.evidence where target_type = 'user' and target_id = :'wati'),
  'ev_wati', 'Laporan akun merekam profil');

insert into private.user_sanctions (user_id, kind, category, reason, created_by)
values (:'tono', 'ban', 'zero_tolerance', 'Materi terlarang', :'kirana');
select is((select count(distinct c.evidence_id)::integer from private.evidence_custody c
           join private.evidence e on e.id = c.evidence_id
           where c.details ? 'sanction_id' and e.author_id = :'tono'), 2,
  'Toleransi nol merekam profil dan konten akun');

insert into private.media_reviews (bucket, name, uploader, model, scores, category, score)
values ('attachments', 'posts/' || :'wati' || '/tahan.jpg', :'wati', 'nsfw@1', '{"porn": 0.7}', 'porn', 0.7)
returning id as review \gset
update private.media_reviews set status = 'removed', decided_at = now(), decided_by = :'kirana' where id = :'review';
select results_eq(format($$select e.source, f.source_name, f.status from private.evidence e
                           join private.evidence_files f on f.evidence_id = e.id
                           where e.target_type = 'media' and e.author_id = %L$$, :'wati'),
  format($$values ('media_removed'::text, %L::text, 'missing'::text)$$, 'posts/' || :'wati' || '/tahan.jpg'),
  'Gambar yang dihapus moderator direkam (file yang sudah tidak ada ditandai hilang)');

select * from finish();
rollback;
