begin;
select plan(6);

select tests.create_agent('Sari Batas', '{cs_super_admin}', '{}') as sari \gset

select is((select column_default from information_schema.columns
            where table_schema = 'private' and table_name = 'integration_keys' and column_name = 'rate_limit_per_minute'),
  '3000', 'Default kolom batas per menit 3000');

select tests.authenticate_agent(:'sari');
select cs_api.integration_key_create('OLT notifEngine batas', '{notify}') as created \gset
select is((:'created'::jsonb ->> 'rate_limit_per_minute')::integer, 3000,
  'Key baru tanpa batas eksplisit mendapat 3000 per menit');

select cs_api.integration_key_create('OLT batas kecil', '{notify}', null, '{}', 600) as small \gset
select is((:'small'::jsonb ->> 'rate_limit_per_minute')::integer, 600, 'Batas eksplisit tetap dipakai');

select cs_api.integration_key_update((:'small'::jsonb ->> 'id')::uuid, 'OLT batas kecil', '{notify}') as updated \gset
select is((:'updated'::jsonb ->> 'rate_limit_per_minute')::integer, 3000,
  'Ubah key tanpa batas eksplisit memakai default baru');

select throws_ok($$select cs_api.integration_key_create('OLT batas lebih', '{notify}', null, '{}', 100001)$$,
  'PT400', 'invalid_rate_limit', 'Batas di atas 100000 tetap ditolak');
select throws_ok($$select cs_api.integration_key_create('OLT batas nol', '{notify}', null, '{}', 0)$$,
  'PT400', 'invalid_rate_limit', 'Batas 0 tetap ditolak');
reset role;

select * from finish();
rollback;
