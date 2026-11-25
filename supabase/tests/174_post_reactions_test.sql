begin;
select plan(39);

update private.rate_limits set max_count = 1000 where action in ('reaction', 'post', 'comment');
update private.settings set value = '0' where key = 'safety.new_account_days';

create function pg_temp.summary(p_post uuid) returns jsonb language sql security definer as $$
  select reaction_summary from public.posts where id = p_post
$$;
create function pg_temp.likes(p_post uuid) returns integer language sql security definer as $$
  select like_count from public.posts where id = p_post
$$;

select tests.create_user('pr_ani') as ani \gset
select tests.create_user('pr_budi') as budi \gset
select tests.create_user('pr_cici') as cici \gset
select tests.create_user('pr_dodi') as dodi \gset
select tests.create_user('pr_eka') as eka \gset

select tests.authenticate_as(:'ani');
select public.register_push_device('android-token-pr-ani-0000001', 'android', 'id-ID', '2.4.0') is not null as device \gset
reset role;

insert into public.posts (author_id, body) values (:'ani', 'Post reaksi Ani') returning id as post \gset
insert into public.posts (author_id, body, moderation_status) values (:'ani', 'Post tersembunyi', 'hidden')
returning id as hidden \gset
insert into public.posts (author_id, body) values (:'ani', 'Post dihapus') returning id as gone \gset
update public.posts set deleted_at = now() where id = :'gone';
insert into public.comments (post_id, author_id, body) values (:'post', :'ani', 'Komentar Ani') returning id as comment \gset

select is((public.get_client_config() -> 'config' -> 'post_reactions'), to_jsonb(private.message_reaction_emojis()),
  'Konfigurasi klien membawa daftar reaksi post');
select ok('👍' = any (private.message_reaction_emojis()), 'Jempol termasuk daftar emoji reaksi');
select is((select count(*)::integer from public.posts p
           where p.like_count <> coalesce((select sum((x ->> 'count')::integer) from jsonb_array_elements(p.reaction_summary) x), 0)),
  0, 'Ringkasan reaksi post lama sama dengan like_count');

select tests.authenticate_as(:'budi');
select is((select row(like_count, liked_by_me, my_reaction, reaction_summary)::text
           from set_post_reaction(:'post', '❤️')),
  row(1, true, '❤️', '[{"count": 1, "emoji": "❤️"}]'::jsonb)::text,
  'Reaksi emoji mengembalikan post dengan jumlah, reaksi saya, dan ringkasan');
reset role;
select is((select title from private.push_queue where user_id = :'ani' and kind = 'like'),
  'Pr Budi menanggapi konten Anda dengan ❤️', 'Push reaksi emoji menyebut emojinya');
select is((select payload ->> 'emoji' from public.notifications where user_id = :'ani' and type = 'like'), '❤️',
  'Notifikasi reaksi membawa emoji');

select tests.authenticate_as(:'budi');
select is((select row(like_count, my_reaction, reaction_summary)::text from set_post_reaction(:'post', '🔥')),
  row(1, '🔥', '[{"count": 1, "emoji": "🔥"}]'::jsonb)::text,
  'Mengganti emoji tidak menambah jumlah reaksi');
reset role;
select is((select count(*)::integer || '/' || max(event_count) || '/' || max(payload ->> 'emoji')
           from public.notifications where user_id = :'ani' and type = 'like'),
  '1/1/🔥', 'Mengganti emoji memperbarui notifikasi yang sama tanpa menambah kejadian');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'like'), 1,
  'Mengganti emoji tidak mengirim push lagi');

select tests.authenticate_as(:'cici');
insert into public.reactions (user_id, target_type, target_id) values (:'cici', 'post', :'post');
reset role;
select is(pg_temp.summary(:'post'), '[{"count": 1, "emoji": "👍"}, {"count": 1, "emoji": "🔥"}]'::jsonb,
  'Like dari klien lama tercatat sebagai jempol, seri diurutkan menurut daftar emoji');
select is(pg_temp.likes(:'post'), 2, 'like_count menghitung semua reaksi');

select tests.authenticate_as(:'dodi');
select is((select reaction_summary from set_post_reaction(:'post', '🔥')),
  '[{"count": 2, "emoji": "🔥"}, {"count": 1, "emoji": "👍"}]'::jsonb, 'Ringkasan diurutkan dari jumlah terbanyak');

select tests.authenticate_as(:'cici');
select is((select row(like_count, my_reaction)::text from set_post_reaction(:'post', '👍')), row(3, '👍')::text,
  'Memilih jempol saat sudah like tidak mengubah apa pun');
select is((select my_reaction from set_post_reaction(:'post', 'like')), '👍', 'Nilai like sama dengan jempol');
select is((select my_reaction from set_post_reaction(:'post', '❤')), '❤️', 'Hati tanpa variation selector dinormalkan');
select is((select my_reaction from set_post_reaction(:'post', '👍')), '👍', 'Kembali ke jempol');
select is((select type from public.reactions where user_id = :'cici' and target_id = :'post'), 'like',
  'Jempol disimpan sebagai like');
update public.reactions set type = '😂' where user_id = :'cici' and target_id = :'post';
select is((select row(like_count, my_reaction)::text from get_post(:'post')), row(3, '😂')::text,
  'Mengubah reaksi langsung lewat tabel ikut memperbarui ringkasan');
select throws_ok(format('update public.reactions set type = %L where user_id = %L', '🍌', :'cici'),
  'PT400', 'invalid_reaction', 'Reaksi di luar daftar ditolak saat diubah langsung');
select is((select row(like_count, liked_by_me, my_reaction)::text from set_post_reaction(:'post', null)),
  row(2, false, null::text)::text, 'Reaksi null menghapus reaksi saya');
select throws_ok(format('select * from set_post_reaction(%L, %L)', :'post', '🍌'), 'PT400', 'invalid_reaction',
  'Emoji di luar daftar ditolak');
reset role;
select is(pg_temp.summary(:'post'), '[{"count": 2, "emoji": "🔥"}]'::jsonb,
  'Emoji yang jumlahnya nol hilang dari ringkasan');

select tests.authenticate_as(:'budi');
select throws_ok(format('insert into public.reactions (user_id, target_type, target_id, type) values (%L, %L, %L, %L)',
                        :'budi', 'comment', :'comment', '❤️'),
  'PT400', 'invalid_reaction', 'Komentar hanya menerima like');
insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'comment', :'comment');
select is((select like_count from public.comments where id = :'comment'), 1, 'Like komentar tetap berjalan seperti biasa');
select throws_ok(format('select * from set_post_reaction(%L, %L)', :'hidden', '❤️'), 'PT404', 'target_not_found',
  'Post tersembunyi tidak bisa diberi reaksi');
select throws_ok(format('select * from set_post_reaction(%L, %L)', :'gone', '❤️'), 'PT404', 'target_not_found',
  'Post terhapus tidak bisa diberi reaksi');
select tests.authenticate_as(:'ani');
select is((select my_reaction from set_post_reaction(:'hidden', '😮')), '😮',
  'Penulis tetap bisa memberi reaksi pada post tersembunyinya sendiri');
reset role;

insert into public.blocks (blocker_id, blocked_id) values (:'ani', :'eka'), (:'ani', :'budi');
select tests.authenticate_as(:'eka');
select throws_ok(format('select * from set_post_reaction(%L, %L)', :'post', '❤️'), 'PT403', 'blocked',
  'Pengguna yang diblokir penulis tidak bisa memberi reaksi');
select tests.authenticate_as(:'budi');
select throws_ok(format('select * from set_post_reaction(%L, %L)', :'post', '😢'), 'PT403', 'blocked',
  'Mengganti emoji setelah diblokir juga ditolak');
reset role;
delete from public.blocks where blocker_id = :'ani' and blocked_id = :'budi';

update public.reactions set created_at = now() - interval '3 minutes' where user_id = :'budi' and target_id = :'post';
update public.reactions set created_at = now() - interval '1 minute' where user_id = :'dodi' and target_id = :'post';

select tests.authenticate_as(:'ani');
select is(array(select username || ':' || emoji from post_reactors(:'post')), array['pr_dodi:🔥', 'pr_budi:🔥'],
  'Daftar pemberi reaksi terbaru lebih dulu beserta emojinya');
select is((select count(*)::integer from post_reactors(:'post', '👍')), 0, 'Daftar bisa disaring per emoji');
select post_reactors.cursor as next from post_reactors(:'post', null, 1) \gset
select is(array(select username from post_reactors(:'post', null, 1, :'next')), array['pr_budi'],
  'Daftar pemberi reaksi berhalaman lewat cursor');
select throws_ok(format('select * from post_reactors(%L, %L)', :'post', '🍌'), 'PT400', 'invalid_reaction',
  'Saringan emoji di luar daftar ditolak');
select tests.authenticate_as(:'cici');
select is((select row(is_me, is_following)::text from post_reactors(:'post') where username = 'pr_dodi'),
  row(false, false)::text, 'Daftar membawa is_me dan is_following');
reset role;
insert into public.blocks (blocker_id, blocked_id) values (:'cici', :'dodi');
select tests.authenticate_as(:'cici');
select is(array(select username from post_reactors(:'post')), array['pr_budi'],
  'Pemberi reaksi yang diblokir penonton tidak ditampilkan');
select tests.authenticate_as(:'budi');
select throws_ok(format('select * from post_reactors(%L)', :'hidden'), 'PT404', 'target_not_found',
  'Daftar reaksi post tersembunyi milik orang lain tidak bisa dibuka');

select tests.authenticate_as(:'dodi');
delete from public.reactions where user_id = :'dodi' and target_id = :'post';
reset role;
select is(pg_temp.summary(:'post') || to_jsonb(pg_temp.likes(:'post')),
  '[{"count": 1, "emoji": "🔥"}, 1]'::jsonb, 'Unlike lewat klien lama ikut mengurangi ringkasan');
select is((select actor_id from public.notifications where user_id = :'ani' and type = 'like'
           and group_key = 'like:post:' || :'post'), :'budi'::uuid,
  'Unlike mengembalikan pelaku notifikasi ke pemberi reaksi sebelumnya');

select is((select count(*)::integer from information_schema.columns
           where table_schema = 'public' and table_name = 'posts' and column_name = 'reaction_summary'), 1,
  'Ringkasan reaksi tersimpan di tabel posts sehingga ikut realtime UPDATE');

select * from finish();
rollback;
