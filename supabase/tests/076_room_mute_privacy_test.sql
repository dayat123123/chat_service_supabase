begin;
select plan(28);

update private.rate_limits set max_count = 1000 where action in ('message', 'stock_room_create', 'room_mod_action');
update cs.agents set community_permissions = '{}';
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';
select tests.create_user('rp_mod') as moderator \gset
select tests.create_user('rp_target') as target \gset
select tests.create_user('rp_other') as other \gset
update public.profiles set trust_level = 2 where id = :'moderator';
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select tests.authenticate_as(:'target');
select public.register_push_device('n76-token-target-0000000000001', 'android') as dev_target \gset
select join_stock_room('RMPV') as room \gset
reset role;
select tests.authenticate_as(:'other');
select join_stock_room('RMPV') is not null as joined_other \gset
reset role;

select tests.authenticate_agent(:'dodi');
select cs_api.community_appoint_room_moderator('RMPV', :'moderator', null) is not null as appointed \gset
reset role;

select count(*)::integer as broadcasts_before from realtime.messages
where topic = 'room:' || :'room' and event = 'room_state' \gset

select tests.authenticate_as(:'moderator');
select room_mod_mute_user(:'room', :'target', 60, 'spam', 'Promosi grup') ->> 'mute_until' as mute_until \gset
select is(jsonb_array_length(get_stock_room_state('RMPV') -> 'mutes'), 1, 'Moderator room melihat daftar bisu');
select is(get_stock_room_state('RMPV') -> 'mutes' -> 0 ->> 'user_id', :'target',
  'Daftar bisu moderator memuat anggota yang dibisukan');
select is((get_stock_room_state('RMPV') -> 'mutes' -> 0 ->> 'until')::timestamptz, :'mute_until'::timestamptz,
  'Daftar bisu moderator memuat batas waktu bisu');
select throws_ok(format($$select room_mod_mute_user(%L, %L, 30, 'spam')$$, :'room', :'target'), 'PT409', 'already_muted',
  'Moderator tetap tidak bisa membisukan dua kali');
reset role;

select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'room' and event = 'room_state'),
  :'broadcasts_before'::integer, 'Membisukan anggota tidak menyiarkan status room ke semua anggota');

select tests.authenticate_as(:'other');
select ok(not (get_stock_room_state('RMPV') ? 'mutes'), 'Anggota biasa tidak menerima daftar bisu');
select ok(position(:'target' in get_stock_room_state('RMPV')::text) = 0,
  'Status room anggota biasa tidak menyebut anggota yang dibisukan');
select is(get_stock_room_state('RMPV') ->> 'muted_until', null, 'Anggota biasa yang tidak dibisukan tanpa batas bisu');
select ok(get_stock_room_state('RMPV') -> 'moderators' ? :'moderator', 'Daftar moderator tetap terlihat untuk lencana');
reset role;

select tests.authenticate_as(:'target');
select is((get_stock_room_state('RMPV') ->> 'muted_until')::timestamptz, :'mute_until'::timestamptz,
  'Anggota yang dibisukan melihat batas bisunya sendiri');
select ok(not (get_stock_room_state('RMPV') ? 'mutes'), 'Anggota yang dibisukan tidak menerima daftar bisu');
select throws_ok(format($$select send_message(%L, 'Coba kirim', 'c7600000-0000-4000-8000-000000000001')$$, :'room'),
  'PT403', 'room_muted', 'Anggota yang dibisukan tetap ditolak saat mengirim');
reset role;

select count(*) as broadcast_done from private.broadcast_room_state(:'room') \gset
select ok(exists (select 1 from realtime.messages where topic = 'room:' || :'room' and event = 'room_state'),
  'Status room tetap disiarkan');
select ok(not exists (select 1 from realtime.messages
                      where topic = 'room:' || :'room' and event = 'room_state'
                        and (payload ? 'mutes' or payload ? 'muted_until' or position(:'target' in payload::text) > 0)),
  'Siaran status room tidak membawa daftar bisu');

select is((select payload - 'excerpt' from public.notifications
           where user_id = :'target' and type = 'moderation' and payload ->> 'target_type' = 'room'),
  jsonb_build_object('target_type', 'room', 'target_id', :'room', 'state', 'muted', 'appealable', false,
                     'room_id', :'room', 'stock_code', 'RMPV', 'until', (:'mute_until'::timestamptz), 'reason', 'spam'),
  'Anggota yang dibisukan diberi tahu lewat notifikasi pribadinya');
select is((select actor_id from public.notifications
           where user_id = :'target' and type = 'moderation' and payload ->> 'target_type' = 'room'), null,
  'Notifikasi bisu tidak menyebut moderator');
select ok(position(:'moderator' in (select payload::text from public.notifications
                                    where user_id = :'target' and type = 'moderation'
                                      and payload ->> 'target_type' = 'room')) = 0,
  'Payload notifikasi bisu tanpa identitas moderator');
select is((select count(*)::integer from public.notifications
           where user_id in (:'other', :'moderator') and type = 'moderation' and payload ->> 'target_type' = 'room'), 0,
  'Anggota lain tidak menerima notifikasi bisu');
select is((select title from private.push_queue where user_id = :'target' and kind = 'moderation'),
  'Anda dibisukan moderator di $RMPV', 'Push bisu menyebut room saham');
select ok((select body from private.push_queue where user_id = :'target' and kind = 'moderation') like '%WIB',
  'Push bisu menyebut kapan bisa mengirim lagi');

select tests.authenticate_agent(:'dodi');
select is(jsonb_array_length(cs_api.community_room_state('RMPV') -> 'mutes'), 1, 'Staf tetap melihat daftar bisu room');
select (select x ->> 'id' from jsonb_array_elements(cs_api.community_room_moderator_actions('RMPV') -> 'items') x
        where x ->> 'action' = 'mute') as mute_action \gset
select is(cs_api.community_undo_room_moderator_action(:'mute_action', 'Bukan spam') ->> 'action', 'mute',
  'Staf membatalkan bisu');
reset role;

select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'room' and event = 'room_state'),
  :'broadcasts_before'::integer + 1, 'Pembatalan bisu tidak menyiarkan status room');
select ok(exists (select 1 from public.notifications
                  where user_id = :'target' and type = 'moderation' and payload ->> 'target_type' = 'room'
                    and payload ->> 'state' = 'unmuted' and payload -> 'until' = 'null'::jsonb),
  'Anggota diberi tahu saat bisunya dicabut');
select is((select title from private.push_queue
           where user_id = :'target' and kind = 'moderation' and data ->> 'state' = 'unmuted'),
  'Bisu Anda di $RMPV dicabut', 'Push pencabutan bisu menyebut room saham');

select tests.authenticate_as(:'target');
select is(get_stock_room_state('RMPV') ->> 'muted_until', null, 'Batas bisu hilang setelah dicabut');
reset role;
select tests.authenticate_as(:'moderator');
select is(get_stock_room_state('RMPV') -> 'mutes', '[]'::jsonb, 'Daftar bisu moderator kosong setelah dicabut');
reset role;
select tests.authenticate_as(:'other');
select is(get_stock_room_state('RMPVX') ? 'mutes', false, 'Room yang belum ada juga tanpa daftar bisu');
reset role;

select * from finish();
rollback;
