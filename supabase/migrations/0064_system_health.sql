create table private.service_instances (
  service      text not null check (service ~ '^[a-z][a-z0-9-]{1,39}$'),
  instance     text not null check (char_length(instance) between 1 and 200),
  version      text,
  started_at   timestamptz,
  last_seen_at timestamptz not null default now(),
  status       text not null default 'ok' check (status in ('ok', 'degraded', 'error')),
  error        text,
  detail       jsonb not null default '{}',
  primary key (service, instance)
);
alter table private.service_instances enable row level security;

create table private.health_probes (
  name          text primary key,
  target        text,
  ok            boolean not null,
  status        integer,
  latency_ms    integer,
  error         text,
  checked_at    timestamptz not null,
  last_ok_at    timestamptz,
  failing_since timestamptz
);
alter table private.health_probes enable row level security;

create table private.health_disks (
  name        text primary key,
  total_bytes bigint not null,
  free_bytes  bigint not null,
  avail_bytes bigint not null,
  checked_at  timestamptz not null
);
alter table private.health_disks enable row level security;

create table private.health_checks (
  key           text primary key,
  severity      text not null check (severity in ('warning', 'critical')),
  title         text not null,
  detail        text,
  failing_since timestamptz not null,
  last_seen_at  timestamptz not null
);
alter table private.health_checks enable row level security;

create table private.health_alerts (
  id              bigint generated always as identity primary key,
  key             text not null,
  severity        text not null check (severity in ('warning', 'critical')),
  title           text not null,
  detail          text,
  opened_at       timestamptz not null default now(),
  ok_since        timestamptz,
  resolved_at     timestamptz,
  acknowledged_by uuid,
  acknowledged_at timestamptz
);
create unique index health_alerts_open_key on private.health_alerts (key) where resolved_at is null;
create index health_alerts_opened_idx on private.health_alerts (opened_at desc);
alter table private.health_alerts enable row level security;

create table private.health_meta (
  singleton    boolean primary key default true check (singleton),
  evaluated_at timestamptz
);
insert into private.health_meta (singleton) values (true);
alter table private.health_meta enable row level security;

create table private.alert_channels (
  singleton          boolean primary key default true check (singleton),
  revision           bigint not null default 0,
  label              text not null default 'OLT Social' check (char_length(label) between 1 and 40),
  console_url        text check (console_url ~ '^https?://[^[:space:]]{1,200}$'),
  telegram_enabled   boolean not null default false,
  telegram_secret_id uuid,
  telegram_chat_ids  text[] not null default '{}',
  email_enabled      boolean not null default false,
  smtp_host          text,
  smtp_port          integer check (smtp_port between 1 and 65535),
  smtp_security      text check (smtp_security in ('tls', 'starttls', 'none')),
  smtp_username      text,
  smtp_secret_id     uuid,
  email_from         text,
  email_to           text[] not null default '{}',
  updated_by         uuid,
  updated_at         timestamptz not null default now()
);
insert into private.alert_channels (singleton) values (true);
alter table private.alert_channels enable row level security;

create table private.alert_deliveries (
  id           bigint generated always as identity primary key,
  alert_id     bigint references private.health_alerts(id) on delete cascade,
  kind         text not null check (kind in ('opened', 'escalated', 'resolved', 'test')),
  channel      text not null check (channel in ('telegram', 'email')),
  subject      text not null,
  body         text not null,
  status       text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  attempts     integer not null default 0,
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text,
  error        text,
  created_by   uuid,
  created_at   timestamptz not null default now(),
  sent_at      timestamptz
);
create index alert_deliveries_pending_idx on private.alert_deliveries (available_at) where status = 'pending';
create index alert_deliveries_created_idx on private.alert_deliveries (created_at desc);
alter table private.alert_deliveries enable row level security;

insert into private.settings (key, value, description) values
  ('health.expected_services', '["media", "sentinel", "backup", "notifier"]',
   'Layanan yang wajib mengirim heartbeat; hilang lebih dari 90 detik dianggap tidak aktif'),
  ('health.alert_after_seconds', '120', 'Lama masalah bertahan sebelum alert dibuka (detik)'),
  ('health.resolve_after_seconds', '60', 'Lama masalah hilang sebelum alert dinyatakan pulih (detik)'),
  ('health.disk_warn_ratio', '0.8', 'Pemakaian disk yang memicu peringatan (0–1)'),
  ('health.disk_critical_ratio', '0.9', 'Pemakaian disk yang memicu alert kritis (0–1)')
on conflict (key) do nothing;

create or replace function private.health_fmt_time(p_at timestamptz)
returns text
language sql
immutable
set search_path = ''
as $$
  select extract(day from p_at at time zone 'Asia/Jakarta')::integer || ' '
      || (array['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'])
         [extract(month from p_at at time zone 'Asia/Jakarta')::integer] || ' '
      || to_char(p_at at time zone 'Asia/Jakarta', 'YYYY HH24:MI') || ' WIB';
$$;

create or replace function private.health_fmt_duration(p_span interval)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when s < 60 then 'kurang dari 1 menit'
    when s < 3600 then (s / 60) || ' menit'
    when s < 86400 then (s / 3600) || ' jam' || case when (s % 3600) / 60 > 0 then ' ' || (s % 3600) / 60 || ' menit' else '' end
    else (s / 86400) || ' hari' || case when (s % 86400) / 3600 > 0 then ' ' || (s % 86400) / 3600 || ' jam' else '' end
  end
  from (select greatest(0, extract(epoch from p_span))::bigint as s) x;
$$;

create or replace function private.health_service_label(p_service text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_service
    when 'media' then 'Upload media'
    when 'sentinel' then 'Pemantau sistem'
    when 'backup' then 'Backup'
    when 'notifier' then 'Notifier push'
    when 'janitor' then 'Pembersih storage'
    when 'auth-bridge' then 'Auth bridge'
    when 'nasabah-gateway' then 'Gateway nasabah'
    when 'rest' then 'API (PostgREST)'
    when 'auth' then 'Login staf (GoTrue)'
    when 'storage' then 'Storage'
    when 'realtime' then 'Realtime'
    when 'functions' then 'Edge Functions'
    when 'imgproxy' then 'Imgproxy'
    when 'kong' then 'Kong'
    when 'valkey' then 'Valkey'
    when 'pgbouncer' then 'PgBouncer'
    when 'db' then 'Database'
    when 'cs-console' then 'Web CS'
    else p_service
  end;
$$;

create or replace function public.service_heartbeat(
  p_service text, p_instance text, p_version text, p_started_at timestamptz,
  p_status text default 'ok', p_error text default null, p_detail jsonb default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(p_service, '') !~ '^[a-z][a-z0-9-]{1,39}$' or char_length(coalesce(p_instance, '')) not between 1 and 200 then
    perform private.api_error(400, 'invalid_heartbeat', 'Nama layanan atau instance tidak valid');
  end if;
  if coalesce(p_status, 'ok') not in ('ok', 'degraded', 'error') then
    perform private.api_error(400, 'invalid_heartbeat', 'Status harus ok, degraded, atau error');
  end if;
  insert into private.service_instances as s (service, instance, version, started_at, last_seen_at, status, error, detail)
  values (p_service, p_instance, left(p_version, 40), p_started_at, now(), coalesce(p_status, 'ok'),
          left(nullif(btrim(p_error), ''), 500),
          case when jsonb_typeof(p_detail) = 'object' and pg_column_size(p_detail) <= 8192 then p_detail else '{}' end)
  on conflict (service, instance) do update
     set version = excluded.version, started_at = excluded.started_at, last_seen_at = now(),
         status = excluded.status, error = excluded.error, detail = excluded.detail;
end;
$$;

create or replace function private.health_checks_services()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with expected as (
    select jsonb_array_elements_text(
             private.setting_json('health.expected_services', '["media","sentinel","backup","notifier"]')) as service
  ),
  live as (
    select s.service, s.status, s.error
    from private.service_instances s
    where s.last_seen_at > now() - interval '90 seconds'
    union all
    select 'notifier', case when p.error is null then 'ok' else 'degraded' end, p.error
    from private.push_instances p
    where p.seen_at > now() - interval '90 seconds'
  ),
  worst as (
    select distinct on (l.service) l.service, l.status, l.error
    from live l
    order by l.service, case l.status when 'error' then 0 when 'degraded' then 1 else 2 end
  )
  select 'service:' || e.service, 'critical',
         'Layanan ' || private.health_service_label(e.service) || ' tidak aktif',
         'Tidak ada heartbeat dalam 90 detik terakhir'
  from expected e
  where not exists (select 1 from live l where l.service = e.service)
  union all
  select 'service:' || w.service || ':status', case when w.status = 'error' then 'critical' else 'warning' end,
         'Layanan ' || private.health_service_label(w.service) || ' bermasalah',
         coalesce(w.error, 'Status ' || w.status)
  from worst w
  where w.status <> 'ok';
$$;

create or replace function private.health_checks_probes()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'probe:' || p.name, 'critical',
         private.health_service_label(p.name) || ' tidak merespons',
         coalesce(p.error, case when p.status is not null then 'HTTP ' || p.status end, 'Tidak ada respons')
  from private.health_probes p
  where not p.ok and p.checked_at > now() - interval '90 seconds';
$$;

create or replace function private.health_checks_disks()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'disk:' || d.name,
         case when d.used >= private.setting_num('health.disk_critical_ratio', 0.9) then 'critical' else 'warning' end,
         'Disk ' || d.name || ' hampir penuh',
         'Terpakai ' || round(d.used * 100) || '%, sisa ' || pg_catalog.pg_size_pretty(d.avail_bytes)
           || ' dari ' || pg_catalog.pg_size_pretty(d.total_bytes)
  from (select h.*, 1 - h.avail_bytes::numeric / nullif(h.total_bytes, 0) as used
        from private.health_disks h
        where h.checked_at > now() - interval '90 seconds') d
  where d.used >= private.setting_num('health.disk_warn_ratio', 0.8);
$$;

create or replace function private.health_checks_database()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with conn as (
    select count(*)::numeric as used, current_setting('max_connections')::numeric as max
    from pg_catalog.pg_stat_activity
  ),
  runs as (
    select distinct on (d.jobid) d.jobid, d.status, d.return_message, d.start_time
    from cron.job_run_details d
    where d.runid > coalesce((select max(x.runid) from cron.job_run_details x), 0) - 40000
    order by d.jobid, d.start_time desc
  )
  select 'db:connections', case when c.used / c.max >= 0.9 then 'critical' else 'warning' end,
         'Koneksi database hampir habis', c.used || ' dari ' || c.max || ' koneksi terpakai'
  from conn c
  where c.used / c.max >= 0.8
  union all
  select 'db:slot:' || s.slot_name, 'critical', 'Slot replikasi ' || s.slot_name || ' hilang',
         'WAL yang dibutuhkan slot sudah dihapus (max_slot_wal_keep_size terlampaui)'
  from pg_catalog.pg_replication_slots s
  where s.wal_status = 'lost'
  union all
  select 'db:slot:' || s.slot_name || ':retained', 'warning', 'Slot replikasi ' || s.slot_name || ' menahan WAL',
         pg_catalog.pg_size_pretty(pg_catalog.pg_wal_lsn_diff(pg_catalog.pg_current_wal_lsn(), s.restart_lsn))
           || ' WAL tertahan karena slot tidak aktif'
  from pg_catalog.pg_replication_slots s
  where not s.active and s.wal_status <> 'lost' and s.restart_lsn is not null
    and pg_catalog.pg_wal_lsn_diff(pg_catalog.pg_current_wal_lsn(), s.restart_lsn) > 256 * 1024 * 1024
  union all
  select 'db:long_transaction', 'warning', 'Transaksi database berjalan terlalu lama',
         count(*) || ' transaksi lebih dari 15 menit, terlama '
           || private.health_fmt_duration(max(now() - a.xact_start))
  from pg_catalog.pg_stat_activity a
  where a.backend_type = 'client backend' and a.state <> 'idle' and a.xact_start < now() - interval '15 minutes'
  having count(*) > 0
  union all
  select 'cron:' || j.jobname, 'warning', 'Job terjadwal ' || j.jobname || ' gagal',
         left(coalesce(r.return_message, 'Gagal tanpa pesan'), 300)
  from cron.job j
  join runs r on r.jobid = j.jobid
  where j.active and r.status = 'failed';
$$;

create or replace function private.health_checks_queues()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'queue:push', 'warning', 'Antrean push tertahan',
         count(*) || ' push menunggu lebih dari 10 menit'
  from private.push_queue q
  where q.status = 'queued' and q.available_at < now() - interval '10 minutes'
    and exists (select 1 from private.push_credentials c where c.secret_id is not null)
  having count(*) > 0
  union all
  select 'queue:storage_cleanup', 'warning', 'Pembersihan file storage gagal',
         count(*) || ' folder gagal dibersihkan berulang kali'
  from private.storage_cleanup_queue q
  where q.done_at is null and q.failures >= 3
  having count(*) > 0
  union all
  select 'alerts:delivery', 'warning', 'Alert gagal dikirim',
         count(*) || ' pesan alert gagal dikirim dalam 24 jam terakhir'
  from private.alert_deliveries d
  where d.status = 'failed' and d.created_at > now() - interval '24 hours' and d.kind <> 'test'
  having count(*) > 0;
$$;

create or replace function private.health_checks_backup()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select null::text, null::text, null::text, null::text where false;
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
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
$$;

create or replace function private.alert_message(p_alert private.health_alerts, p_kind text,
                                                 out subject text, out body text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_channels private.alert_channels;
  v_level    text := case when p_alert.severity = 'critical' then 'KRITIS' else 'PERINGATAN' end;
  v_icon     text := case when p_alert.severity = 'critical' then '🔴' else '🟠' end;
begin
  select * into v_channels from private.alert_channels c where c.singleton;
  if p_kind = 'resolved' then
    subject := '[' || v_channels.label || '] PULIH: ' || p_alert.title;
    body := '✅ PULIH — ' || p_alert.title || E'\n'
         || 'Lama gangguan: ' || private.health_fmt_duration(coalesce(p_alert.resolved_at, now()) - p_alert.opened_at) || E'\n'
         || 'Pulih: ' || private.health_fmt_time(coalesce(p_alert.resolved_at, now()));
  elsif p_kind = 'escalated' then
    subject := '[' || v_channels.label || '] MEMBURUK: ' || p_alert.title;
    body := '🔴 MEMBURUK — ' || p_alert.title || ' (sekarang kritis)' || E'\n'
         || coalesce(p_alert.detail || E'\n', '')
         || 'Sejak: ' || private.health_fmt_time(p_alert.opened_at);
  else
    subject := '[' || v_channels.label || '] ' || v_level || ': ' || p_alert.title;
    body := v_icon || ' ' || v_level || ' — ' || p_alert.title || E'\n'
         || coalesce(p_alert.detail || E'\n', '')
         || 'Sejak: ' || private.health_fmt_time(p_alert.opened_at);
  end if;
  if v_channels.console_url is not null then
    body := body || E'\nBuka: ' || rtrim(v_channels.console_url, '/') || '/system';
  end if;
end;
$$;

create or replace function private.alert_enqueue(p_alert_id bigint, p_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alert private.health_alerts;
  v_c     private.alert_channels;
  v_msg   record;
begin
  select * into v_alert from private.health_alerts a where a.id = p_alert_id;
  select * into v_c from private.alert_channels c where c.singleton;
  select * into v_msg from private.alert_message(v_alert, p_kind);
  if v_c.telegram_enabled and v_c.telegram_secret_id is not null and cardinality(v_c.telegram_chat_ids) > 0 then
    insert into private.alert_deliveries (alert_id, kind, channel, subject, body)
    values (p_alert_id, p_kind, 'telegram', v_msg.subject, v_msg.body);
  end if;
  if v_c.email_enabled and v_c.smtp_host is not null and cardinality(v_c.email_to) > 0 then
    insert into private.alert_deliveries (alert_id, kind, channel, subject, body)
    values (p_alert_id, p_kind, 'email', v_msg.subject, v_msg.body);
  end if;
end;
$$;

create or replace function private.health_evaluate()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_after   interval := make_interval(secs => private.setting_num('health.alert_after_seconds', 120));
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

  for v_check in select * from private.health_checks h where h.failing_since <= now() - v_after loop
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

create or replace function private.health_purge()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.alert_deliveries d where d.created_at < now() - interval '90 days';
  delete from private.health_alerts a where a.resolved_at < now() - interval '90 days';
$$;

create or replace function public.health_report(
  p_instance text, p_version text, p_started_at timestamptz, p_probes jsonb default '[]', p_disks jsonb default '[]'
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
  perform public.service_heartbeat('sentinel', p_instance, p_version, p_started_at, 'ok', null,
    jsonb_build_object('probes', jsonb_array_length(p_probes), 'disks', jsonb_array_length(p_disks)));

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

  perform private.health_evaluate();
  return jsonb_build_object('evaluated_at', now());
end;
$$;

create or replace function public.alert_channels(p_revision bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_c private.alert_channels;
begin
  select * into v_c from private.alert_channels c where c.singleton;
  if p_revision is not null and p_revision = v_c.revision then
    return jsonb_build_object('revision', v_c.revision, 'unchanged', true);
  end if;
  return jsonb_build_object(
    'revision', v_c.revision,
    'telegram', case when v_c.telegram_enabled and v_c.telegram_secret_id is not null then jsonb_build_object(
      'bot_token', (select s.decrypted_secret from vault.decrypted_secrets s where s.id = v_c.telegram_secret_id),
      'chat_ids', to_jsonb(v_c.telegram_chat_ids)) end,
    'email', case when v_c.email_enabled and v_c.smtp_host is not null then jsonb_build_object(
      'host', v_c.smtp_host, 'port', v_c.smtp_port, 'security', v_c.smtp_security,
      'username', v_c.smtp_username,
      'password', (select s.decrypted_secret from vault.decrypted_secrets s where s.id = v_c.smtp_secret_id),
      'from', v_c.email_from, 'to', to_jsonb(v_c.email_to)) end);
end;
$$;

create or replace function public.alert_claim(p_instance text, p_limit integer default 20, p_lease_seconds integer default 60)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 200 then
    perform private.api_error(400, 'invalid_instance', 'Instance tidak valid');
  end if;
  with c as (select * from private.alert_channels where singleton),
  picked as (
    select d.id
    from private.alert_deliveries d, c
    where d.status = 'pending' and d.available_at <= now()
      and (d.locked_until is null or d.locked_until < now())
      and ((d.channel = 'telegram' and c.telegram_enabled and c.telegram_secret_id is not null)
           or (d.channel = 'email' and c.email_enabled and c.smtp_host is not null))
    order by d.id
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
    for update of d skip locked
  ),
  claimed as (
    update private.alert_deliveries d
       set locked_until = now() + make_interval(secs => least(greatest(coalesce(p_lease_seconds, 60), 10), 600)),
           locked_by = p_instance, attempts = d.attempts + 1
      from picked
     where d.id = picked.id
    returning d.id, d.channel, d.subject, d.body
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'channel', channel, 'subject', subject, 'text', body)
                            order by id), '[]')
    into v_result
  from claimed;
  return v_result;
end;
$$;

create or replace function public.alert_report(p_instance text, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row   record;
  v_count integer := 0;
  v_n     integer;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_alert_report', 'Hasil harus berupa array');
  end if;
  for v_row in select * from jsonb_to_recordset(p_results) as x(id bigint, ok boolean, error text, retry boolean) loop
    update private.alert_deliveries d
       set status = case when coalesce(v_row.ok, false) then 'sent'
                         when coalesce(v_row.retry, true) and d.attempts < 8 then 'pending'
                         else 'failed' end,
           sent_at = case when coalesce(v_row.ok, false) then now() end,
           error = case when coalesce(v_row.ok, false) then null else left(coalesce(nullif(btrim(v_row.error), ''), 'Gagal'), 500) end,
           available_at = case when coalesce(v_row.ok, false) then d.available_at
                               else now() + least(interval '1 hour', interval '30 seconds' * power(2, greatest(d.attempts - 1, 0))) end,
           locked_until = null, locked_by = null
     where d.id = v_row.id and d.locked_by = p_instance and d.status = 'pending';
    get diagnostics v_n = row_count;
    v_count := v_count + v_n;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.backup_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select null::jsonb;
$$;

create or replace function cs.alert_channels_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'revision', c.revision, 'label', c.label, 'console_url', c.console_url,
    'updated_at', c.updated_at, 'updated_by', cs.agent_name(c.updated_by),
    'telegram', jsonb_build_object('enabled', c.telegram_enabled, 'token_set', c.telegram_secret_id is not null,
                                   'chat_ids', to_jsonb(c.telegram_chat_ids)),
    'email', jsonb_build_object('enabled', c.email_enabled, 'host', c.smtp_host, 'port', c.smtp_port,
                                'security', c.smtp_security, 'username', c.smtp_username,
                                'password_set', c.smtp_secret_id is not null, 'from', c.email_from,
                                'to', to_jsonb(c.email_to)),
    'last', jsonb_build_object(
      'telegram', (select jsonb_build_object('kind', d.kind, 'status', d.status, 'at', coalesce(d.sent_at, d.created_at),
                                             'error', d.error)
                   from private.alert_deliveries d where d.channel = 'telegram' order by d.id desc limit 1),
      'email', (select jsonb_build_object('kind', d.kind, 'status', d.status, 'at', coalesce(d.sent_at, d.created_at),
                                          'error', d.error)
                from private.alert_deliveries d where d.channel = 'email' order by d.id desc limit 1)))
  from private.alert_channels c
  where c.singleton;
$$;

create or replace function cs.vault_store_secret(p_secret_id uuid, p_value text, p_name text, p_description text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_secret_id is not null then
    perform vault.update_secret(p_secret_id, p_value);
    return p_secret_id;
  end if;
  delete from vault.secrets s where s.name = p_name;
  return vault.create_secret(p_value, p_name, p_description);
end;
$$;

create or replace function cs_api.alert_channels_view()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return cs.alert_channels_view();
end;
$$;

create or replace function cs_api.alert_set_telegram(p_enabled boolean, p_chat_ids text[], p_bot_token text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_c     private.alert_channels;
  v_token text := nullif(btrim(coalesce(p_bot_token, '')), '');
  v_chats text[] := coalesce((select array_agg(distinct btrim(x) order by btrim(x))
                              from unnest(coalesce(p_chat_ids, '{}')) x where btrim(x) <> ''), '{}');
begin
  if v_token is not null and v_token !~ '^[0-9]{5,16}:[A-Za-z0-9_-]{30,80}$' then
    perform private.api_error(400, 'invalid_telegram_token', 'Token bot Telegram tidak valid');
  end if;
  if cardinality(v_chats) > 5 or exists (select 1 from unnest(v_chats) x where x !~ '^(-?[0-9]{1,20}|@[A-Za-z0-9_]{5,32})$') then
    perform private.api_error(400, 'invalid_telegram_chat', 'Chat ID Telegram tidak valid (maks 5)');
  end if;
  select * into v_c from private.alert_channels c where c.singleton for update;
  if coalesce(p_enabled, false) and (v_token is null and v_c.telegram_secret_id is null or cardinality(v_chats) = 0) then
    perform private.api_error(400, 'telegram_incomplete', 'Isi token bot dan minimal satu chat ID');
  end if;
  if v_token is not null then
    v_c.telegram_secret_id := cs.vault_store_secret(v_c.telegram_secret_id, v_token, 'alerts.telegram_bot_token',
                                                    'Token bot Telegram untuk alert sistem');
  end if;
  update private.alert_channels c
     set telegram_enabled = coalesce(p_enabled, false), telegram_chat_ids = v_chats,
         telegram_secret_id = v_c.telegram_secret_id, revision = c.revision + 1, updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('alerts.telegram_set', null, null, jsonb_build_object(
    'enabled', coalesce(p_enabled, false), 'chat_ids', to_jsonb(v_chats), 'token_changed', v_token is not null));
  return cs.alert_channels_view();
end;
$$;

create or replace function cs_api.alert_set_email(
  p_enabled boolean, p_host text, p_port integer, p_security text, p_username text, p_from text, p_to text[],
  p_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_c     private.alert_channels;
  v_host  text := nullif(lower(btrim(coalesce(p_host, ''))), '');
  v_user  text := nullif(btrim(coalesce(p_username, '')), '');
  v_from  text := nullif(btrim(coalesce(p_from, '')), '');
  v_to    text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                              from unnest(coalesce(p_to, '{}')) x where btrim(x) <> ''), '{}');
  v_email text := '^[^@[:space:]]{1,64}@[A-Za-z0-9.-]{1,253}$';
begin
  if v_host is not null and v_host !~ '^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$' then
    perform private.api_error(400, 'invalid_smtp', 'Host SMTP tidak valid');
  end if;
  if p_port is not null and p_port not between 1 and 65535 then
    perform private.api_error(400, 'invalid_smtp', 'Port SMTP 1–65535');
  end if;
  if p_security is not null and p_security not in ('tls', 'starttls', 'none') then
    perform private.api_error(400, 'invalid_smtp', 'Keamanan SMTP harus tls, starttls, atau none');
  end if;
  if char_length(coalesce(v_user, '')) > 200 or char_length(coalesce(p_password, '')) > 500 then
    perform private.api_error(400, 'invalid_smtp', 'Username atau password SMTP terlalu panjang');
  end if;
  if v_from is not null and v_from !~ v_email or cardinality(v_to) > 10
     or exists (select 1 from unnest(v_to) x where x !~ v_email) then
    perform private.api_error(400, 'invalid_email_address', 'Alamat email tidak valid (maks 10 penerima)');
  end if;
  if coalesce(p_enabled, false) and (v_host is null or p_port is null or p_security is null or v_from is null
                                     or cardinality(v_to) = 0) then
    perform private.api_error(400, 'email_incomplete', 'Isi host, port, keamanan, pengirim, dan minimal satu penerima');
  end if;
  select * into v_c from private.alert_channels c where c.singleton for update;
  if p_password is not null then
    if p_password = '' then
      delete from vault.secrets s where s.id = v_c.smtp_secret_id;
      v_c.smtp_secret_id := null;
    else
      v_c.smtp_secret_id := cs.vault_store_secret(v_c.smtp_secret_id, p_password, 'alerts.smtp_password',
                                                  'Password SMTP untuk alert sistem');
    end if;
  end if;
  update private.alert_channels c
     set email_enabled = coalesce(p_enabled, false), smtp_host = v_host, smtp_port = p_port, smtp_security = p_security,
         smtp_username = v_user, smtp_secret_id = v_c.smtp_secret_id, email_from = v_from, email_to = v_to,
         revision = c.revision + 1, updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('alerts.email_set', null, null, jsonb_build_object(
    'enabled', coalesce(p_enabled, false), 'host', v_host, 'port', p_port, 'security', p_security,
    'from', v_from, 'to', to_jsonb(v_to), 'password_changed', p_password is not null));
  return cs.alert_channels_view();
end;
$$;

create or replace function cs_api.alert_set_options(p_label text, p_console_url text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_label text := btrim(coalesce(p_label, ''));
  v_url   text := nullif(rtrim(btrim(coalesce(p_console_url, '')), '/'), '');
begin
  if char_length(v_label) not between 1 and 40 then
    perform private.api_error(400, 'invalid_alert_label', 'Label 1–40 karakter');
  end if;
  if v_url is not null and v_url !~ '^https?://[^[:space:]]{1,200}$' then
    perform private.api_error(400, 'invalid_console_url', 'Alamat web CS harus diawali http:// atau https://');
  end if;
  update private.alert_channels c
     set label = v_label, console_url = v_url, revision = c.revision + 1, updated_by = v_me, updated_at = now()
   where c.singleton;
  perform cs.audit('alerts.options_set', null, null, jsonb_build_object('label', v_label, 'console_url', v_url));
  return cs.alert_channels_view();
end;
$$;

create or replace function cs_api.alert_send_test(p_channel text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_c    private.alert_channels;
  v_name text := cs.agent_name(v_me);
begin
  select * into v_c from private.alert_channels c where c.singleton;
  if p_channel = 'telegram' then
    if not (v_c.telegram_enabled and v_c.telegram_secret_id is not null) then
      perform private.api_error(409, 'alert_channel_disabled', 'Aktifkan dan simpan kanal Telegram dulu');
    end if;
  elsif p_channel = 'email' then
    if not (v_c.email_enabled and v_c.smtp_host is not null) then
      perform private.api_error(409, 'alert_channel_disabled', 'Aktifkan dan simpan kanal email dulu');
    end if;
  else
    perform private.api_error(400, 'invalid_alert_channel', 'Kanal harus telegram atau email');
  end if;
  if exists (select 1 from private.alert_deliveries d
             where d.kind = 'test' and d.channel = p_channel and d.created_at > now() - interval '20 seconds') then
    perform private.api_error(429, 'too_many_requests', 'Tunggu sebentar sebelum mengirim uji lagi');
  end if;
  insert into private.alert_deliveries (kind, channel, subject, body, created_by)
  values ('test', p_channel, '[' || v_c.label || '] Uji alert',
          '🧪 Uji alert dari Kesehatan sistem web CS' || E'\n'
          || 'Dikirim oleh ' || coalesce(v_name, 'Super Admin') || ' pada ' || private.health_fmt_time(now()) || E'\n'
          || 'Bila pesan ini sampai, kanal ' || case p_channel when 'telegram' then 'Telegram' else 'email' end
          || ' sudah benar.',
          v_me);
  perform cs.audit('alerts.test_sent', null, null, jsonb_build_object('channel', p_channel));
  return cs.alert_channels_view();
end;
$$;

create or replace function cs.health_status_of(p_checks jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when exists (select 1 from jsonb_array_elements(p_checks) c where c ->> 'severity' = 'critical') then 'critical'
    when jsonb_array_length(p_checks) > 0 then 'warning'
    else 'ok'
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
  v_me     uuid := cs.require_agent('{cs_super_admin}');
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

create or replace function cs_api.system_health_badge()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return (select jsonb_build_object(
    'critical', count(*) filter (where a.severity = 'critical' and a.acknowledged_at is null),
    'warning', count(*) filter (where a.severity = 'warning' and a.acknowledged_at is null),
    'open', count(*))
  from private.health_alerts a where a.resolved_at is null);
end;
$$;

create or replace function cs_api.health_acknowledge(p_alert_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_alert private.health_alerts;
begin
  select * into v_alert from private.health_alerts a where a.id = p_alert_id and a.resolved_at is null for update;
  if not found then
    perform private.api_error(404, 'alert_not_found', 'Alert tidak ditemukan atau sudah pulih');
  end if;
  update private.health_alerts a set acknowledged_by = v_me, acknowledged_at = now() where a.id = p_alert_id;
  perform cs.audit('health.alert_acknowledged', null, null,
                   jsonb_build_object('alert', p_alert_id, 'key', v_alert.key, 'title', v_alert.title));
end;
$$;

select cron.schedule('health-evaluate', '* * * * *', 'select private.health_evaluate()');
select cron.schedule('health-purge', '41 3 * * *', 'select private.health_purge()');

revoke execute on function private.health_fmt_time(timestamptz) from public;
revoke execute on function private.health_fmt_duration(interval) from public;
revoke execute on function private.health_service_label(text) from public;
revoke execute on function private.health_checks_services() from public;
revoke execute on function private.health_checks_probes() from public;
revoke execute on function private.health_checks_disks() from public;
revoke execute on function private.health_checks_database() from public;
revoke execute on function private.health_checks_queues() from public;
revoke execute on function private.health_checks_backup() from public;
revoke execute on function private.health_current() from public;
revoke execute on function private.alert_message(private.health_alerts, text) from public;
revoke execute on function private.alert_enqueue(bigint, text) from public;
revoke execute on function private.health_evaluate() from public;
revoke execute on function private.health_purge() from public;
revoke execute on function cs.backup_summary() from public;
revoke execute on function cs.alert_channels_view() from public;
revoke execute on function cs.vault_store_secret(uuid, text, text, text) from public;
revoke execute on function cs.health_status_of(jsonb) from public;
revoke execute on function public.service_heartbeat(text, text, text, timestamptz, text, text, jsonb)
  from public, anon, authenticated;
revoke execute on function public.health_report(text, text, timestamptz, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.alert_channels(bigint) from public, anon, authenticated;
revoke execute on function public.alert_claim(text, integer, integer) from public, anon, authenticated;
revoke execute on function public.alert_report(text, jsonb) from public, anon, authenticated;
revoke execute on function cs_api.alert_channels_view() from public;
revoke execute on function cs_api.alert_set_telegram(boolean, text[], text) from public;
revoke execute on function cs_api.alert_set_email(boolean, text, integer, text, text, text, text[], text) from public;
revoke execute on function cs_api.alert_set_options(text, text) from public;
revoke execute on function cs_api.alert_send_test(text) from public;
revoke execute on function cs_api.system_health() from public;
revoke execute on function cs_api.system_health_badge() from public;
revoke execute on function cs_api.health_acknowledge(bigint) from public;

grant execute on function public.service_heartbeat(text, text, text, timestamptz, text, text, jsonb) to service_role;
grant execute on function public.health_report(text, text, timestamptz, jsonb, jsonb) to service_role;
grant execute on function public.alert_channels(bigint) to service_role;
grant execute on function public.alert_claim(text, integer, integer) to service_role;
grant execute on function public.alert_report(text, jsonb) to service_role;
grant execute on function cs_api.alert_channels_view() to authenticated;
grant execute on function cs_api.alert_set_telegram(boolean, text[], text) to authenticated;
grant execute on function cs_api.alert_set_email(boolean, text, integer, text, text, text, text[], text) to authenticated;
grant execute on function cs_api.alert_set_options(text, text) to authenticated;
grant execute on function cs_api.alert_send_test(text) to authenticated;
grant execute on function cs_api.system_health() to authenticated;
grant execute on function cs_api.system_health_badge() to authenticated;
grant execute on function cs_api.health_acknowledge(bigint) to authenticated;
