begin;
select plan(12);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'push_register');

select tests.create_user('gm_owen') as owen \gset
select tests.create_user('gm_ani') as ani \gset
select tests.create_user('gm_budi') as budi \gset
select tests.create_user('gm_cici') as cici \gset
select tests.create_user('gm_dedi') as dedi \gset
select tests.create_user('gm_eko') as eko \gset
select tests.create_user('gm_fani') as fani \gset
select tests.create_user('gm_luar') as luar \gset
update public.profiles set display_name = 'Owen' where id = :'owen';

create function pg_temp.kinds(p_user uuid, p_room uuid) returns text language sql security definer as $$
  select coalesce(string_agg(n.type || ':' || n.event_count, ',' order by n.type), '-')
  from public.notifications n where n.user_id = p_user and n.payload ->> 'room_id' = p_room::text
$$;

select tests.authenticate_as(:'owen');
select create_group_room('Investor', array[:'ani', :'budi', :'cici', :'dedi', :'eko', :'fani']::uuid[]) as grp \gset
reset role;

update public.chat_members set muted = true where room_id = :'grp' and user_id in (:'budi', :'eko');
insert into public.mutes (muter_id, muted_id) values (:'dedi', :'owen');
insert into private.mention_preferences (user_id, policy) values (:'cici', 'none');
select tests.authenticate_as(:'budi');
select public.register_push_device('gm-token-budi-0000000000000001', 'android') as dev \gset
reset role;
delete from public.notifications where payload ->> 'room_id' = :'grp';

select tests.authenticate_as(:'owen');
select id as msg1 from send_message(:'grp', 'Rapat @gm_ani @GM_Budi @gm_cici @gm_dedi @gm_luar jam 3') \gset
reset role;

select is(pg_temp.kinds(:'ani', :'grp'), 'mention:1', 'Anggota yang disebut mendapat notifikasi mention, bukan pesan biasa');
select is(pg_temp.kinds(:'budi', :'grp'), 'mention:1', 'Anggota yang membisukan grup tetap diberi tahu saat disebut');
select is(pg_temp.kinds(:'cici', :'grp'), 'message:1', 'Pengaturan mention none: tetap dapat notifikasi pesan biasa');
select is(pg_temp.kinds(:'dedi', :'grp'), 'message:1', 'Membisukan pengirim: mention diabaikan, pesan biasa tetap');
select is(pg_temp.kinds(:'eko', :'grp'), '-', 'Grup dibisukan dan tidak disebut: tanpa notifikasi');
select is(pg_temp.kinds(:'fani', :'grp'), 'message:1', 'Anggota lain mendapat notifikasi pesan biasa');
select is((select count(*)::integer from public.notifications where user_id = :'luar'), 0,
  'Bukan anggota grup tidak diberi tahu walau disebut');
select is((select payload from public.notifications where user_id = :'ani' and type = 'mention'),
  jsonb_build_object('room_id', :'grp', 'room_type', 'group', 'room_name', 'Investor', 'message_id', :'msg1',
                     'snippet', 'Rapat @gm_ani @GM_Budi @gm_cici @gm_dedi @gm_luar jam 3'),
  'Payload mention grup memuat room, nama grup, pesan, dan cuplikan');
select is((select title from private.push_queue where user_id = :'budi' and kind = 'mention'),
  'Owen menyebut Anda di Investor', 'Push mention menyebut nama grup');

select tests.authenticate_as(:'owen');
select id as msg2 from send_message(:'grp', '@gm_ani setuju?') \gset
reset role;
select is(pg_temp.kinds(:'ani', :'grp'), 'mention:2', 'Mention berulang di grup yang sama digabung');
select is(pg_temp.kinds(:'fani', :'grp'), 'message:2', 'Pesan tanpa menyebut tetap digabung sebagai pesan biasa');

select tests.authenticate_as(:'ani');
select id as msg3 from send_message(:'grp', 'Siap @gm_owen') \gset
reset role;
select is(pg_temp.kinds(:'owen', :'grp'), 'mention:1', 'Pembuat grup juga bisa disebut');

select * from finish();
rollback;
