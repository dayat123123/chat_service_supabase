begin;
select plan(26);

update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
update cs.cs_settings set value = '2' where key = 'trade_share.review_subscriber_threshold';
delete from private.trade_sharers;
delete from private.trade_activities;
delete from private.trade_share_flags;
delete from private.trade_relay_status;
update private.trade_relay_config set iproxy_addr = null;

select tests.create_user('tcp_budi') as budi \gset
select tests.create_user('tcp_sari') as sari \gset
select tests.create_user('tcp_dodi') as dodi \gset
insert into private.account_links (cust_id, profile_id) values ('CB1', :'budi'), ('CS1', :'sari'), ('CD1', :'dodi');
insert into private.trade_sharers (profile_id, status, delay_minutes) values
  (:'budi', 'active', 15), (:'dodi', 'suspended', 15);
update private.trade_sharers set suspended_until = now() - interval '1 minute' where profile_id = :'dodi';
insert into private.trade_sharer_accounts (profile_id, cust_id) values (:'budi', 'CB1'), (:'dodi', 'CD1');
insert into private.trade_subscriptions (subscriber_id, trader_id, status, decided_at) values
  (:'sari', :'budi', 'active', now()), (:'dodi', :'budi', 'active', now());
insert into private.trade_subscriptions (subscriber_id, trader_id, status, expires_at, requested_at) values
  (:'sari', :'dodi', 'pending', now() - interval '1 minute', now() - interval '15 days');
insert into private.trade_activities (trader_id, order_ref, stock, side, shares, total_shares, order_shares, lot_size,
                                      price, show_lot, partial, completed_at) values
  (:'budi', repeat('a', 64), 'BBCA', 'buy', 1000, 1000, 1000, 100, 9150, true, false, now() - interval '40 minutes'),
  (:'budi', repeat('b', 64), 'BBCA', 'sell', 1000, 1000, 1000, 100, 9200, true, false, now() - interval '10 minutes'),
  (:'dodi', repeat('c', 64), 'TLKM', 'buy', 500, 500, 1000, 100, 3000, true, true, now() - interval '50 days');
update private.trade_activities set created_at = completed_at;

select ok(private.trade_share_detect_flags() >= 2, 'Deteksi penanda menemukan kasus');
select ok(exists (select 1 from private.trade_share_flags where profile_id = :'budi' and kind = 'review_threshold'),
  'Trader yang melewati ambang pelanggan masuk tinjauan');
select ok(exists (select 1 from private.trade_share_flags where profile_id = :'budi' and kind = 'quick_flip'),
  'Beli lalu jual saham yang sama dalam 60 menit ditandai');
select is(private.trade_share_detect_flags(), 0, 'Penanda yang masih terbuka tidak dibuat ganda');

select private.trade_share_maintenance() as m \gset
select ok((:'m'::jsonb ->> 'expired_requests')::integer >= 1, 'Pemeliharaan mengakhiri permintaan langganan kedaluwarsa');
select is((select status from private.trade_sharers where profile_id = :'dodi'), 'active',
  'Pemeliharaan mengakhiri penangguhan yang lewat batas');
select ok(not exists (select 1 from private.trade_activities where order_ref = repeat('c', 64)),
  'Aktivitas lebih lama dari masa simpan dihapus');

select tests.create_agent('Kirana', '{compliance}') as kirana \gset
select tests.create_agent('Laras', '{compliance}') as laras \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.authenticate_agent(:'superadmin');
select cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.review,trade_share.manage}') as p1 \gset
select cs_api.admin_set_trade_permissions(:'laras', '{trade_share.review}') as p2 \gset

select tests.authenticate_agent(:'kirana');
select ok(jsonb_array_length(cs_api.trade_share_flags('open')) >= 2, 'Kepatuhan melihat penanda terbuka');
select (cs_api.trade_share_flags('open') -> 0 ->> 'id') as flag \gset
select throws_ok(format('select cs_api.trade_share_review_flag(%s, null)', :'flag'), 'PT400', 'reason_required',
  'Meninjau penanda wajib memberi catatan');
select lives_ok(format('select cs_api.trade_share_review_flag(%s, %L)', :'flag', 'Sudah diperiksa'), 'Kepatuhan meninjau penanda');
select is(cs_api.trade_share_dashboard() #>> '{subscriptions,active}', '2', 'Dasbor menghitung pelanggan aktif');
select cs_api.trade_share_export(current_date - 1, current_date + 1) as ex \gset
select is((:'ex'::jsonb ->> 'rows')::integer, 2, 'Ekspor berisi aktivitas dalam rentang tanggal');
select ok(:'ex'::jsonb ->> 'csv' like 'waktu_wib,trader,saham,%', 'Ekspor memakai header kolom');
select throws_ok(format('select cs_api.trade_share_export(%L, %L)', current_date - 200, current_date), 'PT400',
  'invalid_range', 'Rentang ekspor dibatasi');
select tests.authenticate_agent(:'laras');
select throws_ok(format('select cs_api.trade_share_export(%L, %L)', current_date - 1, current_date), 'PT403',
  'trade_forbidden', 'Ekspor hanya untuk izin manage');
reset role;
select ok(exists (select 1 from cs.cs_audit_log where action = 'trade_share.export'), 'Ekspor tercatat di audit');
select is(private.trade_share_csv('=cmd'), '"''=cmd"', 'Nilai yang diawali tanda formula diamankan di CSV');
select is(private.trade_share_csv('a"b'), '"a""b"', 'Tanda kutip di CSV di-escape');

insert into private.trade_orders (order_ref, profile_id, cust_id, stock, side, board, status, order_shares,
                                  remain_shares, traded_shares)
values (repeat('e', 64), :'budi', 'CB1', 'BBCA', 'buy', 'RG', 'open', 100, 50, 50);
update cs.cs_settings set value = 'false' where key = 'trade_share.enabled';
select is((select report_state from private.trade_orders where order_ref = repeat('e', 64)), 'cancelled',
  'Tombol darurat langsung membatalkan order yang belum dilaporkan');
update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';

update private.trade_relay_config set iproxy_addr = 'tcp://10.0.0.5:9990';
select ok(exists (select 1 from private.health_checks_trade_relay() where key = 'trade_relay:down'),
  'Relay yang dikonfigurasi tetapi tidak melapor memicu alert');
insert into private.trade_relay_status (instance, connected, counters, reported_at)
values ('relay-1', true, '{"received": 1000, "decode_errors": 200}', now());
select ok(not exists (select 1 from private.health_checks_trade_relay() where key = 'trade_relay:down'),
  'Alert relay mati hilang setelah relay melapor');
select ok(exists (select 1 from private.health_checks_trade_relay() where key = 'trade_relay:decode_errors'),
  'Lonjakan paket rusak memicu alert');
select ok(exists (select 1 from private.health_current() where key = 'trade_relay:decode_errors'),
  'Alert relay masuk laporan Kesehatan sistem');
update private.trade_relay_config set iproxy_addr = null;
select ok(not exists (select 1 from private.health_checks_trade_relay()), 'Relay yang belum dikonfigurasi tidak memicu alert');

select tests.authenticate_as(:'budi');
select ok(public.export_my_data() ? 'trade_share', 'Ekspor data pribadi memuat data berbagi trade');
select is(public.export_my_data() #>> '{trade_share,trader,status}', 'active', 'Ekspor data pribadi memuat status trader');

select * from finish();
rollback;
