begin;
select plan(8);

update private.rate_limits set max_count = 1000 where action in ('message', 'content_edit', 'stock_room_create');
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'maya';
select tests.create_user('eh_budi') as budi \gset
select tests.create_user('eh_sari') as sari \gset
insert into public.follows (follower_id, following_id) values (:'budi', :'sari'), (:'sari', :'budi');

select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'sari') as dm \gset
select id as dm_msg from send_message(:'dm', 'Isi awal pribadi') \gset
select body from edit_message(:'dm_msg', 'Isi baru pribadi');
select join_stock_room('EHXT') as stock \gset
select id as stock_msg from send_message(:'stock', 'Isi awal publik') \gset
select body from edit_message(:'stock_msg', 'Isi baru publik');
reset role;

select tests.authenticate_agent(:'maya');
select is((cs_api.community_edit_history('message', :'stock_msg') -> 0 ->> 'body'), 'Isi awal publik',
  'Moderator melihat isi asli pesan room saham yang diedit');
select throws_ok(format($$select cs_api.community_edit_history('message', %L)$$, :'dm_msg'), 'PT403',
  'private_message_forbidden', 'Riwayat pesan pribadi yang tidak dilaporkan tidak bisa dibuka');
select throws_ok($$select cs_api.community_edit_history('message', gen_random_uuid())$$, 'PT404', 'content_not_found',
  'Pesan yang tidak ada ditolak');
reset role;

insert into public.reports (reporter_id, target_type, target_id, reason) values (:'sari', 'message', :'dm_msg', 'spam');

select tests.authenticate_agent(:'maya');
select is((cs_api.community_edit_history('message', :'dm_msg') -> 0 ->> 'body'), 'Isi awal pribadi',
  'Riwayat pesan pribadi yang dilaporkan bisa dibuka');
reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'community.private_message_edits_view' and details ->> 'message' = :'dm_msg'), 1,
  'Membuka riwayat pesan pribadi tercatat di audit');
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'community.private_message_edits_view' and details ->> 'message' = :'stock_msg'), 0,
  'Riwayat pesan room saham tidak dicatat sebagai akses pesan pribadi');

select tests.authenticate_as(:'budi');
select throws_ok(format($$select cs_api.community_edit_history('message', %L)$$, :'stock_msg'), 'PT403', null,
  'Pengguna biasa tidak bisa membaca riwayat edit');
reset role;
select ok(has_function_privilege('authenticated', 'cs_api.community_edit_history(text, uuid)', 'EXECUTE'),
  'Hak eksekusi RPC tetap sama');

select * from finish();
rollback;
