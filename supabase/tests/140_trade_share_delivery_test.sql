begin;
select plan(32);

update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
update cs.cs_settings set value = 'false' where key = 'trade_share.pilot_only';
update cs.cs_settings set value = '["RG"]' where key = 'trade_share.boards';
update cs.cs_settings set value = 'false' where key = 'trade_share.force_hide_price';
update cs.cs_settings set value = 'false' where key = 'trade_share.force_hide_lot';
update cs.cs_settings set value = '50' where key = 'trade_share.daily_push_cap';
update cs.cs_settings set value = '"23:59"' where key = 'trade_share.eod_flush_time';
delete from private.trade_sharers;
delete from private.trade_orders;
delete from private.trade_activities;

select tests.create_user('tdl_budi') as budi \gset
select tests.create_user('tdl_sari') as sari \gset
select tests.create_user('tdl_dodi') as dodi \gset
select tests.create_user('tdl_eko') as eko \gset
insert into private.account_links (cust_id, profile_id) values
  ('DB1', :'budi'), ('DS1', :'sari'), ('DD1', :'dodi'), ('DE1', :'eko');
insert into private.trade_sharers (profile_id, status, delay_minutes, show_price, show_lot) values
  (:'budi', 'active', 15, true, true);
insert into private.trade_sharer_accounts (profile_id, cust_id) values (:'budi', 'DB1');
insert into private.trade_subscriptions (subscriber_id, trader_id, status, decided_at, requested_at) values
  (:'sari', :'budi', 'active', now() - interval '1 day', now() - interval '1 day'),
  (:'dodi', :'budi', 'active', now() - interval '1 day', now() - interval '1 day'),
  (:'eko', :'budi', 'active', now() - interval '1 day', now() - interval '1 day');
update private.trade_subscriptions set muted = true where subscriber_id = :'eko';
insert into private.push_devices (user_id, token, platform, locale) values
  (:'sari', 'token-sari-0123456789abcdef', 'android', 'id'),
  (:'dodi', 'token-dodi-0123456789abcdef', 'ios', 'en'),
  (:'eko', 'token-eko-01234567890abcdef', 'android', 'id');

create function pg_temp.h(p text) returns text language sql as $$ select encode(sha256(convert_to(p, 'UTF8')), 'hex') $$;
create function pg_temp.ord(p_order text, p_status text, p_price integer, p_shares bigint, p_remain bigint,
                            p_traded bigint, p_day date default (now() at time zone 'Asia/Jakarta')::date)
returns jsonb language sql as $$
  select jsonb_build_object('kind', 'order', 'cust_id', 'DB1', 'order_ref', pg_temp.h(p_order),
                            'seq', pg_temp.h(p_order || p_status || p_price || p_remain || p_traded),
                            'status', p_status, 'stock', 'BBCA', 'side', 'buy', 'board', 'RG',
                            'order_date', p_day, 'order_shares', p_shares, 'remain_shares', p_remain,
                            'traded_shares', p_traded, 'order_price', p_price)
$$;
create function pg_temp.fill(p_order text, p_trade text, p_price integer, p_shares bigint)
returns jsonb language sql as $$
  select jsonb_build_object('kind', 'fill', 'cust_id', 'DB1', 'order_ref', pg_temp.h(p_order),
                            'key', pg_temp.h(p_trade), 'stock', 'BBCA', 'side', 'buy', 'board', 'RG',
                            'traded_at', now(), 'shares', p_shares, 'price', p_price)
$$;
create function pg_temp.send(variadic p_events jsonb[]) returns jsonb language sql as $$
  select public.trade_relay_events('test-relay', to_jsonb(p_events))
$$;
create function pg_temp.age(p_order text) returns void language sql as $$
  update private.trade_orders set last_change_at = now() - interval '16 minutes' where order_ref = pg_temp.h(p_order)
$$;
create function pg_temp.acts() returns integer language sql as $$
  select count(*)::integer from private.trade_activities where trader_id = (select profile_id from private.trade_sharers limit 1)
$$;

select pg_temp.send(pg_temp.ord('F1', 'open', 9150, 2500, 2500, 0),
                    pg_temp.fill('F1', 'T1', 9150, 1000), pg_temp.ord('F1', 'open', 9150, 2500, 1500, 1000)) as s1 \gset
select private.trade_share_flush() as f0 \gset
select is(pg_temp.acts(), 0, 'Match sebagian di tengah hari belum dilaporkan');

select pg_temp.send(pg_temp.fill('F1', 'T2', 9150, 1500), pg_temp.ord('F1', 'matched', 9150, 2500, 0, 2500)) as s2 \gset
select private.trade_share_flush() as f1 \gset
select is(pg_temp.acts(), 0, 'Order penuh menunggu jeda sebelum dilaporkan');
select pg_temp.age('F1');
select private.trade_share_flush() as f2 \gset
select is(pg_temp.acts(), 1, 'Order penuh dilaporkan setelah jeda');
select is((select shares from private.trade_activities where order_ref = pg_temp.h('F1')), 2500::bigint,
  'Volume aktivitas adalah volume match');
select ok(not (select partial from private.trade_activities where order_ref = pg_temp.h('F1')), 'Order penuh tidak berlabel sebagian');
select is((select report_state from private.trade_orders where order_ref = pg_temp.h('F1')), 'reported', 'Order ditandai sudah dilaporkan');
select is((private.trade_activity_text((select a from private.trade_activities a where a.order_ref = pg_temp.h('F1')), 'id')) ->> 'body',
  '25 lot @ 9.150', 'Teks aktivitas berisi lot dan harga order');

select pg_temp.send(pg_temp.ord('F2', 'open', 500, 1000, 1000, 0), pg_temp.fill('F2', 'T3', 500, 300),
                    pg_temp.ord('F2', 'open', 500, 1000, 700, 300), pg_temp.ord('F2', 'withdrawn', 500, 1000, 700, 300)) as s3 \gset
select pg_temp.age('F2');
select private.trade_share_flush() as f3 \gset
select ok((select partial from private.trade_activities where order_ref = pg_temp.h('F2')), 'Sebagian lalu ditarik dilaporkan sebagai sebagian');
select is((private.trade_activity_text((select a from private.trade_activities a where a.order_ref = pg_temp.h('F2')), 'id')) ->> 'body',
  '3 lot dari 10 lot @ 500 · sebagian', 'Teks sebagian menyebut lot match dari lot order');
select is((private.trade_activity_text((select a from private.trade_activities a where a.order_ref = pg_temp.h('F2')), 'en')) ->> 'title',
  'Tdl Budi bought $BBCA', 'Judul aktivitas tersedia dalam bahasa Inggris');

select pg_temp.send(pg_temp.ord('F3', 'open', 700, 500, 500, 0, ((now() at time zone 'Asia/Jakarta')::date - 1)),
                    pg_temp.fill('F3', 'T4', 700, 200),
                    pg_temp.ord('F3', 'open', 700, 500, 300, 200, ((now() at time zone 'Asia/Jakarta')::date - 1))) as s4 \gset
select pg_temp.age('F3');
select private.trade_share_flush() as f4 \gset
select is((select report_state from private.trade_orders where order_ref = pg_temp.h('F3')), 'partial_reported',
  'Order yang masih open melewati penutupan hari dilaporkan sebagian');
select pg_temp.send(pg_temp.fill('F3', 'T5', 700, 300), pg_temp.ord('F3', 'matched', 700, 500, 0, 500)) as s5 \gset
select is((select report_state from private.trade_orders where order_ref = pg_temp.h('F3')), 'pending',
  'Match tambahan setelah dilaporkan membuat order menunggu dilaporkan lagi');
select pg_temp.age('F3');
select private.trade_share_flush() as f5 \gset
select is((select shares from private.trade_activities where order_ref = pg_temp.h('F3') and additional), 300::bigint,
  'Hanya tambahan volume yang dilaporkan');

select pg_temp.send(pg_temp.ord('F4', 'open', 100, 100, 100, 0), pg_temp.ord('F4', 'rejected', 100, 100, 100, 0)) as s6 \gset
select pg_temp.age('F4');
select private.trade_share_flush() as f6 \gset
select is((select report_state from private.trade_orders where order_ref = pg_temp.h('F4')), 'cancelled',
  'Order ditolak tanpa match tidak dilaporkan');

select private.trade_share_fanout() as fan \gset
select is((select count(*)::integer from public.notifications where user_id = :'sari' and type = 'trade_activity'), 4,
  'Pelanggan menerima semua aktivitas di kotak notifikasi');
select is((select count(*)::integer from public.notifications where user_id = :'eko' and type = 'trade_activity'), 0,
  'Pelanggan yang membisukan trader tidak menerima aktivitas');
select is((select count(*)::integer from private.push_queue where user_id = :'sari' and kind = 'trade_activity'), 4,
  'Push aktivitas diantrekan ke pelanggan');
select is((select title from private.push_queue where user_id = :'dodi' and kind = 'trade_activity' order by id limit 1),
  'Tdl Budi bought $BBCA', 'Push mengikuti bahasa perangkat');
select is((select status from private.trade_fanout_jobs order by created_at limit 1), 'done', 'Job pengiriman selesai');

update cs.cs_settings set value = '1' where key = 'trade_share.daily_push_cap';
select pg_temp.send(pg_temp.ord('F5', 'open', 100, 100, 100, 0), pg_temp.fill('F5', 'T6', 100, 100),
                    pg_temp.ord('F5', 'matched', 100, 100, 0, 100)) as s7 \gset
select pg_temp.age('F5');
select private.trade_share_flush() as f7 \gset
select private.trade_share_fanout() as fan2 \gset
select is((select count(*)::integer from public.notifications where user_id = :'sari' and type = 'trade_activity'), 5,
  'Kotak notifikasi tetap terisi walau batas push harian tercapai');
select is((select count(*)::integer from private.push_queue where user_id = :'sari' and kind = 'trade_activity'), 4,
  'Push dihentikan setelah batas harian tercapai');
update cs.cs_settings set value = '50' where key = 'trade_share.daily_push_cap';

update private.trade_sharers set show_lot = false where profile_id = :'budi';
select pg_temp.send(pg_temp.ord('F6', 'open', 200, 1000, 1000, 0), pg_temp.fill('F6', 'T7', 200, 400),
                    pg_temp.ord('F6', 'withdrawn', 200, 1000, 600, 400)) as s8 \gset
select pg_temp.age('F6');
select private.trade_share_flush() as f8 \gset
select is((private.trade_activity_text((select a from private.trade_activities a where a.order_ref = pg_temp.h('F6')), 'id')) ->> 'body',
  '@ 200 · sebagian', 'Lot tersembunyi: label sebagian tampil tanpa angka');
select ok(not (private.trade_activity_payload((select a from private.trade_activities a where a.order_ref = pg_temp.h('F6'))) ? 'lots'),
  'Payload tidak membawa lot bila trader menyembunyikan lot');
update private.trade_sharers set show_lot = true where profile_id = :'budi';

select id as act_f1 from private.trade_activities where order_ref = pg_temp.h('F1') \gset
select tests.authenticate_as(:'sari');
select ok(jsonb_array_length(public.trade_activity_feed()) >= 5, 'Pelanggan melihat feed aktivitas trader');
select is(public.trade_activity_detail(:'act_f1') ->> 'stock',
  'BBCA', 'Pelanggan membuka detail aktivitas');
select tests.create_user('tdl_luar') as luar \gset
select tests.authenticate_as(:'luar');
select throws_ok(format('select public.trade_activity_detail(%L)', :'act_f1'),
  'PT404', 'activity_not_found', 'Bukan pelanggan tidak bisa membuka detail aktivitas');
reset role;

select tests.create_agent('Kirana', '{compliance}') as kirana \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.authenticate_agent(:'superadmin');
select cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.review}') as perm \gset
select tests.authenticate_agent(:'kirana');
select cs_api.trade_share_suspend(:'budi', 'Dalam pemeriksaan') ->> 'status' as susp \gset
reset role;
select ok(exists (select 1 from public.notifications where user_id = :'budi' and type = 'trade_share'
                   and payload ->> 'action' = 'suspended'), 'Trader menerima notifikasi penangguhan');
select pg_temp.send(pg_temp.ord('F7', 'open', 100, 100, 100, 0)) as s9 \gset
select is(pg_temp.send(pg_temp.fill('F7', 'T8', 100, 100)) #>> '{results,0,reason}', 'not_shared',
  'Trader yang ditangguhkan tidak menerima data baru');

update private.trade_sharers set status = 'active', suspended_until = null where profile_id = :'budi';
insert into private.trade_subscriptions (subscriber_id, trader_id, status, expires_at) values (:'luar', :'budi', 'pending', now() + interval '1 day');
select ok(exists (select 1 from public.notifications where user_id = :'budi' and type = 'trade_share'
                   and payload ->> 'action' = 'subscription_request'), 'Trader diberi tahu ada permintaan langganan');
update private.trade_subscriptions set status = 'active', decided_at = now(), expires_at = null where subscriber_id = :'luar';
select ok(exists (select 1 from public.notifications where user_id = :'luar' and type = 'trade_share'
                   and payload ->> 'action' = 'subscription_approved'), 'Pelanggan diberi tahu langganannya disetujui');

select pg_temp.send(pg_temp.ord('F8', 'open', 100, 100, 100, 0), pg_temp.fill('F8', 'T9', 100, 100),
                    pg_temp.ord('F8', 'matched', 100, 100, 0, 100)) as s10 \gset
update cs.cs_settings set value = 'false' where key = 'trade_share.enabled';
select private.trade_share_flush() as f9 \gset
select is((select report_state from private.trade_orders where order_ref = pg_temp.h('F8')), 'cancelled',
  'Tombol darurat membatalkan order yang belum dilaporkan');
select ok(private.trade_share_tick() is not null, 'Tick tetap aman saat fitur dimatikan');

select * from finish();
rollback;
