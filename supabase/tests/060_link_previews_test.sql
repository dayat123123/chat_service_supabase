begin;
select plan(68);

delete from private.link_preview_queue;
delete from public.link_previews;
update private.settings set value = 'true' where key = 'link_preview.enabled';

select tests.create_user('lp_budi') as budi \gset
select tests.create_user('lp_sari') as sari \gset
select tests.create_user('lp_tono') as tono \gset
update public.profiles set created_at = now() - interval '60 days', trust_level = 1
 where id in (:'budi', :'sari', :'tono');
select private.link_preview_hash('https://news.example.com/bbca?x=1') as h_news,
       private.link_preview_hash('https://blog.example.org/a') as h_blog,
       private.link_preview_hash('https://komentar.example.net/k') as h_komentar,
       private.link_preview_hash('https://chat.example.net/dm') as h_dm,
       private.link_preview_hash('https://held.example.com/p') as h_held,
       private.link_preview_hash('https://aman.example/') as h_aman,
       private.link_preview_hash('https://stale.example.com/') as h_stale \gset

select has_table('public', 'link_previews', 'Tabel hasil pratinjau link ada');
select has_table('private', 'link_preview_queue', 'Antrean pratinjau link ada');
select ok((select relrowsecurity from pg_class where oid = 'public.link_previews'::regclass), 'RLS aktif di link_previews');
select ok((select relrowsecurity from pg_class where oid = 'private.link_preview_queue'::regclass),
  'RLS aktif di antrean pratinjau');
select results_eq(
  $$select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'link-previews'$$,
  $$values (true, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])$$,
  'Bucket link-previews publik, maks 5 MB, gambar saja');
select ok(not exists (select 1 from pg_policy where polrelid = 'storage.objects'::regclass
                       and polcmd in ('a', 'w', 'd') and pg_get_expr(polwithcheck, polrelid) like '%link-previews%'),
  'Tidak ada kebijakan tulis bucket link-previews untuk pengguna');
select bag_eq(
  $$select tgrelid::regclass::text || '.' || tgname from pg_trigger
    where not tgisinternal and tgname like '%\_50\_link\_preview'$$,
  $$values ('posts.posts_50_link_preview'), ('comments.comments_50_link_preview'), ('messages.messages_50_link_preview')$$,
  'Trigger pratinjau terpasang di postingan, komentar, dan pesan');

select is(private.link_preview_normalize('HTTPS://Example.COM'), 'https://example.com/', 'Skema dan host diseragamkan');
select is(private.link_preview_normalize('http://example.com:80/a?b=1#bagian'), 'http://example.com/a?b=1',
  'Port bawaan dan fragmen dibuang');
select is(private.link_preview_normalize('https://id.wikipedia.org/wiki/Saham_(keuangan)).'),
  'https://id.wikipedia.org/wiki/Saham_(keuangan)', 'Tanda baca penutup dibuang, kurung seimbang dipertahankan');
select is(private.link_preview_normalize('http://admin@127.0.0.1/'), null, 'URL dengan userinfo tidak diproses');
select is(private.link_preview_normalize('http://%31%32%37.0.0.1/'), null, 'Host dengan persen-encoding tidak diproses');
select is(private.link_preview_normalize('ftp://example.com/'), null, 'Hanya http dan https');
select is(private.link_preview_urls('a https://a.example/1 b https://b.example/2, c https://A.example/1 d https://c.example/ e https://d.example/'),
  array['https://a.example/1', 'https://b.example/2', 'https://c.example/'], 'Maksimal tiga link unik per konten');
select is(private.link_preview_domains('www.berita.co.id'), array['www.berita.co.id', 'berita.co.id', 'co.id', 'id'],
  'Domain induk ikut dicocokkan');

select tests.authenticate_as(:'budi');
select (public.create_post('Analisa $BBCA https://news.example.com/bbca?x=1 dan https://blog.example.org/a', null, '[]', null, null)).id as post1 \gset
select (public.create_post('Tanpa link sama sekali, hanya teks', null, '[]', null, null)).id as post2 \gset
reset role;

select bag_eq($$select url, source from private.link_preview_queue$$,
  $$values ('https://news.example.com/bbca?x=1'::text, 'post'::text), ('https://blog.example.org/a', 'post')$$,
  'Link postingan masuk antrean');

select tests.authenticate_as(:'sari');
select lives_ok(format($$select public.create_comment(%L, null, 'Sumber: https://news.example.com/bbca?x=1 dan https://komentar.example.net/k', null)$$,
  :'post1'), 'Komentar dengan link dibuat');
select get_or_create_direct_room(:'budi') as dm \gset
select lives_ok(format($$select public.send_message(%L, 'lihat https://chat.example.net/dm', null, null, '[]')$$, :'dm'),
  'Pesan DM dengan link terkirim');
reset role;

select is((select count(*)::integer from private.link_preview_queue where url = 'https://news.example.com/bbca?x=1'), 1,
  'Link yang sudah mengantre tidak digandakan');
select is((select source from private.link_preview_queue where url = 'https://komentar.example.net/k'), 'comment',
  'Link komentar masuk antrean');
select is((select source from private.link_preview_queue where url = 'https://chat.example.net/dm'), 'message',
  'Link chat DM masuk antrean');

select tests.authenticate_as(:'tono');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
reset role;
select room_id as support from cs.tickets where id = :'ticket' \gset
select tests.authenticate_as(:'tono');
select lives_ok(format($$select public.send_message(%L, 'bukti transfer https://support-only.example.com/x', null, null, '[]')$$,
  :'support'), 'Pesan nasabah ke chat CS terkirim');
reset role;
select ok(not exists (select 1 from private.link_preview_queue where url like 'https://support-only.example.com%'),
  'Link di chat CS tidak dibuatkan pratinjau');

insert into public.posts (author_id, body, moderation_status)
values (:'tono', 'Postingan ditahan https://held.example.com/p', 'held') returning id as held_post \gset
select ok(not exists (select 1 from private.link_preview_queue where url = 'https://held.example.com/p'),
  'Konten yang ditahan moderasi belum diantrekan');
update public.posts set moderation_status = 'visible' where id = :'held_post';
select ok(exists (select 1 from private.link_preview_queue where url = 'https://held.example.com/p'),
  'Konten yang dilepas moderasi diantrekan');

insert into public.link_previews (url_hash, url, status, title, fetched_at, expires_at) values
  (private.link_preview_hash('https://fresh.example.com/'), 'https://fresh.example.com/', 'ok', 'Segar', now(), now() + interval '1 day'),
  (private.link_preview_hash('https://stale.example.com/'), 'https://stale.example.com/', 'ok', 'Lama', now() - interval '8 days', now() - interval '1 day');
update public.posts set body = 'Edit: https://fresh.example.com dan https://stale.example.com' where id = :'post2';
select ok(not exists (select 1 from private.link_preview_queue where url = 'https://fresh.example.com/'),
  'Pratinjau yang masih segar tidak diambil ulang');
select ok(exists (select 1 from private.link_preview_queue where url = 'https://stale.example.com/'),
  'Pratinjau kedaluwarsa diambil ulang saat link muncul lagi lewat edit');

update private.settings set value = 'false' where key = 'link_preview.enabled';
update public.posts set body = 'Saat fitur mati https://off.example.com/' where id = :'post2';
select ok(not exists (select 1 from private.link_preview_queue where url = 'https://off.example.com/'),
  'Saklar link_preview.enabled=false menghentikan antrean');
update private.settings set value = 'true' where key = 'link_preview.enabled';

select tests.authenticate_as(:'budi');
select throws_ok($$select count(*) from public.link_previews$$, '42501', null, 'Pengguna tidak bisa membaca tabel langsung');
select throws_ok($$select public.link_preview_claim('x')$$, '42501', null, 'Pengguna tidak bisa mengambil antrean');
select throws_ok($$select public.link_preview_report('x', '[]')$$, '42501', null, 'Pengguna tidak bisa melapor hasil');
reset role;
select tests.authenticate_anon();
select throws_ok($$select * from public.get_link_previews(array['https://fresh.example.com/'])$$, '42501', null,
  'Anonim tidak bisa membaca pratinjau');
reset role;

select tests.authenticate_service();
select throws_ok($$select public.link_preview_claim('lp-a', 0)$$, 'PT400', 'invalid_claim', 'Batas claim di luar rentang ditolak');
select throws_ok($$select public.link_preview_claim('', 5)$$, 'PT400', 'invalid_instance', 'Instance kosong ditolak');
select public.link_preview_claim('lp-a', 100, 120) as claim \gset
reset role;

select is(jsonb_array_length(:'claim'), (select count(*)::integer from private.link_preview_queue),
  'Semua link yang menunggu diambil worker');
select ok((select bool_and(locked_by = 'lp-a' and locked_until > now() and attempts = 1) from private.link_preview_queue),
  'Link yang diambil dikunci untuk worker itu dan percobaannya dihitung');
select ok((select bool_and(e ->> 'url_hash' = private.link_preview_hash(e ->> 'url') and (e ->> 'attempt')::integer = 1)
           from jsonb_array_elements(:'claim'::jsonb) e), 'Claim membawa hash, URL, dan nomor percobaan');

select tests.authenticate_service();
select is(jsonb_array_length(public.link_preview_claim('lp-b')), 0, 'Worker lain tidak mengambil link yang dikunci');
select is(public.link_preview_report('lp-b', jsonb_build_array(jsonb_build_object(
  'url_hash', :'h_news', 'status', 'ok', 'title', 'Curang'))), 0,
  'Laporan dari worker yang tidak memegang kunci diabaikan');
select is(public.link_preview_report('lp-a', jsonb_build_array(
  jsonb_build_object('url_hash', :'h_news', 'status', 'ok',
    'final_url', 'https://news.example.com/bbca', 'title', E'  BBCA\n naik\t5%  ', 'description', repeat('d', 1500),
    'site_name', 'Berita Contoh',
    'image_path', :'h_news' || '/0123456789abcdef/preview.jpg',
    'image_width', 1200, 'image_height', 630, 'image_sha256', repeat('1', 64), 'image_verdict', 'allow'),
  jsonb_build_object('url_hash', :'h_blog', 'status', 'ok',
    'title', 'Blog', 'image_path', 'lain/0123456789abcdef/preview.jpg', 'image_width', 10, 'image_height', 10),
  jsonb_build_object('url_hash', :'h_komentar', 'status', 'ok'),
  jsonb_build_object('url_hash', :'h_dm', 'status', 'blocked',
    'error', 'private_address'),
  jsonb_build_object('url_hash', :'h_held', 'status', 'retry',
    'error', 'timeout'))), 5, 'Lima hasil diterapkan');
reset role;

select results_eq(
  $$select status, final_url, title, char_length(description), site_name, image_width, image_height, expires_at > now() + interval '6 days'
    from public.link_previews where url = 'https://news.example.com/bbca?x=1'$$,
  $$values ('ok'::text, 'https://news.example.com/bbca'::text, 'BBCA naik 5%'::text, 1000, 'Berita Contoh'::text, 1200, 630, true)$$,
  'Pratinjau tersimpan: teks dirapikan dan dipotong, cache 7 hari');
select is((select image_path from public.link_previews where url = 'https://blog.example.org/a'), null,
  'Path gambar di luar folder hash link ditolak');
select is((select status from public.link_previews where url = 'https://komentar.example.net/k'), 'empty',
  'Halaman tanpa judul, deskripsi, dan gambar dicatat kosong');
select results_eq($$select status, error, title from public.link_previews where url = 'https://chat.example.net/dm'$$,
  $$values ('blocked'::text, 'private_address'::text, null::text)$$, 'Link yang diblokir worker dicatat tanpa isi');
select results_eq(
  $$select locked_by, attempts, error, available_at > now() + interval '30 seconds'
    from private.link_preview_queue where url = 'https://held.example.com/p'$$,
  $$values (null::text, 1, 'timeout'::text, true)$$, 'Kegagalan sementara dicoba lagi dengan jeda');
select ok(not exists (select 1 from private.link_preview_queue
                      where url in ('https://news.example.com/bbca?x=1', 'https://komentar.example.net/k')),
  'Link yang selesai keluar dari antrean');

select tests.authenticate_service();
select is(public.link_preview_report('lp-a', jsonb_build_array(jsonb_build_object('url_hash', :'h_stale',
  'status', 'release'))), 1,
  'Worker bisa melepas link yang belum sempat diproses');
reset role;
select results_eq($$select locked_by, attempts from private.link_preview_queue where url = 'https://stale.example.com/'$$,
  $$values (null::text, 0)$$, 'Link yang dilepas kembali ke antrean tanpa menghabiskan percobaan');

update private.link_preview_queue set available_at = now() - interval '1 second', attempts = 3
 where url = 'https://held.example.com/p';
select tests.authenticate_service();
select ok(not (public.link_preview_claim('lp-a', 100, 120) @> jsonb_build_array(jsonb_build_object('url', 'https://held.example.com/p'))),
  'Link yang melewati batas percobaan tidak diambil lagi');
reset role;
select results_eq($$select status, error from public.link_previews where url = 'https://held.example.com/p'$$,
  $$values ('failed'::text, 'timeout'::text)$$, 'Link yang melewati batas percobaan dicatat gagal');
select ok((select expires_at between now() + interval '23 hours' and now() + interval '25 hours'
           from public.link_previews where url = 'https://held.example.com/p'), 'Link gagal ditahan 24 jam');

select tests.authenticate_as(:'sari');
select throws_ok(format($$select * from public.get_link_previews(array_fill(%L::text, array[21]))$$, 'https://a.example/'),
  'PT400', 'too_many_urls', 'Maksimal 20 link per permintaan');
select results_eq(
  $$select url, status, title, site_name, image_path is not null from public.get_link_previews(array[
      'HTTPS://NEWS.example.com/bbca?x=1#atas', 'https://komentar.example.net/k', 'https://stale.example.com/',
      'https://belum.example.com/', 'bukan url'])$$,
  $$values ('HTTPS://NEWS.example.com/bbca?x=1#atas'::text, 'ok'::text, 'BBCA naik 5%'::text, 'Berita Contoh'::text, true),
           ('https://komentar.example.net/k', 'none', null, null, false),
           ('https://stale.example.com/', 'ok', 'Lama', null, false),
           ('https://belum.example.com/', 'none', null, null, false),
           ('bukan url', 'none', null, null, false)$$,
  'Pratinjau dicocokkan setelah normalisasi, urut sesuai permintaan');
select is((select status from public.get_link_previews(array['https://stale.example.com']) ), 'ok',
  'Pratinjau lama tetap tampil selama belum dihapus');
reset role;

update private.link_preview_queue set locked_by = null, locked_until = null where url = 'https://stale.example.com/';
update public.link_previews set status = 'failed', title = null where url = 'https://stale.example.com/';
select tests.authenticate_as(:'sari');
select is((select status from public.get_link_previews(array['https://stale.example.com/'])), 'pending',
  'Link yang sedang mengantre ditandai pending');
reset role;

do $$
begin
  if to_regclass('cs.blocked_domains') is not null then
    alter table cs.blocked_domains rename to blocked_domains_lp060;
  end if;
  if to_regclass('cs.allowed_domains') is not null then
    alter table cs.allowed_domains rename to allowed_domains_lp060;
  end if;
end;
$$;
create table cs.blocked_domains (domain text primary key, action text);
create table cs.allowed_domains (domain text primary key);
insert into cs.blocked_domains values ('judi.example', 'block'), ('pendek.example', 'hold'), ('boleh.example', 'allow');
insert into cs.allowed_domains values ('resmi.judi.example');

select is(private.link_preview_blocked_hosts(array['www.judi.example', 'pendek.example', 'boleh.example',
                                                   'resmi.judi.example', 'aman.example']),
  array['pendek.example', 'www.judi.example'], 'Domain dan subdomain yang diblokir dikenali, allowlist dihormati');
select is(private.link_preview_enqueue(array['https://www.judi.example/promo', 'https://aman.example/'], 'post'), 1,
  'Hanya link yang aman yang diantrekan');
select results_eq($$select status, error from public.link_previews where url = 'https://www.judi.example/promo'$$,
  $$values ('blocked'::text, 'blocked_domain'::text)$$, 'Domain terblokir langsung dicatat tanpa diambil');

insert into private.link_preview_queue (url_hash, url, source)
values (private.link_preview_hash('https://pendek.example/abc'), 'https://pendek.example/abc', 'message');
update private.link_preview_queue set locked_by = null, locked_until = null, available_at = now() - interval '1 second';
select tests.authenticate_service();
select public.link_preview_claim('lp-c', 100, 120) as claim2 \gset
reset role;
select ok(not (:'claim2'::jsonb @> jsonb_build_array(jsonb_build_object('url', 'https://pendek.example/abc'))),
  'Domain yang diblokir setelah masuk antrean tidak diambil');
select is((select status from public.link_previews where url = 'https://pendek.example/abc'), 'blocked',
  'Domain yang diblokir setelah masuk antrean dicatat diblokir');

select tests.authenticate_service();
select is(public.link_preview_report('lp-c', jsonb_build_array(jsonb_build_object(
  'url_hash', :'h_aman', 'status', 'ok', 'title', 'Dialihkan',
  'final_url', 'https://judi.example/landing'))), 1, 'Hasil dengan pengalihan ke domain terblokir diterima');
reset role;
select results_eq($$select status, title from public.link_previews where url = 'https://aman.example/'$$,
  $$values ('blocked'::text, null::text)$$, 'Pengalihan ke domain terblokir tidak dibuatkan pratinjau');

insert into cs.blocked_domains values ('news.example.com', 'block');
select tests.authenticate_as(:'sari');
select is((select status from public.get_link_previews(array['https://news.example.com/bbca?x=1'])), 'none',
  'Pratinjau domain yang baru diblokir tidak lagi ditampilkan');
reset role;

insert into public.link_previews (url_hash, url, status, title, image_path, image_width, image_height, fetched_at, expires_at,
                                  image_sha256, image_verdict)
values (private.link_preview_hash('https://kuno.example.com/'), 'https://kuno.example.com/', 'ok', 'Kuno',
        private.link_preview_hash('https://kuno.example.com/') || '/aaaaaaaaaaaaaaaa/preview.png', 10, 10,
        now() - interval '60 days', now() - interval '53 days', repeat('2', 64), 'allow');
insert into storage.objects (bucket_id, name, created_at) values
  ('link-previews', private.link_preview_hash('https://kuno.example.com/') || '/aaaaaaaaaaaaaaaa/preview.png', now() - interval '60 days'),
  ('link-previews', private.link_preview_hash('https://news.example.com/bbca?x=1') || '/0123456789abcdef/preview.jpg', now() - interval '2 days'),
  ('link-previews', private.link_preview_hash('https://yatim.example.com/') || '/bbbbbbbbbbbbbbbb/preview.webp', now() - interval '2 days'),
  ('link-previews', private.link_preview_hash('https://baru.example.com/') || '/cccccccccccccccc/preview.gif', now());
delete from private.storage_cleanup_queue where bucket_id = 'link-previews';

select is(private.link_preview_purge(), 1, 'Pratinjau yang lama kedaluwarsa dihapus');
select bag_eq($$select prefix from private.storage_cleanup_queue where bucket_id = 'link-previews' and done_at is null$$,
  format($$values (%L::text), (%L)$$,
         private.link_preview_hash('https://kuno.example.com/') || '/aaaaaaaaaaaaaaaa/',
         private.link_preview_hash('https://yatim.example.com/') || '/bbbbbbbbbbbbbbbb/'),
  'Gambar yatim lebih dari sehari masuk antrean janitor; gambar yang dipakai dan yang baru tidak');
select is(private.link_preview_purge(), 0, 'Purge kedua tidak menggandakan antrean');
select is((select count(*)::integer from private.storage_cleanup_queue where bucket_id = 'link-previews' and done_at is null), 2,
  'Folder gambar tidak diantrekan dua kali');
select ok(exists (select 1 from cron.job where jobname = 'link-preview-purge'), 'Job purge harian terjadwal');

select * from finish();
rollback;
