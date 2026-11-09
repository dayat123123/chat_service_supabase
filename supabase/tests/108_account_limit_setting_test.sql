begin;
select plan(9);

select tests.create_user('al_budi') as budi \gset
select tests.create_agent('Sinta Batas', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Batas', '{cs_agent}', '{"general": 1}') as rina \gset

select is(cs.setting('accounts.max_per_customer'), '200'::jsonb, 'Batas rekening bawaan 200');
select ok(cs.admin_editable('accounts.max_per_customer'), 'Batas rekening bisa diubah dari Hub');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_set_setting('accounts.max_per_customer', '100')$$, 'PT403', null,
  'Agen biasa tidak bisa mengubah batas rekening');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_set_setting('accounts.max_per_customer', '201')$$, 'PT400', 'invalid_setting',
  'Batas di atas 200 ditolak');
select throws_ok($$select cs_api.admin_set_setting('accounts.max_per_customer', '0')$$, 'PT400', 'invalid_setting',
  'Batas 0 ditolak');
select throws_ok($$select cs_api.admin_set_setting('accounts.max_per_customer', '"50"')$$, 'PT400', 'invalid_setting',
  'Batas harus angka');
select is(cs_api.admin_set_setting('accounts.max_per_customer', '3') -> 'value', '3'::jsonb,
  'Super Admin mengubah batas rekening');
reset role;

select ok(exists (select 1 from cs.cs_audit_log a where a.action = 'setting.update' and a.actor_id = :'sinta'
                    and a.details ->> 'key' = 'accounts.max_per_customer'),
  'Perubahan batas rekening tercatat di jejak audit');

select tests.authenticate_service();
select is(public.set_olt_account_links(:'budi', '["A1", "A2", "A3", "A4", "A5"]'),
  '{"linked": 3, "ignored": 2}'::jsonb, 'Fungsi tautan rekening mengikuti pengaturan batas');
reset role;

select * from finish();
rollback;
