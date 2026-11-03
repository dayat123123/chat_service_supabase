begin;
select plan(36);

delete from private.link_preview_queue;
delete from public.link_previews;
delete from private.link_preview_image_scores;

select private.link_preview_hash('https://aman.nsfw.example/') as h_safe,
       private.link_preview_hash('https://porno.nsfw.example/') as h_porn,
       private.link_preview_hash('https://ragu.nsfw.example/') as h_hold,
       private.link_preview_hash('https://mati.nsfw.example/') as h_down,
       private.link_preview_hash('https://tanpa-hash.nsfw.example/') as h_nosha,
       private.link_preview_hash('https://skor-aneh.nsfw.example/') as h_bad,
       private.link_preview_hash('https://cache.nsfw.example/') as h_cache,
       private.link_preview_hash('https://ulang.nsfw.example/') as h_ulang,
       repeat('a', 64) as sha_safe, repeat('b', 64) as sha_porn, repeat('c', 64) as sha_hold,
       repeat('d', 64) as sha_down, repeat('e', 64) as sha_bad \gset

select has_table('private', 'link_preview_image_scores', 'Cache skor gambar pratinjau ada');
select ok((select relrowsecurity from pg_class where oid = 'private.link_preview_image_scores'::regclass),
  'RLS aktif di cache skor gambar');
select has_column('public', 'link_previews', 'image_verdict', 'Verdict gambar dicatat per pratinjau');
select has_column('public', 'link_previews', 'image_sha256', 'Hash gambar dicatat per pratinjau');
select ok(not exists (select 1 from public.link_previews where image_path is not null and image_verdict is distinct from 'allow'),
  'Tidak ada gambar pratinjau yang belum lolos klasifikasi');
select throws_ok(format($$insert into public.link_previews (url_hash, url, status, title, image_path, image_width, image_height, expires_at)
                         values (%L, 'https://x.nsfw.example/', 'ok', 'X', %L, 10, 10, now() + interval '1 day')$$,
                        private.link_preview_hash('https://x.nsfw.example/'),
                        private.link_preview_hash('https://x.nsfw.example/') || '/0123456789abcdef/preview.png'),
  '23514', null, 'Gambar tanpa verdict allow ditolak tabel');

select tests.authenticate_as(tests.create_user('lp_nsfw_budi'));
select throws_ok(format($$select public.link_preview_image_scores(%L)$$, repeat('a', 64)), '42501', null,
  'Pengguna tidak bisa membaca cache skor gambar');
reset role;

insert into private.link_preview_queue (url_hash, url, source)
select private.link_preview_hash(u), u, 'post'
from unnest(array['https://aman.nsfw.example/', 'https://porno.nsfw.example/', 'https://ragu.nsfw.example/',
                  'https://mati.nsfw.example/', 'https://tanpa-hash.nsfw.example/', 'https://skor-aneh.nsfw.example/',
                  'https://cache.nsfw.example/']) u;
select tests.authenticate_service();
select is(jsonb_array_length(public.link_preview_claim('lp-n', 100, 120)), 7, 'Worker mengambil semua link');
select is(public.link_preview_report('lp-n', jsonb_build_array(
  jsonb_build_object('url_hash', :'h_safe', 'status', 'ok', 'title', 'Aman',
    'image_path', :'h_safe' || '/0123456789abcdef/preview.png', 'image_width', 64, 'image_height', 64,
    'image_sha256', :'sha_safe', 'image_verdict', 'allow', 'image_category', 'porn', 'image_score', 0.01,
    'image_model', 'mnv4@1', 'image_scores', jsonb_build_object('neutral', 0.98, 'porn', 0.01), 'thresholds_revision', 3),
  jsonb_build_object('url_hash', :'h_porn', 'status', 'ok', 'title', 'Judul tetap', 'description', 'Deskripsi tetap',
    'image_path', :'h_porn' || '/0123456789abcdef/preview.jpg', 'image_width', 64, 'image_height', 64,
    'image_sha256', :'sha_porn', 'image_verdict', 'block', 'image_category', 'porn', 'image_score', 0.97123,
    'image_model', 'mnv4@1', 'image_scores', jsonb_build_object('porn', 0.97123, 'neutral', 0.01), 'thresholds_revision', 3),
  jsonb_build_object('url_hash', :'h_hold', 'status', 'ok', 'title', 'Ragu',
    'image_sha256', :'sha_hold', 'image_verdict', 'hold', 'image_category', 'sexy', 'image_score', 0.88,
    'image_model', 'mnv4@1', 'image_scores', jsonb_build_object('sexy', 0.88), 'thresholds_revision', 3),
  jsonb_build_object('url_hash', :'h_down', 'status', 'ok', 'title', 'Classifier mati',
    'image_sha256', :'sha_down', 'image_verdict', 'unavailable'),
  jsonb_build_object('url_hash', :'h_nosha', 'status', 'ok', 'title', 'Tanpa hash',
    'image_path', :'h_nosha' || '/0123456789abcdef/preview.png', 'image_width', 64, 'image_height', 64,
    'image_verdict', 'allow'),
  jsonb_build_object('url_hash', :'h_bad', 'status', 'ok', 'title', 'Skor aneh',
    'image_sha256', :'sha_bad', 'image_verdict', 'allow', 'image_model', 'mnv4@1',
    'image_scores', jsonb_build_object('porn', 1.5)),
  jsonb_build_object('url_hash', :'h_cache', 'status', 'ok',
    'image_path', :'h_cache' || '/0123456789abcdef/preview.png', 'image_width', 64, 'image_height', 64,
    'image_sha256', :'sha_porn', 'image_verdict', 'block', 'image_category', 'porn', 'image_score', 0.97))), 7,
  'Tujuh hasil dengan verdict gambar diterapkan');
select is(public.link_preview_image_scores(:'sha_porn'),
  jsonb_build_object('model', 'mnv4@1', 'scores', jsonb_build_object('porn', 0.97123, 'neutral', 0.01)),
  'Skor gambar bisa dibaca ulang dari cache per hash');
select is(public.link_preview_image_scores(repeat('f', 64)), null, 'Hash yang belum pernah diklasifikasi tidak ada di cache');
reset role;

select results_eq(
  $$select status, image_path is not null, image_verdict, image_sha256, image_thresholds_revision
    from public.link_previews where url = 'https://aman.nsfw.example/'$$,
  format($$values ('ok'::text, true, 'allow'::text, %L::text, 3::bigint)$$, :'sha_safe'),
  'Gambar yang lolos klasifikasi disimpan dengan verdict allow');
select results_eq(
  $$select status, title, description, image_path, image_width, image_verdict, image_category, image_score
    from public.link_previews where url = 'https://porno.nsfw.example/'$$,
  $$values ('ok'::text, 'Judul tetap'::text, 'Deskripsi tetap'::text, null::text, null::integer, 'block'::text, 'porn'::text, 0.9712::numeric)$$,
  'Gambar eksplisit dibuang, judul dan deskripsi tetap, verdict dicatat');
select results_eq(
  $$select status, image_path, image_verdict, image_category from public.link_previews where url = 'https://ragu.nsfw.example/'$$,
  $$values ('ok'::text, null::text, 'hold'::text, 'sexy'::text)$$,
  'Gambar ragu-ragu tidak ditampilkan dan tidak masuk antrean tinjauan');
select results_eq(
  $$select status, title, image_path, image_verdict from public.link_previews where url = 'https://mati.nsfw.example/'$$,
  $$values ('ok'::text, 'Classifier mati'::text, null::text, 'unavailable'::text)$$,
  'Classifier mati: pratinjau tanpa gambar (fail closed)');
select ok((select expires_at between now() + interval '23 hours' and now() + interval '25 hours'
           from public.link_previews where url = 'https://mati.nsfw.example/'),
  'Pratinjau tanpa klasifikasi hanya di-cache selama masa gagal');
select results_eq(
  $$select locked_by, attempts, error, available_at > now() + interval '30 seconds'
    from private.link_preview_queue where url = 'https://mati.nsfw.example/'$$,
  $$values (null::text, 1, 'classifier_unavailable'::text, true)$$,
  'Classifier mati: link dicoba lagi dengan jeda');
select is((select image_path from public.link_previews where url = 'https://tanpa-hash.nsfw.example/'), null,
  'Gambar tanpa hash klasifikasi ditolak');
select is((select status from public.link_previews where url = 'https://cache.nsfw.example/'), 'empty',
  'Link gambar langsung yang diblokir menjadi pratinjau kosong');
select is((select image_verdict from public.link_previews where url = 'https://cache.nsfw.example/'), 'block',
  'Verdict dari cache tetap dicatat');
select ok(not exists (select 1 from private.link_preview_image_scores where sha256 = :'sha_bad'),
  'Skor di luar rentang tidak disimpan di cache');
select ok(not exists (select 1 from private.link_preview_image_scores where sha256 = :'sha_down'),
  'Gambar yang belum diklasifikasi tidak masuk cache');
select is((select count(*)::integer from private.link_preview_image_scores), 3, 'Tiga gambar tersimpan di cache');
select ok(not exists (select 1 from private.link_preview_queue
                      where url in ('https://aman.nsfw.example/', 'https://porno.nsfw.example/', 'https://ragu.nsfw.example/')),
  'Link dengan verdict final keluar dari antrean');

select tests.authenticate_as(tests.create_user('lp_nsfw_sari'));
select results_eq(
  $$select url, status, title, image_path is not null from public.get_link_previews(array[
      'https://aman.nsfw.example/', 'https://porno.nsfw.example/', 'https://ragu.nsfw.example/', 'https://mati.nsfw.example/'])$$,
  $$values ('https://aman.nsfw.example/'::text, 'ok'::text, 'Aman'::text, true),
           ('https://porno.nsfw.example/', 'ok', 'Judul tetap', false),
           ('https://ragu.nsfw.example/', 'ok', 'Ragu', false),
           ('https://mati.nsfw.example/', 'ok', 'Classifier mati', false)$$,
  'Klien hanya melihat gambar yang lolos; teks tetap tampil selama classifier dicoba lagi');
reset role;

update private.link_preview_queue set available_at = now() - interval '1 second', attempts = 2
 where url = 'https://mati.nsfw.example/';
select tests.authenticate_service();
select is((public.link_preview_claim('lp-n', 100, 120) -> 0 ->> 'attempt')::integer, 3, 'Percobaan terakhir diambil');
select is(public.link_preview_report('lp-n', jsonb_build_array(jsonb_build_object('url_hash', :'h_down', 'status', 'ok',
  'title', 'Classifier mati', 'image_sha256', :'sha_down', 'image_verdict', 'unavailable'))), 1,
  'Laporan percobaan terakhir diterima');
reset role;
select ok(not exists (select 1 from private.link_preview_queue where url = 'https://mati.nsfw.example/'),
  'Setelah batas percobaan, pratinjau tetap tanpa gambar dan tidak diantrekan lagi');
select results_eq($$select status, image_verdict from public.link_previews where url = 'https://mati.nsfw.example/'$$,
  $$values ('ok'::text, 'unavailable'::text)$$, 'Verdict unavailable tetap tercatat');

update private.link_preview_image_scores set last_used_at = now() - interval '10 days' where sha256 = :'sha_porn';
insert into private.link_preview_queue (url_hash, url, source)
values (private.link_preview_hash('https://ulang.nsfw.example/'), 'https://ulang.nsfw.example/', 'comment');
select tests.authenticate_service();
select is(jsonb_array_length(public.link_preview_claim('lp-n', 100, 120)), 1, 'Link baru diambil');
select is(public.link_preview_report('lp-n', jsonb_build_array(jsonb_build_object(
  'url_hash', :'h_ulang', 'status', 'ok', 'title', 'Ulang',
  'image_sha256', :'sha_porn', 'image_verdict', 'block', 'image_category', 'porn', 'image_score', 0.97))), 1,
  'Verdict dari cache dilaporkan tanpa skor');
reset role;
select ok((select last_used_at > now() - interval '1 minute' from private.link_preview_image_scores where sha256 = :'sha_porn'),
  'Cache yang dipakai lagi diperbarui waktunya');
select is((select scores from private.link_preview_image_scores where sha256 = :'sha_porn'),
  jsonb_build_object('porn', 0.97123, 'neutral', 0.01), 'Skor cache tidak berubah karena verdict ulang');

update private.link_preview_image_scores set last_used_at = now() - interval '60 days' where sha256 = :'sha_hold';
select ok(private.link_preview_purge() >= 0, 'Purge harian berjalan');
select ok(not exists (select 1 from private.link_preview_image_scores where sha256 = :'sha_hold'),
  'Purge menghapus skor yang lama tidak dipakai');
select ok(exists (select 1 from private.link_preview_image_scores where sha256 = :'sha_porn'),
  'Purge mempertahankan skor yang masih dipakai');

select * from finish();
rollback;
