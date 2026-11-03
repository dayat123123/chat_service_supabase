insert into private.settings (key, value, description) values
  ('notifications.aggregate_minutes', '60',
   'Like dan follow dalam sekian menit sejak notifikasi pertama digabung menjadi satu notifikasi')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('notification_prefs', 30, 60)
on conflict (action, window_seconds) do nothing;

create or replace function private.notification_pref_types()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'olt.trade'];
$$;

create or replace function private.notification_pref_type(p_kind text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_kind in ('reply', 'mention', 'like', 'follow', 'message', 'announcement') then p_kind
    when p_kind like 'olt.%' then 'olt.trade'
  end;
$$;

create table private.notification_prefs (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       text not null check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'olt.trade')),
  in_app     boolean not null default true,
  push       boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, type)
);
alter table private.notification_prefs enable row level security;

create table private.notification_settings (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  quiet_start time(0),
  quiet_end   time(0),
  updated_at  timestamptz not null default now(),
  constraint notification_settings_quiet check (
    (quiet_start is null) = (quiet_end is null) and (quiet_start is null or quiet_start <> quiet_end))
);
alter table private.notification_settings enable row level security;

create table private.notification_actors (
  notification_id uuid not null references public.notifications (id) on delete cascade,
  actor_id        uuid not null references public.profiles (id) on delete cascade,
  created_at      timestamptz not null default clock_timestamp(),
  updated_at      timestamptz not null default clock_timestamp(),
  primary key (notification_id, actor_id)
);
create index notification_actors_actor_idx on private.notification_actors (actor_id);
alter table private.notification_actors enable row level security;

create or replace function private.push_allowed(p_profile uuid, p_kind text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select np.push from private.notification_prefs np
                   where np.user_id = p_profile and np.type = private.notification_pref_type(p_kind)), true);
$$;

create or replace function private.quiet_hours_end(p_profile uuid, p_at timestamptz default now())
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start time;
  v_end   time;
  v_local timestamp := p_at at time zone 'Asia/Jakarta';
  v_time  time := (p_at at time zone 'Asia/Jakarta')::time;
  v_until timestamp;
begin
  select s.quiet_start, s.quiet_end into v_start, v_end
  from private.notification_settings s where s.user_id = p_profile;
  if v_start is null then
    return null;
  end if;
  if not (case when v_start < v_end then v_time >= v_start and v_time < v_end
               else v_time >= v_start or v_time < v_end end) then
    return null;
  end if;
  v_until := v_local::date + v_end;
  if v_until <= v_local then
    v_until := v_until + interval '1 day';
  end if;
  return v_until at time zone 'Asia/Jakarta';
end;
$$;

create or replace function private.push_queue_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
  v_ids   bigint[];
begin
  if new.kind = 'test' then
    return new;
  end if;
  if not (new.kind = 'message' and new.data ->> 'room_type' = 'support')
     and not private.push_allowed(new.user_id, new.kind) then
    return null;
  end if;
  v_until := private.quiet_hours_end(new.user_id, now());
  if v_until is not null and v_until > new.available_at then
    new.expires_at := v_until + greatest(new.expires_at - now(), interval '1 minute');
    new.available_at := v_until;
    if new.collapse_key is not null then
      with cancelled as (
        update private.push_queue q
           set status = 'cancelled', finished_at = now(), locked_until = null
         where q.user_id = new.user_id
           and q.device_id is not distinct from new.device_id
           and q.collapse_key = new.collapse_key
           and q.status = 'queued'
           and q.available_at > now()
           and q.locked_until is null
        returning q.id)
      select array_agg(c.id) into v_ids from cancelled c;
      perform private.push_count_finished(coalesce(v_ids, '{}'));
    end if;
  end if;
  return new;
end;
$$;

create trigger push_queue_40_preferences
  before insert on private.push_queue
  for each row execute function private.push_queue_preferences();

create or replace function private.notifications_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pref private.notification_prefs;
  v_id   uuid;
begin
  if not (new.type = 'message' and new.payload ->> 'room_type' = 'support') then
    select * into v_pref from private.notification_prefs np
    where np.user_id = new.user_id and np.type = private.notification_pref_type(new.type);
    if found and not v_pref.in_app then
      if v_pref.push then
        perform private.notification_push(new);
      end if;
      return null;
    end if;
  end if;

  if new.type in ('like', 'follow') and new.actor_id is not null then
    select n.id into v_id
    from public.notifications n
    where n.user_id = new.user_id
      and n.type = new.type
      and n.read_at is null
      and (new.type = 'follow' or n.group_key = new.group_key)
      and coalesce((select min(a.created_at) from private.notification_actors a where a.notification_id = n.id),
                   n.created_at)
          > now() - make_interval(mins => private.setting_num('notifications.aggregate_minutes', 60)::integer)
    order by n.created_at desc
    limit 1
    for update;
    if v_id is not null then
      update public.notifications
         set actor_id = new.actor_id, payload = new.payload, event_count = event_count + 1, created_at = now()
       where id = v_id;
      return null;
    end if;
    if new.group_key is not null then
      update public.notifications
         set group_key = null
       where user_id = new.user_id and group_key = new.group_key and read_at is null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.notification_actors_track()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.notification_actors (notification_id, actor_id) values (new.id, new.actor_id)
  on conflict (notification_id, actor_id) do update set updated_at = clock_timestamp();
  return null;
end;
$$;

create trigger notifications_40_preferences
  before insert on public.notifications
  for each row execute function private.notifications_before_insert();
create trigger notifications_42_actors
  after insert or update of event_count on public.notifications
  for each row when (new.type in ('like', 'follow') and new.actor_id is not null)
  execute function private.notification_actors_track();

drop function public.get_notifications(text, integer);
create function public.get_notifications(p_cursor text default null, p_limit integer default 30)
returns table (
  id                 uuid,
  type               text,
  actor_id           uuid,
  actor_username     text,
  actor_display_name text,
  actor_avatar_url   text,
  payload            jsonb,
  event_count        integer,
  read_at            timestamptz,
  created_at         timestamptz,
  cursor             text,
  actor_count        integer,
  actors             jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ts  timestamptz;
  v_id  uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_cursor is not null then
    begin
      v_ts := split_part(p_cursor, '|', 1)::timestamptz;
      v_id := split_part(p_cursor, '|', 2)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor');
    end;
  end if;

  return query
  select n.id, n.type, n.actor_id, a.username::text, a.display_name, a.avatar_url,
         n.payload, n.event_count, n.read_at, n.created_at,
         to_char(n.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || n.id,
         coalesce(ac.total, case when n.actor_id is null then 0 else 1 end),
         coalesce(ac.actors,
                  case when a.id is null then '[]'::jsonb
                       else jsonb_build_array(jsonb_build_object('id', a.id, 'username', a.username::text,
                                                                 'display_name', a.display_name,
                                                                 'avatar_url', a.avatar_url)) end)
  from public.notifications n
  left join public.profiles a on a.id = n.actor_id
  left join lateral (
    select count(*)::integer as total,
           jsonb_agg(jsonb_build_object('id', x.id, 'username', x.username, 'display_name', x.display_name,
                                        'avatar_url', x.avatar_url) order by x.updated_at desc)
             filter (where x.rn <= 3) as actors
    from (
      select p.id, p.username::text as username, p.display_name, p.avatar_url, na.updated_at,
             row_number() over (order by na.updated_at desc) as rn
      from private.notification_actors na
      join public.profiles p on p.id = na.actor_id
      where na.notification_id = n.id
    ) x
    having count(*) > 0
  ) ac on true
  where n.user_id = v_uid
    and (v_ts is null or (n.created_at, n.id) < (v_ts, v_id))
  order by n.created_at desc, n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

create or replace function private.notification_prefs_view(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'types', (select jsonb_agg(jsonb_build_object(
                       'type', t.type,
                       'in_app', case when t.type = 'olt.trade' then null else coalesce(np.in_app, true) end,
                       'push', coalesce(np.push, true)) order by t.ord)
              from unnest(private.notification_pref_types()) with ordinality as t(type, ord)
              left join private.notification_prefs np on np.user_id = p_user and np.type = t.type),
    'quiet_hours', coalesce((select jsonb_build_object('enabled', true,
                                                       'start', to_char(s.quiet_start, 'HH24:MI'),
                                                       'end', to_char(s.quiet_end, 'HH24:MI'),
                                                       'timezone', 'Asia/Jakarta')
                             from private.notification_settings s
                             where s.user_id = p_user and s.quiet_start is not null),
                            jsonb_build_object('enabled', false, 'start', null, 'end', null, 'timezone', 'Asia/Jakarta')),
    'aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60));
$$;

create or replace function public.get_notification_prefs()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return private.notification_prefs_view(auth.uid());
end;
$$;

create or replace function public.set_notification_prefs(p_prefs jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_types  jsonb;
  v_item   record;
  v_in_app boolean;
  v_push   boolean;
  v_quiet  jsonb;
  v_start  time;
  v_end    time;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if jsonb_typeof(p_prefs) is distinct from 'object'
     or exists (select 1 from jsonb_object_keys(p_prefs) k where k not in ('types', 'quiet_hours')) then
    perform private.api_error(400, 'invalid_preferences', 'Format preferensi notifikasi tidak valid');
  end if;
  perform private.consume_rate_limit(v_uid, 'notification_prefs');

  v_types := case coalesce(jsonb_typeof(p_prefs -> 'types'), 'null')
    when 'null' then '[]'::jsonb
    when 'array' then p_prefs -> 'types'
    when 'object' then (select coalesce(jsonb_agg(case when jsonb_typeof(e.value) = 'object'
                                                       then e.value || jsonb_build_object('type', e.key)
                                                       else 'null'::jsonb end), '[]')
                        from jsonb_each(p_prefs -> 'types') e)
  end;
  if v_types is null then
    perform private.api_error(400, 'invalid_preferences', 'types harus berupa daftar atau objek per jenis');
  end if;

  for v_item in select e.value as item from jsonb_array_elements(v_types) e loop
    if jsonb_typeof(v_item.item) <> 'object'
       or not coalesce(v_item.item ->> 'type' = any (private.notification_pref_types()), false) then
      perform private.api_error(400, 'invalid_notification_type',
        'Jenis notifikasi harus salah satu dari ' || array_to_string(private.notification_pref_types(), ', '));
    end if;
    if (v_item.item ? 'in_app' and jsonb_typeof(v_item.item -> 'in_app') not in ('boolean', 'null'))
       or (v_item.item ? 'push' and jsonb_typeof(v_item.item -> 'push') <> 'boolean') then
      perform private.api_error(400, 'invalid_preferences', 'in_app dan push harus bernilai true/false');
    end if;
    select coalesce(case when v_item.item ->> 'type' = 'olt.trade' then null
                         else (v_item.item ->> 'in_app')::boolean end, np.in_app, true),
           coalesce((v_item.item ->> 'push')::boolean, np.push, true)
      into v_in_app, v_push
    from (select 1) d
    left join private.notification_prefs np on np.user_id = v_uid and np.type = v_item.item ->> 'type';
    if v_item.item ->> 'type' = 'olt.trade' then
      v_in_app := true;
    end if;
    if v_in_app and v_push then
      delete from private.notification_prefs np where np.user_id = v_uid and np.type = v_item.item ->> 'type';
    else
      insert into private.notification_prefs (user_id, type, in_app, push)
      values (v_uid, v_item.item ->> 'type', v_in_app, v_push)
      on conflict (user_id, type) do update set in_app = excluded.in_app, push = excluded.push, updated_at = now();
    end if;
  end loop;

  v_quiet := p_prefs -> 'quiet_hours';
  if v_quiet is not null and jsonb_typeof(v_quiet) <> 'null' then
    if jsonb_typeof(v_quiet) <> 'object' or jsonb_typeof(v_quiet -> 'enabled') <> 'boolean' then
      perform private.api_error(400, 'invalid_quiet_hours', 'quiet_hours butuh enabled, start, dan end');
    end if;
    if (v_quiet ->> 'enabled')::boolean then
      if coalesce(v_quiet ->> 'start', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
         or coalesce(v_quiet ->> 'end', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
         or v_quiet ->> 'start' = v_quiet ->> 'end' then
        perform private.api_error(400, 'invalid_quiet_hours', 'Jam tenang memakai format HH:MM dan jam mulai ≠ jam selesai');
      end if;
      v_start := (v_quiet ->> 'start')::time;
      v_end := (v_quiet ->> 'end')::time;
      insert into private.notification_settings (user_id, quiet_start, quiet_end)
      values (v_uid, v_start, v_end)
      on conflict (user_id) do update
        set quiet_start = excluded.quiet_start, quiet_end = excluded.quiet_end, updated_at = now();
    else
      delete from private.notification_settings s where s.user_id = v_uid;
    end if;
  end if;

  return private.notification_prefs_view(v_uid);
end;
$$;

create or replace function private.social_forget_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.bookmarks where user_id = new.id;
  delete from public.message_reactions where user_id = new.id;
  delete from private.notification_prefs where user_id = new.id;
  delete from private.notification_settings where user_id = new.id;
  delete from private.notification_actors where actor_id = new.id;
  return null;
end;
$$;

create trigger profiles_40_social_forget
  after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function private.social_forget_profile();

revoke execute on function private.notification_pref_types() from public;
revoke execute on function private.notification_pref_type(text) from public;
revoke execute on function private.push_allowed(uuid, text) from public;
revoke execute on function private.quiet_hours_end(uuid, timestamptz) from public;
revoke execute on function private.push_queue_preferences() from public;
revoke execute on function private.notifications_before_insert() from public;
revoke execute on function private.notification_actors_track() from public;
revoke execute on function private.notification_prefs_view(uuid) from public;
revoke execute on function private.social_forget_profile() from public;
revoke execute on function public.get_notifications(text, integer) from public, anon;
revoke execute on function public.get_notification_prefs() from public, anon;
revoke execute on function public.set_notification_prefs(jsonb) from public, anon;
grant execute on function public.get_notifications(text, integer) to authenticated;
grant execute on function public.get_notification_prefs() to authenticated;
grant execute on function public.set_notification_prefs(jsonb) to authenticated;
