begin;
select plan(24);

delete from private.alert_deliveries;
delete from private.health_alerts;
delete from private.health_checks;
delete from private.health_metric_sources;
delete from private.health_metric_samples;
delete from private.health_report_misses;
update private.settings set value = '120' where key = 'health.alert_after_seconds';
update private.settings set value = '60' where key = 'health.resolve_after_seconds';

create function pg_temp.sample(p_source text, p_instance text, p_name text, p_value double precision, p_age integer)
returns void language sql as $$
  insert into private.health_metric_samples (source, instance, name, value, sampled_at)
  values (p_source, p_instance, p_name, p_value, now() - make_interval(secs => p_age));
$$;

create function pg_temp.check_of(p_key text) returns text language sql as $$
  select c.severity || ' | ' || c.title || ' | ' || c.detail from private.health_checks_metrics() c where c.key = p_key;
$$;

create function pg_temp.report(p_probes jsonb, p_metrics jsonb) returns void language plpgsql as $$
begin
  perform tests.authenticate_service();
  perform public.health_report('sentinel-t', '0.3.0', now(), p_probes, '[]', p_metrics);
  reset role;
end;
$$;

select has_table('private', 'health_report_misses', 'Tabel sampel/probe yang hilang ada');

select is(private.health_alert_after('realtime:events'), interval '25 seconds', 'Alert kapasitas Realtime memakai tunda 25 dtk');
select is(private.health_alert_after('rest:pool'), interval '25 seconds', 'Alert pool PostgREST memakai tunda 25 dtk');
select is(private.health_alert_after('metrics:rest'), interval '25 seconds', 'metrics:<sumber> memakai pengaturan prefiks metrics:*');
select is(private.health_alert_after('probe:rest'), interval '120 seconds', 'Kunci lain tetap memakai health.alert_after_seconds');
update private.settings set value = '10' where key = 'health.alert_after_seconds';
select is(private.health_alert_after('realtime:events'), interval '10 seconds', 'Tunda per kunci tidak melebihi tunda global');
update private.settings set value = '120' where key = 'health.alert_after_seconds';

select private.health_realtime_events_limit() as max_rate \gset
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 0, 75);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 30 * 0.2 * :max_rate, 45);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 30 * 0.2 * :max_rate + 30 * 0.8 * :max_rate, 15);
select is(pg_temp.check_of('realtime:events'),
  'warning | Realtime mendekati batas event tenant | ' || round(0.8 * :max_rate) || ' event/dtk dari batas ' || :max_rate
    || ' (80%), rata-rata 45 dtk terakhir. Di atas batas, pesan tidak sampai lewat Realtime',
  'Laju dinilai dari 45 dtk terakhir sebelum sampel terbaru, bukan rata-rata 2 menit');

update private.settings set value = '150' where key = 'health.realtime_events_window_seconds';
select is(pg_temp.check_of('realtime:events'), null, 'Dengan jendela lama 150 dtk lonjakan yang sama belum terlihat (rata-rata 50%)');
update private.settings set value = '45' where key = 'health.realtime_events_window_seconds';

delete from private.health_metric_samples;
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 0, 130);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 30 * 0.9 * :max_rate, 100);
select is(pg_temp.check_of('realtime:events'), null, 'Sampel Realtime lebih dari 90 dtk tidak dinilai');

delete from private.health_metric_samples;
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 0, 45);
select pg_temp.sample('realtime', 'a', 'realtime_channel_global_events', 30 * 0.95 * :max_rate, 15);
select private.health_evaluate();
select is((select count(*)::int from private.health_alerts where key = 'realtime:events'), 0,
  'Pelanggaran pertama baru dicatat sebagai pemeriksaan, belum alert');
update private.health_checks set failing_since = now() - interval '26 seconds' where key = 'realtime:events';
delete from private.settings where key = 'health.alert_after_seconds.realtime:events';
select private.health_evaluate();
select is((select count(*)::int from private.health_alerts where key = 'realtime:events'), 0,
  'Tanpa tunda per kunci, 26 dtk belum cukup (tunda global 120 dtk)');
insert into private.settings (key, value, description)
values ('health.alert_after_seconds.realtime:events', '25', 'uji');
select private.health_evaluate();
select is((select severity || ' ' || (opened_at = now() - interval '26 seconds')::text from private.health_alerts
            where key = 'realtime:events' and resolved_at is null),
  'critical true', 'Pelanggaran yang bertahan 25 dtk membuka alert kritis dengan waktu mulai pelanggaran');

delete from private.health_metric_samples;
delete from private.health_checks;
delete from private.health_alerts;
select pg_temp.report('[]', '[{"source":"rest","instance":"10.0.1.4","ok":false,"error":"HTTP 503","values":{}}]');
select is(pg_temp.check_of('metrics:rest'), 'warning | Metrik API (PostgREST) tidak bisa dibaca | 10.0.1.4: HTTP 503',
  'Satu kegagalan baca tetap tampil seperti sebelumnya');
select pg_temp.report('[]', '[{"source":"rest","instance":"10.0.1.4","ok":false,"error":"HTTP 503","values":{}}]');
select is(pg_temp.check_of('metrics:rest'),
  'warning | Metrik API (PostgREST) tidak bisa dibaca | 10.0.1.4: HTTP 503; 2 sampel gagal dibaca dalam 5 menit terakhir',
  'Kegagalan berturut-turut dihitung');
select pg_temp.report('[]', '[{"source":"rest","instance":"10.0.1.4","ok":true,"values":{"pgrst_db_pool_max":10}}]');
select is(pg_temp.check_of('metrics:rest'),
  'warning | Metrik API (PostgREST) tidak bisa dibaca | 2 sampel gagal dibaca dalam 5 menit terakhir (termasuk laporan sentinel yang tidak terkirim)',
  'Sampel yang gagal tetap dihitung selama jendela walau sumber sudah terbaca lagi');

delete from private.health_report_misses;
select pg_temp.report('[{"name":"rest","target":"http://rest:3000/","ok":true,"status":200,"latency_ms":3}]',
  '[{"source":"rest","instance":"10.0.1.4","ok":true,"missed":2,"values":{"pgrst_db_pool_max":10}},
    {"source":"sentinel","instance":"sentinel-t","ok":true,"values":{"sentinel_reports_lost":2}}]');
select is(pg_temp.check_of('metrics:rest'),
  'warning | Metrik API (PostgREST) tidak bisa dibaca | 2 sampel gagal dibaca dalam 5 menit terakhir (termasuk laporan sentinel yang tidak terkirim)',
  'Kegagalan baca dari laporan yang tidak terkirim dibawa ke laporan berikutnya');
select is((select count(*)::int from private.health_report_misses where name = 'sentinel'), 0,
  'Sumber sentinel sintetis bukan sumber metrik yang gagal');
select is(pg_temp.check_of('metrics:sentinel'), null, 'Laporan yang hilang tidak membuka metrics:sentinel');
select is(pg_temp.check_of('rest:pool'),
  'warning | API (PostgREST) tidak menjawab | 0 request menunggu koneksi pool (maks. 10 koneksi), 0 timeout PGRST003 (HTTP 504) dalam 5 menit terakhir; 2 sampel metrik API atau laporan sentinel hilang, probe API gagal 0 kali dalam 5 menit terakhir',
  'Dua laporan sentinel yang hilang dalam 5 menit menjadi peringatan rest:pool');

delete from private.health_report_misses;
delete from private.health_metric_samples;
select pg_temp.report('[{"name":"rest","target":"http://rest:3000/","ok":true,"status":200,"latency_ms":3}]',
  '[{"source":"sentinel","instance":"sentinel-t","ok":true,"values":{"sentinel_reports_lost":1}}]');
select is(pg_temp.check_of('rest:pool'), null, 'Satu laporan hilang tanpa probe API gagal tidak memicu alert');

select pg_temp.report('[{"name":"rest","target":"http://rest:3000/","ok":true,"status":200,"latency_ms":3,"missed":1}]',
  '[{"source":"rest","instance":"10.0.1.4","ok":true,"values":{"pgrst_db_pool_max":10}}]');
select is(left(pg_temp.check_of('rest:pool'), 41), 'critical | API (PostgREST) tidak menjawab',
  'Laporan hilang saat probe API juga gagal menjadi kritis');
select is((select carried || ' ' || failed from private.health_report_misses where kind = 'probe' and name = 'rest'), '1 false',
  'Probe yang gagal di laporan yang hilang dicatat');

update private.health_report_misses set observed_at = now() - interval '20 minutes';
select pg_temp.report('[]', '[]');
select is((select count(*)::int from private.health_report_misses), 0, 'Catatan lebih dari 15 menit dibuang');

select lives_ok($$select public.health_report('sentinel-a', '0.2.0', now(), '[]', '[]',
  '[{"source":"rest","instance":"10.0.1.4","ok":true,"error":null,"values":{"pgrst_db_pool_max":10}}]')$$,
  'Sentinel 0.2.0 tanpa field missed tetap diterima');

select * from finish();
rollback;
