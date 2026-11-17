begin;
select plan(40);

update private.rate_limits set max_count = 1000 where action in ('comment', 'post', 'follow', 'data_export');
select tests.create_user('kk_ani') as ani \gset
select tests.create_user('kk_budi') as budi \gset
select tests.create_user('kk_cici') as cici \gset
select tests.create_user('kk_dedi') as dedi \gset
select tests.create_user('kk_eko') as eko \gset
select tests.create_user('kk_fani') as fani \gset
insert into follows (follower_id, following_id) values
  (:'budi', :'ani'), (:'ani', :'cici'), (:'dedi', :'ani'), (:'ani', :'dedi');
insert into blocks (blocker_id, blocked_id) values (:'ani', :'fani');
insert into posts (id, author_id, body) values ('a4600000-0000-4000-8000-000000000001', :'ani', 'Diskusi kontrol komentar');

create function pg_temp.attempt(p_user uuid, p_parent uuid default null) returns text language plpgsql as $$
begin
  perform tests.authenticate_as(p_user);
  perform create_comment('a4600000-0000-4000-8000-000000000001', p_parent, 'Komentar ' || md5(random()::text));
  reset role;
  return 'ok';
exception when others then
  return sqlerrm;
end;
$$;

create function pg_temp.matrix() returns text[] language sql as $$
  select array[pg_temp.attempt(u[1]), pg_temp.attempt(u[2]), pg_temp.attempt(u[3]),
               pg_temp.attempt(u[4]), pg_temp.attempt(u[5]), pg_temp.attempt(u[6])]
  from (select array_agg(p.id order by p.username) as u from profiles p where p.username::text like 'kk\_%') x;
$$;

create function pg_temp.set_audience(p_owner uuid, p_audience text) returns void language plpgsql as $$
begin
  perform tests.authenticate_as(p_owner);
  perform set_post_comment_audience('a4600000-0000-4000-8000-000000000001', p_audience);
  reset role;
end;
$$;

create function pg_temp.post_as(p_user uuid) returns public.feed_post language plpgsql as $$
declare
  v public.feed_post;
begin
  perform tests.authenticate_as(p_user);
  select * into v from get_post('a4600000-0000-4000-8000-000000000001');
  reset role;
  return v;
end;
$$;

create function pg_temp.thread_size(p_user uuid) returns integer language plpgsql as $$
declare
  v integer;
begin
  perform tests.authenticate_as(p_user);
  select count(*)::integer into v from get_comment_thread('a4600000-0000-4000-8000-000000000001', null, 10, null, 100, 50);
  reset role;
  return v;
end;
$$;

select is((select comment_audience::text from posts where id = 'a4600000-0000-4000-8000-000000000001'), 'everyone',
  'Post tanpa pengaturan terbuka untuk semua orang');

select tests.authenticate_as(:'ani');
select is(get_comment_settings() ->> 'audience', 'everyone', 'Pengaturan akun bawaan: semua orang');
select throws_ok($$select set_comment_audience('off')$$, 'PT400', 'invalid_comment_audience',
  'Pengaturan akun tidak bisa mematikan komentar');
select throws_ok($$select set_comment_audience('teman')$$, 'PT400', 'invalid_comment_audience',
  'Pilihan audiens akun yang tidak dikenal ditolak');
reset role;

select is(pg_temp.matrix(), array['ok', 'ok', 'ok', 'ok', 'ok', 'blocked'],
  'Semua orang: hanya pengguna diblokir yang ditolak');
select pg_temp.set_audience(:'ani', 'following');
select is(pg_temp.matrix(), array['ok', 'comments_restricted', 'ok', 'ok', 'comments_restricted', 'blocked'],
  'Orang yang saya ikuti: pemilik, yang diikuti, dan yang saling mengikuti boleh');
select pg_temp.set_audience(:'ani', 'followers');
select is(pg_temp.matrix(), array['ok', 'ok', 'comments_restricted', 'ok', 'comments_restricted', 'blocked'],
  'Pengikut saya: pemilik, pengikut, dan yang saling mengikuti boleh');
select pg_temp.set_audience(:'ani', 'following_and_followers');
select is(pg_temp.matrix(), array['ok', 'ok', 'ok', 'ok', 'comments_restricted', 'blocked'],
  'Diikuti dan pengikut: hanya orang asing dan pengguna diblokir yang ditolak');
select pg_temp.set_audience(:'ani', 'off');
select is(pg_temp.matrix(), array['comments_off', 'comments_off', 'comments_off', 'comments_off', 'comments_off', 'blocked'],
  'Komentar mati: tidak ada yang bisa berkomentar, termasuk pemilik');

select pg_temp.set_audience(:'ani', 'followers');
select is(((pg_temp.post_as(:'eko')).can_comment, (pg_temp.post_as(:'eko')).comment_restriction)::text, '(f,followers)',
  'Orang asing melihat tidak bisa berkomentar beserta alasannya');
select is(((pg_temp.post_as(:'budi')).can_comment, (pg_temp.post_as(:'budi')).comment_restriction)::text, '(t,)',
  'Pengikut melihat bisa berkomentar');
select is((pg_temp.post_as(:'ani')).comment_audience, 'followers', 'Pemilik melihat pengaturan audiens');
select is((pg_temp.post_as(:'budi')).comment_audience, null, 'Bukan pemilik tidak melihat pengaturan audiens');

select pg_temp.set_audience(:'ani', 'everyone');
select tests.authenticate_as(:'eko');
select id as e1 from create_comment('a4600000-0000-4000-8000-000000000001', null, 'Komentar orang asing') \gset
select tests.authenticate_as(:'cici');
select id as r1 from create_comment('a4600000-0000-4000-8000-000000000001', :'e1', 'Balasan dari yang diikuti') \gset
reset role;
select pg_temp.set_audience(:'ani', 'following');
select is(pg_temp.attempt(:'eko', :'r1'), 'comments_restricted', 'Balasan tingkat dua dari orang asing ditolak');
select is(pg_temp.attempt(:'budi', :'e1'), 'comments_restricted', 'Balasan tingkat satu dari pengikut ditolak');
select is(pg_temp.attempt(:'cici', :'r1'), 'ok', 'Yang diikuti tetap bisa membalas di tingkat mana pun');
select is(pg_temp.attempt(:'ani', :'e1'), 'ok', 'Pemilik selalu bisa membalas');

select pg_temp.set_audience(:'ani', 'everyone');
select pg_temp.thread_size(:'budi') as thread_before \gset
select count(*)::integer as stored from comments
 where post_id = 'a4600000-0000-4000-8000-000000000001' and deleted_at is null \gset
select pg_temp.set_audience(:'ani', 'off');
select is(pg_temp.thread_size(:'budi'), 0, 'Komentar mati: thread kosong bagi pembaca');
select is(pg_temp.thread_size(:'ani'), 0, 'Komentar mati: thread kosong juga bagi pemilik');
select is((pg_temp.post_as(:'budi')).comment_count, null, 'Komentar mati: jumlah disembunyikan dari bukan pemilik');
select is((pg_temp.post_as(:'ani')).comment_count, :stored, 'Komentar mati: pemilik tetap melihat jumlahnya');
select is((pg_temp.post_as(:'budi')).top_comment, null, 'Komentar mati: komentar teratas tidak ditampilkan');
select tests.authenticate_as(:'budi');
select is((select count(*)::integer from comments where post_id = 'a4600000-0000-4000-8000-000000000001'), 0,
  'Komentar mati: komentar tidak bisa dibaca lewat REST');
reset role;
select tests.authenticate_as(:'eko');
select throws_ok(format($$insert into comments (post_id, author_id, body) values ('a4600000-0000-4000-8000-000000000001', %L, 'Lewat REST')$$, :'eko'),
  'PT403', 'comments_off', 'Komentar mati: insert REST langsung ditolak');
reset role;
select is((select count(*)::integer from comments
           where post_id = 'a4600000-0000-4000-8000-000000000001' and deleted_at is null), :stored,
  'Komentar mati: data komentar tidak dihapus');
select is(private.shared_post_preview(jsonb_build_array(jsonb_build_object('type', 'post',
            'post_id', 'a4600000-0000-4000-8000-000000000001')), :'budi') -> 'comment_count', 'null'::jsonb,
  'Komentar mati: pratinjau post di chat menyembunyikan jumlah');

select pg_temp.set_audience(:'ani', 'everyone');
select is(pg_temp.thread_size(:'budi'), :thread_before, 'Komentar dinyalakan lagi: komentar lama kembali');
select is((pg_temp.post_as(:'budi')).comment_count, :stored, 'Komentar dinyalakan lagi: jumlah tampil lagi');

select tests.authenticate_as(:'budi');
select throws_ok($$select set_post_comment_audience('a4600000-0000-4000-8000-000000000001', 'off')$$,
  'PT403', 'forbidden', 'Pengguna lain tidak bisa mengubah pengaturan komentar post orang');
select throws_ok($$update posts set comment_audience = 'off' where id = 'a4600000-0000-4000-8000-000000000001'$$,
  '42501', null, 'Kolom pengaturan komentar tidak bisa diubah lewat REST');
select throws_ok($$select set_post_comment_audience('a4600000-0000-4000-8000-0000000000ff', 'off')$$,
  'PT404', 'post_not_found', 'Post yang tidak ada ditolak');
reset role;
select is((select comment_audience::text from posts where id = 'a4600000-0000-4000-8000-000000000001'), 'everyone',
  'Pengaturan post tidak berubah oleh pengguna lain');
select tests.authenticate_as(:'ani');
select throws_ok($$select set_post_comment_audience('a4600000-0000-4000-8000-000000000001', 'semua')$$,
  'PT400', 'invalid_comment_audience', 'Pilihan audiens post yang tidak dikenal ditolak');

select is(set_comment_audience('followers') ->> 'audience', 'followers', 'Pemilik mengubah pengaturan akun');
select is((select comment_audience::text from posts where id = 'a4600000-0000-4000-8000-000000000001'), 'everyone',
  'Pengaturan akun tidak mengubah post yang sudah terbit');
select is((select comment_audience from create_post('Post baru mengikuti akun')), 'followers',
  'Post baru memakai pengaturan akun');
select is((select comment_audience from create_post('Post tanpa komentar', p_comment_audience => 'off')), 'off',
  'Composer bisa mematikan komentar saat membuat post');
select throws_ok($$select create_post('Post audiens aneh', p_comment_audience => 'semua')$$,
  'PT400', 'invalid_comment_audience', 'Audiens post baru yang tidak dikenal ditolak');
select is(export_my_data() ->> 'comment_audience', 'followers', 'Ekspor data menyertakan pengaturan komentar');
reset role;
select tests.authenticate_as(:'budi');
select is(get_comment_settings() ->> 'audience', 'everyone', 'Pengaturan akun pengguna lain tidak terpengaruh');
reset role;

select * from finish();
rollback;
