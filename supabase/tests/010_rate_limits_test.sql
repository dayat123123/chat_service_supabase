-- Rate limit berlapis (0012): beberapa jendela, trust_level, Retry-After,
-- retry idempoten, buat room, upload/ekspor (event).
begin;
select plan(12);

select tests.create_user('rl_normal') as normal \gset
select tests.create_user('rl_baru') as newbie \gset
select tests.create_user('rl_percaya') as trusted \gset
select tests.create_user('rl_retry') as retry \gset
update profiles set trust_level = 0 where id = :'newbie';
update profiles set trust_level = 2 where id = :'trusted';

select is(private.setting_num('rate_limit.trusted_factor', 9), 2::numeric, 'Pengaturan dibaca dari private.settings');

-- Jendela harian post (diturunkan agar tes cepat): 3 per hari.
update private.rate_limits set max_count = 3 where action = 'post' and window_seconds = 86400;
insert into posts (author_id, body, created_at) values
  (:'normal', 'post dua jam lalu', now() - interval '2 hours'),
  (:'normal', 'post tiga jam lalu', now() - interval '3 hours');
select tests.authenticate_as(:'normal');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'post ketiga hari ini')$$,
  'Post ke-3 dalam sehari diizinkan');
-- Retry-After = sampai post tertua keluar dari jendela 24 jam (24j - 3j).
select throws_like($$insert into posts (author_id, body) values (auth.uid(), 'post keempat hari ini')$$,
  '%"PT429"%86400 detik%Coba lagi dalam 75600 detik%', 'Jendela harian menolak post ke-4 dengan Retry-After');
reset role;
update private.rate_limits set max_count = 50 where action = 'post' and window_seconds = 86400;

-- Akun baru (trust 0): batas per menit 5 x 0.5 = 2.
select tests.authenticate_as(:'newbie');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'akun baru pertama')$$, 'Akun baru: post 1');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'akun baru kedua')$$, 'Akun baru: post 2');
select throws_like($$insert into posts (author_id, body) values (auth.uid(), 'akun baru ketiga')$$,
  '%"rate_limited"%Batas 2 post per 60 detik%', 'Akun baru: batas per menit dikali 0.5');
reset role;

-- Akun tepercaya (trust 2): 5 x 2 = 10 per menit.
select tests.authenticate_as(:'trusted');
select lives_ok($q$do $d$ begin
    for i in 1..6 loop
      insert into posts (author_id, body) values (auth.uid(), 'akun tepercaya nomor ' || i);
    end loop;
  end $d$$q$, 'Akun tepercaya: 6 post per menit diizinkan');
reset role;

-- Kirim ulang dengan client_id yang sama tidak dihitung sebagai aksi baru.
update private.rate_limits set max_count = 2 where action = 'post' and window_seconds = 60;
select tests.authenticate_as(:'retry');
select (create_post('retry pertama', null, '[]', 'b1000000-0000-4000-8000-000000000001')).id as retry_post1 \gset
select (create_post('retry kedua', null, '[]', 'b1000000-0000-4000-8000-000000000002')).id as retry_post2 \gset
select lives_ok($$select create_post('retry pertama', null, '[]', 'b1000000-0000-4000-8000-000000000001')$$,
  'Retry client_id lama setelah batas tercapai tidak ditolak');
select throws_like($$select create_post('retry ketiga', null, '[]', 'b1000000-0000-4000-8000-000000000003')$$,
  '%"rate_limited"%', 'Post baru setelah batas tercapai ditolak');
reset role;

-- Buat room: dibatasi per jam (room saham tidak dihitung).
update private.rate_limits set max_count = 1 where action = 'room_create';
select tests.authenticate_as(:'normal');
select lives_ok($$select create_group_room('Grup pertama')$$, 'Room pertama dibuat');
select throws_like($$select create_group_room('Grup kedua')$$, '%"rate_limited"%room_create%',
  'Room kedua dalam sejam ditolak');
reset role;

-- Aksi berbasis event (upload, ekspor data).
update private.rate_limits set max_count = 1 where action = 'upload';
select private.consume_rate_limit(:'normal', 'upload') as upload1 \gset
select throws_like(format($$select private.consume_rate_limit(%L, 'upload')$$, :'normal'),
  '%"rate_limited"%upload%', 'Upload melebihi kuota harian ditolak');

select * from finish();
rollback;
