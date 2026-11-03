begin;
select plan(26);

update private.rate_limits set max_count = 1000
 where action in ('post_draft', 'post', 'message', 'follow', 'room_create', 'stock_room_create', 'data_export',
                  'notification_event');
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select tests.create_user('d69_budi') as budi \gset
select tests.create_user('d69_sari') as sari \gset

select ok((select relrowsecurity from pg_class where oid = 'public.post_drafts'::regclass), 'RLS aktif di tabel draf');

select tests.authenticate_as(:'budi');
select public.save_post_draft('d6900000-0000-4000-8000-000000000001', '  Analisa $BBCA minggu ini  ', 'bullish',
  '{" bbca",TLKM,bbca}', '[]', '{"options": ["Naik", "Turun"], "duration_hours": 24}') as d1 \gset
select is((:'d1'::jsonb - 'id' - 'created_at' - 'updated_at'),
  '{"client_draft_id": "d6900000-0000-4000-8000-000000000001", "body": "Analisa $BBCA minggu ini", "sentiment": "bullish",
    "stocks": ["BBCA", "TLKM"], "attachments": [], "poll": {"options": ["Naik", "Turun"], "duration_hours": 24}}'::jsonb,
  'Draf tersimpan dengan teks dirapikan dan kode saham dinormalkan');
select is(jsonb_array_length(public.get_post_drafts()), 1, 'Draf tersinkron ke daftar draf');
select is(public.save_post_draft('d6900000-0000-4000-8000-000000000001', 'Analisa $BBCA revisi',
  p_base_updated_at => (:'d1'::jsonb ->> 'updated_at')::timestamptz) ->> 'id', :'d1'::jsonb ->> 'id',
  'Draf yang sama diperbarui, bukan diduplikasi');
select throws_ok(format($$select public.save_post_draft('d6900000-0000-4000-8000-000000000001', 'Versi lama',
  p_base_updated_at => %L)$$, :'d1'::jsonb ->> 'updated_at'), 'PT409', 'draft_conflict',
  'Perubahan dari perangkat dengan versi lama ditolak');
select throws_ok($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', '   ')$$, 'PT400', 'empty_draft',
  'Draf kosong ditolak');
select throws_ok($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', 'x', 'moon')$$, 'PT400',
  'invalid_sentiment', 'Sentimen divalidasi');
select throws_ok($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', 'x', null, '{1X}')$$, 'PT400',
  'invalid_stocks', 'Kode saham divalidasi');
select throws_ok($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', 'x', null, '{}',
  '[{"path": "posts/orang-lain/a.jpg"}]')$$, 'PT400', 'invalid_attachments', 'Lampiran harus di folder milik pengguna');
select throws_ok(format($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', %L)$$, repeat('a', 2001)),
  'PT400', 'body_too_long', 'Panjang draf mengikuti batas postingan');
select throws_ok($$select public.save_post_draft('d6900000-0000-4000-8000-000000000002', 'x', p_poll => '[1, 2]')$$,
  'PT400', 'invalid_poll', 'Polling draf harus objek');
reset role;

insert into public.post_drafts (user_id, client_draft_id, body)
select :'budi', gen_random_uuid(), 'Draf ' || g from generate_series(1, 19) g;
select tests.authenticate_as(:'budi');
select throws_ok($$select public.save_post_draft(gen_random_uuid(), 'Draf ke-21')$$, 'PT409', 'draft_limit',
  'Maksimal 20 draf per pengguna');
reset role;
select tests.authenticate_as(:'sari');
select is((select count(*)::integer from public.post_drafts), 0, 'Draf orang lain tidak terlihat');
reset role;

select tests.authenticate_as(:'budi');
select is(public.delete_post_draft((select client_draft_id from public.post_drafts where body = 'Draf 1')), true, 'Draf bisa dihapus');
select is(public.delete_post_draft('d6900000-0000-4000-8000-0000000000ff'), false, 'Menghapus draf yang tidak ada tidak error');
select id as post_from_draft from public.create_post(p_body => 'Analisa $BBCA revisi',
  p_client_id => 'd6900000-0000-4000-8000-000000000001') \gset
select ok(not exists (select 1 from public.post_drafts where client_draft_id = 'd6900000-0000-4000-8000-000000000001'),
  'Draf terhapus otomatis saat diterbitkan dengan client_id yang sama');
reset role;

insert into public.follows (follower_id, following_id) values (:'sari', :'budi'), (:'budi', :'sari');
select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'sari') as dm \gset
select id as m1 from send_message(:'dm', '', null, null,
  '[{"type": "stock", "code": " bbca"}, {"type": "stock", "code": "BBCA"}, {"type": "stock", "code": "TLKM", "price": 9000}]') \gset
select is((select attachments from get_messages(:'dm') where id = :'m1'),
  '[{"type": "stock", "code": "BBCA"}, {"type": "stock", "code": "TLKM"}]'::jsonb,
  'Kartu saham dinormalkan (huruf besar, tanpa duplikat, tanpa data harga) dan tampil di baris pesan');
select is((select last_message_preview from public.chat_rooms where id = :'dm'), '[lampiran]', 'Pratinjau room untuk kartu saham');
select throws_ok(format($$select send_message(%L, 'Empat kartu', null, null,
  '[{"type": "stock", "code": "BBCA"}, {"type": "stock", "code": "TLKM"}, {"type": "stock", "code": "ASII"}, {"type": "stock", "code": "BBRI"}]')$$, :'dm'),
  'PT400', 'invalid_attachments', 'Maksimal tiga kartu saham per pesan');
select throws_ok(format($$select send_message(%L, 'Kode salah', null, null, '[{"type": "stock", "code": "1X"}]')$$, :'dm'),
  'PT400', 'invalid_attachments', 'Kode saham kartu divalidasi');
select id as m2 from send_message(:'dm', 'Lihat ini', null, null,
  jsonb_build_array(jsonb_build_object('type', 'stock', 'code', 'ASII'),
                    jsonb_build_object('type', 'post', 'post_id', :'post_from_draft', 'extra', 1))) \gset
select is((select attachments from get_messages(:'dm') where id = :'m2'),
  jsonb_build_array(jsonb_build_object('type', 'post', 'post_id', :'post_from_draft'), jsonb_build_object('type', 'stock', 'code', 'ASII')),
  'Kartu saham bisa digabung dengan bagikan postingan');
select ok((select shared_post ->> 'available' from get_messages(:'dm') where id = :'m2')::boolean,
  'Pratinjau bagikan postingan tetap berjalan');
select join_stock_room('BBCA') as stock_room \gset
select lives_ok(format($$select send_message(%L, 'Pantau', null, null, '[{"type": "stock", "code": "BBRI"}]')$$, :'stock_room'),
  'Kartu saham bisa dikirim di room saham');
reset role;
insert into public.chat_rooms (type, customer_id) values ('support', :'sari') returning id as support_room \gset
select throws_ok(format($$select private.validate_stock_cards('[{"type": "stock", "code": "BBCA"}]', %L)$$, :'support_room'),
  'PT400', 'share_not_allowed', 'Kartu saham tidak bisa dikirim ke chat CS');

select tests.authenticate_as(:'budi');
select public.save_post_draft('d6900000-0000-4000-8000-000000000003', 'Draf untuk ekspor') as d3 \gset
select id as follow_note from public.notifications where user_id = :'budi' and type = 'follow' limit 1 \gset
select public.report_notification_event('opened', :'follow_note') as ev \gset
select public.export_my_data() as export \gset
select ok((select bool_or(d ->> 'body' = 'Draf untuk ekspor') from jsonb_array_elements(:'export'::jsonb -> 'post_drafts') d)
          and (:'export'::jsonb -> 'notification_events' -> 0 ->> 'source_type') = 'notification',
  'Ekspor data memuat draf dan event notifikasi');
reset role;

update public.profiles set deleted_at = now() where id = :'budi';
select ok(not exists (select 1 from public.post_drafts where user_id = :'budi')
          and not exists (select 1 from private.notification_events where user_id = :'budi')
          and exists (select 1 from private.notification_events where source_id = :'follow_note'::uuid and user_id is null),
  'Hapus akun menghapus draf dan menganonimkan event notifikasi');

select * from finish();
rollback;
