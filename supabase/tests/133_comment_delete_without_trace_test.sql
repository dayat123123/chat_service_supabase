begin;
select plan(20);

update private.rate_limits set max_count = 1000 where action = 'comment';
select tests.create_user('cd_ani') as ani \gset
select tests.create_user('cd_budi') as budi \gset
select tests.create_user('cd_cici') as cici \gset
insert into posts (id, author_id, body) values ('a3000000-0000-4000-8000-000000000001', :'ani', 'Diskusi');

create function pg_temp.thread(p_sort text) returns uuid[] language sql as $$
  select array_agg(id) from get_comment_thread('a3000000-0000-4000-8000-000000000001', null, 10, null, 50, 50, false, p_sort)
$$;

select tests.authenticate_as(:'ani');
select id as a from create_comment('a3000000-0000-4000-8000-000000000001', null, 'Komentar A') \gset
select tests.authenticate_as(:'budi');
select id as b from create_comment('a3000000-0000-4000-8000-000000000001', :'a', 'Balasan B') \gset
select tests.authenticate_as(:'cici');
select id as c from create_comment('a3000000-0000-4000-8000-000000000001', :'b', 'Balasan C') \gset
select tests.authenticate_as(:'ani');
select id as d from create_comment('a3000000-0000-4000-8000-000000000001', null, 'Komentar D') \gset

select tests.authenticate_as(:'budi');
select lives_ok(format('select delete_comment(%L)', :'b'), 'Penulis menghapus balasan B');
select is(pg_temp.thread('oldest'), array[:'a', :'c', :'d']::uuid[], 'Thread tidak memuat komentar terhapus');
select is((select parent_id from get_comment_thread('a3000000-0000-4000-8000-000000000001', null, 10, null, 50, 50)
           where id = :'c'), :'a'::uuid, 'Balasan C naik ke induk terdekat A');
select is((select depth from get_comment_thread('a3000000-0000-4000-8000-000000000001', null, 10, null, 50, 50)
           where id = :'c'), 1, 'Depth balasan C disesuaikan');
select ok((select path from comments where id = :'c') operator(extensions.<@) (select path from comments where id = :'a'),
  'Path balasan C berada di bawah A');
select is((select reply_count from comments where id = :'a'), 1, 'reply_count A menghitung C, bukan B');
select is((select comment_count from posts where id = 'a3000000-0000-4000-8000-000000000001'), 3,
  'comment_count tidak menghitung komentar terhapus');
select throws_ok(format($$select * from get_comment_thread('a3000000-0000-4000-8000-000000000001', %L, 3, null, 10, 3, true)$$,
                        :'b'), 'PT404', 'comment_not_found', 'Thread dari komentar terhapus tidak bisa dibuka');
select is((select count(*)::integer from get_comment_thread('a3000000-0000-4000-8000-000000000001', null, 10, null, 50, 50)
           where is_deleted), 0, 'Tidak ada placeholder komentar dihapus');

select tests.authenticate_as(:'ani');
select lives_ok(format('select delete_comment(%L)', :'a'), 'Penulis menghapus komentar tingkat atas A');
select is(pg_temp.thread('oldest'), array[:'c', :'d']::uuid[], 'Balasan tanpa induk menjadi komentar tingkat atas');
select is((select parent_id from comments where id = :'c'), null, 'parent_id balasan C kosong');
select is((select depth from comments where id = :'c'), 0, 'Depth balasan C menjadi 0');
select is(pg_temp.thread('latest'), array[:'d', :'c']::uuid[], 'Urutan terbaru tanpa komentar terhapus');
select is((select count(*)::integer from unnest(pg_temp.thread('top')) t where t in (:'a', :'b')), 0,
  'Urutan teratas tanpa komentar terhapus');
select is((select comment_count from posts where id = 'a3000000-0000-4000-8000-000000000001'), 2,
  'comment_count berkurang lagi');

select tests.authenticate_as(:'budi');
select id as e from create_comment('a3000000-0000-4000-8000-000000000001', :'c', 'Balasan E') \gset
select is((select depth from comments where id = :'e'), 1, 'Balasan baru memakai depth induk yang sudah naik');
select is((select reply_count from comments where id = :'c'), 1, 'reply_count C bertambah');

reset role;
select is((select count(*)::integer from private.content_archive
           where target_type = 'comment' and target_id in (:'a', :'b')), 2, 'Komentar terhapus tetap diarsipkan');
select ok((select deleted_at is not null from comments where id = :'b'), 'Baris komentar terhapus tetap ada untuk moderasi');

select * from finish();
rollback;
