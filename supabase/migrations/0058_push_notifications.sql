insert into private.settings (key, value, description) values
  ('push.ttl_hours', '24', 'Push yang belum terkirim setelah sekian jam dibatalkan'),
  ('push.max_attempts', '6', 'Batas percobaan kirim satu push sebelum dianggap gagal'),
  ('push.retention_days', '7', 'Riwayat antrean push disimpan selama sekian hari'),
  ('push.device_stale_days', '270', 'Perangkat yang tidak membuka aplikasi selama sekian hari dilepas dari push'),
  ('push.max_devices_per_user', '10', 'Batas perangkat push per pengguna; yang paling lama tidak aktif dilepas')
on conflict (key) do nothing;

delete from cs.cs_settings where key = 'community.push_ready';

create table private.push_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  token        text not null unique check (char_length(token) between 20 and 4096),
  platform     text not null check (platform in ('android', 'ios', 'web')),
  locale       text not null default 'id' check (locale in ('id', 'en')),
  app_version  text check (char_length(app_version) <= 40),
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index push_devices_user_idx on private.push_devices (user_id, last_seen_at desc);
create index push_devices_seen_idx on private.push_devices (last_seen_at);

create table private.push_queue (
  id           bigint generated always as identity primary key,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  device_id    uuid references private.push_devices(id) on delete set null,
  kind         text not null check (kind ~ '^[a-z][a-z0-9_.]{1,39}$'),
  ref          text check (char_length(ref) <= 100),
  title        text not null check (char_length(title) between 1 and 200),
  body         text not null check (char_length(body) <= 1000),
  data         jsonb not null default '{}' check (jsonb_typeof(data) = 'object'),
  collapse_key text check (char_length(collapse_key) <= 64),
  badge        integer check (badge >= 0),
  priority     text not null default 'high' check (priority in ('high', 'normal')),
  status       text not null default 'queued'
               check (status in ('queued', 'sent', 'failed', 'invalid', 'expired', 'cancelled')),
  attempts     smallint not null default 0,
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text,
  expires_at   timestamptz not null,
  created_at   timestamptz not null default now(),
  finished_at  timestamptz,
  error        text check (char_length(error) <= 500)
);
create index push_queue_ready_idx on private.push_queue (available_at, id) where status = 'queued';
create index push_queue_finished_idx on private.push_queue (finished_at) where status <> 'queued';
create index push_queue_user_idx on private.push_queue (user_id);
create index push_queue_device_idx on private.push_queue (device_id) where device_id is not null;
create index push_queue_ref_idx on private.push_queue (ref) where ref is not null;

create table private.push_ref_stats (
  ref        text primary key,
  sent       integer not null default 0,
  failed     integer not null default 0,
  invalid    integer not null default 0,
  expired    integer not null default 0,
  cancelled  integer not null default 0,
  updated_at timestamptz not null default now()
);

create table private.push_instances (
  instance_id text primary key check (char_length(instance_id) between 1 and 100),
  version     text check (char_length(version) <= 40),
  configured  boolean not null,
  project_id  text check (char_length(project_id) <= 100),
  error       text check (char_length(error) <= 500),
  started_at  timestamptz not null,
  seen_at     timestamptz not null default now()
);

alter table private.push_devices enable row level security;
alter table private.push_queue enable row level security;
alter table private.push_ref_stats enable row level security;
alter table private.push_instances enable row level security;

create or replace function private.push_text(p_value jsonb, p_locale text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case jsonb_typeof(p_value)
    when 'string' then p_value #>> '{}'
    when 'object' then coalesce(p_value ->> p_locale, p_value ->> 'id', p_value ->> 'en')
  end;
$$;

create or replace function private.push_data(p_data jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e.key, case when jsonb_typeof(e.value) = 'string' then e.value
                                               else to_jsonb(e.value::text) end), '{}')
  from jsonb_each(coalesce(p_data, '{}')) e
  where jsonb_typeof(e.value) <> 'null';
$$;

create or replace function private.push_enqueue(p_user_id uuid, p_kind text, p_title jsonb, p_body jsonb,
                                                p_data jsonb default '{}', p_options jsonb default '{}')
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_collapse text := nullif(btrim(coalesce(p_options ->> 'collapse_key', '')), '');
  v_ttl      integer := coalesce((p_options ->> 'ttl_seconds')::integer,
                                 (private.setting_num('push.ttl_hours', 24) * 3600)::integer);
  v_priority text := case when p_options ->> 'priority' = 'normal' then 'normal' else 'high' end;
  v_badge    integer;
  v_count    integer;
begin
  if p_user_id is null or not exists (select 1 from private.push_devices d where d.user_id = p_user_id) then
    return 0;
  end if;
  if coalesce((p_options ->> 'badge')::boolean, true) then
    select count(*) into v_badge from public.notifications n where n.user_id = p_user_id and n.read_at is null;
  end if;
  if char_length(v_collapse) > 64 then
    v_collapse := md5(v_collapse);
  end if;
  insert into private.push_queue (user_id, device_id, kind, ref, title, body, data, collapse_key, badge, priority,
                                  expires_at)
  select p_user_id, d.id, p_kind, left(nullif(btrim(coalesce(p_options ->> 'ref', '')), ''), 100),
         left(coalesce(nullif(btrim(private.push_text(p_title, d.locale)), ''),
                       case d.locale when 'en' then 'New notification' else 'Notifikasi baru' end), 200),
         left(coalesce(private.push_text(p_body, d.locale), ''), 1000),
         private.push_data(coalesce(p_data, '{}') || jsonb_build_object('kind', p_kind)),
         v_collapse, v_badge, v_priority,
         now() + make_interval(secs => greatest(60, least(v_ttl, 2419200)))
  from private.push_devices d
  where d.user_id = p_user_id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.notification_push(n public.notifications)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name     text;
  v_username text;
  v_id       text;
  v_en       text;
  v_others   integer := n.event_count - 1;
  v_snippet  text := coalesce(n.payload ->> 'snippet', '');
  v_snip_en  text;
  v_room     text := nullif(btrim(coalesce(n.payload ->> 'room_name', '')), '');
  v_title    jsonb;
  v_body     jsonb;
begin
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text), p.username::text into v_name, v_username
  from public.profiles p where p.id = n.actor_id;
  v_id := coalesce(v_name, 'Seseorang');
  v_en := coalesce(v_name, 'Someone');
  v_snip_en := case when v_snippet = '[lampiran]' then '[attachment]' else v_snippet end;
  v_body := jsonb_build_object('id', v_snippet, 'en', v_snip_en);

  case n.type
    when 'reply' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya membalas postingan Anda', v_id, v_others),
                                'en', format('%s and %s others replied to your post', v_en, v_others))
        else jsonb_build_object('id', format('%s membalas Anda', v_id), 'en', format('%s replied to you', v_en)) end;
    when 'mention' then
      v_title := jsonb_build_object('id', format('%s menyebut Anda', v_id), 'en', format('%s mentioned you', v_en));
    when 'like' then
      v_title := case when v_others > 0
        then jsonb_build_object('id', format('%s dan %s lainnya menyukai konten Anda', v_id, v_others),
                                'en', format('%s and %s others liked your content', v_en, v_others))
        else jsonb_build_object('id', format('%s menyukai konten Anda', v_id),
                                'en', format('%s liked your content', v_en)) end;
    when 'follow' then
      v_title := jsonb_build_object('id', format('%s mulai mengikuti Anda', v_id),
                                    'en', format('%s started following you', v_en));
      v_body := '""';
    when 'message' then
      if n.payload ->> 'room_type' = 'support' then
        v_title := to_jsonb(coalesce(v_room, cs.setting('brand.support_name') #>> '{}', 'Customer Service'));
      elsif n.payload ->> 'room_type' = 'group' then
        v_title := to_jsonb(coalesce(v_room, v_id));
        v_body := jsonb_build_object('id', format('%s: %s', v_id, v_snippet), 'en', format('%s: %s', v_en, v_snip_en));
      elsif n.event_count > 1 then
        v_title := jsonb_build_object('id', format('%s · %s pesan baru', v_id, n.event_count),
                                      'en', format('%s · %s new messages', v_en, n.event_count));
      else
        v_title := jsonb_build_object('id', v_id, 'en', v_en);
      end if;
    when 'announcement' then
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          jsonb_build_object('id', format('%s membuat pengumuman', v_id),
                                             'en', format('%s posted an announcement', v_en)));
      v_body := to_jsonb(coalesce(n.payload ->> 'body', ''));
    else
      v_title := coalesce(to_jsonb(nullif(btrim(coalesce(n.payload ->> 'title', '')), '')),
                          '{"id": "Notifikasi baru", "en": "New notification"}'::jsonb);
      v_body := coalesce(to_jsonb(n.payload ->> 'body'), v_body);
  end case;

  return private.push_enqueue(
    n.user_id, n.type, v_title, v_body,
    (select coalesce(jsonb_object_agg(e.key, e.value), '{}') from jsonb_each(n.payload) e
      where e.key not in ('title', 'body', 'snippet'))
      || jsonb_build_object('source', 'rendezvous_community', 'type', n.type, 'notification_id', n.id,
                            'actor_id', n.actor_id, 'actor_username', v_username),
    jsonb_build_object(
      'collapse_key', n.group_key,
      'priority', case when n.type in ('like', 'follow') then 'normal' else 'high' end,
      'ref', case when n.payload ? 'campaign_id' then 'campaign:' || (n.payload ->> 'campaign_id') end));
end;
$$;

create or replace function private.notifications_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT'
     or (new.event_count > old.event_count and new.read_at is null and new.type not in ('like', 'follow')) then
    perform private.notification_push(new);
  end if;
  return null;
end;
$$;

create trigger notifications_push
  after insert or update of event_count on public.notifications
  for each row execute function private.notifications_push();

create or replace function private.push_forget_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.push_queue where user_id = new.id;
  delete from private.push_devices where user_id = new.id;
  return null;
end;
$$;

create trigger profiles_push_forget
  after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function private.push_forget_profile();

create or replace function private.push_count_finished(p_ids bigint[])
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.push_ref_stats as s (ref, sent, failed, invalid, expired, cancelled)
  select q.ref,
         count(*) filter (where q.status = 'sent'),
         count(*) filter (where q.status = 'failed'),
         count(*) filter (where q.status = 'invalid'),
         count(*) filter (where q.status = 'expired'),
         count(*) filter (where q.status = 'cancelled')
  from private.push_queue q
  where q.id = any(p_ids) and q.ref is not null and q.status <> 'queued'
  group by q.ref
  on conflict (ref) do update
     set sent = s.sent + excluded.sent, failed = s.failed + excluded.failed, invalid = s.invalid + excluded.invalid,
         expired = s.expired + excluded.expired, cancelled = s.cancelled + excluded.cancelled, updated_at = now();
$$;

create or replace function public.register_push_device(p_token text, p_platform text, p_locale text default 'id',
                                                       p_app_version text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_token  text := btrim(coalesce(p_token, ''));
  v_locale text := case when lower(left(coalesce(p_locale, ''), 2)) = 'en' then 'en' else 'id' end;
  v_old    private.push_devices;
  v_device private.push_devices;
  v_done   bigint[];
begin
  if v_uid is null or not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if char_length(v_token) not between 20 and 4096 or v_token ~ '\s' then
    perform private.api_error(400, 'invalid_push_token', 'Token push tidak valid');
  end if;
  if p_platform is null or p_platform not in ('android', 'ios', 'web') then
    perform private.api_error(400, 'invalid_platform', 'Platform push harus android, ios, atau web');
  end if;

  select * into v_old from private.push_devices d where d.token = v_token for update;
  if found and v_old.user_id <> v_uid then
    with cancelled as (
      update private.push_queue q
         set status = 'cancelled', finished_at = now(), locked_until = null, error = 'Perangkat berganti akun'
       where q.device_id = v_old.id and q.status = 'queued'
      returning q.id)
    select array_agg(id) into v_done from cancelled;
    perform private.push_count_finished(v_done);
  end if;

  insert into private.push_devices as d (user_id, token, platform, locale, app_version)
  values (v_uid, v_token, p_platform, v_locale, nullif(left(btrim(coalesce(p_app_version, '')), 40), ''))
  on conflict (token) do update
     set user_id = excluded.user_id, platform = excluded.platform, locale = excluded.locale,
         app_version = excluded.app_version, last_seen_at = now(),
         created_at = case when d.user_id = excluded.user_id then d.created_at else now() end
  returning d.* into v_device;

  delete from private.push_devices d
   where d.id in (select x.id from private.push_devices x
                  where x.user_id = v_uid
                  order by x.last_seen_at desc, x.created_at desc
                  offset greatest(1, private.setting_num('push.max_devices_per_user', 10)::integer));

  return jsonb_build_object('id', v_device.id, 'platform', v_device.platform, 'locale', v_device.locale);
end;
$$;

create or replace function public.unregister_push_device(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device private.push_devices;
  v_done   bigint[];
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_device from private.push_devices d
   where d.token = btrim(coalesce(p_token, '')) and d.user_id = auth.uid();
  if not found then
    return;
  end if;
  with cancelled as (
    update private.push_queue q
       set status = 'cancelled', finished_at = now(), locked_until = null, error = 'Perangkat keluar dari akun'
     where q.device_id = v_device.id and q.status = 'queued'
    returning q.id)
  select array_agg(id) into v_done from cancelled;
  perform private.push_count_finished(v_done);
  delete from private.push_devices where id = v_device.id;
end;
$$;

create or replace function public.push_claim(p_instance text, p_limit integer default 100,
                                             p_lease_seconds integer default 60)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jobs jsonb;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance notifier tidak valid');
  end if;
  with picked as (
    select q.id
    from private.push_queue q
    where q.status = 'queued'
      and q.available_at <= now()
      and q.expires_at > now()
      and q.device_id is not null
      and (q.locked_until is null or q.locked_until < now())
    order by q.available_at, q.id
    limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ), claimed as (
    update private.push_queue q
       set locked_until = now() + make_interval(secs => greatest(10, least(coalesce(p_lease_seconds, 60), 600))),
           locked_by = p_instance,
           attempts = q.attempts + 1
      from picked
     where q.id = picked.id
    returning q.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'token', d.token, 'platform', d.platform, 'kind', c.kind, 'title', c.title, 'body', c.body,
           'data', c.data, 'collapse_key', c.collapse_key, 'badge', c.badge, 'priority', c.priority,
           'ttl_seconds', greatest(0, floor(extract(epoch from c.expires_at - now())))::integer,
           'attempt', c.attempts) order by c.id), '[]')
    into v_jobs
  from claimed c
  join private.push_devices d on d.id = c.device_id;
  return v_jobs;
end;
$$;

create or replace function public.push_report(p_instance text, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max     integer := private.setting_num('push.max_attempts', 6)::integer;
  v_done    bigint[] := '{}';
  v_count   integer := 0;
  r         record;
  v_row     private.push_queue;
  v_outcome text;
  v_delay   double precision;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_results', 'Hasil kirim harus berupa array');
  end if;
  for r in
    select x.id, x.outcome, left(nullif(btrim(coalesce(x.error, '')), ''), 500) as error, x.retry_after
    from jsonb_to_recordset(p_results) as x(id bigint, outcome text, error text, retry_after integer)
  loop
    select * into v_row from private.push_queue q
     where q.id = r.id and q.status = 'queued' and q.locked_by = p_instance
     for update;
    continue when not found;

    v_outcome := case when r.outcome = 'retry' and v_row.attempts >= v_max then 'failed' else r.outcome end;

    case v_outcome
      when 'sent' then
        update private.push_queue
           set status = 'sent', finished_at = now(), locked_until = null, error = null
         where id = r.id;
        v_done := v_done || r.id;
      when 'failed' then
        update private.push_queue
           set status = 'failed', finished_at = now(), locked_until = null, error = r.error
         where id = r.id;
        v_done := v_done || r.id;
      when 'invalid' then
        with invalidated as (
          update private.push_queue q
             set status = 'invalid', finished_at = now(), locked_until = null,
                 error = coalesce(r.error, 'Token perangkat tidak berlaku')
           where q.device_id = v_row.device_id and q.status = 'queued'
          returning q.id)
        select v_done || coalesce(array_agg(id), '{}') into v_done from invalidated;
        delete from private.push_devices where id = v_row.device_id;
      when 'retry' then
        v_delay := coalesce(greatest(1, least(r.retry_after, 3600)),
                            least(1800, 30 * power(2, greatest(v_row.attempts - 1, 0))) * (0.8 + random() * 0.4));
        update private.push_queue
           set available_at = now() + make_interval(secs => v_delay), locked_until = null, locked_by = null,
               error = r.error
         where id = r.id;
      when 'release' then
        update private.push_queue
           set attempts = greatest(0, attempts - 1),
               available_at = now() + make_interval(secs => coalesce(greatest(1, least(r.retry_after, 3600)), 30)),
               locked_until = null, locked_by = null, error = r.error
         where id = r.id;
      else
        continue;
    end case;
    v_count := v_count + 1;
  end loop;
  perform private.push_count_finished(v_done);
  return v_count;
end;
$$;

create or replace function public.push_heartbeat(p_instance text, p_version text, p_configured boolean,
                                                 p_project_id text default null, p_error text default null,
                                                 p_started_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance notifier tidak valid');
  end if;
  insert into private.push_instances (instance_id, version, configured, project_id, error, started_at, seen_at)
  values (p_instance, left(p_version, 40), coalesce(p_configured, false), left(nullif(p_project_id, ''), 100),
          left(nullif(btrim(coalesce(p_error, '')), ''), 500), coalesce(p_started_at, now()), now())
  on conflict (instance_id) do update
     set version = excluded.version, configured = excluded.configured, project_id = excluded.project_id,
         error = excluded.error, started_at = excluded.started_at, seen_at = now();
  return jsonb_build_object(
    'queued', (select count(*) from private.push_queue q where q.status = 'queued' and q.expires_at > now()));
end;
$$;

create or replace function private.push_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_done    bigint[];
  v_expired integer;
  v_purged  integer;
  v_devices integer;
begin
  with closed as (
    update private.push_queue q
       set status = case when q.device_id is null then 'cancelled' else 'expired' end,
           finished_at = now(), locked_until = null
     where q.status = 'queued'
       and (q.expires_at <= now() or (q.device_id is null and (q.locked_until is null or q.locked_until < now())))
    returning q.id)
  select array_agg(id), count(*) into v_done, v_expired from closed;
  perform private.push_count_finished(v_done);

  delete from private.push_queue
   where id in (select q.id from private.push_queue q
                where q.status <> 'queued'
                  and q.finished_at < now() - make_interval(days => private.setting_num('push.retention_days', 7)::integer)
                limit 20000);
  get diagnostics v_purged = row_count;

  delete from private.push_devices
   where last_seen_at < now() - make_interval(days => private.setting_num('push.device_stale_days', 270)::integer);
  get diagnostics v_devices = row_count;

  delete from private.push_instances where seen_at < now() - interval '1 day';
  delete from private.push_ref_stats where updated_at < now() - interval '400 days';

  return jsonb_build_object('closed', v_expired, 'purged', v_purged, 'stale_devices', v_devices);
end;
$$;

select cron.schedule('push-maintenance', '* * * * *', 'select private.push_maintenance()');

create or replace function cs.push_state()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with live as (
    select i.configured, i.error from private.push_instances i where i.seen_at > now() - interval '90 seconds')
  select case
    when not exists (select 1 from live) then 'offline'
    when exists (select 1 from live where configured and error is null) then 'active'
    when exists (select 1 from live where configured) then 'error'
    else 'not_configured'
  end;
$$;

create or replace function cs.push_ref_view(p_ref text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'sent', coalesce(s.sent, 0), 'failed', coalesce(s.failed, 0), 'invalid', coalesce(s.invalid, 0),
    'expired', coalesce(s.expired, 0), 'cancelled', coalesce(s.cancelled, 0),
    'queued', (select count(*) from private.push_queue q
               where q.ref = p_ref and q.status = 'queued' and q.expires_at > now()))
  from (select 1) one
  left join private.push_ref_stats s on s.ref = p_ref;
$$;

create or replace function cs_api.push_status()
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
    'state', cs.push_state(),
    'instances', coalesce((
      select jsonb_agg(jsonb_build_object(
               'instance', i.instance_id, 'version', i.version, 'configured', i.configured,
               'project_id', i.project_id, 'error', i.error, 'started_at', i.started_at, 'seen_at', i.seen_at,
               'live', i.seen_at > now() - interval '90 seconds') order by i.seen_at desc)
      from private.push_instances i where i.seen_at > now() - interval '1 hour'), '[]'),
    'devices', (
      select jsonb_build_object(
               'total', count(*), 'users', count(distinct d.user_id),
               'android', count(*) filter (where d.platform = 'android'),
               'ios', count(*) filter (where d.platform = 'ios'),
               'web', count(*) filter (where d.platform = 'web'),
               'active_30d', count(*) filter (where d.last_seen_at > now() - interval '30 days'))
      from private.push_devices d),
    'queue', (
      select jsonb_build_object('queued', count(*), 'oldest_at', min(q.created_at))
      from private.push_queue q where q.status = 'queued' and q.expires_at > now()),
    'last_24h', (
      select jsonb_build_object(
               'sent', count(*) filter (where q.status = 'sent'),
               'failed', count(*) filter (where q.status = 'failed'),
               'invalid', count(*) filter (where q.status = 'invalid'),
               'expired', count(*) filter (where q.status in ('expired', 'cancelled')))
      from private.push_queue q where q.status <> 'queued' and q.finished_at > now() - interval '24 hours'),
    'last_sent_at', (select max(q.finished_at) from private.push_queue q where q.status = 'sent'),
    'last_error', (
      select jsonb_build_object('at', q.finished_at, 'kind', q.kind, 'error', q.error)
      from private.push_queue q
      where q.status = 'failed' and q.error is not null
      order by q.finished_at desc limit 1),
    'ttl_hours', private.setting_num('push.ttl_hours', 24),
    'max_attempts', private.setting_num('push.max_attempts', 6));
end;
$$;

create or replace function cs_api.push_find_users(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_text text := ltrim(btrim(coalesce(p_query, '')), '@');
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(v_text, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', p.id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
             'devices', (select jsonb_agg(jsonb_build_object('platform', d.platform, 'app_version', d.app_version,
                                                             'last_seen_at', d.last_seen_at)
                                          order by d.last_seen_at desc)
                         from private.push_devices d where d.user_id = p.id))
           order by p.username)
    from (select x.* from public.profiles x
          where x.deleted_at is null
            and exists (select 1 from private.push_devices d where d.user_id = x.id)
            and (x.username::text ilike v_like or x.display_name ilike v_like)
          order by (x.username::text ilike v_text) desc, x.username
          limit 10) p), '[]');
end;
$$;

create or replace function cs_api.push_test(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_name  text := cs.agent_name(v_me);
  v_count integer;
begin
  if not exists (select 1 from private.push_devices d where d.user_id = p_user_id) then
    perform private.api_error(404, 'no_push_devices', 'Pengguna ini belum punya perangkat terdaftar untuk push');
  end if;
  v_count := private.push_enqueue(
    p_user_id, 'test',
    '{"id": "Tes push notification", "en": "Push notification test"}',
    jsonb_build_object(
      'id', format('Dikirim dari web CS oleh %s. Bila pesan ini muncul, push sudah berjalan.', v_name),
      'en', format('Sent from the CS console by %s. If you can read this, push is working.', v_name)),
    '{"source": "rendezvous_community"}',
    '{"ref": "test", "badge": false, "ttl_seconds": 600}');
  perform cs.audit('push.test', null, p_user_id, jsonb_build_object('devices', v_count));
  return jsonb_build_object('queued', v_count);
end;
$$;

create or replace function cs_api.community_campaign_push(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post,community.publish}');
begin
  if not exists (select 1 from cs.community_campaigns c where c.id = p_id) then
    perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
  end if;
  return cs.push_ref_view('campaign:' || p_id) || jsonb_build_object('state', cs.push_state());
end;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent();
  v_ready boolean := cs.nasabah_ready();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'nasabah_permissions', case when v_ready then to_jsonb(a.nasabah_permissions) else '[]'::jsonb end,
      'community_permissions', to_jsonb(a.community_permissions),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes'),
        'nasabah_ready', v_ready,
        'community_four_eyes', coalesce((cs.setting('community.four_eyes') #>> '{}')::boolean, true),
        'community_push_ready', cs.push_state() = 'active'))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.community_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return jsonb_build_object(
    'pending_posts', (select count(*) from cs.community_posts where status = 'pending'),
    'scheduled_posts', (select count(*) from cs.community_posts where status = 'scheduled'),
    'pending_campaigns', (select count(*) from cs.community_campaigns where status = 'pending'),
    'open_reports', (select count(distinct (r.target_type, r.target_id)) from public.reports r
                     where r.status in ('open', 'reviewing')),
    'accounts', (select count(*) from cs.official_accounts where disabled_at is null),
    'four_eyes', cs.four_eyes(),
    'push_ready', cs.push_state() = 'active',
    'push_state', cs.push_state());
end;
$$;

create or replace function cs_api.community_save_account(p_id uuid, p_username text, p_display_name text,
                                                          p_bio text default null, p_avatar_url text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.accounts}');
  v_username text := btrim(coalesce(p_username, ''));
  v_name     text := btrim(coalesce(p_display_name, ''));
  v_bio      text := nullif(btrim(coalesce(p_bio, '')), '');
  v_avatar   text := nullif(btrim(coalesce(p_avatar_url, '')), '');
  v_id       uuid := p_id;
  v_old      public.profiles;
  v_changes  jsonb := '{}';
begin
  if v_username !~ '^[A-Za-z0-9_]{3,30}$' then
    perform private.api_error(400, 'invalid_username', 'Username 3–30 karakter: huruf, angka, atau garis bawah');
  end if;
  if char_length(v_name) not between 2 and 60 then
    perform private.api_error(400, 'invalid_name', 'Nama akun 2–60 karakter');
  end if;
  if char_length(coalesce(v_bio, '')) > 300 then
    perform private.api_error(400, 'invalid_bio', 'Bio maksimal 300 karakter');
  end if;
  if exists (select 1 from public.profiles p
             where p.username = v_username::extensions.citext and p.id is distinct from v_id) then
    perform private.api_error(409, 'username_taken', 'Username sudah dipakai');
  end if;

  if v_id is null then
    if v_avatar is not null then
      perform private.api_error(400, 'invalid_avatar', 'Unggah foto setelah akun dibuat');
    end if;
    v_id := gen_random_uuid();
    insert into public.profiles (id, olt_user_id, username, display_name, bio, is_verified, trust_level)
    values (v_id, 'official:' || v_id, v_username, v_name, v_bio, true, 3);
    insert into cs.official_accounts (profile_id, created_by) values (v_id, v_me);
    perform cs.audit('community.account_create', null, v_id,
                     jsonb_build_object('account', v_id, 'username', v_username, 'display_name', v_name));
    return cs.official_account_view(v_id);
  end if;

  if not exists (select 1 from cs.official_accounts o where o.profile_id = v_id) then
    perform private.api_error(404, 'account_not_found', 'Akun resmi tidak ditemukan');
  end if;
  if v_avatar is not null
     and v_avatar !~ ('^https?://[^/]+/storage/v1/object/public/avatars/' || v_id::text || '/[A-Za-z0-9._-]+$') then
    perform private.api_error(400, 'invalid_avatar', 'Foto akun harus diunggah lewat web CS');
  end if;
  select * into v_old from public.profiles p where p.id = v_id for update;
  if v_old.username::text is distinct from v_username then
    v_changes := v_changes || jsonb_build_object('username', jsonb_build_object('from', v_old.username, 'to', v_username));
  end if;
  if v_old.display_name is distinct from v_name then
    v_changes := v_changes || jsonb_build_object('display_name', jsonb_build_object('from', v_old.display_name, 'to', v_name));
  end if;
  if v_old.bio is distinct from v_bio then
    v_changes := v_changes || jsonb_build_object('bio', jsonb_build_object('from', v_old.bio, 'to', v_bio));
  end if;
  if v_old.avatar_url is distinct from v_avatar then
    v_changes := v_changes || jsonb_build_object('avatar', case when v_avatar is null then 'removed'
                                                                when v_old.avatar_url is null then 'added'
                                                                else 'replaced' end);
  end if;
  if v_changes <> '{}' then
    update public.profiles
       set username = v_username, display_name = v_name, bio = v_bio, avatar_url = v_avatar
     where id = v_id;
    perform cs.audit('community.account_update', null, v_id,
                     jsonb_build_object('account', v_id, 'username', v_username, 'changes', v_changes));
  end if;
  return cs.official_account_view(v_id);
end;
$$;

create policy olt_official_avatar_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars'
         and cs.can_upload_official((storage.foldername(name))[1], 'community.accounts'));

revoke execute on function private.push_text(jsonb, text) from public;
revoke execute on function private.push_data(jsonb) from public;
revoke execute on function private.push_enqueue(uuid, text, jsonb, jsonb, jsonb, jsonb) from public;
revoke execute on function private.notification_push(public.notifications) from public;
revoke execute on function private.notifications_push() from public;
revoke execute on function private.push_forget_profile() from public;
revoke execute on function private.push_count_finished(bigint[]) from public;
revoke execute on function private.push_maintenance() from public;
revoke execute on function cs.push_state() from public;
revoke execute on function cs.push_ref_view(text) from public;

revoke execute on function public.register_push_device(text, text, text, text) from public, anon;
revoke execute on function public.unregister_push_device(text) from public, anon;
revoke execute on function public.push_claim(text, integer, integer) from public, anon, authenticated;
revoke execute on function public.push_report(text, jsonb) from public, anon, authenticated;
revoke execute on function public.push_heartbeat(text, text, boolean, text, text, timestamptz)
  from public, anon, authenticated;
revoke execute on function cs_api.push_status() from public;
revoke execute on function cs_api.push_find_users(text) from public;
revoke execute on function cs_api.push_test(uuid) from public;
revoke execute on function cs_api.community_campaign_push(uuid) from public;

grant execute on function public.register_push_device(text, text, text, text) to authenticated;
grant execute on function public.unregister_push_device(text) to authenticated;
grant execute on function public.push_claim(text, integer, integer) to service_role;
grant execute on function public.push_report(text, jsonb) to service_role;
grant execute on function public.push_heartbeat(text, text, boolean, text, text, timestamptz) to service_role;
grant execute on function cs_api.push_status() to authenticated;
grant execute on function cs_api.push_find_users(text) to authenticated;
grant execute on function cs_api.push_test(uuid) to authenticated;
grant execute on function cs_api.community_campaign_push(uuid) to authenticated;
