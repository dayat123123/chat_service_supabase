alter table private.integration_keys drop constraint integration_keys_scopes_check;
alter table private.integration_keys add constraint integration_keys_scopes_check
  check (cardinality(scopes) between 1 and 4
         and scopes <@ array['notify', 'bot_post', 'notify_broadcast', 'health_read']
         and (not 'notify_broadcast' = any (scopes) or 'notify' = any (scopes)));

create or replace function cs.integration_scopes(p_scopes text[])
returns text[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_scopes text[];
begin
  select coalesce(array_agg(distinct btrim(s) order by btrim(s)), '{}') into v_scopes
  from unnest(coalesce(p_scopes, '{}')) s
  where btrim(coalesce(s, '')) <> '';
  if cardinality(v_scopes) = 0 or not v_scopes <@ array['notify', 'bot_post', 'notify_broadcast', 'health_read'] then
    perform private.api_error(400, 'invalid_scopes', 'Pilih izin notify, notify_broadcast, bot_post, health_read, atau gabungannya');
  end if;
  if 'notify_broadcast' = any (v_scopes) and not 'notify' = any (v_scopes) then
    perform private.api_error(400, 'invalid_scopes', 'Izin notify_broadcast harus disertai izin notify');
  end if;
  return v_scopes;
end;
$$;

create or replace function private.system_health_view()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_checks jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('key', c.key, 'severity', c.severity, 'title', c.title,
                                               'detail', c.detail,
                                               'failing_since', coalesce(h.failing_since, now()))
                            order by case c.severity when 'critical' then 0 else 1 end, c.key), '[]')
    into v_checks
  from private.health_current() c
  left join private.health_checks h on h.key = c.key;

  return jsonb_build_object(
    'status', cs.health_status_of(v_checks),
    'now', now(),
    'evaluated_at', (select m.evaluated_at from private.health_meta m where m.singleton),
    'checks', v_checks,
    'alerts', jsonb_build_object(
      'open', coalesce((select jsonb_agg(jsonb_build_object(
          'id', a.id, 'key', a.key, 'severity', a.severity, 'title', a.title, 'detail', a.detail,
          'opened_at', a.opened_at, 'acknowledged_by', cs.agent_name(a.acknowledged_by),
          'acknowledged_at', a.acknowledged_at) order by a.opened_at desc)
        from private.health_alerts a where a.resolved_at is null), '[]'),
      'recent', coalesce((select jsonb_agg(r.v order by r.opened_at desc) from (
          select a.opened_at, jsonb_build_object('id', a.id, 'key', a.key, 'severity', a.severity, 'title', a.title,
                                                 'opened_at', a.opened_at, 'resolved_at', a.resolved_at) as v
          from private.health_alerts a
          where a.resolved_at is not null and a.resolved_at > now() - interval '7 days'
          order by a.opened_at desc limit 30) r), '[]')),
    'services', coalesce((select jsonb_agg(x.v order by x.service) from (
        select i.service, jsonb_build_object('service', i.service, 'label', private.health_service_label(i.service),
               'instances', jsonb_agg(jsonb_build_object(
                 'instance', i.instance, 'version', i.version, 'started_at', i.started_at, 'last_seen_at', i.last_seen_at,
                 'status', i.status, 'error', i.error, 'detail', i.detail,
                 'live', i.last_seen_at > now() - interval '90 seconds') order by i.last_seen_at desc)) as v
        from (
          select s.service, s.instance, s.version, s.started_at, s.last_seen_at, s.status, s.error, s.detail
          from private.service_instances s
          union all
          select 'notifier', p.instance_id, p.version, p.started_at, p.seen_at,
                 case when p.error is null then 'ok' else 'degraded' end, p.error,
                 jsonb_build_object('configured', p.configured)
          from private.push_instances p
          where p.seen_at > now() - interval '1 day'
        ) i
        group by i.service) x), '[]'),
    'probes', coalesce((select jsonb_agg(jsonb_build_object(
        'name', p.name, 'label', private.health_service_label(p.name), 'target', p.target, 'ok', p.ok,
        'status', p.status, 'latency_ms', p.latency_ms, 'error', p.error, 'checked_at', p.checked_at,
        'last_ok_at', p.last_ok_at, 'stale', p.checked_at < now() - interval '90 seconds') order by p.name)
      from private.health_probes p), '[]'),
    'disks', coalesce((select jsonb_agg(jsonb_build_object(
        'name', d.name, 'total_bytes', d.total_bytes, 'avail_bytes', d.avail_bytes,
        'used_ratio', round(1 - d.avail_bytes::numeric / nullif(d.total_bytes, 0), 4), 'checked_at', d.checked_at)
        order by d.name)
      from private.health_disks d), '[]'),
    'database', jsonb_build_object(
      'size_bytes', pg_catalog.pg_database_size(current_database()),
      'connections', (select count(*) from pg_catalog.pg_stat_activity),
      'max_connections', current_setting('max_connections')::integer,
      'slots', coalesce((select jsonb_agg(jsonb_build_object(
          'name', s.slot_name, 'type', s.slot_type, 'active', s.active, 'wal_status', s.wal_status,
          'retained_bytes', case when s.restart_lsn is not null
                                 then pg_catalog.pg_wal_lsn_diff(pg_catalog.pg_current_wal_lsn(), s.restart_lsn) end)
          order by s.slot_name)
        from pg_catalog.pg_replication_slots s), '[]')),
    'queues', jsonb_build_object(
      'push', (select jsonb_build_object('queued', count(*), 'oldest_at', min(q.created_at))
               from private.push_queue q where q.status = 'queued'),
      'storage_cleanup', (select jsonb_build_object('pending', count(*), 'failing', count(*) filter (where q.failures > 0),
                                                    'oldest_at', min(q.queued_at))
                          from private.storage_cleanup_queue q where q.done_at is null),
      'alerts', (select jsonb_build_object('pending', count(*) filter (where d.status = 'pending'),
                                           'failed_24h', count(*) filter (where d.status = 'failed'
                                                                          and d.created_at > now() - interval '24 hours'))
                 from private.alert_deliveries d where d.created_at > now() - interval '7 days')),
    'cron', coalesce((select jsonb_agg(jsonb_build_object(
        'job', j.jobname, 'schedule', j.schedule, 'active', j.active,
        'last_status', r.status, 'last_start', r.start_time, 'last_message', left(r.return_message, 300))
        order by j.jobname)
      from cron.job j
      left join lateral (select d.status, d.start_time, d.return_message from cron.job_run_details d
                         where d.jobid = j.jobid
                           and d.runid > coalesce((select max(x.runid) from cron.job_run_details x), 0) - 40000
                         order by d.start_time desc limit 1) r on true), '[]'),
    'backup', cs.backup_summary(),
    'channels', cs.alert_channels_view());
end;
$$;

create or replace function private.system_nodes_view()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
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

create or replace function cs_api.system_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return private.system_health_view();
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
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return private.system_nodes_view();
end;
$$;

create or replace function private.system_health_external()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v        jsonb := private.system_health_view();
  v_ch     jsonb := v -> 'channels';
begin
  return v - 'channels' || jsonb_build_object(
    'api_version', 1,
    'probes', coalesce((select jsonb_agg(p - 'target' order by p ->> 'name')
                        from jsonb_array_elements(coalesce(v -> 'probes', '[]')) p), '[]'),
    'backup', coalesce(v -> 'backup', '{}') - 'target',
    'channels', jsonb_build_object(
      'telegram', jsonb_build_object(
        'enabled', coalesce((v_ch #>> '{telegram,enabled}')::boolean, false),
        'configured', coalesce((v_ch #>> '{telegram,token_set}')::boolean, false)
                      and jsonb_array_length(coalesce(v_ch #> '{telegram,chat_ids}', '[]')) > 0,
        'last', v_ch #> '{last,telegram}'),
      'email', jsonb_build_object(
        'enabled', coalesce((v_ch #>> '{email,enabled}')::boolean, false),
        'configured', coalesce(v_ch #>> '{email,host}', '') <> ''
                      and jsonb_array_length(coalesce(v_ch #> '{email,to}', '[]')) > 0,
        'last', v_ch #> '{last,email}')));
end;
$$;

create or replace function private.system_nodes_external()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.system_nodes_view() || jsonb_build_object('api_version', 1);
$$;

create or replace function public.integration_system_health(p_key_id uuid, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k private.integration_keys := private.integration_key_for(p_key_id, 'health_read', p_ip);
begin
  perform private.integration_touch(k.id, p_ip, '{}');
  return private.system_health_external();
end;
$$;

create or replace function public.integration_system_nodes(p_key_id uuid, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k private.integration_keys := private.integration_key_for(p_key_id, 'health_read', p_ip);
begin
  perform private.integration_touch(k.id, p_ip, '{}');
  return private.system_nodes_external();
end;
$$;

revoke execute on function private.system_health_view() from public;
revoke execute on function private.system_nodes_view() from public;
revoke execute on function private.system_health_external() from public;
revoke execute on function private.system_nodes_external() from public;
revoke execute on function cs_api.system_health() from public;
revoke execute on function cs_api.system_nodes() from public;
revoke execute on function public.integration_system_health(uuid, text) from public, anon, authenticated;
revoke execute on function public.integration_system_nodes(uuid, text) from public, anon, authenticated;
grant execute on function cs_api.system_health() to authenticated;
grant execute on function cs_api.system_nodes() to authenticated;
grant execute on function public.integration_system_health(uuid, text) to service_role;
grant execute on function public.integration_system_nodes(uuid, text) to service_role;
