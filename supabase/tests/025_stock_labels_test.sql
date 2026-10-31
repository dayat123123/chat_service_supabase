begin;
select plan(10);

select hasnt_table('public', 'stocks', 'Server tidak menyimpan daftar saham');
select hasnt_function('public', 'search_stocks', 'Pencarian saham ditangani app klien');
select hasnt_function('public', 'sync_stocks', 'Tidak ada sinkron daftar saham dari sistem klien');

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset

select tests.authenticate_as(:'alice');
insert into stock_watchers (user_id, stock_code) values (auth.uid(), 'NEWCO');
select tests.authenticate_as(:'bob');
insert into stock_watchers (user_id, stock_code) values (auth.uid(), 'NEWCO');
delete from stock_watchers where user_id = auth.uid() and stock_code = 'NEWCO';

select results_eq(
  $$select code, watcher_count, watching from get_stock('newco')$$,
  $$values ('NEWCO'::text, 1, false)$$,
  'get_stock menghitung pemantau semua user dan menormalkan kode');

select tests.authenticate_as(:'alice');
select results_eq(
  $$select watcher_count, watching from get_stock('NEWCO')$$,
  $$values (1, true)$$,
  'get_stock menandai kode yang dipantau pemanggil');
select is_empty($$select * from get_stock('12AB')$$, 'Kode berformat salah tidak menghasilkan baris');
select results_eq(
  $$select watcher_count, watching from get_stock('NOBODY')$$,
  $$values (0, false)$$,
  'Kode yang belum dipantau siapa pun tetap valid dengan nol pemantau');

select throws_ok(
  $$insert into stock_watchers (user_id, stock_code) values (auth.uid(), 'bad code')$$,
  '23514', null, 'Kode pantauan wajib berformat kode saham');
select throws_ok(
  $$insert into muted_stocks (user_id, stock_code) values (auth.uid(), 'x')$$,
  '23514', null, 'Kode bisuan wajib berformat kode saham');

reset role;
select ok(
  has_function_privilege('authenticated', 'public.get_stock(text)', 'EXECUTE')
    and not has_function_privilege('anon', 'public.get_stock(text)', 'EXECUTE'),
  'get_stock hanya untuk user yang login');

select * from finish();
rollback;
