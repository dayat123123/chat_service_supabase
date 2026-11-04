begin;
select plan(6);

create function pg_temp.trending_locks() returns integer language sql as $$
  select count(*)::integer from pg_locks
  where locktype = 'advisory' and pid = pg_backend_pid() and granted
    and objid = (hashtext('private.trending')::bigint & 4294967295)::oid;
$$;

select is(pg_temp.trending_locks(), 0, 'Belum ada kunci trending sebelum job berjalan');

select lives_ok('select private.trending_tick()', 'Tick trending berjalan');
select is(pg_temp.trending_locks(), 1, 'Tick memegang kunci trending sampai transaksinya selesai');

select lives_ok('select private.trending_rebuild()', 'Rebuild sesudah tick di transaksi yang sama tidak bentrok kunci');
select ok((select jsonb_typeof(private.trending_rebuild() -> 'purged') = 'number'), 'Rebuild tetap mengembalikan jumlah agregat yang dibersihkan');

select ok(exists (select 1 from cron.job where jobname = 'social-trending' and schedule = '*/5 * * * *')
          and exists (select 1 from cron.job where jobname = 'social-trending-rebuild' and schedule = '40 2 * * *'),
  'Jadwal job trending tidak berubah');

select * from finish();
rollback;
