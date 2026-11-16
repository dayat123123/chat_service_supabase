begin;
select plan(13);

delete from private.system_nodes;
delete from private.healer_events;
update private.settings set value = '45' where key = 'health.nodes_stale_seconds';

select tests.create_agent('Nina Peta', '{cs_super_admin}', '{}') as nina \gset
select tests.create_agent('Rudi Peta', '{cs_agent}', '{"general": 1}') as rudi \gset
select tests.create_user('sn_budi') as budi \gset

insert into private.healer_events (id, at, service, container, action, reason, result) values
  ('sn-1', now() - interval '2 hours', 'rest', 'olt-social-rest-2', 'restart', 'unhealthy', 'ok'),
  ('sn-2', now() - interval '1 hour', 'rest', 'olt-social-rest-2', 'restart', 'unhealthy', 'ok'),
  ('sn-3', now() - interval '30 hours', 'media', 'olt-social-media-1', 'restart', 'unhealthy', 'ok');
select max(at) as last_rest from private.healer_events where id in ('sn-1', 'sn-2') \gset

select tests.authenticate_agent(:'nina');
select is(cs_api.system_nodes() ->> 'stale', 'true', 'Tanpa laporan, peta layanan ditandai terlambat');
select is(cs_api.system_nodes() -> 'report', '{}'::jsonb, 'Tanpa laporan, isi peta kosong');

reset role;
select tests.authenticate_as(:'budi');
select throws_ok($$select public.nodes_report('x', '{}')$$, '42501', null, 'Nasabah tidak bisa mengirim laporan container');

reset role;
select tests.authenticate_service();
select throws_ok($$select public.nodes_report('sentinel-1', '[]')$$, 'PT400', 'invalid_nodes_report',
  'Laporan yang bukan objek ditolak');
select throws_ok($$select public.nodes_report('', '{"containers": []}')$$, 'PT400', 'invalid_nodes_report',
  'Instance pelapor wajib diisi');
select throws_ok(format($$select public.nodes_report('sentinel-1', %L)$$,
                        jsonb_build_object('containers', (select jsonb_agg(jsonb_build_object('name', 'c' || g)) from generate_series(1, 201) g))),
  'PT400', 'invalid_nodes_report', 'Lebih dari 200 container ditolak');
select lives_ok($$select public.nodes_report('sentinel-1', jsonb_build_object(
    'version', '0.2.0', 'project', 'olt-social', 'checked_at', now(),
    'host', jsonb_build_object('name', 'srv-1', 'cpus', 8, 'memory_bytes', 34359738368),
    'containers', jsonb_build_array(
      jsonb_build_object('service', 'rest', 'name', 'olt-social-rest-1', 'replica', 1, 'state', 'running', 'health', 'healthy', 'cpu_percent', 3.5),
      jsonb_build_object('service', 'rest', 'name', 'olt-social-rest-2', 'replica', 2, 'state', 'running', 'health', 'healthy'))))$$,
  'Sentinel menyimpan laporan container');
select lives_ok($$select public.nodes_report('sentinel-1', '{"project": "olt-social", "containers": []}')$$,
  'Laporan baru menimpa laporan lama');
select lives_ok($$select public.nodes_report('sentinel-1', jsonb_build_object('project', 'olt-social', 'checked_at', now(),
    'containers', jsonb_build_array(jsonb_build_object('service', 'rest', 'name', 'olt-social-rest-1', 'state', 'running'))))$$,
  'Laporan terbaru tersimpan');

reset role;
select is((select count(*) from private.system_nodes), 1::bigint, 'Hanya satu baris laporan yang disimpan');
select tests.authenticate_agent(:'rudi');
select throws_ok('select cs_api.system_nodes()', 'PT403', null, 'Agen CS tidak bisa membuka peta layanan');

reset role;
select tests.authenticate_agent(:'nina');
select is(jsonb_array_length(cs_api.system_nodes() #> '{report,containers}'), 1,
  'Super Admin melihat container dari laporan terbaru');
select is(cs_api.system_nodes() -> 'restarts', jsonb_build_array(jsonb_build_object('service', 'rest', 'count', 2,
            'last_at', :'last_rest'::timestamptz)),
  'Restart 24 jam terakhir dihitung per service');

reset role;
select * from finish();
rollback;
