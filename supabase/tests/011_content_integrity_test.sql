begin;
select plan(19);

-- Per-minute post limit raised because this test creates many posts within a minute.
update private.rate_limits set max_count = 100 where action = 'post' and window_seconds = 60;

select tests.create_user('ci_ani') as ani \gset
select tests.create_user('ci_budi') as budi \gset
select 'BBCA' as bbca \gset
select tests.create_admin('compliance_admin') as compliance \gset

select tests.authenticate_as(:'ani');
select (create_post('Post idempoten $BBCA', null, '[]', 'c1000000-0000-4000-8000-000000000001')).id as post1 \gset
select is((create_post('Post idempoten $BBCA', null, '[]', 'c1000000-0000-4000-8000-000000000001')).id,
  :'post1'::uuid, 'create_post dengan client_id sama mengembalikan post yang sama');
select is((select count(*)::int from posts where author_id = auth.uid() and client_id = 'c1000000-0000-4000-8000-000000000001'),
  1, 'Tidak ada post ganda');
select lives_ok(format($$select create_comment(%L, null, 'Komentar dengan tiga parameter')$$, :'post1'),
  'create_comment versi lama (3 parameter) tetap jalan');
select (create_comment(:'post1', null, 'Komentar idempoten', 'c2000000-0000-4000-8000-000000000001')).id as comment1 \gset
select is((create_comment(:'post1', null, 'Komentar idempoten', 'c2000000-0000-4000-8000-000000000001')).id,
  :'comment1'::uuid, 'create_comment dengan client_id sama tidak membuat komentar ganda');

select throws_ok($$insert into posts (author_id, body) values (auth.uid(), E'halo\x07dunia')$$,
  'PT422', 'invalid_characters', 'Karakter kontrol ditolak');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), E'baris satu\nbaris dua\tTAB')$$,
  'Newline dan tab diizinkan');
select throws_ok($$insert into posts (author_id, body)
    values (auth.uid(), 'https://a.example/1 https://a.example/2 www.a.example/3 http://a.example/4')$$,
  'PT422', 'too_many_links', 'Lebih dari 3 link ditolak');
select throws_ok(format($$insert into posts (author_id, body) values (auth.uid(), %L)$$,
    (select string_agg('@user' || g, ' ') from generate_series(10, 20) g)),
  'PT422', 'too_many_mentions', 'Lebih dari 10 mention ditolak');
select throws_ok(format($$insert into posts (author_id, body) values (auth.uid(), %L)$$,
    (select string_agg('$KODE' || chr(64 + g), ' ') from generate_series(1, 11) g)),
  'PT422', 'too_many_stock_tags', 'Lebih dari 10 kode saham ditolak');
select throws_ok($$update profiles set bio = E'bio\x01' where id = auth.uid()$$,
  'PT422', 'invalid_characters', 'Karakter kontrol di bio ditolak');

insert into posts (author_id, body) values (auth.uid(), 'Gabung grup saham kami sekarang');
insert into posts (author_id, body) values (auth.uid(), 'gabung   GRUP saham kami sekarang');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'Gabung grup saham kami sekarang')$$,
  'PT422', 'duplicate_content', 'Konten sama ke-3 dalam 5 menit ditolak (spasi/huruf besar diabaikan)');
reset role;
select tests.authenticate_as(:'budi');
select lives_ok($q$do $d$ begin
    insert into posts (author_id, body) values (auth.uid(), 'ok');
    insert into posts (author_id, body) values (auth.uid(), 'ok');
    insert into posts (author_id, body) values (auth.uid(), 'ok');
  end $d$$q$, 'Teks pendek tidak dicek duplikat');
reset role;

insert into private.user_sanctions (user_id, kind, reason, ends_at)
values (:'budi', 'mute', 'uji', now() + interval '1 hour')
returning id as mute_id \gset
select tests.authenticate_as(:'budi');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'saat dibisukan')$$,
  'PT403', 'user_muted', 'User yang di-mute tidak bisa posting');
select throws_ok(format($$select create_comment(%L, null, 'komentar saat dibisukan')$$, :'post1'),
  'PT403', 'user_muted', 'User yang di-mute tidak bisa berkomentar');
reset role;
update private.user_sanctions set revoked_at = now() where id = :'mute_id';
select tests.authenticate_as(:'budi');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'setelah mute dicabut')$$,
  'Setelah mute dicabut, bisa posting lagi');
reset role;

select tests.authenticate_admin(:'compliance');
select admin_api.publish_legal_document('terms', 'Syarat & Ketentuan', 'Isi v1') as terms_v1 \gset
reset role;
select tests.authenticate_as(:'ani');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'belum setuju syarat')$$,
  'PT403', 'consent_required', 'Belum menyetujui S&K: posting ditolak');
select is((select count(*)::int from get_pending_consents()), 1, 'Dokumen yang perlu disetujui muncul');
select accept_legal_document(:'terms_v1') as accepted \gset
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'sudah setuju syarat')$$,
  'Setelah menyetujui, posting diizinkan');
reset role;
select tests.authenticate_admin(:'compliance');
select admin_api.publish_legal_document('terms', 'Syarat & Ketentuan', 'Isi v2') as terms_v2 \gset
reset role;
select tests.authenticate_as(:'ani');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'versi baru terbit')$$,
  'PT403', 'consent_required', 'Versi baru terbit: wajib menyetujui ulang');
reset role;

select * from finish();
rollback;
