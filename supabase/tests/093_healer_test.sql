begin;
select plan(43);

delete from private.alert_deliveries;
delete from private.health_alerts;
delete from private.health_checks;
delete from private.healer_events;
delete from private.healer_state;
update private.settings set value = '120' where key = 'health.alert_after_seconds';
update private.settings set value = '0' where key = 'health.resolve_after_seconds';
update private.settings set value = '120' where key = 'health.healer_stale_seconds';

select tests.create_agent('Hana', '{cs_super_admin}', '{}') as hana \gset
select tests.create_agent('Rudi', '{cs_agent}', '{"general": 1}') as rudi \gset
select tests.create_user('hl_budi') as budi \gset

create function pg_temp.state(p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object(
    'version', '0.1.0', 'project', 'olt-social', 'enabled', true,
    'started_at', now() - interval '1 hour', 'checked_at', now() - interval '5 seconds',
    'rules', jsonb_build_object('unhealthy_seconds', 60, 'min_uptime_seconds', 120, 'max_restarts_per_hour', 3,
                                'global_cooldown_seconds', 30, 'systemic_fraction', 0.5, 'interval_seconds', 10),
    'watched', 19, 'unhealthy', '[]'::jsonb, 'skip', null, 'gave_up', '[]'::jsonb,
    'events', jsonb_build_array(
      jsonb_build_object('id', '18a1-aa01', 'at', now() - interval '10 minutes', 'service', 'rest',
                         'container', 'olt-social-rest-1', 'action', 'restart', 'reason', 'unhealthy', 'result', 'ok',
                         'detail', 'unhealthy 61s, uptime 300s: exit 1'),
      jsonb_build_object('id', '18a2-aa02', 'at', now() - interval '5 minutes', 'service', 'rest',
                         'container', 'olt-social-rest-1', 'action', 'restart', 'reason', 'unhealthy', 'result', 'failed',
                         'error', 'docker restart: status 500'),
      jsonb_build_object('id', 'BAD ID', 'at', now(), 'service', 'rest', 'action', 'restart'),
      jsonb_build_object('id', '18a3-aa03', 'at', now(), 'service', 'rest', 'action', 'delete'),
      jsonb_build_object('id', '18a4-aa04', 'at', 'kemarin', 'service', 'rest', 'action', 'restart'),
      '"bukan objek"'::jsonb)
  ) || p_extra;
$$;

create function pg_temp.report(p_healer jsonb) returns jsonb language plpgsql as $$
declare
  v jsonb;
begin
  perform tests.authenticate_service();
  v := public.health_report('sentinel-t', '0.4.0', now(), '[]', '[]', '[]', p_healer);
  reset role;
  return v;
end;
$$;

create function pg_temp.check_of(p_key text) returns text language sql as $$
  select c.severity || ' | ' || c.title || ' | ' || c.detail from private.health_checks_healer() c where c.key = p_key;
$$;

select has_table('private', 'healer_state', 'Tabel status healer ada');
select has_table('private', 'healer_events', 'Tabel riwayat restart otomatis ada');
select has_function('public', 'health_report',
  array['text', 'text', 'timestamp with time zone', 'jsonb', 'jsonb', 'jsonb', 'jsonb'], 'health_report menerima p_healer');
select hasnt_function('public', 'health_report',
  array['text', 'text', 'timestamp with time zone', 'jsonb', 'jsonb', 'jsonb'], 'Versi tanpa p_healer sudah diganti');

select tests.authenticate_as(:'budi');
select throws_ok($$select public.health_report('x', '0', now(), '[]', '[]', '[]', '{}')$$, '42501', null,
  'Nasabah tidak bisa mengirim laporan kesehatan');
reset role;

select ok(pg_temp.report(pg_temp.state()) ? 'evaluated_at', 'Sentinel melaporkan status healer');
select is((select project || ' ' || enabled || ' ' || watched || ' ' || version from private.healer_state),
  'olt-social true 19 0.1.0', 'Status healer tersimpan');
select is((select rules ->> 'max_restarts_per_hour' from private.healer_state), '3', 'Aturan healer tersimpan');
select is((select count(*)::int from private.healer_events), 2,
  'Hanya event yang valid disimpan (id, aksi, waktu, dan objek tidak valid diabaikan)');
select is((select result || ' ' || error from private.healer_events where id = '18a2-aa02'),
  'failed docker restart: status 500', 'Restart gagal tersimpan dengan pesan error');
select pg_temp.report(pg_temp.state());
select is((select count(*)::int from private.healer_events), 2, 'Laporan berulang tidak menggandakan event');
select is(pg_temp.check_of('healer:stale'), null, 'Healer yang segar tidak memicu healer:stale');
select is((select count(*)::int from private.health_checks_healer()), 0, 'Healer normal tanpa pemeriksaan bermasalah');

select is(private.health_alert_after('healer:gave_up:rest'), interval '0 seconds', 'Alert menyerah dibuka tanpa tunda');
select is(private.health_alert_after('healer:stale'), interval '60 seconds', 'Alert healer:stale ditunda 60 dtk');
select is(private.health_alert_after('healer:systemic'), interval '120 seconds',
  'Alert healer:systemic memakai tunda global');

select pg_temp.report(pg_temp.state(jsonb_build_object('gave_up', jsonb_build_array(
  jsonb_build_object('service', 'rest', 'since', now(), 'until', '2026-11-04T04:30:00Z', 'restarts', 3),
  jsonb_build_object('service', 'Bukan Nama', 'since', now(), 'until', now(), 'restarts', 3)))));
select is(pg_temp.check_of('healer:gave_up:rest'),
  'critical | Restart otomatis menyerah: API (PostgREST) | Sudah di-restart 3 kali dalam 1 jam namun tetap unhealthy. '
    || 'Restart otomatis dihentikan untuk layanan ini sampai 4 Nov 2026 11:30 WIB; periksa log layanan ini',
  'Layanan yang ditinggalkan healer menjadi masalah kritis');
select is((select count(*)::int from private.health_checks_healer() where key like 'healer:gave_up:%'), 1,
  'Nama layanan yang tidak valid diabaikan');
select is((select severity from private.health_alerts where key = 'healer:gave_up:rest' and resolved_at is null), 'critical',
  'Alert healer:gave_up dibuka pada laporan yang sama');

select pg_temp.report(pg_temp.state());
select ok((select resolved_at is not null from private.health_alerts where key = 'healer:gave_up:rest'),
  'Alert menyerah pulih setelah layanan tidak lagi ditinggalkan');

select pg_temp.report(pg_temp.state(jsonb_build_object('skip',
  jsonb_build_object('reason', 'systemic', 'since', now(), 'services', jsonb_build_array('rest', 'auth', 'kong')))));
select is(pg_temp.check_of('healer:systemic'),
  'warning | Restart otomatis ditahan | Gangguan sistemik: banyak layanan unhealthy bersamaan, tidak ada yang di-restart. '
    || 'Layanan unhealthy: auth, kong, rest',
  'Gangguan sistemik menjadi peringatan');
select is((select count(*)::int from private.health_alerts where key = 'healer:systemic'), 0,
  'Peringatan sistemik belum menjadi alert sebelum bertahan 120 dtk');
select pg_temp.report(pg_temp.state(jsonb_build_object('skip',
  jsonb_build_object('reason', 'db_unhealthy', 'since', now(), 'services', jsonb_build_array('rest')))));
select is(pg_temp.check_of('healer:systemic'),
  'warning | Restart otomatis ditahan | Database tidak sehat, tidak ada layanan yang di-restart. Layanan unhealthy: rest',
  'Database tidak sehat dijelaskan di detail');
select pg_temp.report(pg_temp.state(jsonb_build_object('skip',
  jsonb_build_object('reason', 'pgbouncer_unhealthy', 'since', now(), 'services', 'bukan array'))));
select is(pg_temp.check_of('healer:systemic'),
  'warning | Restart otomatis ditahan | PgBouncer tidak sehat, hanya PgBouncer yang boleh di-restart. Layanan unhealthy: -',
  'Daftar layanan yang tidak valid tidak menggagalkan pemeriksaan');

select pg_temp.report(pg_temp.state(jsonb_build_object('checked_at', now() - interval '3 minutes')));
select ok(pg_temp.check_of('healer:stale') like 'warning | Restart otomatis tidak berjalan | Healer tidak memperbarui status sejak %',
  'Status healer yang lebih tua dari 2 menit memicu healer:stale');
update private.settings set value = '600' where key = 'health.healer_stale_seconds';
select is(pg_temp.check_of('healer:stale'), null, 'Ambang basi mengikuti health.healer_stale_seconds');
update private.settings set value = '120' where key = 'health.healer_stale_seconds';
select pg_temp.report(pg_temp.state(jsonb_build_object('checked_at', now() - interval '3 minutes', 'enabled', false)));
select is(pg_temp.check_of('healer:stale'), null, 'Healer mode laporan saja tidak memicu healer:stale');

select pg_temp.report(pg_temp.state(jsonb_build_object('error', 'docker list: dial unix /var/run/docker.sock: permission denied')));
select is(pg_temp.check_of('healer:stale'),
  'warning | Restart otomatis tidak berjalan | Healer tidak bisa membaca status container dari Docker: '
    || 'docker list: dial unix /var/run/docker.sock: permission denied',
  'Healer yang tidak bisa menjangkau Docker memicu healer:stale');

select pg_temp.report(pg_temp.state());
select pg_temp.report('{"read_error": "state file not found; is the healer running?"}');
select is(pg_temp.check_of('healer:stale'),
  'warning | Restart otomatis tidak berjalan | Status healer tidak terbaca: state file not found; is the healer running?',
  'File status yang tidak terbaca memicu healer:stale');
select is((select project || ' ' || watched from private.healer_state), 'olt-social 19',
  'Status terakhir yang terbaca tetap disimpan saat file tidak terbaca');

select ok(pg_temp.report('[1, 2]') ? 'evaluated_at', 'Status healer yang bukan objek tidak menggagalkan laporan');
select is((select read_error from private.healer_state), 'Status healer bukan objek JSON', 'Payload rusak dicatat');
select ok(pg_temp.report('{"checked_at": "rusak", "watched": "banyak", "events": "bukan array", "gave_up": {"x": 1}}') ? 'evaluated_at',
  'Field dengan tipe salah tidak menggagalkan laporan');
select is((select coalesce(checked_at::text, 'null') || ' ' || watched || ' ' || gave_up::text from private.healer_state),
  'null 0 []', 'Field dengan tipe salah disimpan sebagai nilai kosong');

select pg_temp.report(pg_temp.state());
update private.healer_state set reported_at = now() - interval '91 seconds', checked_at = now() - interval '1 hour';
select is((select count(*)::int from private.health_checks_healer()), 0,
  'Tanpa laporan sentinel terbaru, healer tidak dinilai (alert sentinel yang berlaku)');
select pg_temp.report(null);
select ok((select reported_at < now() - interval '90 seconds' from private.healer_state),
  'Sentinel tanpa HEALER_STATE_FILE tidak mengubah status healer');

insert into private.healer_events (id, at, action) values ('old-1', now() - interval '31 days', 'restart');
select pg_temp.report(pg_temp.state());
select is((select count(*)::int from private.healer_events where id = 'old-1'), 0, 'Event lebih dari 30 hari dihapus');

select tests.authenticate_agent(:'rudi');
select throws_ok('select cs_api.healer_overview()', 'PT403', null, 'Agen CS tidak bisa membuka restart otomatis');
reset role;

select tests.authenticate_agent(:'hana');
select is((select cs_api.healer_overview() #>> '{state,project}'), 'olt-social', 'Super Admin melihat status healer');
select is((select (cs_api.healer_overview() #>> '{state,fresh}')::boolean and (cs_api.healer_overview() #>> '{state,live}')::boolean),
  true, 'Status healer segar dan dilaporkan sentinel');
select is((select cs_api.healer_overview() #> '{events,0}' ->> 'id'), '18a2-aa02', 'Riwayat restart terbaru di atas');
select is((select cs_api.healer_overview() #> '{events,0}' ->> 'label'), 'API (PostgREST)', 'Riwayat memakai label layanan');
select is((select cs_api.healer_overview() -> 'counts'),
  '{"restarts_24h": 2, "failed_24h": 1, "gave_up_24h": 0, "skipped_24h": 0}'::jsonb, 'Ringkasan 24 jam');
reset role;

select * from finish();
rollback;
