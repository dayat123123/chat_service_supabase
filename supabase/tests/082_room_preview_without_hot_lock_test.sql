begin;
select plan(28);

update private.rate_limits set max_count = 1000 where action = 'message';
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select tests.create_user('rp_alice') as alice \gset
select tests.create_user('rp_bob') as bob \gset

select has_table('private', 'room_preview_queue', 'Antrean pratinjau room tersedia');
select is((select prokind::text from pg_proc where oid = 'private.room_preview_worker(integer)'::regprocedure), 'p',
  'Worker pratinjau berupa procedure agar bisa commit per putaran');
select results_eq(
  $$select schedule, command from cron.job where jobname = 'chat-room-preview'$$,
  $$values ('10 seconds'::text, 'call private.room_preview_worker()'::text)$$,
  'Job pg_cron pratinjau room terdaftar');
select ok(pg_get_functiondef('private.messages_after_insert()'::regprocedure) ilike '%for no key update skip locked%',
  'Trigger pesan tidak menunggu kunci baris room saham');
select ok(not has_function_privilege('authenticated', 'private.room_preview_tick()', 'execute'),
  'Pengguna tidak bisa menjalankan tick pratinjau');
select ok(not has_table_privilege('authenticated', 'private.room_preview_queue', 'select'),
  'Pengguna tidak bisa membaca antrean pratinjau');

select tests.authenticate_as(:'alice');
select join_stock_room('RPLK') as stock \gset
select get_or_create_direct_room(:'bob') as dm \gset
select tests.authenticate_as(:'bob');
select join_stock_room('RPLK') is not null as joined \gset

select tests.authenticate_as(:'alice');
select id as m1 from send_message(:'stock', 'Pembukaan sesi pagi', 'e8200000-0000-4000-8000-000000000001') \gset
reset role;
select results_eq(
  format($$select last_message_preview, last_message_sender_id from public.chat_rooms where id = %L$$, :'stock'),
  format($$values ('Pembukaan sesi pagi'::text, %L::uuid)$$, :'alice'),
  'Room saham sepi: pratinjau langsung diperbarui');
select is((select count(*)::integer from private.room_preview_queue where room_id = :'stock'), 0,
  'Kunci room bebas: tidak ada antrean pratinjau');

select tests.authenticate_as(:'bob');
select id as m2 from send_message(:'stock', 'Antrean beli tebal @rp_alice', 'e8200000-0000-4000-8000-000000000002') \gset
reset role;
select is((select last_message_preview from public.chat_rooms where id = :'stock'), 'Antrean beli tebal @rp_alice',
  'Pesan berikutnya dengan waktu sama tetap memperbarui pratinjau');
select is((select count(*)::integer from public.notifications
            where user_id = :'alice' and type = 'mention' and payload ->> 'message_id' = :'m2'), 1,
  'Mention di room saham tetap memberi notifikasi');
select is((select last_read_at from public.chat_members where room_id = :'stock' and user_id = :'bob'),
  (select created_at from public.messages where id = :'m2'), 'Pesan pengirim tetap menandai room terbaca');

update public.chat_rooms set last_message_at = now() + interval '1 minute', last_message_preview = 'lebih baru'
 where id = :'stock';
select tests.authenticate_as(:'alice');
select id as m3 from send_message(:'stock', 'Pesan terlambat commit', 'e8200000-0000-4000-8000-000000000003') \gset
reset role;
select is((select last_message_preview from public.chat_rooms where id = :'stock'), 'lebih baru',
  'Pesan lebih lama tidak menimpa pratinjau yang lebih baru');

update public.chat_rooms set last_message_at = now() - interval '1 hour', last_message_preview = 'lama'
 where id = :'stock';
insert into public.messages (room_id, sender_id, body, moderation_status)
values (:'stock', :'bob', 'Tertahan moderasi', 'held');
select is((select last_message_preview from public.chat_rooms where id = :'stock'), 'lama',
  'Pesan tertahan tidak mengubah pratinjau');
select is((select count(*)::integer from private.room_preview_queue where room_id = :'stock'), 0,
  'Pesan tertahan tidak masuk antrean pratinjau');

update public.messages set created_at = now() - interval '4 minutes' where id = :'m1';
update public.messages set created_at = now() - interval '3 minutes' where id = :'m2';
update public.messages set created_at = now() - interval '2 minutes', moderation_status = 'hidden' where id = :'m3';
update public.messages set created_at = now() - interval '5 minutes' where room_id = :'stock' and moderation_status = 'held';
select tests.authenticate_as(:'alice');
select id as m4 from send_message(:'stock', 'Akan dihapus', 'e8200000-0000-4000-8000-000000000004') \gset
reset role;
update public.messages set created_at = now() - interval '1 minute', deleted_at = now() where id = :'m4';
update public.chat_rooms set last_message_at = now() - interval '1 hour', last_message_preview = 'basi',
                             last_message_sender_id = null
 where id = :'stock';
insert into private.room_preview_queue (room_id) values (:'stock'), (:'stock'), (gen_random_uuid());

select is(private.room_preview_tick(), 2, 'Tick memproses room unik di antrean, termasuk room yang sudah hilang');
select results_eq(
  format($$select last_message_preview, last_message_sender_id, last_message_at = now() - interval '3 minutes'
           from public.chat_rooms where id = %L$$, :'stock'),
  format($$values ('Antrean beli tebal @rp_alice'::text, %L::uuid, true)$$, :'bob'),
  'Tick memulihkan pratinjau ke pesan terlihat terbaru, melewati pesan tersembunyi dan terhapus');
select is((select count(*)::integer from private.room_preview_queue), 0, 'Antrean kosong setelah tick');

select tests.authenticate_as(:'alice');
select is((select last_message_preview from get_my_rooms() where id = :'stock'), 'Antrean beli tebal @rp_alice',
  'Daftar room membaca pratinjau hasil tick');
reset role;

update public.chat_rooms set last_message_at = now() + interval '1 minute', last_message_preview = 'lebih baru'
 where id = :'stock';
insert into private.room_preview_queue (room_id) values (:'stock');
select is(private.room_preview_tick(), 1, 'Tick tetap mengosongkan antrean room yang sudah mutakhir');
select is((select last_message_preview from public.chat_rooms where id = :'stock'), 'lebih baru',
  'Tick tidak memundurkan pratinjau yang lebih baru');

update public.messages set moderation_status = 'hidden' where room_id = :'stock';
update public.chat_rooms set last_message_at = null, last_message_preview = null, last_message_sender_id = null
 where id = :'stock';
select ok(private.refresh_room_preview(:'stock'), 'Refresh berhasil saat kunci room bebas');
select is((select last_message_preview from public.chat_rooms where id = :'stock'), null,
  'Room tanpa pesan terlihat tetap tanpa pratinjau');
select ok(private.refresh_room_preview(gen_random_uuid()), 'Refresh room yang tidak ada dianggap selesai');

update public.chat_members set last_read_at = now() - interval '1 minute', last_delivered_at = now() - interval '1 minute'
 where room_id = :'dm' and user_id = :'bob';
select tests.authenticate_as(:'alice');
select id as m5 from send_message(:'dm', 'Halo Bob langsung', 'e8200000-0000-4000-8000-000000000005') \gset
select is((select last_message_status from get_my_rooms() where id = :'dm'), 'sent', 'Status pesan terakhir tetap dari pratinjau room');
reset role;
select results_eq(
  format($$select last_message_preview, last_message_sender_id from public.chat_rooms where id = %L$$, :'dm'),
  format($$values ('Halo Bob langsung'::text, %L::uuid)$$, :'alice'),
  'Pesan langsung memperbarui pratinjau seketika');
select is((select count(*)::integer from public.notifications
            where user_id = :'bob' and type = 'message' and payload ->> 'message_id' = :'m5'), 1,
  'Pesan langsung tetap memberi notifikasi');
select is((select count(*)::integer from private.room_preview_queue), 0, 'Pesan langsung tidak memakai antrean');

update private.dm_requests set status = 'accepted', responded_at = now() where room_id = :'dm';
select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 1, 'Badge belum dibaca tetap membaca pratinjau room');
reset role;

select * from finish();
rollback;
