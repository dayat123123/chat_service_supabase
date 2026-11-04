create table private.healer_state (
  singleton   boolean primary key default true check (singleton),
  reported_at timestamptz not null default now(),
  read_error  text,
  version     text,
  project     text,
  enabled     boolean,
  started_at  timestamptz,
  checked_at  timestamptz,
  rules       jsonb not null default '{}',
  watched     integer not null default 0,
  unhealthy   jsonb not null default '[]',
  skip        jsonb,
  gave_up     jsonb not null default '[]',
  error       text
);
alter table private.healer_state enable row level security;

create table private.healer_events (
  id          text primary key check (id ~ '^[0-9a-z-]{1,80}$'),
  at          timestamptz not null,
  service     text not null default '',
  container   text not null default '',
  action      text not null check (action in ('restart', 'report', 'give_up', 'skip')),
  reason      text not null default '',
  result      text not null default '',
  detail      text,
  error       text,
  received_at timestamptz not null default now()
);
create index healer_events_at_idx on private.healer_events (at desc);
alter table private.healer_events enable row level security;

insert into private.settings (key, value, description) values
  ('health.healer_stale_seconds', '120',
   'Status healer (restart otomatis) yang tidak diperbarui lebih lama dari ini (detik) memicu healer:stale'),
  ('health.alert_after_seconds.healer:*', '0',
   'Tunda sebelum alert healer:<...> dibuka (detik); healer sudah menunggu sendiri sebelum menyerah'),
  ('health.alert_after_seconds.healer:stale', '60',
   'Tunda sebelum alert healer:stale dibuka (detik), agar start ulang healer/sentinel tidak memicu alert'),
  ('health.alert_after_seconds.healer:systemic', '120',
   'Tunda sebelum alert healer:systemic dibuka (detik, tidak melebihi health.alert_after_seconds)')
on conflict (key) do nothing;

create or replace function private.healer_ts(p_value text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  return p_value::timestamptz;
exception when others then
  return null;
end;
$$;

create or replace function private.healer_array(p_value jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_value) = 'array'
              then coalesce((select jsonb_agg(x) from jsonb_array_elements(p_value) x where jsonb_typeof(x) = 'object'), '[]')
              else '[]' end;
$$;

create or replace function private.healer_ingest(p_healer jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_read_error text := left(nullif(btrim(p_healer ->> 'read_error'), ''), 300);
begin
  if jsonb_typeof(p_healer) is distinct from 'object' then
    v_read_error := 'Status healer bukan objek JSON';
  end if;
  if v_read_error is not null then
    insert into private.healer_state as h (singleton, reported_at, read_error)
    values (true, now(), v_read_error)
    on conflict (singleton) do update set reported_at = now(), read_error = excluded.read_error;
    return;
  end if;

  insert into private.healer_state as h (singleton, reported_at, read_error, version, project, enabled, started_at,
                                         checked_at, rules, watched, unhealthy, skip, gave_up, error)
  values (true, now(), null, left(p_healer ->> 'version', 40), left(p_healer ->> 'project', 63),
          case when jsonb_typeof(p_healer -> 'enabled') = 'boolean' then (p_healer ->> 'enabled')::boolean end,
          private.healer_ts(p_healer ->> 'started_at'), private.healer_ts(p_healer ->> 'checked_at'),
          case when jsonb_typeof(p_healer -> 'rules') = 'object' then p_healer -> 'rules' else '{}' end,
          case when jsonb_typeof(p_healer -> 'watched') = 'number' then least(greatest((p_healer ->> 'watched')::numeric, 0), 10000)::integer else 0 end,
          private.healer_array(p_healer -> 'unhealthy'),
          case when jsonb_typeof(p_healer -> 'skip') = 'object' then p_healer -> 'skip' end,
          private.healer_array(p_healer -> 'gave_up'),
          left(nullif(btrim(p_healer ->> 'error'), ''), 300))
  on conflict (singleton) do update
     set reported_at = now(), read_error = null, version = excluded.version, project = excluded.project,
         enabled = excluded.enabled, started_at = excluded.started_at, checked_at = excluded.checked_at,
         rules = excluded.rules, watched = excluded.watched, unhealthy = excluded.unhealthy, skip = excluded.skip,
         gave_up = excluded.gave_up, error = excluded.error;

  insert into private.healer_events (id, at, service, container, action, reason, result, detail, error)
  select e.id, private.healer_ts(e.at), left(coalesce(e.service, ''), 60), left(coalesce(e.container, ''), 200), e.action,
         left(coalesce(e.reason, ''), 40), left(coalesce(e.result, ''), 20),
         left(nullif(btrim(e.detail), ''), 300), left(nullif(btrim(e.error), ''), 300)
  from jsonb_to_recordset(private.healer_array(p_healer -> 'events'))
       as e(id text, at text, service text, container text, action text, reason text, result text, detail text, error text)
  where e.id ~ '^[0-9a-z-]{1,80}$' and e.action in ('restart', 'report', 'give_up', 'skip')
    and private.healer_ts(e.at) is not null
  limit 200
  on conflict (id) do nothing;
  delete from private.healer_events e where e.at < now() - interval '30 days';
end;
$$;

create or replace function private.health_checks_healer()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with s as (
    select h.* from private.healer_state h
    where h.singleton and h.reported_at > now() - interval '90 seconds'
  )
  select 'healer:gave_up:' || g.service, 'critical',
         'Restart otomatis menyerah: ' || private.health_service_label(g.service),
         'Sudah di-restart ' || coalesce(g.restarts, 0) || ' kali dalam 1 jam namun tetap unhealthy. Restart otomatis '
           || 'dihentikan untuk layanan ini' || coalesce(' sampai ' || private.health_fmt_time(private.healer_ts(g.until)), '')
           || '; periksa log layanan ini'
  from s
  cross join lateral jsonb_to_recordset(s.gave_up) as g(service text, until text, restarts integer)
  where s.read_error is null and g.service ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
  union all
  select 'healer:systemic', 'warning', 'Restart otomatis ditahan',
         case s.skip ->> 'reason'
           when 'db_unhealthy' then 'Database tidak sehat, tidak ada layanan yang di-restart'
           when 'pgbouncer_unhealthy' then 'PgBouncer tidak sehat, hanya PgBouncer yang boleh di-restart'
           else 'Gangguan sistemik: banyak layanan unhealthy bersamaan, tidak ada yang di-restart'
         end || '. Layanan unhealthy: '
           || coalesce((select string_agg(x, ', ' order by x)
                        from jsonb_array_elements_text(case when jsonb_typeof(s.skip -> 'services') = 'array'
                                                            then s.skip -> 'services' else '[]' end) x), '-')
  from s
  where s.read_error is null and jsonb_typeof(s.skip) = 'object'
  union all
  select 'healer:stale', 'warning', 'Restart otomatis tidak berjalan',
         case
           when s.read_error is not null then 'Status healer tidak terbaca: ' || s.read_error
           when s.error is not null then 'Healer tidak bisa membaca status container dari Docker: ' || s.error
           when s.checked_at is null then 'Healer belum pernah memperbarui status'
           else 'Healer tidak memperbarui status sejak ' || private.health_fmt_time(s.checked_at)
         end
  from s
  where coalesce(s.enabled, true)
    and (s.read_error is not null or s.error is not null or s.checked_at is null
         or s.checked_at < now() - make_interval(secs => private.setting_num('health.healer_stale_seconds', 120)));
$$;

create or replace function private.health_current()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (c.key) c.key, c.severity, left(c.title, 200), left(c.detail, 500)
  from (
    select * from private.health_checks_services()
    union all select * from private.health_checks_probes()
    union all select * from private.health_checks_disks()
    union all select * from private.health_checks_database()
    union all select * from private.health_checks_queues()
    union all select * from private.health_checks_backup()
    union all select * from private.health_checks_secrets()
    union all select * from private.health_checks_metrics()
    union all select * from private.health_checks_room_preview()
    union all select * from private.health_checks_healer()
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
$$;

drop function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb);

create function public.health_report(
  p_instance text, p_version text, p_started_at timestamptz, p_probes jsonb default '[]', p_disks jsonb default '[]',
  p_metrics jsonb default '[]', p_healer jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_probes) is distinct from 'array' or jsonb_typeof(p_disks) is distinct from 'array'
     or jsonb_array_length(p_probes) > 100 or jsonb_array_length(p_disks) > 20 then
    perform private.api_error(400, 'invalid_health_report', 'Probe dan disk harus berupa array (maks 100/20)');
  end if;
  if jsonb_typeof(p_metrics) is distinct from 'array' or jsonb_array_length(p_metrics) > 200
     or pg_column_size(p_metrics) > 262144 then
    perform private.api_error(400, 'invalid_health_report', 'Metrik harus berupa array (maks 200 sumber)');
  end if;
  if p_healer is not null and pg_column_size(p_healer) > 262144 then
    perform private.api_error(400, 'invalid_health_report', 'Status healer maks 256 KB');
  end if;
  perform public.service_heartbeat('sentinel', p_instance, p_version, p_started_at, 'ok', null,
    jsonb_build_object('probes', jsonb_array_length(p_probes), 'disks', jsonb_array_length(p_disks),
                       'metrics', jsonb_array_length(p_metrics), 'healer', p_healer is not null));

  insert into private.health_probes as h (name, target, ok, status, latency_ms, error, checked_at, last_ok_at, failing_since)
  select distinct on (x.name) x.name, left(x.target, 300), coalesce(x.ok, false), x.status, x.latency_ms,
         left(nullif(btrim(x.error), ''), 300), now(),
         case when coalesce(x.ok, false) then now() end,
         case when coalesce(x.ok, false) then null else now() end
  from jsonb_to_recordset(p_probes) as x(name text, target text, ok boolean, status integer, latency_ms integer, error text)
  where x.name ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
  order by x.name
  on conflict (name) do update
     set target = excluded.target, ok = excluded.ok, status = excluded.status, latency_ms = excluded.latency_ms,
         error = excluded.error, checked_at = now(),
         last_ok_at = case when excluded.ok then now() else h.last_ok_at end,
         failing_since = case when excluded.ok then null else coalesce(h.failing_since, now()) end;
  delete from private.health_probes h
   where h.name not in (select x.name from jsonb_to_recordset(p_probes) as x(name text) where x.name is not null);

  insert into private.health_disks as h (name, total_bytes, free_bytes, avail_bytes, checked_at)
  select distinct on (x.name) x.name, greatest(x.total_bytes, 0), greatest(x.free_bytes, 0), greatest(x.avail_bytes, 0), now()
  from jsonb_to_recordset(p_disks) as x(name text, total_bytes bigint, free_bytes bigint, avail_bytes bigint)
  where x.name ~ '^[a-z0-9][a-z0-9_.-]{0,39}$' and x.total_bytes > 0
  order by x.name
  on conflict (name) do update
     set total_bytes = excluded.total_bytes, free_bytes = excluded.free_bytes, avail_bytes = excluded.avail_bytes,
         checked_at = now();
  delete from private.health_disks h
   where h.name not in (select x.name from jsonb_to_recordset(p_disks) as x(name text) where x.name is not null);

  with reported as (
    select distinct on (x.source, coalesce(left(x.instance, 100), ''))
           x.source, coalesce(left(x.instance, 100), '') as instance, coalesce(x.ok, false) as ok,
           left(nullif(btrim(x.error), ''), 300) as error
    from jsonb_to_recordset(p_metrics) as x(source text, instance text, ok boolean, error text)
    where x.source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
    order by x.source, coalesce(left(x.instance, 100), '')
  ),
  saved as (
    insert into private.health_metric_sources as h (source, instance, ok, error, checked_at)
    select r.source, r.instance, r.ok, r.error, now() from reported r
    on conflict (source, instance) do update
       set ok = excluded.ok, error = excluded.error, checked_at = now()
    returning h.source, h.instance
  )
  delete from private.health_metric_sources h
   where not exists (select 1 from saved s where s.source = h.source and s.instance = h.instance);

  insert into private.health_metric_samples (source, instance, name, value, sampled_at)
  select x.source, coalesce(left(x.instance, 100), ''), v.key, (v.value #>> '{}')::double precision, now()
  from jsonb_to_recordset(p_metrics) as x(source text, instance text, ok boolean, "values" jsonb)
  cross join lateral jsonb_each(case when jsonb_typeof(x."values") = 'object' then x."values" else '{}' end) v
  where coalesce(x.ok, false) and x.source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
    and v.key ~ '^[a-z][a-z0-9_]{0,79}$' and jsonb_typeof(v.value) = 'number';
  delete from private.health_metric_samples s where s.sampled_at < now() - interval '15 minutes';

  insert into private.health_report_misses (kind, name, instance, carried, failed)
  select 'probe', x.name, '', least(greatest(coalesce(x.missed, 0), 0), 1000), not coalesce(x.ok, false)
  from jsonb_to_recordset(p_probes) as x(name text, ok boolean, missed integer)
  where x.name ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
    and (coalesce(x.missed, 0) > 0 or not coalesce(x.ok, false))
  union all
  select 'scrape', x.source, coalesce(left(x.instance, 100), ''), least(greatest(coalesce(x.missed, 0), 0), 1000),
         not coalesce(x.ok, false)
  from jsonb_to_recordset(p_metrics) as x(source text, instance text, ok boolean, missed integer)
  where x.source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$' and x.source <> 'sentinel'
    and (coalesce(x.missed, 0) > 0 or not coalesce(x.ok, false));
  delete from private.health_report_misses m where m.observed_at < now() - interval '15 minutes';

  if p_healer is not null then
    begin
      perform private.healer_ingest(p_healer);
    exception when others then
      insert into private.healer_state as h (singleton, reported_at, read_error)
      values (true, now(), left('Status healer ditolak database: ' || sqlerrm, 300))
      on conflict (singleton) do update set reported_at = now(), read_error = excluded.read_error;
    end;
  end if;

  perform private.health_evaluate();
  return jsonb_build_object('evaluated_at', now());
end;
$$;

create or replace function cs.healer_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'reported_at', h.reported_at,
    'live', h.reported_at > now() - interval '90 seconds',
    'fresh', h.read_error is null and h.checked_at is not null
             and h.checked_at >= now() - make_interval(secs => private.setting_num('health.healer_stale_seconds', 120)),
    'read_error', h.read_error, 'version', h.version, 'project', h.project, 'enabled', h.enabled,
    'started_at', h.started_at, 'checked_at', h.checked_at, 'rules', h.rules, 'watched', h.watched,
    'unhealthy', h.unhealthy, 'skip', h.skip, 'error', h.error,
    'gave_up', coalesce((select jsonb_agg(g || jsonb_build_object('label', private.health_service_label(g ->> 'service')))
                         from jsonb_array_elements(h.gave_up) g), '[]'))
  from private.healer_state h
  where h.singleton;
$$;

create or replace function cs_api.healer_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return jsonb_build_object(
    'now', now(),
    'state', cs.healer_summary(),
    'events', coalesce((select jsonb_agg(x.v order by x.at desc, x.id desc) from (
        select e.at, e.id, jsonb_build_object('id', e.id, 'at', e.at, 'service', e.service,
                                              'label', private.health_service_label(e.service), 'container', e.container,
                                              'action', e.action, 'reason', e.reason, 'result', e.result,
                                              'detail', e.detail, 'error', e.error) as v
        from private.healer_events e
        where e.at > now() - interval '7 days'
        order by e.at desc, e.id desc
        limit 50) x), '[]'),
    'counts', (select jsonb_build_object(
        'restarts_24h', count(*) filter (where e.action = 'restart'),
        'failed_24h', count(*) filter (where e.action = 'restart' and e.result = 'failed'),
        'gave_up_24h', count(*) filter (where e.action = 'give_up'),
        'skipped_24h', count(*) filter (where e.action = 'skip'))
      from private.healer_events e where e.at > now() - interval '24 hours'));
end;
$$;

revoke execute on function private.healer_ts(text) from public;
revoke execute on function private.healer_array(jsonb) from public;
revoke execute on function private.healer_ingest(jsonb) from public;
revoke execute on function private.health_checks_healer() from public;
revoke execute on function private.health_current() from public;
revoke execute on function cs.healer_summary() from public;
revoke execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb, jsonb)
  from public, anon, authenticated;
revoke execute on function cs_api.healer_overview() from public;

grant execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb, jsonb) to service_role;
grant execute on function cs_api.healer_overview() to authenticated;
