begin;
select plan(8);

select tests.create_user('il_ani') as ani \gset
select tests.authenticate_as(:'ani');

select is((select count(*)::integer from public.get_market_instruments()), 46, 'Daftar awal memuat 46 indeks IDX');
select results_eq(
  $$select code from public.get_market_instruments() limit 5$$,
  $$values ('COMPOSITE'::text), ('LQ45'), ('JII'), ('MBX'), ('DBX')$$,
  'Urutan indeks mengikuti daftar OLT');
select is((select code from public.get_market_instruments() order by "position" desc limit 1), 'IDXCMDTY20',
  'Indeks terakhir IDXCMDTY20');
select is((select aliases from public.get_market_instruments() where code = 'COMPOSITE'), array['IHSG', 'JCI'],
  'IHSG dan JCI menjadi alias COMPOSITE');
select ok(not exists (select 1 from public.get_market_instruments() where code in ('IHSG', 'PEFINDO25')),
  'IHSG bukan kode utama dan PEFINDO25 tidak ada di daftar');
reset role;

select is(private.extract_cashtags('$IHSG $I-GRADE $igrade-nya $SMinfra18 $Investor33'),
  array['COMPOSITE', 'I-GRADE', 'SMINFRA18', 'INVESTOR33'], 'Kode baru dan alias dikenali');

select is(private.stock_code('ihsg'), 'COMPOSITE', 'stock_code mengarahkan IHSG ke COMPOSITE');
select ok(not exists (select 1 from public.post_stocks where stock_code = 'IHSG'), 'Tidak ada tag IHSG tersisa');

select * from finish();
rollback;
