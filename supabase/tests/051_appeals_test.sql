begin;
select plan(39);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'appeal');
update cs.agents set community_permissions = '{}';
select tests.create_user('ap_sari') as sari \gset
select tests.create_user('ap_budi') as budi \gset
select tests.create_user('ap_rudi') as rudi \gset
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 1}') as nadia \gset
update cs.agents set community_permissions = '{community.moderate,community.sanction}' where user_id in (:'dodi', :'maya');
insert into public.posts (id, author_id, body) values
  ('a1710000-0000-4000-8000-000000000001', :'budi', 'Analisa saham pilihan minggu ini'),
  ('a1710000-0000-4000-8000-000000000002', :'budi', 'Postingan biasa yang tetap tampil'),
  ('a1710000-0000-4000-8000-000000000003', :'rudi', 'Konten milik Rudi');
insert into public.comments (id, post_id, author_id, body)
values ('a1710000-0000-4000-8000-000000000011', 'a1710000-0000-4000-8000-000000000002', :'budi', 'Komentar yang dihapus moderator');

select tests.authenticate_agent(:'dodi');
select cs_api.community_sanction_user(:'sari', 'Spam ajakan grup berulang', 'mute', 24) as sanctioned \gset
select cs_api.community_resolve_report('post', 'a1710000-0000-4000-8000-000000000001', 'hide', 'Dianggap menyesatkan') as hidden \gset
select cs_api.community_resolve_report('comment', 'a1710000-0000-4000-8000-000000000011', 'remove', 'Dianggap spam') as removed \gset
reset role;
select id as sanction_id from private.user_sanctions where user_id = :'sari' \gset

select tests.authenticate_as(:'sari');
select throws_ok(format($$select create_appeal('sanction', %L, 'pendek')$$, :'sanction_id'), 'PT400', 'invalid_reason',
  'Alasan banding minimal 10 karakter');
select throws_ok(format($$select create_appeal('akun', %L, 'Saya tidak melakukan spam')$$, :'sanction_id'), 'PT400', 'invalid_target',
  'Jenis banding divalidasi');
select is(create_appeal('sanction', :'sanction_id', 'Saya tidak melakukan spam, itu grup resmi kantor') ->> 'status', 'pending',
  'Pengguna mengajukan banding atas sanksi');
select throws_ok(format($$select create_appeal('sanction', %L, 'Saya ajukan lagi bandingnya')$$, :'sanction_id'), 'PT409', 'appeal_exists',
  'Satu banding per sanksi');
select is((select count(*)::int from get_my_appeals()), 1, 'Pengguna melihat bandingnya sendiri');
select is((select count(*)::int from public.appeals), 1, 'RLS: pengguna hanya melihat banding miliknya');
select throws_ok($$select original_decider from public.appeals$$, '42501', null, 'Identitas staf pemutus tidak terbaca pengguna');

select tests.authenticate_as(:'budi');
select throws_ok(format($$select create_appeal('sanction', %L, 'Bukan sanksi saya tapi coba')$$, :'sanction_id'), 'PT404', 'target_not_found',
  'Tidak bisa banding atas sanksi orang lain');
select throws_ok($$select create_appeal('post', 'a1710000-0000-4000-8000-000000000002', 'Postingan ini tidak dibatasi')$$,
  'PT409', 'appeal_not_allowed', 'Konten yang tidak dibatasi tidak bisa dibanding');
select throws_ok($$select create_appeal('post', 'a1710000-0000-4000-8000-000000000003', 'Konten bukan milik saya')$$,
  'PT404', 'target_not_found', 'Tidak bisa banding atas konten orang lain');
select lives_ok($$select create_appeal('post', 'a1710000-0000-4000-8000-000000000001', 'Analisa saya berbasis data laporan keuangan')$$,
  'Banding atas postingan yang disembunyikan');
select lives_ok($$select create_appeal('comment', 'a1710000-0000-4000-8000-000000000011', 'Komentar saya bukan spam sama sekali')$$,
  'Banding atas komentar yang dihapus moderator');

select tests.authenticate_agent(:'nadia');
select throws_ok('select cs_api.community_appeals()', 'PT403', 'community_forbidden', 'Staf tanpa izin komunitas tidak melihat banding');

select tests.authenticate_agent(:'dodi');
select is(jsonb_array_length(cs_api.community_appeals()), 3, 'Moderator melihat antrean banding');
select is((select x -> 'original_decider' ->> 'name' from jsonb_array_elements(cs_api.community_appeals()) x
           where x ->> 'target_type' = 'sanction'), 'Dodi', 'Antrean menampilkan pemberi keputusan awal');
select is((select (x ->> 'can_decide')::boolean from jsonb_array_elements(cs_api.community_appeals()) x
           where x ->> 'target_type' = 'sanction'), false, 'Pemberi sanksi tidak bisa memutus bandingnya sendiri');
select is((select x -> 'target' ->> 'excerpt' from jsonb_array_elements(cs_api.community_appeals()) x
           where x ->> 'target_type' = 'comment'), 'Komentar yang dihapus moderator', 'Isi konten yang dihapus tampil dari arsip');
select (x ->> 'id') as appeal_sanction from jsonb_array_elements(cs_api.community_appeals()) x where x ->> 'target_type' = 'sanction' \gset
select (x ->> 'id') as appeal_post from jsonb_array_elements(cs_api.community_appeals()) x where x ->> 'target_type' = 'post' \gset
select (x ->> 'id') as appeal_comment from jsonb_array_elements(cs_api.community_appeals()) x where x ->> 'target_type' = 'comment' \gset
select throws_ok(format($$select cs_api.community_appeal_decide(%L, true, 'Saya cabut sendiri')$$, :'appeal_sanction'),
  'PT403', 'appeal_reviewer_conflict', 'Peninjau harus berbeda dari pemberi sanksi bila ada staf lain');
select throws_ok(format($$select cs_api.community_appeal_decide(%L, true, 'ok')$$, :'appeal_sanction'),
  'PT400', 'note_required', 'Catatan keputusan wajib');

select tests.authenticate_agent(:'maya');
select is(cs_api.community_appeal_decide(:'appeal_sanction', true, 'Grup resmi, bukan spam') ->> 'status', 'accepted',
  'Staf lain menerima banding sanksi');
select throws_ok(format($$select cs_api.community_appeal_decide(%L, false, 'Berubah pikiran')$$, :'appeal_sanction'),
  'PT409', 'appeal_decided', 'Banding yang sudah diputus tidak bisa diputus ulang');
select is(cs_api.community_appeal_decide(:'appeal_post', true, 'Analisa berbasis data') ->> 'status', 'accepted',
  'Banding konten tersembunyi diterima');
select is(cs_api.community_appeal_decide(:'appeal_comment', true, 'Bukan spam') -> 'decided_by' ->> 'name', 'Maya',
  'Pemutus banding tercatat');

reset role;
select ok((select revoked_at is not null and revoked_by = :'maya' from private.user_sanctions where id = :'sanction_id'),
  'Menerima banding mencabut sanksi');
select ok(not private.is_muted(:'sari'), 'Pengguna tidak lagi dibisukan');
select is((select moderation_status from public.posts where id = 'a1710000-0000-4000-8000-000000000001'), 'visible',
  'Postingan yang dibanding tampil lagi');
select is((select body || '/' || (deleted_at is null) from public.comments where id = 'a1710000-0000-4000-8000-000000000011'),
  'Komentar yang dihapus moderator/true', 'Komentar yang dihapus dipulihkan dari arsip');
select is((select count(*)::int from public.notifications where user_id = :'sari' and type = 'appeal'
           and payload ->> 'status' = 'accepted'), 1, 'Pengguna diberi notifikasi keputusan banding');
select ok(exists (select 1 from private.push_queue where user_id = :'sari' and kind = 'appeal')
          or not exists (select 1 from private.push_devices where user_id = :'sari'),
  'Notifikasi banding memakai jalur push yang ada');
select is((select count(*)::int from cs.cs_audit_log where action = 'community.appeal_decide' and actor_id = :'maya'), 3,
  'Keputusan banding tercatat di audit');

update cs.agents set community_permissions = '{}' where user_id = :'maya';
select tests.authenticate_agent(:'dodi');
select cs_api.community_sanction_user(:'budi', 'Peringatan ajakan beli', 'warning') as warned \gset
reset role;
select id as warning_id from private.user_sanctions where user_id = :'budi' and kind = 'warning' \gset
select tests.authenticate_as(:'budi');
select create_appeal('sanction', :'warning_id', 'Saya hanya berbagi analisa, bukan ajakan') ->> 'id' as appeal_warning \gset
select tests.authenticate_agent(:'dodi');
select is(cs_api.community_appeal_decide(:'appeal_warning', false, 'Ajakan beli tetap melanggar') ->> 'status', 'rejected',
  'Bila tidak ada staf lain yang berwenang, pemberi sanksi boleh memutus');
reset role;
select ok((select revoked_at is null from private.user_sanctions where id = :'warning_id'), 'Banding ditolak: sanksi tetap');
select is((select payload ->> 'title' from public.notifications where user_id = :'budi' and type = 'appeal'
           and payload ->> 'status' = 'rejected'),
  'Banding Anda ditolak', 'Penolakan banding juga diberitahukan');

update private.user_sanctions set created_at = now() - interval '40 days', starts_at = now() - interval '40 days'
 where user_id = :'sari';
insert into private.user_sanctions (user_id, kind, reason, created_at, starts_at)
values (:'sari', 'warning', 'lama', now() - interval '40 days', now() - interval '40 days') returning id as old_id \gset
select tests.authenticate_as(:'sari');
select throws_ok(format($$select create_appeal('sanction', %L, 'Sanksi lama ingin saya banding')$$, :'old_id'),
  'PT400', 'appeal_window_closed', 'Banding dibatasi 30 hari');

select tests.authenticate_agent(:'dodi');
select is((cs_api.community_zero_tolerance(:'rudi', 'Materi eksploitasi anak') -> 'hidden' ->> 'posts')::int, 1,
  'Toleransi nol: semua konten akun disembunyikan');
reset role;
select ok(private.is_banned(:'rudi') and exists (select 1 from private.user_sanctions where user_id = :'rudi'
          and kind = 'ban' and ends_at is null and category = 'zero_tolerance'), 'Toleransi nol: ban permanen');
select id as zt_id from private.user_sanctions where user_id = :'rudi' and category = 'zero_tolerance' \gset
select tests.authenticate_as(:'rudi');
select throws_ok(format($$select create_appeal('sanction', %L, 'Mohon ditinjau kembali sanksinya')$$, :'zt_id'),
  'PT403', 'appeal_not_allowed', 'Sanksi toleransi nol tidak bisa dibanding');
select tests.authenticate_with(:'rudi', jsonb_build_object('iat', floor(extract(epoch from now())) + 5));
select set_config('request.path', '/rpc/create_appeal', true) as path_appeal \gset
select lives_ok('select private.check_request()', 'Akun yang di-ban tetap bisa membuka jalur banding');
select set_config('request.path', '/rpc/get_feed', true) as path_feed \gset
select throws_ok('select private.check_request()', 'PT403', 'user_banned', 'Akun yang di-ban tetap ditolak di fitur lain');

select * from finish();
rollback;
