begin;
select plan(13);

update private.rate_limits set max_count = 1000
 where action in ('message', 'room_create', 'comment', 'post', 'follow', 'dm_request');

select tests.create_user('dl_ani') as ani \gset
select tests.create_user('dl_budi') as budi \gset
select tests.create_user('dl_cici') as cici \gset
select tests.create_user('dl_dedi') as dedi \gset
select tests.create_user('dl_eko') as eko \gset
select tests.create_user('dl_fani') as fani \gset

insert into blocks (blocker_id, blocked_id) values (:'ani', :'budi'), (:'budi', :'dedi');
insert into mutes (muter_id, muted_id) values (:'cici', :'budi'), (:'budi', :'eko');
insert into follows (follower_id, following_id) values (:'ani', :'eko'), (:'budi', :'cici'), (:'cici', :'budi');
insert into posts (id, author_id, body) values ('a5100000-0000-4000-8000-000000000001', :'ani', 'Post Ani');

select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'fani') as dm \gset
reset role;
select is((select status from private.dm_requests where room_id = :'dm'), 'pending', 'DM ke orang asing menjadi permintaan');
select tests.authenticate_as(:'fani');
select respond_message_request(:'dm', 'decline') as declined \gset
reset role;

select tests.authenticate_as(:'budi');
select lives_ok($$select delete_my_account()$$, 'Budi menghapus akunnya');
reset role;

select is((select count(*)::integer from blocks where blocker_id = :'ani' and blocked_id = :'budi'), 1,
  'Blokir orang lain terhadap akun yang dihapus tetap tersimpan');
select is((select count(*)::integer from mutes where muter_id = :'cici' and muted_id = :'budi'), 1,
  'Mute orang lain terhadap akun yang dihapus tetap tersimpan');
select is((select count(*)::integer from blocks where blocker_id = :'budi'), 0, 'Blokir yang dibuat Budi dihapus');
select is((select count(*)::integer from mutes where muter_id = :'budi'), 0, 'Mute yang dibuat Budi dihapus');
select is((select count(*)::integer from follows where follower_id = :'budi' or following_id = :'budi'), 0,
  'Follow dua arah tetap dihapus');

select upsert_olt_profile(:'budi', 'test:' || :'budi', 'dl_budi', 'Budi') as relogin \gset
select ok(private.is_blocked_pair(:'ani', :'budi'), 'Setelah login lagi, blokir Ani tetap berlaku');

select tests.authenticate_as(:'budi');
select throws_ok($$select get_or_create_direct_room('$$ || :'ani' || $$')$$, 'PT403', 'blocked',
  'Akun yang login lagi tetap tidak bisa DM orang yang memblokirnya');
select throws_ok($$select create_comment('a5100000-0000-4000-8000-000000000001', null, 'Halo lagi')$$, 'PT403', 'blocked',
  'Akun yang login lagi tetap tidak bisa berkomentar di post orang yang memblokirnya');
select is(get_or_create_direct_room(:'fani'), :'dm'::uuid, 'DM ke orang yang pernah menolak memakai room yang sama');
reset role;
select is((select status from private.dm_requests where room_id = :'dm'), 'declined',
  'Permintaan DM yang pernah ditolak tetap ditolak');
select ok(not private.is_blocked_pair(:'budi', :'dedi'), 'Blokir lama milik Budi tidak kembali');

select * from finish();
rollback;
