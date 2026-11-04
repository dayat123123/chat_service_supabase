create table private.health_report_misses (
  kind        text not null check (kind in ('scrape', 'probe')),
  name        text not null,
  instance    text not null default '',
  carried     integer not null default 0 check (carried >= 0),
  failed      boolean not null default false,
  observed_at timestamptz not null default now()
);
create index health_report_misses_name_idx on private.health_report_misses (kind, name, observed_at);
alter table private.health_report_misses enable row level security;

insert into private.settings (key, value, description) values
  ('health.realtime_events_window_seconds', '45',
   'Jendela rata-rata laju event Realtime (detik), dihitung mundur dari sampel terakhir'),
  ('health.alert_after_seconds.rest:pool', '25',
   'Tunda maksimum sebelum alert rest:pool dibuka (detik, tidak melebihi health.alert_after_seconds)'),
  ('health.alert_after_seconds.realtime:events', '25',
   'Tunda maksimum sebelum alert realtime:events dibuka (detik, tidak melebihi health.alert_after_seconds)'),
  ('health.alert_after_seconds.pgbouncer:queue', '25',
   'Tunda maksimum sebelum alert pgbouncer:queue dibuka (detik, tidak melebihi health.alert_after_seconds)'),
  ('health.alert_after_seconds.db:lock_waits', '25',
   'Tunda maksimum sebelum alert db:lock_waits dibuka (detik, tidak melebihi health.alert_after_seconds)'),
  ('health.alert_after_seconds.metrics:*', '25',
   'Tunda maksimum sebelum alert metrics:<sumber> dibuka (detik, tidak melebihi health.alert_after_seconds)'),
  ('health.metrics_missed_warn', '2',
   'Sampel metrik yang gagal dibaca dalam jendela (termasuk dari laporan sentinel yang tidak terkirim) yang memicu metrics:<sumber>'),
  ('health.metrics_missed_window_seconds', '300',
   'Jendela hitung sampel metrik yang gagal dibaca (detik)'),
  ('health.rest_blind_warn', '2',
   'Laporan sentinel yang tidak terkirim ditambah sampel metrik rest yang gagal dalam 5 menit yang memicu rest:pool')
on conflict (key) do nothing;

create or replace function private.health_alert_after(p_key text)
returns interval
language sql
stable
security definer
set search_path = ''
as $$
  select make_interval(secs => least(g.secs, coalesce(
           private.setting_num('health.alert_after_seconds.' || p_key, null),
           private.setting_num('health.alert_after_seconds.' || split_part(p_key, ':', 1) || ':*', null),
           g.secs))::double precision)
  from (select private.setting_num('health.alert_after_seconds', 120) as secs) g;
$$;

create or replace function private.health_checks_metrics()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with latest as (
    select distinct on (s.source, s.instance, s.name) s.source, s.instance, s.name, s.value
    from private.health_metric_samples s
    where s.sampled_at > now() - interval '90 seconds'
    order by s.source, s.instance, s.name, s.sampled_at desc
  ),
  increments as (
    select x.source, x.instance, x.name, x.sampled_at, x.prev_at,
           case when x.value >= x.prev then x.value - x.prev else x.value end as inc
    from (
      select s.source, s.instance, s.name, s.value, s.sampled_at,
             lag(s.value) over w as prev, lag(s.sampled_at) over w as prev_at
      from private.health_metric_samples s
      where s.name in ('pgrst_db_pool_timeouts_total', 'realtime_channel_global_events')
        and s.sampled_at > now() - interval '5 minutes'
      window w as (partition by s.source, s.instance, s.name order by s.sampled_at)
    ) x
    where x.prev is not null
  ),
  rest as (
    select (select coalesce(sum(i.inc), 0) from increments i where i.name = 'pgrst_db_pool_timeouts_total') as timeouts,
           (select coalesce(sum(w.value), 0)
              from latest w
              join latest a on a.source = w.source and a.instance = w.instance and a.name = 'pgrst_db_pool_available'
             where w.name = 'pgrst_db_pool_waiting' and a.value <= 0) as waiting,
           (select coalesce(sum(l.value), 0) from latest l where l.name = 'pgrst_db_pool_max') as pool,
           (select coalesce(sum(s.value), 0)
              from private.health_metric_samples s
             where s.source = 'sentinel' and s.name = 'sentinel_reports_lost' and s.sampled_at > now() - interval '5 minutes')
           + (select count(*)
                from private.health_report_misses m
               where m.kind = 'scrape' and m.name = 'rest' and m.failed and m.observed_at > now() - interval '5 minutes') as blind,
           (select coalesce(sum(m.carried + m.failed::int), 0)
              from private.health_report_misses m
             where m.kind = 'probe' and m.name = 'rest' and m.observed_at > now() - interval '5 minutes') as probe_failures
  ),
  realtime_window as (
    select private.setting_num('health.realtime_events_window_seconds', 45) as secs
  ),
  realtime_last as (
    select i.source, i.instance, max(i.sampled_at) as last_at
    from increments i
    where i.name = 'realtime_channel_global_events'
    group by i.source, i.instance
  ),
  realtime as (
    select r.rate, private.health_realtime_events_limit() as max_rate, w.secs
    from (
      select sum(p.rate) as rate
      from (
        select sum(i.inc) / extract(epoch from max(i.sampled_at) - min(i.prev_at)) as rate
        from increments i
        join realtime_last l on l.source = i.source and l.instance = i.instance
        cross join realtime_window w
        where i.name = 'realtime_channel_global_events'
          and l.last_at > now() - interval '90 seconds'
          and i.prev_at >= l.last_at - make_interval(secs => w.secs::double precision)
        group by i.source, i.instance
        having extract(epoch from max(i.sampled_at) - min(i.prev_at)) >= 20
      ) p
    ) r
    cross join realtime_window w
    where r.rate is not null
  ),
  bouncer as (
    select coalesce(sum(l.value) filter (where l.name = 'pgbouncer_cl_waiting'), 0) as waiting,
           coalesce(max(l.value) filter (where l.name = 'pgbouncer_maxwait_seconds'), 0) as maxwait,
           count(*) filter (where l.name = 'pgbouncer_cl_waiting') as instances
    from latest l
  ),
  locks as (
    select count(distinct l.pid) as waiters,
           coalesce(extract(epoch from max(now() - l.waitstart)), 0) as longest
    from pg_catalog.pg_locks l
    where not l.granted
  ),
  failing_sources as (
    select m.source,
           string_agg(case when m.instance = '' then '' else m.instance || ': ' end || coalesce(m.error, 'gagal'), '; '
                      order by m.instance) as detail
    from private.health_metric_sources m
    where not m.ok and m.checked_at > now() - interval '90 seconds'
    group by m.source
  ),
  missed_window as (
    select private.setting_num('health.metrics_missed_window_seconds', 300) as secs
  ),
  missed_sources as (
    select m.name as source, sum(m.carried + m.failed::int) as rounds, w.secs
    from private.health_report_misses m
    cross join missed_window w
    where m.kind = 'scrape' and m.observed_at > now() - make_interval(secs => w.secs::double precision)
    group by m.name, w.secs
    having sum(m.carried + m.failed::int) >= private.setting_num('health.metrics_missed_warn', 2)
  )
  select 'rest:pool',
         case when r.timeouts >= private.setting_num('health.rest_pool_timeouts_critical', 20)
                or (r.blind >= 1 and r.probe_failures >= 1) then 'critical' else 'warning' end,
         case when r.timeouts < private.setting_num('health.rest_pool_timeouts_warn', 1)
               and r.waiting < private.setting_num('health.rest_pool_waiting_warn', 1)
              then 'API (PostgREST) tidak menjawab' else 'Pool koneksi API (PostgREST) penuh' end,
         r.waiting::bigint || ' request menunggu koneksi pool (maks. ' || r.pool::bigint || ' koneksi), '
           || r.timeouts::bigint || ' timeout PGRST003 (HTTP 504) dalam 5 menit terakhir'
           || case when r.blind > 0
                   then '; ' || r.blind::bigint || ' sampel metrik API atau laporan sentinel hilang, probe API gagal '
                        || r.probe_failures::bigint || ' kali dalam 5 menit terakhir'
                   else '' end
  from rest r
  where r.timeouts >= private.setting_num('health.rest_pool_timeouts_warn', 1)
     or r.waiting >= private.setting_num('health.rest_pool_waiting_warn', 1)
     or r.blind >= private.setting_num('health.rest_blind_warn', 2)
     or (r.blind >= 1 and r.probe_failures >= 1)
  union all
  select 'realtime:events',
         case when r.rate >= r.max_rate * private.setting_num('health.realtime_events_critical_ratio', 0.9)
              then 'critical' else 'warning' end,
         case when r.rate >= r.max_rate then 'Realtime membuang event: batas tenant tercapai'
              else 'Realtime mendekati batas event tenant' end,
         round(r.rate) || ' event/dtk dari batas ' || r.max_rate || ' (' || round(r.rate * 100 / r.max_rate) || '%), '
           || 'rata-rata ' || case when r.secs >= 60 then floor(r.secs / 60) || ' menit' else r.secs || ' dtk' end
           || ' terakhir. Di atas batas, pesan tidak sampai lewat Realtime'
  from realtime r
  where r.rate >= r.max_rate * private.setting_num('health.realtime_events_warn_ratio', 0.7)
  union all
  select 'pgbouncer:queue',
         case when b.maxwait >= private.setting_num('health.pgbouncer_maxwait_critical_seconds', 5)
              then 'critical' else 'warning' end,
         'PgBouncer mengantre koneksi',
         b.waiting::bigint || ' klien menunggu koneksi server, tunggu terlama ' || round(b.maxwait::numeric, 1) || ' dtk'
  from bouncer b
  where b.instances > 0
    and (b.waiting >= private.setting_num('health.pgbouncer_waiting_warn', 1)
         or b.maxwait >= private.setting_num('health.pgbouncer_maxwait_warn_seconds', 1))
  union all
  select 'db:lock_waits',
         case when k.waiters >= private.setting_num('health.lock_waiters_critical', 20)
                or k.longest >= private.setting_num('health.lock_wait_critical_seconds', 30)
              then 'critical' else 'warning' end,
         'Proses database menunggu lock',
         k.waiters || ' proses menunggu lock, terlama ' || round(k.longest::numeric, 1) || ' dtk'
  from locks k
  where k.waiters >= private.setting_num('health.lock_waiters_warn', 5)
     or k.longest >= private.setting_num('health.lock_wait_warn_seconds', 5)
  union all
  select 'metrics:' || coalesce(f.source, d.source), 'warning',
         'Metrik ' || private.health_service_label(coalesce(f.source, d.source)) || ' tidak bisa dibaca',
         case when f.source is null
              then d.rounds::bigint || ' sampel gagal dibaca dalam ' || private.health_fmt_duration(make_interval(secs => d.secs::double precision))
                   || ' terakhir (termasuk laporan sentinel yang tidak terkirim)'
              else f.detail || coalesce('; ' || d.rounds::bigint || ' sampel gagal dibaca dalam '
                   || private.health_fmt_duration(make_interval(secs => d.secs::double precision)) || ' terakhir', '')
         end
  from failing_sources f
  full join missed_sources d on d.source = f.source;
$$;

create or replace function private.health_evaluate()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_resolve interval := make_interval(secs => private.setting_num('health.resolve_after_seconds', 60));
  v_check   private.health_checks;
  v_alert   private.health_alerts;
  v_id      bigint;
begin
  if not pg_try_advisory_xact_lock(hashtext('olt.health_evaluate')) then
    return;
  end if;

  with cur as materialized (
    select c.key, c.severity, c.title, c.detail from private.health_current() c
  ),
  upserted as (
    insert into private.health_checks as h (key, severity, title, detail, failing_since, last_seen_at)
    select cur.key, cur.severity, cur.title, cur.detail, now(), now() from cur
    on conflict (key) do update
       set severity = excluded.severity, title = excluded.title, detail = excluded.detail, last_seen_at = now()
    returning h.key
  )
  delete from private.health_checks h where not exists (select 1 from cur where cur.key = h.key);

  for v_check in
    select * from private.health_checks h where h.failing_since <= now() - private.health_alert_after(h.key)
  loop
    select * into v_alert from private.health_alerts a where a.key = v_check.key and a.resolved_at is null;
    if not found then
      insert into private.health_alerts (key, severity, title, detail, opened_at)
      values (v_check.key, v_check.severity, v_check.title, v_check.detail, v_check.failing_since)
      returning id into v_id;
      perform private.alert_enqueue(v_id, 'opened');
    else
      update private.health_alerts a
         set detail = v_check.detail, ok_since = null,
             severity = case when v_check.severity = 'critical' then 'critical' else a.severity end
       where a.id = v_alert.id;
      if v_alert.severity = 'warning' and v_check.severity = 'critical' then
        perform private.alert_enqueue(v_alert.id, 'escalated');
      end if;
    end if;
  end loop;

  update private.health_alerts a set ok_since = null
   where a.resolved_at is null and a.ok_since is not null
     and exists (select 1 from private.health_checks h where h.key = a.key);
  update private.health_alerts a set ok_since = now()
   where a.resolved_at is null and a.ok_since is null
     and not exists (select 1 from private.health_checks h where h.key = a.key);
  for v_id in
    update private.health_alerts a set resolved_at = now()
     where a.resolved_at is null and a.ok_since <= now() - v_resolve
    returning a.id
  loop
    perform private.alert_enqueue(v_id, 'resolved');
  end loop;

  update private.alert_deliveries d set status = 'failed', error = 'Kedaluwarsa (lebih dari 6 jam)', locked_until = null
   where d.status = 'pending' and d.created_at < now() - interval '6 hours';
  delete from private.service_instances s where s.last_seen_at < now() - interval '1 day';
  delete from private.health_probes p where p.checked_at < now() - interval '1 day';
  delete from private.health_disks d where d.checked_at < now() - interval '1 day';
  update private.health_meta m set evaluated_at = now() where m.singleton;
end;
$$;

create or replace function public.health_report(
  p_instance text, p_version text, p_started_at timestamptz, p_probes jsonb default '[]', p_disks jsonb default '[]',
  p_metrics jsonb default '[]'
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
  perform public.service_heartbeat('sentinel', p_instance, p_version, p_started_at, 'ok', null,
    jsonb_build_object('probes', jsonb_array_length(p_probes), 'disks', jsonb_array_length(p_disks),
                       'metrics', jsonb_array_length(p_metrics)));

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

  perform private.health_evaluate();
  return jsonb_build_object('evaluated_at', now());
end;
$$;

revoke execute on function private.health_alert_after(text) from public;
revoke execute on function private.health_checks_metrics() from public;
revoke execute on function private.health_evaluate() from public;
revoke execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb) to service_role;
