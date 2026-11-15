begin;
select plan(9);

delete from private.trade_sharers;
select tests.create_user('thg_budi') as budi \gset
insert into private.trade_sharers (profile_id, status, delay_minutes) values (:'budi', 'pending', 15);

select tests.create_agent('Kirana Trade', '{compliance}') as kirana \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.create_agent('Biasa', '{cs_agent}') as biasa \gset
select tests.authenticate_agent(:'superadmin');
select cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.review}') as perm \gset

select tests.authenticate_agent(:'kirana');
select is(cs_api.agent_me() -> 'trade_permissions', '["trade_share.review"]'::jsonb,
  'agent_me membawa izin Berbagi Trade');
select is(cs_api.agent_my_profile() -> 'trade_permissions', '["trade_share.review"]'::jsonb,
  'Profil staf sendiri membawa izin Berbagi Trade');
select throws_ok($$select cs_api.legal_set_required('{terms,trade_share_terms}')$$, 'PT400', 'legal_kind_not_global',
  'S&K Berbagi Trade tidak bisa dijadikan dokumen wajib untuk semua pengguna');
select is(jsonb_array_length(cs_api.trade_share_find_profiles('thg_bu')), 1, 'Staf Berbagi Trade bisa mencari profil');
select is(cs_api.trade_share_find_profiles('thg_bu') -> 0 ->> 'trader_status', 'pending',
  'Hasil pencarian menampilkan status trader');
select throws_ok($$select cs_api.trade_share_find_profiles('x')$$, 'PT400', 'invalid_query', 'Kata kunci terlalu pendek ditolak');
select is(cs_api.trade_share_decide(:'budi', 'reject', 'Belum memenuhi') ->> 'decided_by_name', 'Kirana Trade',
  'Detail menampilkan nama staf yang memutuskan');
select is(cs_api.trade_share_detail(:'budi') #>> '{events,0,actor_name}', 'Kirana Trade',
  'Riwayat menampilkan nama staf');

select tests.authenticate_agent(:'biasa');
select throws_ok($$select cs_api.trade_share_find_profiles('thg_bu')$$, 'PT403', 'trade_forbidden',
  'Staf tanpa izin tidak bisa mencari lewat Berbagi Trade');

select * from finish();
rollback;
