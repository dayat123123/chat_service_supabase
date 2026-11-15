begin;
select plan(30);

update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
update cs.cs_settings set value = 'false' where key = 'trade_share.pilot_only';
update cs.cs_settings set value = '20' where key = 'trade_share.max_subscriptions';
delete from private.trade_sharers;

select tests.create_user('tsub_budi') as budi \gset
select tests.create_user('tsub_rudi') as rudi \gset
select tests.create_user('tsub_sari') as sari \gset
select tests.create_user('tsub_dodi') as dodi \gset
select tests.create_user('tsub_eko') as eko \gset
select tests.create_user('tsub_fani') as fani \gset

insert into private.account_links (cust_id, profile_id) values
  ('TB1', :'budi'), ('TR1', :'rudi'), ('SS1', :'sari'), ('EE1', :'eko'), ('FF1', :'fani');
insert into private.trade_sharers (profile_id, status, delay_minutes, subscribe_mode) values
  (:'budi', 'active', 15, 'auto'), (:'rudi', 'active', 15, 'auto');
insert into private.trade_sharer_accounts (profile_id, cust_id) values (:'budi', 'TB1'), (:'rudi', 'TR1');
insert into public.follows (follower_id, following_id) values
  (:'sari', :'budi'), (:'sari', :'rudi'), (:'dodi', :'budi'), (:'fani', :'budi');

insert into public.legal_documents (kind, version, title, body, effective_at)
values ('trade_share_risk', 1, 'Pernyataan risiko', 'Informasi trade bukan rekomendasi investasi untuk pengujian.',
        now() - interval '1 hour')
returning id as risk \gset

select tests.create_agent('Kirana', '{compliance}') as kirana \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.authenticate_agent(:'superadmin');
select cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.review}') as perm \gset

select tests.authenticate_as(:'sari');
select public.get_trade_share_profile(:'budi') as pv \gset
select ok((:'pv'::jsonb ->> 'sharing')::boolean, 'Profil trader aktif ditandai membagikan trade');
select ok((:'pv'::jsonb ->> 'can_subscribe')::boolean, 'Nasabah yang mengikuti trader boleh berlangganan');
select is(:'pv'::jsonb #>> '{risk_document,id}', :'risk', 'Pernyataan risiko terbaru ikut dikirim');

select tests.authenticate_as(:'dodi');
select is(public.get_trade_share_profile(:'budi') ->> 'blocked_reason', 'no_linked_account',
  'Calon pelanggan tanpa rekening tertaut tidak bisa berlangganan');
select tests.authenticate_as(:'eko');
select is(public.get_trade_share_profile(:'budi') ->> 'blocked_reason', 'not_following',
  'Calon pelanggan harus mengikuti trader dulu');
select throws_ok(format('select public.request_trade_subscription(%L, %L)', :'budi', :'risk'),
  'PT403', 'cannot_subscribe', 'Permintaan tanpa mengikuti trader ditolak');

select tests.authenticate_as(:'sari');
select throws_ok(format('select public.request_trade_subscription(%L, %L)', :'budi', gen_random_uuid()),
  'PT409', 'risk_outdated', 'Pernyataan risiko yang bukan versi terbaru ditolak');
select is(public.request_trade_subscription(:'budi', :'risk') #>> '{subscription,status}', 'active',
  'Mode otomatis: langganan langsung aktif');
select throws_ok(format('select public.request_trade_subscription(%L, %L)', :'budi', :'risk'),
  'PT409', 'already_subscribed', 'Langganan ganda ditolak');
select is(public.mute_trade_subscription(:'budi', true) #>> '{subscription,muted}', 'true', 'Pelanggan membisukan trader');
select is(jsonb_array_length(public.my_trade_subscriptions()), 1, 'Daftar langganan pelanggan berisi trader');

reset role;
select ok(exists (select 1 from public.user_consents where user_id = :'sari' and document_id = :'risk'),
  'Persetujuan pernyataan risiko tercatat');
select is(private.trade_share_subscriber_counts(:'budi') ->> 'active', '1', 'Jumlah pelanggan aktif dihitung');

delete from public.follows where follower_id = :'sari' and following_id = :'budi';
select is((select end_reason from private.trade_subscriptions where subscriber_id = :'sari' and trader_id = :'budi'),
  'unfollowed', 'Berhenti mengikuti trader mengakhiri langganan');
insert into public.follows (follower_id, following_id) values (:'sari', :'budi');

select tests.authenticate_as(:'sari');
select is(public.request_trade_subscription(:'budi', :'risk') #>> '{subscription,status}', 'active',
  'Langganan bisa dibuat ulang setelah berakhir');
select is(public.request_trade_subscription(:'rudi', :'risk') #>> '{subscription,status}', 'active',
  'Pelanggan bisa berlangganan beberapa trader');

reset role;
update cs.cs_settings set value = '2' where key = 'trade_share.max_subscriptions';
insert into private.trade_sharers (profile_id, status, delay_minutes, subscribe_mode) values (:'fani', 'active', 15, 'auto');
insert into private.trade_sharer_accounts (profile_id, cust_id) values (:'fani', 'FF1');
insert into public.follows (follower_id, following_id) values (:'sari', :'fani');
select tests.authenticate_as(:'sari');
select throws_ok(format('select public.request_trade_subscription(%L, %L)', :'fani', :'risk'),
  'PT409', 'subscription_limit', 'Batas jumlah trader yang dilanggan berlaku');

reset role;
update private.trade_sharers set subscribe_mode = 'approval' where profile_id = :'budi';
select tests.authenticate_as(:'fani');
select is(public.request_trade_subscription(:'budi', :'risk') #>> '{subscription,status}', 'pending',
  'Mode persetujuan: permintaan menunggu trader');
select tests.authenticate_as(:'budi');
select is(jsonb_array_length(public.my_trade_subscribers('pending')), 1, 'Trader melihat permintaan yang menunggu');
select is(public.decide_trade_subscription(:'fani', true) ->> 'status', 'active', 'Trader menyetujui pelanggan');
select is(public.remove_trade_subscriber(:'fani') ->> 'status', 'ended', 'Trader mengeluarkan pelanggan');
select tests.authenticate_as(:'sari');
select throws_ok(format('select public.my_trade_subscribers(%L)', 'active'), 'PT403', 'not_trader',
  'Bukan trader tidak bisa melihat daftar pelanggan');

select tests.authenticate_as(:'fani');
select is(public.request_trade_subscription(:'budi', :'risk') #>> '{subscription,status}', 'pending',
  'Permintaan baru setelah dikeluarkan kembali menunggu');
reset role;
update private.trade_subscriptions set expires_at = now() - interval '1 minute'
 where subscriber_id = :'fani' and trader_id = :'budi';
select ok(private.trade_share_expire_requests() >= 1, 'Permintaan yang lewat batas waktu kedaluwarsa');
select is((select status from private.trade_subscriptions where subscriber_id = :'fani' and trader_id = :'budi'),
  'expired', 'Status permintaan menjadi expired');

insert into public.blocks (blocker_id, blocked_id) values (:'budi', :'sari');
select is((select end_reason from private.trade_subscriptions where subscriber_id = :'sari' and trader_id = :'budi'),
  'blocked', 'Blokir mengakhiri langganan');

update private.trade_sharers set status = 'revoked', cooldown_until = now() + interval '30 days' where profile_id = :'rudi';
select is((select end_reason from private.trade_subscriptions where subscriber_id = :'sari' and trader_id = :'rudi'),
  'trader_stopped', 'Trader dicabut mengakhiri semua langganannya');

select tests.authenticate_agent(:'kirana');
select is(jsonb_array_length(cs_api.trade_share_subscribers(:'budi', null)), 2,
  'Kepatuhan melihat riwayat pelanggan trader');

reset role;
update cs.cs_settings set value = 'false' where key = 'trade_share.enabled';
select tests.authenticate_as(:'fani');
select is(public.get_trade_share_profile(:'budi') ->> 'enabled', 'false', 'Tombol darurat menyembunyikan fitur di profil');

reset role;
update public.profiles set deleted_at = now() where id = :'sari';
select ok(not exists (select 1 from private.trade_subscriptions where subscriber_id = :'sari'),
  'Hapus akun menghapus langganan');

select * from finish();
rollback;
