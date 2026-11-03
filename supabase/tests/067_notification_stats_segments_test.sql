begin;
select plan(30);

update private.rate_limits set max_count = 1000 where action in ('follow', 'notification_event', 'analytics');
select cs.set_setting('community.four_eyes', 'true', null) as four_eyes_on \gset

select tests.create_user('s67_budi') as budi \gset
select tests.create_user('s67_sari') as sari \gset
select tests.create_user('s67_joko') as joko \gset
select tests.create_user('s67_dewi') as dewi \gset
select tests.create_user('s67_resmi') as official \gset
update public.profiles set olt_user_id = 'official:' || id where id = :'official';
insert into cs.official_accounts (profile_id) values (:'official');
update public.profiles set olt_user_id = 's67-2002' where id = :'sari';
select tests.create_agent('Maya Kampanye', '{community}', '{}') as maya \gset
select tests.create_agent('Kirana Kampanye', '{community}', '{}') as kirana \gset
select tests.create_agent('Sinta Kampanye', '{cs_super_admin}', '{}') as sinta \gset
update cs.agents set community_permissions = '{community.post}' where user_id = :'maya';
update cs.agents set community_permissions = '{community.publish}' where user_id = :'kirana';
insert into public.follows (follower_id, following_id) values (:'sari', :'official'), (:'dewi', :'official');
update public.profiles set created_at = now() - interval '60 days' where id in (:'budi', :'joko');
insert into private.user_private (user_id, last_login_at)
values (:'joko', now() - interval '30 days'), (:'budi', now() - interval '2 days')
on conflict (user_id) do update set last_login_at = excluded.last_login_at;

select ok(cs.community_audience_match(:'joko', 'inactive', null, 14, null, null)
          and not cs.community_audience_match(:'budi', 'inactive', null, 14, null, null)
          and not cs.community_audience_match(:'sari', 'inactive', null, 14, null, null),
  'Pengguna tidak aktif = tanpa login, perangkat, atau event selama N hari');
select ok(cs.community_audience_match(:'sari', 'new_users', null, 7, null, null)
          and not cs.community_audience_match(:'budi', 'new_users', null, 7, null, null),
  'Pengguna baru = bergabung kurang dari N hari');
select tests.authenticate_as(:'dewi');
select public.register_push_device('s67-token-dewi-000000000000001', 'ios') as dev_dewi \gset
select public.track_events('[{"event": "feed_open"}]', 'macos', '2.4.0') as tracked \gset
reset role;
select ok(cs.community_audience_match(:'dewi', 'platform', null, null, 'ios', null)
          and cs.community_audience_match(:'dewi', 'platform', null, null, 'macos', null)
          and not cs.community_audience_match(:'sari', 'platform', null, null, 'ios', null),
  'Platform = perangkat push terdaftar atau platform terakhir dari analitik');

select tests.authenticate_agent(:'maya');
select is(cs_api.community_audience_size('followers', null, null, null, :'official'), 2,
  'Jumlah penerima pengikut akun resmi dihitung sebelum dikirim');
select ok(cs_api.community_audience_size('platform', null, null, 'macos') >= 1, 'Jumlah penerima per platform dihitung');
select throws_ok($$select cs_api.community_audience_size('vip')$$, 'PT400', 'invalid_audience', 'Segmen tidak dikenal ditolak');
select throws_ok($$select cs_api.community_audience_size('new_users')$$, 'PT400', 'invalid_audience',
  'Segmen pengguna baru butuh jumlah hari');
select throws_ok($$select cs_api.community_audience_size('platform', null, null, 'symbian')$$, 'PT400', 'invalid_audience',
  'Platform tidak dikenal ditolak');
select throws_ok(format($$select cs_api.community_audience_size('followers', null, null, null, %L)$$, :'budi'), 'PT400',
  'invalid_audience', 'Segmen pengikut harus akun resmi');

select cs_api.community_save_campaign(null, :'official', 'Info pengikut', 'Webinar khusus pengikut', null,
  'https://olt.example/webinar', 'followers', null, null, null, null, null, :'official') as camp \gset
select is((:'camp'::jsonb ->> 'audience') || '/' || (:'camp'::jsonb -> 'audience_account' ->> 'id') || '/'
          || (:'camp'::jsonb ->> 'opened') || '/' || coalesce(:'camp'::jsonb ->> 'open_rate', 'null'),
  'followers/' || :'official' || '/0/null', 'Kampanye pengikut tersimpan dengan statistik awal');
select is(cs_api.community_save_campaign((:'camp'::jsonb ->> 'id')::uuid, :'official', 'Info pengguna baru', 'Selamat datang',
  null, null, 'new_users', null, null, null, 14) ->> 'audience_days', '14', 'Kampanye bisa diubah ke segmen pengguna baru');
select is(cs_api.community_save_campaign((:'camp'::jsonb ->> 'id')::uuid, :'official', 'Info pengikut', 'Webinar khusus pengikut',
  null, 'https://olt.example/webinar', 'followers', null, null, null, null, null, :'official') ->> 'audience_days', null,
  'Parameter segmen lain dibersihkan');
select cs_api.community_submit_campaign((:'camp'::jsonb ->> 'id')::uuid) ->> 'status' as camp_pending \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.community_review_campaign((:'camp'::jsonb ->> 'id')::uuid, true) ->> 'status', 'sent',
  'Kampanye pengikut tetap lewat empat mata lalu dikirim');
reset role;
select (:'camp'::jsonb ->> 'id') as camp_id \gset
select is((select string_agg(p.username::text, ',' order by p.username) from public.notifications n
           join public.profiles p on p.id = n.user_id where n.payload ->> 'campaign_id' = :'camp_id'), 's67_dewi,s67_sari',
  'Kampanye pengikut hanya ke pengikut akun resmi');
select is((select data ->> 'campaign_id' from private.push_queue where user_id = :'dewi' and ref = 'campaign:' || :'camp_id'),
  :'camp_id', 'Push kampanye membawa campaign_id');
select id as sari_note from public.notifications where user_id = :'sari' and payload ->> 'campaign_id' = :'camp_id' \gset

select tests.authenticate_as(:'sari');
select is(public.report_notification_event('opened', :'sari_note'),
  jsonb_build_object('recorded', true, 'source', 'campaign', 'source_id', :'camp_id', 'read', true),
  'Membuka notifikasi tercatat untuk kampanye dan menandai dibaca');
select is(public.report_notification_event('opened', :'sari_note') ->> 'recorded', 'false', 'Event yang sama tidak dihitung dua kali');
select throws_ok($$select public.report_notification_event('viewed', gen_random_uuid())$$, 'PT400', 'invalid_event',
  'Event hanya opened atau tapped');
select throws_ok($$select public.report_notification_event('opened')$$, 'PT400', 'missing_source', 'Sumber event wajib');
reset role;
select ok((select read_at is not null from public.notifications where id = :'sari_note'), 'Notifikasi kampanye ditandai dibaca');
select tests.authenticate_as(:'dewi');
select is(public.report_notification_event('tapped', null, :'camp_id') ->> 'source', 'campaign',
  'Ketukan dari push tercatat lewat campaign_id');
select is(public.report_notification_event('opened', :'sari_note') ->> 'source', null,
  'Notifikasi milik orang lain tidak dihitung');
reset role;
select tests.authenticate_agent(:'maya');
select is((select jsonb_build_object('opened', c -> 'opened', 'tapped', c -> 'tapped', 'open_rate', c -> 'open_rate',
                                     'tap_rate', c -> 'tap_rate')
           from jsonb_array_elements(cs_api.community_campaigns()) c where c ->> 'id' = :'camp_id'),
  '{"opened": 2, "tapped": 1, "open_rate": 100.0, "tap_rate": 50.0}'::jsonb,
  'Daftar kampanye memuat jumlah dan rasio dibuka/diketuk (ketukan juga dihitung dibuka)');
select is(cs_api.community_campaign_push(:'camp_id') ->> 'tapped', '1', 'Statistik push kampanye memuat ketukan');
reset role;

insert into public.follows (follower_id, following_id) values (:'budi', :'sari');
select id as follow_note from public.notifications where user_id = :'sari' and type = 'follow' and actor_id = :'budi' \gset
select tests.authenticate_as(:'sari');
select is(public.report_notification_event('opened', :'follow_note') ->> 'source', 'notification',
  'Notifikasi biasa tercatat dengan sumber notification');
select public.register_push_device('s67-token-sari-000000000000001', 'android') as dev_sari \gset
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('OLT siaran S67', '{notify,notify_broadcast}') ->> 'id' as key_id \gset
reset role;
select tests.authenticate_service();
select public.integration_notify(:'key_id',
  '[{"id": "s67-b1", "target": {"olt_user_ids": ["s67-2002"]}, "kind": "olt.news", "channels": ["push", "inbox"],
     "title": "Info pasar", "body": "Bursa tutup lebih awal", "data": {"news_id": "N-1"}}]', null)
  -> 'results' -> 0 ->> 'broadcast_id' as bid \gset
reset role;
select is(private.integration_broadcast_batch(:'bid', 10), 1, 'Siaran diproses');
select is((select payload ->> 'broadcast_id' from public.notifications where user_id = :'sari' and payload ->> 'message_id' = 's67-b1'),
  :'bid', 'Kotak masuk siaran membawa broadcast_id');
select is((select (data ->> 'broadcast_id') || '/' || (data ->> 'news_id') from private.push_queue
           where user_id = :'sari' and data ->> 'message_id' = 's67-b1'),
  :'bid' || '/N-1', 'Push siaran membawa broadcast_id tanpa mengubah data lain');
select id as b_note from public.notifications where user_id = :'sari' and payload ->> 'message_id' = 's67-b1' \gset
select tests.authenticate_as(:'sari');
select is(public.report_notification_event('tapped', :'b_note') ->> 'source', 'broadcast', 'Ketukan siaran tercatat');
reset role;
select tests.authenticate_agent(:'sinta');
select is((select jsonb_build_object('opened', b -> 'opened', 'tapped', b -> 'tapped', 'open_rate', b -> 'open_rate')
           from jsonb_array_elements(cs_api.integration_broadcasts()) b where b ->> 'id' = :'bid'),
  '{"opened": 1, "tapped": 1, "open_rate": 100.0}'::jsonb, 'Daftar siaran memuat statistik dibuka/diketuk');
reset role;

select * from finish();
rollback;
