begin;
select plan(3);

delete from private.trade_share_excluded_accounts;
delete from private.trade_share_excluded_stocks;
delete from private.trade_share_pilot_invites;
select tests.create_user('tcn_budi') as budi \gset
select tests.create_agent('Kirana Daftar', '{compliance}') as kirana \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset
select tests.authenticate_agent(:'superadmin');
select cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.manage}') as perm \gset

select tests.authenticate_agent(:'kirana');
select is(cs_api.trade_share_exclude_account('ACC9', 'Rekening karyawan') -> 0 ->> 'created_by_name', 'Kirana Daftar',
  'Daftar rekening dikecualikan menampilkan nama staf pembuat');
select is(cs_api.trade_share_exclude_stock('GORE', 'Papan pemantauan') -> 0 ->> 'created_by_name', 'Kirana Daftar',
  'Daftar saham dikecualikan menampilkan nama staf pembuat');
select is(cs_api.trade_share_set_pilot_invite(:'budi', true) -> 0 ->> 'created_by_name', 'Kirana Daftar',
  'Daftar undangan pilot menampilkan nama staf pembuat');

select * from finish();
rollback;
