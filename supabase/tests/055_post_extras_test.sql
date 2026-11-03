begin;
select plan(55);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message', 'content_edit');
insert into public.banned_words (word, action) values ('janjiuntungpasti', 'block')
on conflict (word) do update set action = excluded.action;

select tests.create_user('px_ani') as ani \gset
select tests.create_user('px_budi') as budi \gset
select tests.create_user('px_cici') as cici \gset
select tests.create_user('px_resmi') as resmi \gset
select tests.create_agent('Moderator PX', '{community}', '{}') as moder \gset
select tests.create_agent('Agen PX', '{cs_agent}', '{"general": 1}') as agen \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'moder';
insert into cs.official_accounts (profile_id) values (:'resmi');

insert into public.posts (id, author_id, body) values
  ('00000000-0000-4000-8000-00000000f501', :'ani', 'Pandangan awal $BBCA #awal'),
  ('00000000-0000-4000-8000-00000000f502', :'budi', 'Post budi'),
  ('00000000-0000-4000-8000-00000000f503', :'resmi', 'Pengumuman resmi'),
  ('00000000-0000-4000-8000-00000000f504', :'budi', 'Post budi yang ditahan');
update public.posts set moderation_status = 'held' where id = '00000000-0000-4000-8000-00000000f504';
insert into public.comments (id, post_id, author_id, body) values
  ('00000000-0000-4000-8000-00000000c501', '00000000-0000-4000-8000-00000000f502', :'ani', 'Komentar awal');

select tests.authenticate_as(:'ani');
select is((select body || '|' || array_to_string(hashtags, ',') || '|' || (edited_at is not null)::text
           from public.edit_post('00000000-0000-4000-8000-00000000f501', '  Pandangan baru $BBCA #revisi  ')),
  'Pandangan baru $BBCA #revisi|revisi|true', 'Penulis mengedit post dan baris memuat hashtag serta label diedit');
select is((select edited_at is not null from public.get_post('00000000-0000-4000-8000-00000000f501')), true,
  'get_post menandai post yang diedit');
select throws_ok($$select * from public.edit_post('00000000-0000-4000-8000-00000000f502', 'Ubah punya orang')$$,
  'PT403', 'forbidden', 'Hanya penulis yang bisa mengedit post');
select throws_ok($$select * from public.edit_post('00000000-0000-4000-8000-00000000f504', 'Ubah')$$,
  'PT404', 'post_not_found', 'Post orang lain yang ditahan tidak terlihat');
select throws_ok($$select * from public.edit_post('00000000-0000-4000-8000-00000000f501', '   ')$$,
  'PT400', 'empty_body', 'Isi edit tidak boleh kosong');
select throws_ok(format($$select * from public.edit_post('00000000-0000-4000-8000-00000000f501', %L)$$, repeat('x', 2001)),
  'PT400', 'body_too_long', 'Isi edit dibatasi 2000 karakter');
select throws_ok($$select * from public.edit_post('00000000-0000-4000-8000-00000000f501', 'Ada janjiuntungpasti di sini')$$,
  'PT422', 'content_blocked', 'Edit tetap melewati kebijakan konten');
select is((select body from public.edit_comment('00000000-0000-4000-8000-00000000c501', 'Komentar direvisi')),
  'Komentar direvisi', 'Penulis mengedit komentar');
select throws_ok($$select * from public.edit_comment('00000000-0000-4000-8000-00000000c599', 'x')$$,
  'PT404', 'comment_not_found', 'Komentar yang tidak ada ditolak');
select is((select count(*)::integer from public.post_hashtags where post_id = '00000000-0000-4000-8000-00000000f501' and tag = 'awal'), 0,
  'Hashtag lama dilepas setelah edit');
reset role;

select is((select string_agg(body, ' > ' order by edited_at, id) from private.content_edits
           where target_id = '00000000-0000-4000-8000-00000000f501'),
  'Pandangan awal $BBCA #awal', 'Versi lama disimpan di riwayat edit');
select ok((select retain_until > now() + interval '365 days' from private.content_edits
           where target_id = '00000000-0000-4000-8000-00000000c501'), 'Riwayat edit memakai retensi arsip');

update public.posts set created_at = now() - interval '16 minutes' where id = '00000000-0000-4000-8000-00000000f501';
select tests.authenticate_as(:'ani');
select throws_ok($$select * from public.edit_post('00000000-0000-4000-8000-00000000f501', 'Terlambat')$$,
  'PT403', 'edit_window_expired', 'Edit ditolak setelah batas waktu');
select throws_ok($$update public.posts set body = 'Lewat REST' where id = '00000000-0000-4000-8000-00000000f501'$$,
  'PT403', 'edit_window_expired', 'Batas waktu edit juga berlaku untuk update langsung');
select (public.create_post('Pilih mana?', null, '[]', null, '{"options": ["Naik", "Turun"]}')).id as poll_post \gset
select throws_ok(format($$select * from public.edit_post(%L, 'Ubah polling')$$, :'poll_post'),
  'PT409', 'poll_not_editable', 'Post berisi polling tidak bisa diedit');
reset role;

select tests.authenticate_agent(:'agen');
select throws_ok($$select cs_api.community_edit_history('post', '00000000-0000-4000-8000-00000000f501')$$,
  'PT403', 'community_forbidden', 'Riwayat edit hanya untuk moderator komunitas');
reset role;
select tests.authenticate_agent(:'moder');
select is(jsonb_array_length(cs_api.community_edit_history('post', '00000000-0000-4000-8000-00000000f501')), 1,
  'Moderator melihat riwayat edit');
reset role;

select tests.authenticate_as(:'ani');
select is(public.toggle_bookmark('00000000-0000-4000-8000-00000000f502'), true, 'Bookmark ditambahkan');
select is(public.toggle_bookmark('00000000-0000-4000-8000-00000000f502', true), true, 'Set bookmark idempoten');
select is(public.toggle_bookmark('00000000-0000-4000-8000-00000000f503'), true, 'Bookmark kedua ditambahkan');
select is((select is_bookmarked from public.get_post('00000000-0000-4000-8000-00000000f502')), true,
  'Baris feed menandai post yang di-bookmark');
select is((select is_bookmarked from public.get_feed('user', null, null, 5, :'budi') limit 1), true,
  'get_feed membawa status bookmark');
select throws_ok($$select public.toggle_bookmark('00000000-0000-4000-8000-00000000f504')$$,
  'PT404', 'post_not_found', 'Post yang tidak terlihat tidak bisa di-bookmark');
select results_eq($$select id from public.get_bookmarks()$$,
  $$values ('00000000-0000-4000-8000-00000000f503'::uuid), ('00000000-0000-4000-8000-00000000f502'::uuid)$$,
  'Daftar bookmark terbaru dulu');
select (select cursor from public.get_bookmarks(null, 1)) as bm_cursor \gset
select results_eq(format($$select id from public.get_bookmarks(%L, 1)$$, :'bm_cursor'),
  $$values ('00000000-0000-4000-8000-00000000f502'::uuid)$$, 'Cursor bookmark memakai waktu bookmark');
select is((select author_is_official from public.get_post('00000000-0000-4000-8000-00000000f503')), true,
  'Baris feed menandai akun resmi');
select is((select is_bot from public.get_post('00000000-0000-4000-8000-00000000f503')), false,
  'Tanpa penanda bot, post tidak berlabel bot');
reset role;

create or replace function private.post_is_bot(p_post_id uuid)
returns boolean language sql stable set search_path = '' as $$ select p_post_id = '00000000-0000-4000-8000-00000000f503'::uuid $$;
select tests.authenticate_as(:'ani');
select is((select is_bot from public.get_post('00000000-0000-4000-8000-00000000f503')), true,
  'Penanda bot dari layanan integrasi ditampilkan');
select is(public.toggle_bookmark('00000000-0000-4000-8000-00000000f502'), false, 'Bookmark dilepas dengan toggle');
reset role;

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from public.bookmarks), 0, 'Bookmark orang lain tidak terlihat');
select throws_ok($$insert into public.bookmarks (user_id, post_id) values (auth.uid(), '00000000-0000-4000-8000-00000000f502')$$,
  '42501', null, 'Bookmark hanya lewat RPC');
select get_or_create_direct_room(:'ani') as dm \gset
select (public.send_message(:'dm', 'Halo Ani')).id as msg \gset
reset role;

select tests.authenticate_as(:'ani');
select is(public.react_to_message(:'msg', '👍') -> 'reactions', '[{"emoji": "👍", "count": 1, "me": true}]'::jsonb,
  'Anggota room memberi reaksi');
select throws_ok(format($$select public.react_to_message(%L, '🤡')$$, :'msg'), 'PT400', 'invalid_emoji',
  'Emoji di luar daftar ditolak');
reset role;

select tests.authenticate_as(:'budi');
select is(public.react_to_message(:'msg', '❤') ->> 'emoji', '❤️', 'Hati tanpa variation selector dinormalkan');
select is((select reactions from public.get_messages(:'dm') where id = :'msg'),
  '[{"emoji": "👍", "count": 1, "me": false}, {"emoji": "❤️", "count": 1, "me": true}]'::jsonb,
  'Riwayat pesan memuat ringkasan reaksi');
select is(public.react_to_message(:'msg', '😂') -> 'reactions' -> 1 ->> 'emoji', '😂', 'Reaksi baru menggantikan reaksi lama');
select is(public.react_to_message(:'msg', '😂') ->> 'emoji', null, 'Reaksi yang sama dilepas');
reset role;

select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'reaction' and payload ->> 'message_id' = :'msg'), 4,
  'Perubahan reaksi disiarkan ke channel room');
select ok(not exists (select 1 from realtime.messages
                      where topic = 'room:' || :'dm' and event = 'reaction' and payload::text like '%"me"%'),
  'Siaran reaksi tidak membawa status pribadi');

select tests.authenticate_as(:'cici');
select throws_ok(format($$select public.react_to_message(%L, '👍')$$, :'msg'), 'PT404', 'message_not_found',
  'Bukan anggota room tidak bisa memberi reaksi');
select is((select count(*)::integer from public.message_reactions), 0, 'Reaksi room lain tidak terlihat');
reset role;

select tests.authenticate_as(:'budi');
select is((select attachments from public.send_message(:'dm', '', null, null,
            '[{"type": "post", "post_id": "00000000-0000-4000-8000-00000000f503", "extra": 1}]'))
          , '[{"type": "post", "post_id": "00000000-0000-4000-8000-00000000f503"}]'::jsonb,
  'Lampiran postingan dinormalkan');
select (public.share_post_to_chat(:'dm', '00000000-0000-4000-8000-00000000f502', 'Lihat ini')).id as shared \gset
select throws_ok(format($$select public.send_message(%L, 'x', null, null, '[{"type": "post", "post_id": "00000000-0000-4000-8000-00000000f501"}, {"type": "post", "post_id": "00000000-0000-4000-8000-00000000f502"}]')$$, :'dm'),
  'PT400', 'invalid_attachments', 'Maksimal satu postingan per pesan');
select throws_ok(format($$select public.share_post_to_chat(%L, '00000000-0000-4000-8000-0000000fffff')$$, :'dm'),
  'PT404', 'post_not_found', 'Postingan yang tidak ada tidak bisa dibagikan');
select throws_ok(format($$select public.send_message(%L, 'x', null, null, '[{"type": "post", "post_id": "bukan-uuid"}]')$$, :'dm'),
  'PT400', 'invalid_attachments', 'post_id harus UUID');
reset role;

select tests.authenticate_as(:'ani');
select is((select shared_post ->> 'body' from public.get_messages(:'dm') where id = :'shared'), 'Post budi',
  'Penerima melihat pratinjau postingan yang dibagikan');
select is((select shared_post ->> 'available' from public.get_messages(:'dm') where id = :'shared'), 'true',
  'Pratinjau menandai postingan tersedia');
select is((select shared_post from public.get_messages(:'dm') where id = :'msg'), null,
  'Pesan biasa tanpa pratinjau postingan');
reset role;
update public.posts set moderation_status = 'hidden' where id = '00000000-0000-4000-8000-00000000f502';
select tests.authenticate_as(:'ani');
select is((select shared_post from public.get_messages(:'dm') where id = :'shared'),
  '{"post_id": "00000000-0000-4000-8000-00000000f502", "available": false}'::jsonb,
  'Postingan yang tidak lagi terlihat tidak dipratinjau');
reset role;

select tests.authenticate_as(:'cici');
select get_or_create_direct_room(:'ani') as dm2 \gset
select (public.send_message(:'dm2', 'Halo dari orang asing')).id as req_msg \gset
reset role;
create or replace function private.dm_request_pending(p_room uuid, p_user uuid)
returns boolean language sql stable set search_path = ''
as $$ select p_room = (select id from public.chat_rooms where direct_key like '%' || (select id::text from public.profiles where username = 'px_cici') || '%' limit 1)
             and p_user = (select id from public.profiles where username = 'px_ani') $$;
select tests.authenticate_as(:'ani');
select ok(not exists (select 1 from public.get_my_rooms() where id = :'dm2'),
  'Permintaan pesan yang belum diterima tidak tampil di daftar room penerima');
select ok(exists (select 1 from public.get_my_rooms() where id = :'dm'), 'Room DM biasa tetap tampil');
reset role;
select tests.authenticate_as(:'cici');
select ok(exists (select 1 from public.get_my_rooms() where id = :'dm2'), 'Pengirim permintaan tetap melihat room-nya');
reset role;

select is((select count(*)::integer from public.message_reactions where message_id = :'msg'), 1,
  'Reaksi yang dilepas tidak tersimpan');
delete from public.messages where id = :'msg';
select is((select count(*)::integer from public.message_reactions where message_id = :'msg'), 0,
  'Reaksi ikut terhapus bersama pesan');

select tests.authenticate_as(:'ani');
select is((select count(*)::integer from public.get_feed('global', null, null, 50) where hashtags is null or is_bookmarked is null), 0,
  'Kolom baru selalu terisi di get_feed');
reset role;

select * from finish();
rollback;
