begin;
select plan(20);

select tests.create_user('mi_alice') as alice \gset
select tests.create_user('mi_bob') as bob \gset
select tests.create_user('mi_carol') as carol \gset

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select create_group_room('Grup Info', array[:'bob', :'carol']::uuid[]) as grp \gset
select join_stock_room('TLKM') as stock_room \gset
select tests.authenticate_as(:'bob');
select join_stock_room('TLKM') as stock_room_bob \gset

reset role;
update chat_members
   set last_read_at = now() - interval '1 minute',
       last_delivered_at = now() - interval '1 minute'
 where room_id in (:'dm', :'grp', :'stock_room');

select ok(not has_table_privilege('authenticated', 'private.message_receipts', 'select')
          and not has_table_privilege('anon', 'private.message_receipts', 'select'),
  'Tanda terima per pesan tidak bisa dibaca langsung');
select ok((select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_proc p
            where p.oid = 'public.get_message_info(uuid)'::regprocedure),
  'get_message_info SECURITY DEFINER dengan search_path kosong');
select ok(not has_function_privilege('anon', 'public.get_message_info(uuid)', 'execute'),
  'Info pesan hanya untuk pengguna login');

select tests.authenticate_as(:'alice');
select id as m_dm from send_message(:'dm', 'Halo Bob', 'f1000000-0000-4000-8000-000000000001') \gset
select is(get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'user_id', :'bob',
  'Info pesan DM berisi lawan bicara');
select is((get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'delivered')::boolean, false,
  'Sebelum diterima: belum terkirim ke perangkat');

select tests.authenticate_as(:'bob');
select throws_ok(format('select get_message_info(%L)', :'m_dm'), 'PT404', 'message_not_found',
  'Hanya pengirim yang bisa membuka info pesannya');
select mark_rooms_delivered(array[:'dm']::uuid[]);

select tests.authenticate_as(:'alice');
select ok((get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'delivered')::boolean
          and get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'delivered_at' is not null
          and get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'read_at' is null,
  'Setelah diterima: waktu terkirim tercatat, belum dibaca');

select tests.authenticate_as(:'bob');
select mark_room_read(:'dm');

select tests.authenticate_as(:'alice');
select ok((get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'read')::boolean
          and get_message_info(:'m_dm') -> 'recipients' -> 0 ->> 'read_at' is not null,
  'Setelah dibuka: waktu dibaca tercatat');

reset role;
select is((select count(*)::int from private.message_receipts
            where message_id = :'m_dm' and user_id = :'bob' and delivered_at is not null and read_at is not null), 1,
  'Baris tanda terima menyimpan waktu terkirim dan dibaca');
update chat_members set last_read_at = last_read_at + interval '1 hour', last_delivered_at = last_delivered_at + interval '1 hour'
 where room_id = :'dm' and user_id = :'bob';
select is((select count(*)::int from private.message_receipts where message_id = :'m_dm' and user_id = :'bob'), 1,
  'Membuka ulang room tidak menggandakan tanda terima');
select is((select count(*)::int from private.message_receipts where message_id = :'m_dm' and user_id = :'alice'), 0,
  'Pengirim tidak dicatat sebagai penerima pesannya sendiri');

select tests.authenticate_as(:'alice');
select id as m_grp from send_message(:'grp', 'Halo grup', 'f1000000-0000-4000-8000-000000000002') \gset
select tests.authenticate_as(:'bob');
select mark_room_read(:'grp');
select tests.authenticate_as(:'carol');
select mark_rooms_delivered(array[:'grp']::uuid[]);

select tests.authenticate_as(:'alice');
select is(jsonb_array_length(get_message_info(:'m_grp') -> 'recipients'), 2, 'Info pesan grup berisi semua anggota lain');
select is((select count(*)::int from jsonb_array_elements(get_message_info(:'m_grp') -> 'recipients') r
            where (r ->> 'read')::boolean), 1, 'Satu anggota sudah membaca');
select is((select count(*)::int from jsonb_array_elements(get_message_info(:'m_grp') -> 'recipients') r
            where (r ->> 'delivered')::boolean and r ->> 'delivered_at' is not null), 2,
  'Dua anggota sudah menerima, dengan waktunya');
select is(get_message_info(:'m_grp') -> 'recipients' -> 0 ->> 'user_id', :'bob',
  'Yang sudah membaca tampil lebih dulu');

select id as m_stock from send_message(:'stock_room', 'Halo room saham', 'f1000000-0000-4000-8000-000000000003') \gset
select tests.authenticate_as(:'bob');
select mark_room_read(:'stock_room');
select tests.authenticate_as(:'alice');
select is(get_message_info(:'m_stock') -> 'recipients', '[]'::jsonb, 'Room saham tidak punya info penerima');
reset role;
select is((select count(*)::int from private.message_receipts where message_id = :'m_stock'), 0,
  'Room saham tidak mencatat tanda terima per pesan');

insert into private.message_receipts (message_id, user_id, message_created_at, delivered_at)
values (:'m_grp', :'carol', now() - interval '31 days', now())
on conflict (message_id, user_id) do update set message_created_at = excluded.message_created_at;
select private.message_receipts_retention();
select is((select count(*)::int from private.message_receipts where message_id = :'m_grp' and user_id = :'carol'), 0,
  'Tanda terima lebih dari 30 hari dihapus');
select is((select count(*)::int from private.message_receipts where message_id = :'m_dm'), 1,
  'Tanda terima baru tetap ada');
select ok(exists (select 1 from cron.job where jobname = 'message-receipts-retention'), 'Retensi tanda terima terjadwal');

select * from finish();
rollback;
