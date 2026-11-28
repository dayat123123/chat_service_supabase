begin;
select plan(26);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'follow');
update private.settings set value = '0' where key = 'safety.new_account_days';
select tests.create_user('qt_ani') as ani \gset
select tests.create_user('qt_budi') as budi \gset
select tests.create_user('qt_cici') as cici \gset
select tests.create_user('qt_dedi') as dedi \gset
insert into public.blocks (blocker_id, blocked_id) values (:'ani', :'cici');

insert into public.posts (id, author_id, body) values
  ('a1900000-0000-4000-8000-000000000001', :'ani', 'Analisa $BBCA kuartal ini'),
  ('a1900000-0000-4000-8000-000000000002', :'ani', 'Postingan yang akan dihapus'),
  ('a1900000-0000-4000-8000-000000000003', :'dedi', 'Hanya pengikut yang boleh membalas');
update public.posts set comment_audience = 'followers' where id = 'a1900000-0000-4000-8000-000000000003';

select tests.authenticate_as(:'budi');
select * from public.create_post('Setuju, $BBCA menarik', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000001') \gset q_
select is(:'q_quoted_post'::jsonb ->> 'id', 'a1900000-0000-4000-8000-000000000001', 'Post baru membawa kartu post yang dikutip');
select is(:'q_quoted_post'::jsonb ->> 'available', 'true', 'Post yang dikutip tersedia');
select is(:'q_quoted_post'::jsonb ->> 'username', 'qt_ani', 'Kartu kutipan memuat penulis asli');
select is(:'q_quoted_post'::jsonb ->> 'body', 'Analisa $BBCA kuartal ini', 'Kartu kutipan memuat isi asli');
select is(:'q_quoted_post'::jsonb -> 'stocks', '["BBCA"]'::jsonb, 'Kartu kutipan memuat kode saham');
select is(:'q_can_quote'::boolean, true, 'Post kutipan sendiri juga bisa dikutip');
select throws_ok($$select * from public.create_post('Tidak ada', p_quoted_post_id => gen_random_uuid())$$,
  'PT404', 'quoted_post_not_found', 'Post yang tidak ada tidak bisa dikutip');
select throws_ok($$select * from public.create_post('Polling', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000001',
  p_poll => '{"options": ["Ya", "Tidak"], "duration_hours": 24}')$$, 'PT400', 'invalid_quote',
  'Kutipan tidak bisa disertai polling');
select throws_ok($$select * from public.create_post('Dibatasi', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000003')$$,
  'PT403', 'quote_not_allowed', 'Post yang membatasi balasan tidak bisa dikutip oleh yang tidak berhak membalas');
select is((select can_quote from public.get_post('a1900000-0000-4000-8000-000000000003')), false,
  'Tombol kutip mati untuk post yang membatasi balasan');
select is((select can_quote from public.get_post('a1900000-0000-4000-8000-000000000001')), true,
  'Tombol kutip menyala untuk post terbuka');
select throws_ok(format('update public.posts set quoted_post_id = %L where id = %L',
  'a1900000-0000-4000-8000-000000000002', :'q_id'), '42501', null, 'Kutipan tidak bisa diubah setelah dibuat');
reset role;
update public.posts set created_at = now() - interval '1 minute' where id = :'q_id';

select is((select quote_count from public.posts where id = 'a1900000-0000-4000-8000-000000000001'), 1,
  'Jumlah kutipan bertambah');
select is((select row(actor_id, payload ->> 'quote_post_id')::text from public.notifications
           where user_id = :'ani' and type = 'quote'),
  row(:'budi'::uuid, :'q_id')::text, 'Penulis asli mendapat notifikasi kutipan');

select tests.authenticate_as(:'cici');
select throws_ok($$select * from public.create_post('Diblokir', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000001')$$,
  'PT404', 'quoted_post_not_found', 'Akun yang diblokir penulis tidak bisa mengutip');
reset role;

select tests.authenticate_as(:'dedi');
select * from public.create_post('Kutip juga', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000001') \gset d_
select * from public.create_post('Kutip yang akan hilang', p_quoted_post_id => 'a1900000-0000-4000-8000-000000000002') \gset g_
select is((select count(*)::integer from public.post_quotes('a1900000-0000-4000-8000-000000000001')), 2,
  'Daftar kutipan memuat semua kutipan yang tampil');
select is((select id from public.post_quotes('a1900000-0000-4000-8000-000000000001', null, 1)), :'d_id'::uuid,
  'Daftar kutipan terbaru di atas');
select is((select count(*)::integer from public.post_quotes('a1900000-0000-4000-8000-000000000001',
           (select cursor from public.post_quotes('a1900000-0000-4000-8000-000000000001', null, 1)), 1)), 1,
  'Daftar kutipan bisa dipaginasi');
reset role;

select is((select event_count from public.notifications where user_id = :'ani' and type = 'quote'
           and group_key = 'quotes:post:a1900000-0000-4000-8000-000000000001'), 2,
  'Notifikasi kutipan untuk post yang sama dikelompokkan');

update public.posts set deleted_at = now() where id = 'a1900000-0000-4000-8000-000000000002';
select tests.authenticate_as(:'dedi');
select is((select quoted_post ->> 'available' from public.get_post(:'g_id')), 'false',
  'Post yang dikutip lalu dihapus tampil sebagai tidak tersedia');
select is((select quoted_post ->> 'body' from public.get_post(:'g_id')), null, 'Isi post yang dihapus tidak ikut');
reset role;

update public.posts set deleted_at = now() where id = :'d_id';
select is((select quote_count from public.posts where id = 'a1900000-0000-4000-8000-000000000001'), 1,
  'Kutipan yang dihapus tidak dihitung');
update public.posts set moderation_status = 'hidden' where id = :'q_id';
select is((select quote_count from public.posts where id = 'a1900000-0000-4000-8000-000000000001'), 0,
  'Kutipan yang disembunyikan moderasi tidak dihitung');

insert into public.blocks (blocker_id, blocked_id) values (:'ani', :'dedi');
select tests.authenticate_as(:'dedi');
select is((select quoted_post ->> 'available' from public.get_post(:'g_id')), 'false',
  'Kartu kutipan tertutup bila penulis asli memblokir pembaca');
reset role;

select is(private.notification_pref_types() @> array['quote'], true, 'Kutipan bisa diatur di preferensi notifikasi');
select lives_ok($$insert into private.notification_prefs (user_id, type, in_app, push)
  select id, 'quote', false, false from public.profiles where username = 'qt_ani'$$,
  'Preferensi notifikasi kutipan bisa disimpan');

select * from finish();
rollback;
