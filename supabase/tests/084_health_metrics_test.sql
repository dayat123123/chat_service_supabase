begin;
select plan(36);

delete from private.alert_deliveries;
delete from private.health_alerts;
delete from private.health_checks;
delete from private.health_metric_sources;
delete from private.health_metric_samples;
update private.settings set value = '0' where key in ('health.alert_after_seconds', 'health.resolve_after_seconds');
update private.settings set value = '150' where key = 'health.realtime_events_window_seconds';
delete from private.health_report_misses;

create function pg_temp.sample(p_source text, p_instance text, p_name text, p_value double precision, p_age integer)
returns void language sql as $$
  insert into private.health_metric_samples (source, instance, name, value, sampled_at)
  values (p_source, p_instance, p_name, p_value, now() - make_interval(secs => p_age));
$$;

create function pg_temp.check_of(p_key text) returns text language sql as $$
  select c.severity || ' | ' || c.title || ' | ' || c.detail from private.health_checks_metrics() c where c.key = p_key;
$$;

select tests.create_user('hm_budi') as budi \gset

select has_function('public', 'health_report', array['text', 'text', 'timestamp with time zone', 'jsonb', 'jsonb', 'jsonb'],
  'health_report menerima p_metrics');
select hasnt_function('public', 'health_report', array['text', 'text', 'timestamp with time zone', 'jsonb', 'jsonb'],
  'Versi lama tanpa p_metrics sudah diganti');

select tests.authenticate_as(:'budi');
select throws_ok($$select public.health_report('x', '0', now(), '[]', '[]', '[]')$$, '42501', null,
  'Nasabah tidak bisa mengirim laporan kesehatan');
reset role;

select tests.authenticate_service();
select throws_ok($$select public.health_report('sentinel-a', '0.2.0', now(), '[]', '[]', '{}')$$, 'PT400',
  'invalid_health_report', 'Metrik yang bukan array ditolak');
select lives_ok($$select public.health_report('sentinel-a', '0.2.0', now(), '[]', '[]')$$,
  'Sentinel lama tanpa p_metrics tetap diterima');
select lives_ok($$select public.health_report('sentinel-a', '0.2.0', now(), '[]', '[]',
  '[{"source":"rest","instance":"10.0.1.4","ok":true,"error":null,
     "values":{"pgrst_db_pool_waiting":0,"pgrst_db_pool_max":10,"pgrst_db_pool_timeouts_total":3,"Bad-Name":1,"label":"x"}},
    {"source":"pgbouncer","instance":"10.0.1.5","ok":false,"error":"koneksi ditolak","values":{"pgbouncer_cl_waiting":9}},
    {"source":"Bad Source","instance":"","ok":true,"values":{"x":1}}]')$$,
  'Sentinel melaporkan sumber metrik');
reset role;

select is((select count(*)::int from private.health_metric_samples where source = 'rest'), 3,
  'Hanya angka dengan nama valid yang disimpan');
select is((select count(*)::int from private.health_metric_samples where source <> 'rest'), 0,
  'Sumber yang gagal atau namanya tidak valid tidak menyimpan sampel');
select is((select string_agg(source || '@' || instance || '=' || ok, ',' order by source) from private.health_metric_sources),
  'pgbouncer@10.0.1.5=false,rest@10.0.1.4=true', 'Status sumber metrik tersimpan');
select is(pg_temp.check_of('metrics:pgbouncer'),
  'warning | Metrik PgBouncer tidak bisa dibaca | 10.0.1.5: koneksi ditolak', 'Sumber metrik yang gagal menjadi peringatan');
select is(pg_temp.check_of('rest:pool'), null, 'Pool PostgREST yang longgar tidak memicu alert');

update private.health_metric_sources set checked_at = now() - interval '5 minutes' where source = 'pgbouncer';
select is(pg_temp.check_of('metrics:pgbouncer'), null, 'Status sumber yang kedaluwarsa diabaikan');

delete from private.health_metric_samples;
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_timeouts_total', 3, 90);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_timeouts_total', 3, 60);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_timeouts_total', 5, 30);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_waiting', 0, 30);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_max', 10, 30);
select is(pg_temp.check_of('rest:pool'),
  'warning | Pool koneksi API (PostgREST) penuh | 0 request menunggu koneksi pool (maks. 10 koneksi), 2 timeout PGRST003 (HTTP 504) dalam 5 menit terakhir',
  'Timeout pool PostgREST yang bertambah menjadi peringatan');

select pg_temp.sample('rest', 'b', 'pgrst_db_pool_timeouts_total', 100, 60);
select pg_temp.sample('rest', 'b', 'pgrst_db_pool_timeouts_total', 18, 10);
select is(left(pg_temp.check_of('rest:pool'), 8), 'critical',
  'Timeout dijumlah lintas replika; counter yang reset dihitung dari nol');

delete from private.health_metric_samples;
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_timeouts_total', 7, 400);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_timeouts_total', 7, 30);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_waiting', 4, 200);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_available', 0, 200);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_waiting', 0, 20);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_available', 3, 20);
select is(pg_temp.check_of('rest:pool'), null, 'Timeout lama dan antrean yang sudah kosong tidak memicu alert');
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_waiting', 2, 10);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_available', 4, 10);
select is(pg_temp.check_of('rest:pool'), null, 'Request yang sedang mengambil koneksi saat pool masih tersedia tidak dihitung');
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_waiting', 6, 5);
select pg_temp.sample('rest', 'a', 'pgrst_db_pool_available', 0, 5);
select is(left(pg_temp.check_of('rest:pool'), 7), 'warning', 'Request yang menunggu saat pool kosong menjadi peringatan');

select private.health_realtime_events_limit() as max_rate \gset
select ok(:max_rate > 0, 'Batas event tenant Realtime terbaca');
delete from private.health_metric_samples;
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 1000, 60);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 1000 + 30 * 0.5 * :max_rate, 30);
select is(pg_temp.check_of('realtime:events'), null, 'Laju event 50% dari batas tidak memicu alert');
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 1000 + 30 * 0.5 * :max_rate + 30 * 1.1 * :max_rate, 0);
select is(pg_temp.check_of('realtime:events'),
  'warning | Realtime mendekati batas event tenant | ' || round(0.8 * :max_rate) || ' event/dtk dari batas ' || :max_rate
    || ' (80%), rata-rata 2 menit terakhir. Di atas batas, pesan tidak sampai lewat Realtime',
  'Laju event 80% dari batas menjadi peringatan');
select pg_temp.sample('realtime', 'b', 'realtime_channel_global_events', 0, 60);
select pg_temp.sample('realtime', 'b', 'realtime_channel_global_events', 60 * 0.3 * :max_rate, 0);
select is(split_part(pg_temp.check_of('realtime:events'), ' | ', 1) || ' | ' || split_part(pg_temp.check_of('realtime:events'), ' | ', 2),
  'critical | Realtime membuang event: batas tenant tercapai', 'Laju dijumlah lintas node; di atas batas menjadi kritis');
delete from private.health_metric_samples;
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 0, 10);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 10 * 5 * :max_rate, 0);
select is(pg_temp.check_of('realtime:events'), null, 'Jendela di bawah 20 detik belum dinilai');

delete from private.health_metric_samples;
select is(pg_temp.check_of('pgbouncer:queue'), null, 'Tanpa sampel PgBouncer tidak ada alert');
select pg_temp.sample('pgbouncer', 'a', 'pgbouncer_cl_waiting', 0, 10);
select pg_temp.sample('pgbouncer', 'a', 'pgbouncer_maxwait_seconds', 0.2, 10);
select is(pg_temp.check_of('pgbouncer:queue'), null, 'PgBouncer tanpa antrean tidak memicu alert');
select pg_temp.sample('pgbouncer', 'a', 'pgbouncer_cl_waiting', 3, 0);
select pg_temp.sample('pgbouncer', 'a', 'pgbouncer_maxwait_seconds', 0.5, 0);
select is(pg_temp.check_of('pgbouncer:queue'),
  'warning | PgBouncer mengantre koneksi | 3 klien menunggu koneksi server, tunggu terlama 0.5 dtk',
  'Klien PgBouncer yang mengantre menjadi peringatan');
select pg_temp.sample('pgbouncer', 'b', 'pgbouncer_cl_waiting', 1, 0);
select pg_temp.sample('pgbouncer', 'b', 'pgbouncer_maxwait_seconds', 6.25, 0);
select is(pg_temp.check_of('pgbouncer:queue'),
  'critical | PgBouncer mengantre koneksi | 4 klien menunggu koneksi server, tunggu terlama 6.3 dtk',
  'Tunggu PgBouncer lebih dari 5 detik menjadi kritis');

update private.settings set value = '1000000'
 where key in ('health.lock_waiters_warn', 'health.lock_waiters_critical', 'health.lock_wait_warn_seconds',
               'health.lock_wait_critical_seconds');
select is(pg_temp.check_of('db:lock_waits'), null, 'Lock wait di bawah ambang tidak memicu alert');
update private.settings set value = '0' where key = 'health.lock_waiters_warn';
select ok(pg_temp.check_of('db:lock_waits') like 'warning | Proses database menunggu lock | % proses menunggu lock, terlama % dtk',
  'Ambang lock wait dibaca dari pengaturan');
update private.settings set value = '5' where key = 'health.lock_waiters_warn';

delete from private.room_preview_queue;
select is((select count(*)::int from private.health_checks_room_preview()), 0, 'Antrean pratinjau kosong tidak memicu alert');
insert into private.room_preview_queue (room_id, queued_at) values (gen_random_uuid(), now() - interval '20 seconds');
select is((select count(*)::int from private.health_checks_room_preview()), 0, 'Antrean pratinjau yang baru masuk belum dinilai');
insert into private.room_preview_queue (room_id, queued_at) values (gen_random_uuid(), now() - interval '90 seconds');
select is((select severity || ' | ' || title || ' | ' || detail from private.health_checks_room_preview()),
  'warning | Pratinjau room tertahan | 2 room menunggu pembaruan pratinjau, terlama 1 menit (90 dtk). Job terjadwal chat-room-preview mati atau macet',
  'Antrean pratinjau lebih dari 1 menit menjadi peringatan');
insert into private.room_preview_queue (room_id, queued_at) values (gen_random_uuid(), now() - interval '10 minutes');
select is((select severity from private.health_current() where key = 'queue:room_preview'), 'critical',
  'Antrean pratinjau lebih dari 5 menit menjadi kritis dan tampil di Kesehatan sistem');
delete from private.room_preview_queue;

select private.health_evaluate();
select ok(exists (select 1 from private.health_alerts where key = 'pgbouncer:queue' and severity = 'critical' and resolved_at is null),
  'Masalah metrik membuka alert lewat aturan yang sama');
select ok(exists (select 1 from private.health_current() where key = 'pgbouncer:queue'),
  'Masalah metrik tampil di Kesehatan sistem');

update private.health_metric_samples set sampled_at = now() - interval '20 minutes';
select tests.authenticate_service();
select public.health_report('sentinel-a', '0.2.0', now(), '[]', '[]', '[]');
reset role;
select is((select count(*)::int from private.health_metric_samples), 0, 'Sampel lebih dari 15 menit dibuang');
select is((select count(*)::int from private.health_metric_sources), 0, 'Sumber yang tidak dilaporkan lagi dihapus');

select * from finish();
rollback;
