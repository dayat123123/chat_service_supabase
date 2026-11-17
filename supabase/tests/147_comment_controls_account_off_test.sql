begin;
select plan(31);

update private.rate_limits set max_count = 1000 where action in ('comment', 'post', 'follow', 'data_export');
select tests.create_user('ko_ani') as ani \gset
select tests.create_user('ko_budi') as budi \gset
select tests.create_user('ko_cici') as cici \gset
insert into follows (follower_id, following_id) values (:'budi', :'ani');
insert into posts (id, author_id, body) values
  ('a4700000-0000-4000-8000-000000000001', :'ani', 'Post terbuka'),
  ('a4700000-0000-4000-8000-000000000002', :'ani', 'Post yang dimatikan sendiri'),
  ('a4700000-0000-4000-8000-000000000003', :'ani', 'Post khusus pengikut'),
  ('a4700000-0000-4000-8000-000000000004', :'cici', 'Post orang lain');
update posts set comment_audience = 'off' where id = 'a4700000-0000-4000-8000-000000000002';
update posts set comment_audience = 'followers' where id = 'a4700000-0000-4000-8000-000000000003';

create function pg_temp.attempt(p_user uuid, p_post uuid, p_parent uuid default null) returns text language plpgsql as $$
begin
  perform tests.authenticate_as(p_user);
  perform create_comment(p_post, p_parent, 'Komentar ' || md5(random()::text));
  reset role;
  return 'ok';
exception when others then
  return sqlerrm;
end;
$$;

create function pg_temp.post_as(p_user uuid, p_post uuid) returns public.feed_post language plpgsql as $$
declare
  v public.feed_post;
begin
  perform tests.authenticate_as(p_user);
  select * into v from get_post(p_post);
  reset role;
  return v;
end;
$$;

create function pg_temp.thread_size(p_user uuid, p_post uuid) returns integer language plpgsql as $$
declare
  v integer;
begin
  perform tests.authenticate_as(p_user);
  select count(*)::integer into v from get_comment_thread(p_post, null, 10, null, 100, 50);
  reset role;
  return v;
end;
$$;

create function pg_temp.set_all_off(p_user uuid, p_off boolean) returns jsonb language plpgsql as $$
declare
  v jsonb;
begin
  perform tests.authenticate_as(p_user);
  v := set_all_comments_off(p_off);
  reset role;
  return v;
end;
$$;

select is(pg_temp.attempt(:'budi', 'a4700000-0000-4000-8000-000000000001'), 'ok', 'Sebelum dimatikan, pengikut bisa berkomentar');
select id as first_comment from comments where post_id = 'a4700000-0000-4000-8000-000000000001' limit 1 \gset
select pg_temp.thread_size(:'budi', 'a4700000-0000-4000-8000-000000000001') as open_thread \gset

select tests.authenticate_as(:'ani');
select is(get_comment_settings() -> 'all_off', 'false'::jsonb, 'Bawaan: komentar akun tidak dimatikan');
select is(set_comment_audience('followers') ->> 'audience', 'followers', 'Pemilik memilih pengikut untuk post baru');
select throws_ok($$select set_all_comments_off(null)$$, 'PT400', 'invalid_comment_setting',
  'Pilihan matikan semua komentar wajib diisi');
reset role;

select is(pg_temp.set_all_off(:'ani', true), '{"audience": "followers", "all_off": true}'::jsonb,
  'Mematikan semua komentar tidak mengubah pilihan audiens akun');

select is(pg_temp.attempt(:'budi', 'a4700000-0000-4000-8000-000000000001'), 'comments_off',
  'Semua komentar mati: pengikut ditolak di post yang tadinya terbuka');
select is(pg_temp.attempt(:'cici', 'a4700000-0000-4000-8000-000000000003'), 'comments_off',
  'Semua komentar mati: orang asing ditolak dengan alasan komentar mati');
select is(pg_temp.attempt(:'ani', 'a4700000-0000-4000-8000-000000000001'), 'comments_off',
  'Semua komentar mati: pemilik juga tidak bisa berkomentar');
select is(pg_temp.attempt(:'budi', 'a4700000-0000-4000-8000-000000000001', :'first_comment'), 'comments_off',
  'Semua komentar mati: balasan juga ditolak');
reset role;
select tests.authenticate_as(:'budi');
select throws_ok(format($$insert into comments (post_id, author_id, body) values ('a4700000-0000-4000-8000-000000000001', %L, 'REST')$$, :'budi'),
  'PT403', 'comments_off', 'Semua komentar mati: insert REST langsung ditolak');
reset role;

select is(((pg_temp.post_as(:'budi', 'a4700000-0000-4000-8000-000000000001')).can_comment,
           (pg_temp.post_as(:'budi', 'a4700000-0000-4000-8000-000000000001')).comment_restriction)::text, '(f,off)',
  'Pembaca melihat komentar mati');
select is((pg_temp.post_as(:'budi', 'a4700000-0000-4000-8000-000000000001')).comment_count, null,
  'Pembaca tidak melihat jumlah komentar');
select is((pg_temp.post_as(:'budi', 'a4700000-0000-4000-8000-000000000001')).comments_off_by_account, null,
  'Pembaca tidak tahu komentar dimatikan dari pengaturan akun');
select is((pg_temp.post_as(:'ani', 'a4700000-0000-4000-8000-000000000001')).comments_off_by_account, true,
  'Pemilik tahu komentar dimatikan dari pengaturan akun');
select is((pg_temp.post_as(:'ani', 'a4700000-0000-4000-8000-000000000001')).comment_audience, 'everyone',
  'Pengaturan per post tetap tersimpan');
select is((pg_temp.post_as(:'ani', 'a4700000-0000-4000-8000-000000000001')).comment_count, 1,
  'Pemilik tetap melihat jumlah komentar');
select is(pg_temp.thread_size(:'budi', 'a4700000-0000-4000-8000-000000000001'), 0,
  'Komentar lama disembunyikan dari pembaca');
select is(pg_temp.thread_size(:'ani', 'a4700000-0000-4000-8000-000000000001'), 0,
  'Komentar lama disembunyikan dari pemilik');
select tests.authenticate_as(:'budi');
select is((select count(*)::integer from comments where post_id = 'a4700000-0000-4000-8000-000000000001'), 0,
  'Komentar tidak terbaca lewat REST');
reset role;
select is(private.shared_post_preview(jsonb_build_array(jsonb_build_object('type', 'post',
            'post_id', 'a4700000-0000-4000-8000-000000000001')), :'budi') -> 'comment_count', 'null'::jsonb,
  'Pratinjau post di chat menyembunyikan jumlah');
select is(pg_temp.attempt(:'budi', 'a4700000-0000-4000-8000-000000000004'), 'ok',
  'Post milik orang lain tidak terpengaruh');

select tests.authenticate_as(:'ani');
select (create_post('Post baru saat semua komentar mati')).id as new_post \gset
reset role;
select is((select comment_audience::text from posts where id = :'new_post'), 'followers',
  'Post baru menyimpan pilihan audiens akun');
select is(pg_temp.attempt(:'budi', :'new_post'), 'comments_off', 'Post baru juga tanpa komentar');
select tests.authenticate_as(:'ani');
select is((select comment_audience from set_post_comment_audience('a4700000-0000-4000-8000-000000000003', 'everyone')),
  'everyone', 'Pemilik tetap bisa mengatur post satu per satu');
reset role;
select is(pg_temp.attempt(:'cici', 'a4700000-0000-4000-8000-000000000003'), 'comments_off',
  'Pengaturan per post tidak menembus pengaturan akun');
select tests.authenticate_as(:'ani');
select is(export_my_data() -> 'comments_all_off', 'true'::jsonb, 'Ekspor data menyertakan saklar komentar');
reset role;

select is(pg_temp.set_all_off(:'ani', false) -> 'all_off', 'false'::jsonb, 'Pemilik menyalakan lagi semua komentar');
select is(pg_temp.thread_size(:'budi', 'a4700000-0000-4000-8000-000000000001'), :open_thread,
  'Komentar lama muncul kembali');
select is(pg_temp.attempt(:'cici', 'a4700000-0000-4000-8000-000000000003'), 'ok',
  'Post kembali ke pengaturannya sendiri (diubah ke semua orang)');
select is(pg_temp.attempt(:'budi', 'a4700000-0000-4000-8000-000000000002'), 'comments_off',
  'Post yang dimatikan satu per satu tetap mati');
select is(pg_temp.attempt(:'cici', :'new_post'), 'comments_restricted',
  'Post baru kembali mengikuti audiens yang tersimpan (pengikut)');

select * from finish();
rollback;
