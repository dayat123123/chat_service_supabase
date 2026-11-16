create table private.system_nodes (
  singleton   boolean primary key default true check (singleton),
  instance    text not null default '',
  reported_at timestamptz not null default now(),
  report      jsonb not null default '{}'
);
alter table private.system_nodes enable row level security;

insert into private.settings (key, value, description) values
  ('health.nodes_stale_seconds', '45',
   'Peta layanan dianggap terlambat bila laporan container terakhir lebih tua dari ini (detik)')
on conflict (key) do nothing;

create or replace function public.nodes_report(p_instance text, p_report jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_report) is distinct from 'object'
     or jsonb_typeof(coalesce(p_report -> 'containers', '[]')) is distinct from 'array'
     or jsonb_array_length(coalesce(p_report -> 'containers', '[]')) > 200
     or pg_column_size(p_report) > 524288 then
    perform private.api_error(400, 'invalid_nodes_report', 'Laporan container harus objek dengan maks 200 container');
  end if;
  if p_instance is null or char_length(p_instance) not between 1 and 200 then
    perform private.api_error(400, 'invalid_nodes_report', 'Instance pelapor wajib diisi');
  end if;
  insert into private.system_nodes as n (singleton, instance, reported_at, report)
  values (true, p_instance, now(), p_report)
  on conflict (singleton) do update
    set instance = excluded.instance, reported_at = excluded.reported_at, report = excluded.report;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function cs_api.system_nodes()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_row   private.system_nodes;
  v_stale integer := private.setting_num('health.nodes_stale_seconds', 45)::integer;
begin
  select * into v_row from private.system_nodes where singleton;
  return jsonb_build_object(
    'now', now(),
    'reported_at', v_row.reported_at,
    'stale', v_row.reported_at is null or v_row.reported_at < now() - make_interval(secs => v_stale),
    'report', coalesce(v_row.report, '{}'),
    'probes', coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'ok', p.ok, 'latency_ms', p.latency_ms,
                                                            'checked_at', p.checked_at, 'failing_since', p.failing_since)
                                         order by p.name)
                        from private.health_probes p), '[]'),
    'restarts', coalesce((select jsonb_agg(jsonb_build_object('service', e.service, 'count', e.n, 'last_at', e.last_at)
                                           order by e.service)
                          from (select service, count(*) as n, max(at) as last_at
                                from private.healer_events
                                where action = 'restart' and at > now() - interval '24 hours'
                                group by service) e), '[]'),
    'versions', coalesce((select jsonb_object_agg(v.service, v.version)
                          from (select distinct on (service) service, version
                                from private.service_instances
                                where version is not null
                                order by service, last_seen_at desc) v), '{}'));
end;
$$;

revoke execute on function public.nodes_report(text, jsonb) from public, anon, authenticated;
revoke execute on function cs_api.system_nodes() from public;
grant execute on function public.nodes_report(text, jsonb) to service_role;
grant execute on function cs_api.system_nodes() to authenticated;
