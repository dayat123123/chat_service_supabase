begin;
select plan(3);

select is(private.analytics_props('{"filter": "polls", "scope": "global"}'),
  '{"filter": "polls", "scope": "global"}'::jsonb, 'Kunci filter feed disimpan di analitik');
select is(private.analytics_props('{"filter": "Bad Key"}'), '{}'::jsonb, 'Kunci filter yang tidak valid dibuang');
select is(private.analytics_props('{"stock_code": "sri-kehati"}'), '{"stock_code": "SRI-KEHATI"}'::jsonb,
  'Kode indeks berstrip diterima di analitik');

select * from finish();
rollback;
