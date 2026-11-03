insert into private.settings (key, value, description) values
  ('integration.broadcast_daily_cap', '3',
   'Batas notifikasi siaran OLT (selain kategori important) per nasabah per hari WIB'),
  ('integration.broadcast_batch_size', '2000', 'Jumlah profil yang diproses per putaran siaran notifikasi OLT'),
  ('integration.broadcast_days', '90', 'Riwayat siaran notifikasi OLT disimpan selama sekian hari')
on conflict (key) do nothing;

alter table private.notification_prefs drop constraint notification_prefs_type_check;
alter table private.notification_prefs add constraint notification_prefs_type_check
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'));

insert into private.notification_prefs (user_id, type, in_app, push, updated_at)
select np.user_id, t.type, true, np.push, np.updated_at
from private.notification_prefs np
cross join unnest(array['olt.funds', 'olt.market', 'olt.info']) as t(type)
where np.type = 'olt.trade' and not np.push
on conflict (user_id, type) do nothing;

alter table private.integration_keys drop constraint integration_keys_scopes_check;
alter table private.integration_keys add constraint integration_keys_scopes_check
  check (cardinality(scopes) between 1 and 3
         and scopes <@ array['notify', 'bot_post', 'notify_broadcast']
         and (not 'notify_broadcast' = any (scopes) or 'notify' = any (scopes)));

create table private.integration_broadcasts (
  id           uuid primary key default gen_random_uuid(),
  key_id       uuid not null references private.integration_keys (id) on delete cascade,
  message_id   text not null check (message_id ~ '^[A-Za-z0-9._:-]{1,100}$'),
  message      jsonb not null check (jsonb_typeof(message) = 'object'),
  target       jsonb not null check (jsonb_typeof(target) = 'object'),
  channels     text[] not null check (cardinality(channels) between 1 and 2 and channels <@ array['push', 'inbox']),
  category     text not null check (category in ('important', 'info', 'promo')),
  status       text not null default 'queued' check (status in ('queued', 'sending', 'done', 'failed')),
  cursor_id    uuid,
  targeted     integer not null default 0,
  recipients   integer not null default 0,
  devices      integer not null default 0,
  inbox        integer not null default 0,
  capped       integer not null default 0,
  pref_skipped integer not null default 0,
  error        text check (char_length(error) <= 500),
  created_at   timestamptz not null default now(),
  started_at   timestamptz,
  finished_at  timestamptz
);
create index integration_broadcasts_pending_idx on private.integration_broadcasts (created_at, id)
  where status in ('queued', 'sending');
create index integration_broadcasts_key_idx on private.integration_broadcasts (key_id, created_at desc);
alter table private.integration_broadcasts enable row level security;

create table private.integration_broadcast_caps (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  day        date not null,
  count      integer not null default 0,
  primary key (profile_id, day)
);
create index integration_broadcast_caps_day_idx on private.integration_broadcast_caps (day);
alter table private.integration_broadcast_caps enable row level security;

alter table private.integration_receipts drop constraint integration_receipts_status_check;
alter table private.integration_receipts add constraint integration_receipts_status_check
  check (status in ('queued', 'no_recipient', 'accepted'));
alter table private.integration_receipts
  add column broadcast_id uuid references private.integration_broadcasts (id) on delete set null;
create index integration_receipts_broadcast_idx on private.integration_receipts (broadcast_id)
  where broadcast_id is not null;

alter table private.integration_daily
  add column accepted integer not null default 0,
  add column inbox integer not null default 0;

create or replace function private.notification_pref_types()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
               'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'];
$$;

create or replace function private.notification_pref_type(p_kind text, p_category text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_kind in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal') then p_kind
    when not starts_with(p_kind, 'olt.') then null
    when p_category = 'promo' then 'olt.promo'
    when starts_with(p_kind, 'olt.trade') or starts_with(p_kind, 'olt.order') then 'olt.trade'
    when starts_with(p_kind, 'olt.deposit') or starts_with(p_kind, 'olt.withdrawal') or starts_with(p_kind, 'olt.rdn')
      then 'olt.funds'
    when starts_with(p_kind, 'olt.price_alert') or starts_with(p_kind, 'olt.ipo')
         or starts_with(p_kind, 'olt.corporate_action') then 'olt.market'
    else 'olt.info'
  end;
$$;

create or replace function private.notification_pref_type(p_kind text)
returns text
language sql
immutable
set search_path = ''
as $$
  select private.notification_pref_type(p_kind, null);
$$;

create or replace function private.notification_pref_default_push(p_type text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_type is distinct from 'olt.promo';
$$;

create or replace function private.push_allowed_for(p_profile uuid, p_kind text, p_category text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not starts_with(coalesce(p_kind, ''), 'olt.') or p_category is null or p_category = 'info'
      then private.push_allowed(p_profile, p_kind)
    when p_category = 'important' then true
    when p_category = 'promo'
      then coalesce((select np.push from private.notification_prefs np
                     where np.user_id = p_profile and np.type = 'olt.promo'),
                    private.notification_pref_default_push('olt.promo'))
    else private.push_allowed(p_profile, p_kind)
  end;
$$;

create or replace function private.push_queue_preferences()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text := case when starts_with(new.kind, 'olt.') then new.data ->> 'category' end;
  v_until    timestamptz;
  v_ids      bigint[];
begin
  if new.kind = 'test' or v_category = 'important' then
    return new;
  end if;
  if not (new.kind = 'message' and new.data ->> 'room_type' = 'support')
     and not private.push_allowed_for(new.user_id, new.kind, v_category) then
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
  if new.type = 'announcement' and new.payload ->> 'source' = 'olt' then
    if new.payload ->> 'category' = 'important' then
      return new;
    end if;
    select * into v_pref from private.notification_prefs np
    where np.user_id = new.user_id
      and np.type = private.notification_pref_type(new.payload ->> 'kind', new.payload ->> 'category');
    if found and not v_pref.in_app then
      return null;
    end if;
    return new;
  end if;

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

create or replace function private.notifications_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type = 'announcement' and new.payload ->> 'source' = 'olt' then
    return null;
  end if;
  if tg_op = 'INSERT'
     or (new.event_count > old.event_count and new.read_at is null and new.type not in ('like', 'follow')) then
    perform private.notification_push(new);
  end if;
  return null;
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
                       'in_app', coalesce(np.in_app, true),
                       'push', coalesce(np.push, private.notification_pref_default_push(t.type))) order by t.ord)
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
  v_type   text;
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
    v_type := v_item.item ->> 'type';
    select coalesce((v_item.item ->> 'in_app')::boolean, np.in_app, true),
           coalesce((v_item.item ->> 'push')::boolean, np.push, private.notification_pref_default_push(v_type))
      into v_in_app, v_push
    from (select 1) d
    left join private.notification_prefs np on np.user_id = v_uid and np.type = v_type;
    if v_in_app and v_push = private.notification_pref_default_push(v_type) then
      delete from private.notification_prefs np where np.user_id = v_uid and np.type = v_type;
    else
      insert into private.notification_prefs (user_id, type, in_app, push)
      values (v_uid, v_type, v_in_app, v_push)
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
  if cardinality(v_scopes) = 0 or not v_scopes <@ array['notify', 'bot_post', 'notify_broadcast'] then
    perform private.api_error(400, 'invalid_scopes', 'Pilih izin notify, notify_broadcast, bot_post, atau gabungannya');
  end if;
  if 'notify_broadcast' = any (v_scopes) and not 'notify' = any (v_scopes) then
    perform private.api_error(400, 'invalid_scopes', 'Izin notify_broadcast harus disertai izin notify');
  end if;
  return v_scopes;
end;
$$;

create or replace function private.integration_target(p_target jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_keys  text[];
  v_cust  text;
  v_stock text;
begin
  if jsonb_typeof(p_target) is distinct from 'object' then
    return null;
  end if;
  select array_agg(k order by k) into v_keys from jsonb_object_keys(p_target) k;
  if v_keys = array['cust_id'] then
    v_cust := private.integration_cust_id(p_target -> 'cust_id');
    return case when v_cust is not null then jsonb_build_object('cust_id', v_cust) end;
  end if;
  if v_keys = array['olt_user_ids'] then
    if jsonb_typeof(p_target -> 'olt_user_ids') <> 'array'
       or jsonb_array_length(p_target -> 'olt_user_ids') not between 1 and 500
       or exists (select 1 from jsonb_array_elements(p_target -> 'olt_user_ids') e
                  where jsonb_typeof(e.value) not in ('string', 'number')
                     or btrim(e.value #>> '{}') !~ '^[A-Za-z0-9._-]{1,64}$') then
      return null;
    end if;
    return jsonb_build_object('olt_user_ids', (select jsonb_agg(distinct btrim(e.value #>> '{}'))
                                               from jsonb_array_elements(p_target -> 'olt_user_ids') e));
  end if;
  if v_keys = array['audience'] and p_target -> 'audience' = '"all"' then
    return jsonb_build_object('audience', 'all');
  end if;
  if v_keys = array['audience', 'stock'] and p_target -> 'audience' = '"stock_watchers"'
     and jsonb_typeof(p_target -> 'stock') = 'string' then
    v_stock := upper(btrim(p_target ->> 'stock'));
    return case when v_stock ~ '^[A-Z][A-Z0-9]{1,11}$'
                then jsonb_build_object('audience', 'stock_watchers', 'stock', v_stock) end;
  end if;
  return null;
end;
$$;

create or replace function private.integration_channels(p_channels jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p_channels) = 'array' and jsonb_array_length(p_channels) between 1 and 2
         and not exists (select 1 from jsonb_array_elements(p_channels) e
                         where e.value not in ('"push"'::jsonb, '"inbox"'::jsonb))
      then (select array_agg(distinct e.value #>> '{}' order by e.value #>> '{}')
            from jsonb_array_elements(p_channels) e)
  end;
$$;

create or replace function private.integration_notify_error(m jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(m) is distinct from 'object' then 'invalid_message'
    when jsonb_typeof(m -> 'id') is distinct from 'string' or (m ->> 'id') !~ '^[A-Za-z0-9._:-]{1,100}$'
      then 'invalid_id'
    when coalesce(jsonb_typeof(m -> 'target'), 'null') = 'null' and private.integration_cust_id(m -> 'cust_id') is null
      then 'invalid_cust_id'
    when coalesce(jsonb_typeof(m -> 'target'), 'null') <> 'null'
         and (coalesce(jsonb_typeof(m -> 'cust_id'), 'null') <> 'null' or private.integration_target(m -> 'target') is null)
      then 'invalid_target'
    when m ? 'kind' and jsonb_typeof(m -> 'kind') <> 'null' and (jsonb_typeof(m -> 'kind') <> 'string'
                         or (m ->> 'kind') !~ '^olt\.[a-z0-9_]+(\.[a-z0-9_]+)*$' or char_length(m ->> 'kind') > 40)
      then 'invalid_kind'
    when private.integration_text(m -> 'title', 200) is null then 'invalid_title'
    when m ? 'body' and jsonb_typeof(m -> 'body') <> 'null' and private.integration_text(m -> 'body', 1000) is null
         and not (jsonb_typeof(m -> 'body') = 'string' and btrim(m ->> 'body') = '')
      then 'invalid_body'
    when m ? 'data' and jsonb_typeof(m -> 'data') <> 'null'
         and (jsonb_typeof(m -> 'data') <> 'object' or octet_length((m -> 'data')::text) > 2048)
      then 'invalid_data'
    when m ? 'ttl_seconds' and jsonb_typeof(m -> 'ttl_seconds') <> 'null'
         and (jsonb_typeof(m -> 'ttl_seconds') <> 'number' or (m ->> 'ttl_seconds') !~ '^[0-9]{1,8}$'
              or (m ->> 'ttl_seconds')::integer not between 60 and 2419200)
      then 'invalid_ttl'
    when m ? 'collapse_key' and jsonb_typeof(m -> 'collapse_key') <> 'null'
         and (jsonb_typeof(m -> 'collapse_key') <> 'string' or char_length(m ->> 'collapse_key') not between 1 and 64)
      then 'invalid_collapse_key'
    when m ? 'priority' and jsonb_typeof(m -> 'priority') <> 'null' and (m ->> 'priority') not in ('high', 'normal')
      then 'invalid_priority'
    when m ? 'channels' and jsonb_typeof(m -> 'channels') <> 'null' and private.integration_channels(m -> 'channels') is null
      then 'invalid_channels'
    when m ? 'category' and jsonb_typeof(m -> 'category') <> 'null'
         and (m -> 'category') not in ('"important"'::jsonb, '"info"'::jsonb, '"promo"'::jsonb)
      then 'invalid_category'
  end;
$$;

create or replace function private.integration_deliver(p_profile uuid, p_message jsonb, p_channels text[],
                                                       p_category text, p_options jsonb,
                                                       out devices integer, out inbox integer, out blocked boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notification uuid;
begin
  devices := 0;
  inbox := 0;
  blocked := false;
  if 'inbox' = any (p_channels) then
    insert into public.notifications (user_id, type, payload)
    values (p_profile, 'announcement', p_message -> 'inbox')
    returning id into v_notification;
    if v_notification is null then
      blocked := true;
    else
      inbox := 1;
    end if;
  end if;
  if 'push' = any (p_channels) then
    if coalesce(private.push_allowed_for(p_profile, p_message ->> 'kind', p_category), false) then
      devices := private.push_enqueue(p_profile, p_message ->> 'kind', p_message -> 'title', p_message -> 'body',
                                      (p_message -> 'data')
                                        || jsonb_strip_nulls(jsonb_build_object('notification_id', v_notification)),
                                      p_options);
    else
      blocked := true;
    end if;
  end if;
end;
$$;

create or replace function private.integration_touch(p_key_id uuid, p_ip text, p_counts jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ip inet;
begin
  begin
    v_ip := nullif(btrim(coalesce(p_ip, '')), '')::inet;
  exception when invalid_text_representation then
    v_ip := null;
  end;
  insert into private.integration_daily as d (key_id, day, received, queued, devices, no_recipient, duplicate, invalid,
                                              posts, posts_rejected, accepted, inbox)
  values (p_key_id, private.integration_day(),
          coalesce((p_counts ->> 'received')::integer, 0), coalesce((p_counts ->> 'queued')::integer, 0),
          coalesce((p_counts ->> 'devices')::integer, 0), coalesce((p_counts ->> 'no_recipient')::integer, 0),
          coalesce((p_counts ->> 'duplicate')::integer, 0), coalesce((p_counts ->> 'invalid')::integer, 0),
          coalesce((p_counts ->> 'posts')::integer, 0), coalesce((p_counts ->> 'posts_rejected')::integer, 0),
          coalesce((p_counts ->> 'accepted')::integer, 0), coalesce((p_counts ->> 'inbox')::integer, 0))
  on conflict (key_id, day) do update
     set received = d.received + excluded.received, queued = d.queued + excluded.queued,
         devices = d.devices + excluded.devices, no_recipient = d.no_recipient + excluded.no_recipient,
         duplicate = d.duplicate + excluded.duplicate, invalid = d.invalid + excluded.invalid,
         posts = d.posts + excluded.posts, posts_rejected = d.posts_rejected + excluded.posts_rejected,
         accepted = d.accepted + excluded.accepted, inbox = d.inbox + excluded.inbox;
  update private.integration_keys
     set last_used_at = now(), last_used_ip = coalesce(v_ip, last_used_ip)
   where id = p_key_id
     and (last_used_at is null or last_used_at < now() - interval '1 minute'
          or last_used_ip is distinct from coalesce(v_ip, last_used_ip));
end;
$$;

create or replace function public.integration_notify(p_key_id uuid, p_messages jsonb, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k          private.integration_keys := private.integration_key_for(p_key_id, 'notify', p_ip);
  v_days     integer := private.setting_num('integration.account_link_days', 30)::integer;
  v_ref      text := private.integration_ref(p_key_id, private.integration_day());
  v_results  jsonb := '[]';
  v_counts   jsonb;
  v_queued   integer := 0;
  v_none     integer := 0;
  v_dup      integer := 0;
  v_invalid  integer := 0;
  v_devices  integer := 0;
  v_accepted integer := 0;
  v_inbox    integer := 0;
  m          jsonb;
  v_index    bigint;
  v_error    text;
  v_id       text;
  v_target   jsonb;
  v_cust     text;
  v_kind     text;
  v_category text;
  v_channels text[];
  v_title    jsonb;
  v_body     jsonb;
  v_data     jsonb;
  v_message  jsonb;
  v_options  jsonb;
  v_count    integer;
  v_boxed    integer;
  v_profile  uuid;
  v_inserted integer;
  v_bid      uuid;
  d          record;
begin
  if jsonb_typeof(p_messages) is distinct from 'array' or jsonb_array_length(p_messages) not between 1 and 500 then
    perform private.api_error(400, 'invalid_batch', 'messages harus array berisi 1–500 pesan');
  end if;

  for m, v_index in select e.value, e.ord - 1 from jsonb_array_elements(p_messages) with ordinality as e(value, ord) loop
    v_error := private.integration_notify_error(m);
    v_id := case when jsonb_typeof(m) = 'object' and jsonb_typeof(m -> 'id') = 'string' then left(m ->> 'id', 100) end;
    v_target := null;
    if v_error is null then
      v_target := coalesce(private.integration_target(m -> 'target'),
                           jsonb_build_object('cust_id', private.integration_cust_id(m -> 'cust_id')));
      if not v_target ? 'cust_id' and not 'notify_broadcast' = any (k.scopes) then
        v_error := 'scope_forbidden';
      end if;
    end if;
    if v_error is not null then
      v_invalid := v_invalid + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'invalid', 'error', v_error);
      continue;
    end if;

    insert into private.integration_receipts (key_id, message_id) values (k.id, v_id) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      select r.broadcast_id into v_bid from private.integration_receipts r where r.key_id = k.id and r.message_id = v_id;
      v_dup := v_dup + 1;
      v_results := v_results || jsonb_strip_nulls(jsonb_build_object('index', v_index, 'id', v_id, 'status', 'duplicate',
                                                                      'broadcast_id', v_bid));
      continue;
    end if;

    v_cust := v_target ->> 'cust_id';
    v_kind := coalesce(m ->> 'kind', case when v_cust is not null then 'olt.trade' else 'olt.info' end);
    v_category := coalesce(m ->> 'category', 'info');
    v_channels := coalesce(private.integration_channels(m -> 'channels'),
                           case when v_cust is not null then array['push'] else array['inbox', 'push'] end);
    v_title := private.integration_text(m -> 'title', 200);
    v_body := private.integration_text(m -> 'body', 1000);
    v_data := case when jsonb_typeof(m -> 'data') = 'object' then m -> 'data' else '{}' end;
    v_message := jsonb_build_object(
      'kind', v_kind, 'title', v_title, 'body', coalesce(v_body, '""'),
      'data', v_data || jsonb_strip_nulls(jsonb_build_object(
                'source', 'olt', 'message_id', v_id, 'cust_id', v_cust,
                'category', case when jsonb_typeof(m -> 'category') = 'string' or v_cust is null then v_category end)),
      'inbox', jsonb_strip_nulls(jsonb_build_object(
                 'source', 'olt', 'kind', v_kind, 'category', v_category, 'title', v_title, 'body', v_body,
                 'data', v_data, 'message_id', v_id, 'cust_id', v_cust)));
    v_options := jsonb_strip_nulls(jsonb_build_object(
      'ttl_seconds', case when jsonb_typeof(m -> 'ttl_seconds') = 'number' then (m ->> 'ttl_seconds')::integer end,
      'collapse_key', case when jsonb_typeof(m -> 'collapse_key') = 'string' then m ->> 'collapse_key' end,
      'priority', case when jsonb_typeof(m -> 'priority') = 'string' then m ->> 'priority' end));

    if v_cust is null then
      insert into private.integration_broadcasts (key_id, message_id, message, target, channels, category)
      values (k.id, v_id, v_message || jsonb_build_object('options', v_options), v_target, v_channels, v_category)
      returning id into v_bid;
      update private.integration_receipts set status = 'accepted', broadcast_id = v_bid
       where key_id = k.id and message_id = v_id;
      v_accepted := v_accepted + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'accepted',
                                                   'broadcast_id', v_bid);
      continue;
    end if;

    v_count := 0;
    v_boxed := 0;
    for v_profile in
      select l.profile_id
      from private.account_links l
      join public.profiles p on p.id = l.profile_id and p.deleted_at is null
      where l.cust_id = v_cust and l.seen_at > now() - make_interval(days => v_days)
      order by l.profile_id
    loop
      select * into d from private.integration_deliver(v_profile, v_message, v_channels, v_category,
                                                         v_options || jsonb_build_object('ref', v_ref));
      v_count := v_count + d.devices;
      v_boxed := v_boxed + d.inbox;
    end loop;

    update private.integration_receipts
       set status = case when v_count + v_boxed > 0 then 'queued' else 'no_recipient' end, devices = v_count
     where key_id = k.id and message_id = v_id;
    if v_count + v_boxed > 0 then
      v_queued := v_queued + 1;
      v_devices := v_devices + v_count;
      v_inbox := v_inbox + v_boxed;
      v_results := v_results || (jsonb_build_object('index', v_index, 'id', v_id, 'status', 'queued', 'devices', v_count)
                                 || case when 'inbox' = any (v_channels) then jsonb_build_object('inbox', v_boxed)
                                         else '{}' end);
    else
      v_none := v_none + 1;
      v_results := v_results || jsonb_build_object('index', v_index, 'id', v_id, 'status', 'no_recipient');
    end if;
  end loop;

  v_counts := jsonb_build_object('received', jsonb_array_length(p_messages), 'queued', v_queued, 'devices', v_devices,
                                 'no_recipient', v_none, 'duplicate', v_dup, 'invalid', v_invalid,
                                 'accepted', v_accepted, 'inbox', v_inbox);
  perform private.integration_touch(k.id, p_ip, v_counts);
  return jsonb_build_object('results', v_results) || (v_counts - 'received');
end;
$$;

create or replace function private.integration_broadcast_batch(p_id uuid, p_size integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  b            private.integration_broadcasts;
  k            private.integration_keys;
  v_size       integer := greatest(coalesce(p_size, 1), 1);
  v_cap        integer := private.setting_num('integration.broadcast_daily_cap', 3)::integer;
  v_day        date := private.integration_day();
  v_ids        uuid[];
  v_profile    uuid;
  v_options    jsonb;
  v_recipients integer := 0;
  v_devices    integer := 0;
  v_inbox      integer := 0;
  v_capped     integer := 0;
  v_skipped    integer := 0;
  v_done       boolean;
  d            record;
begin
  select * into b from private.integration_broadcasts
   where id = p_id and status in ('queued', 'sending')
  for update skip locked;
  if not found then
    return 0;
  end if;
  select * into k from private.integration_keys where id = b.key_id;
  if k.revoked_at is not null or k.disabled_at is not null or not 'notify_broadcast' = any (k.scopes) then
    update private.integration_broadcasts
       set status = 'failed', error = 'key_inactive', started_at = coalesce(started_at, now()), finished_at = now()
     where id = b.id;
    return 0;
  end if;

  if b.target ? 'olt_user_ids' then
    v_ids := array(
      select p.id from public.profiles p
      where p.olt_user_id in (select jsonb_array_elements_text(b.target -> 'olt_user_ids'))
        and p.deleted_at is null
        and (b.cursor_id is null or p.id > b.cursor_id)
      order by p.id
      limit v_size);
  elsif b.target ->> 'audience' = 'stock_watchers' then
    v_ids := array(
      select w.user_id from public.stock_watchers w
      join public.profiles p on p.id = w.user_id
      where w.stock_code = b.target ->> 'stock'
        and p.deleted_at is null
        and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
        and (b.cursor_id is null or w.user_id > b.cursor_id)
      order by w.user_id
      limit v_size);
  else
    v_ids := array(
      select p.id from public.profiles p
      where p.deleted_at is null
        and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
        and (b.cursor_id is null or p.id > b.cursor_id)
      order by p.id
      limit v_size);
  end if;

  v_options := coalesce(b.message -> 'options', '{}')
               || jsonb_build_object('ref', private.integration_ref(k.id, v_day));
  foreach v_profile in array v_ids loop
    if b.category <> 'important'
       and coalesce((select c.count from private.integration_broadcast_caps c
                     where c.profile_id = v_profile and c.day = v_day), 0) >= v_cap then
      v_capped := v_capped + 1;
      continue;
    end if;
    select * into d from private.integration_deliver(v_profile, b.message, b.channels, b.category, v_options);
    if d.devices > 0 or d.inbox > 0 then
      v_recipients := v_recipients + 1;
      v_devices := v_devices + d.devices;
      v_inbox := v_inbox + d.inbox;
      if b.category <> 'important' then
        insert into private.integration_broadcast_caps as c (profile_id, day, count) values (v_profile, v_day, 1)
        on conflict (profile_id, day) do update set count = c.count + 1;
      end if;
    elsif d.blocked then
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  v_done := cardinality(v_ids) < v_size;
  update private.integration_broadcasts
     set status = case when v_done then 'done' else 'sending' end,
         cursor_id = coalesce(v_ids[cardinality(v_ids)], cursor_id),
         targeted = targeted + cardinality(v_ids),
         recipients = recipients + v_recipients,
         devices = devices + v_devices,
         inbox = inbox + v_inbox,
         capped = capped + v_capped,
         pref_skipped = pref_skipped + v_skipped,
         started_at = coalesce(started_at, now()),
         finished_at = case when v_done then now() end
   where id = b.id;
  return cardinality(v_ids);
end;
$$;

create or replace function private.integration_broadcast_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_budget   integer := greatest(private.setting_num('integration.broadcast_batch_size', 2000)::integer, 1);
  v_profiles integer := 0;
  v_jobs     integer := 0;
  v_count    integer;
  r          record;
begin
  for r in
    select b.id from private.integration_broadcasts b
    where b.status in ('queued', 'sending')
    order by b.created_at, b.id
  loop
    exit when v_budget <= 0;
    begin
      v_count := private.integration_broadcast_batch(r.id, v_budget);
    exception when others then
      update private.integration_broadcasts
         set status = 'failed', error = left(coalesce(nullif(sqlerrm, ''), 'error'), 500),
             started_at = coalesce(started_at, now()), finished_at = now()
       where id = r.id;
      v_count := 0;
    end;
    v_jobs := v_jobs + 1;
    v_profiles := v_profiles + v_count;
    v_budget := v_budget - v_count;
  end loop;
  return jsonb_build_object('jobs', v_jobs, 'profiles', v_profiles);
end;
$$;

select cron.schedule('integration-broadcasts', '15 seconds', 'select private.integration_broadcast_tick()');

create or replace function private.integration_broadcast_view(b private.integration_broadcasts)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', b.id,
    'key', (select jsonb_build_object('id', k.id, 'name', k.name, 'prefix', k.prefix)
            from private.integration_keys k where k.id = b.key_id),
    'message_id', b.message_id,
    'kind', b.message ->> 'kind',
    'title', b.message -> 'title',
    'category', b.category,
    'channels', to_jsonb(b.channels),
    'target', case
      when b.target ? 'olt_user_ids'
        then jsonb_build_object('type', 'olt_user_ids', 'count', jsonb_array_length(b.target -> 'olt_user_ids'))
      when b.target ->> 'audience' = 'stock_watchers'
        then jsonb_build_object('type', 'stock_watchers', 'stock', b.target ->> 'stock')
      else jsonb_build_object('type', 'all') end,
    'status', b.status,
    'targeted', b.targeted, 'recipients', b.recipients, 'devices', b.devices, 'inbox', b.inbox,
    'capped', b.capped, 'pref_skipped', b.pref_skipped, 'error', b.error,
    'created_at', b.created_at, 'started_at', b.started_at, 'finished_at', b.finished_at);
$$;

create or replace function cs_api.integration_broadcasts(p_key_id uuid default null, p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((
    select jsonb_agg(private.integration_broadcast_view(s.b) order by (s.b).created_at desc, (s.b).id desc)
    from (select b from private.integration_broadcasts b
          where p_key_id is null or b.key_id = p_key_id
          order by b.created_at desc, b.id desc
          limit least(greatest(coalesce(p_limit, 50), 1), 200)) s), '[]');
end;
$$;

create or replace function cs_api.integration_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_days  integer := greatest(1, least(coalesce(p_days, 7), 90));
  v_from  date := private.integration_day() - (v_days - 1);
  v_since timestamptz := v_from::timestamp at time zone 'Asia/Jakarta';
  v_link  integer := private.setting_num('integration.account_link_days', 30)::integer;
begin
  return jsonb_build_object(
    'days', v_days,
    'from', v_from,
    'keys', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', k.id, 'name', k.name, 'prefix', k.prefix,
               'status', case when k.revoked_at is not null then 'revoked'
                              when k.disabled_at is not null then 'disabled' else 'active' end,
               'last_used_at', k.last_used_at,
               'received', coalesce(d.received, 0), 'queued', coalesce(d.queued, 0),
               'devices', coalesce(d.devices, 0), 'no_recipient', coalesce(d.no_recipient, 0),
               'duplicate', coalesce(d.duplicate, 0), 'invalid', coalesce(d.invalid, 0),
               'posts', coalesce(d.posts, 0), 'posts_rejected', coalesce(d.posts_rejected, 0),
               'accepted', coalesce(d.accepted, 0), 'inbox', coalesce(d.inbox, 0),
               'broadcasts', jsonb_build_object(
                 'total', coalesce(bc.total, 0), 'active', coalesce(bc.active, 0), 'done', coalesce(bc.done, 0),
                 'failed', coalesce(bc.failed, 0), 'recipients', coalesce(bc.recipients, 0),
                 'devices', coalesce(bc.devices, 0), 'inbox', coalesce(bc.inbox, 0),
                 'capped', coalesce(bc.capped, 0), 'pref_skipped', coalesce(bc.pref_skipped, 0)),
               'push', jsonb_build_object(
                 'sent', coalesce(s.sent, 0), 'failed', coalesce(s.failed, 0), 'invalid', coalesce(s.invalid, 0),
                 'expired', coalesce(s.expired, 0) + coalesce(s.cancelled, 0),
                 'pending', (select count(*) from private.push_queue q
                             where q.status = 'queued' and q.expires_at > now()
                               and q.ref like 'olt:' || k.id::text || ':%')))
             order by k.revoked_at nulls first, k.created_at desc)
      from private.integration_keys k
      left join lateral (
        select sum(x.received) as received, sum(x.queued) as queued, sum(x.devices) as devices,
               sum(x.no_recipient) as no_recipient, sum(x.duplicate) as duplicate, sum(x.invalid) as invalid,
               sum(x.posts) as posts, sum(x.posts_rejected) as posts_rejected, sum(x.accepted) as accepted,
               sum(x.inbox) as inbox
        from private.integration_daily x where x.key_id = k.id and x.day >= v_from) d on true
      left join lateral (
        select count(*) as total, count(*) filter (where b.status in ('queued', 'sending')) as active,
               count(*) filter (where b.status = 'done') as done, count(*) filter (where b.status = 'failed') as failed,
               sum(b.recipients) as recipients, sum(b.devices) as devices, sum(b.inbox) as inbox,
               sum(b.capped) as capped, sum(b.pref_skipped) as pref_skipped
        from private.integration_broadcasts b where b.key_id = k.id and b.created_at >= v_since) bc on true
      left join lateral (
        select sum(r.sent) as sent, sum(r.failed) as failed, sum(r.invalid) as invalid, sum(r.expired) as expired,
               sum(r.cancelled) as cancelled
        from private.push_ref_stats r
        where r.ref in (select private.integration_ref(k.id, v_from + i) from generate_series(0, v_days - 1) i)) s on true
      where k.revoked_at is null or k.revoked_at > v_from or d.received is not null or d.posts is not null), '[]'),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', x.day, 'received', x.received, 'queued', x.queued,
                                          'no_recipient', x.no_recipient, 'posts', x.posts,
                                          'accepted', x.accepted) order by x.day)
      from (select y.day, sum(y.received) as received, sum(y.queued) as queued, sum(y.no_recipient) as no_recipient,
                   sum(y.posts) as posts, sum(y.accepted) as accepted
            from private.integration_daily y where y.day >= v_from group by y.day) x), '[]'),
    'broadcasts', (
      select jsonb_build_object(
               'total', count(*), 'active', count(*) filter (where b.status in ('queued', 'sending')),
               'done', count(*) filter (where b.status = 'done'), 'failed', count(*) filter (where b.status = 'failed'),
               'recipients', coalesce(sum(b.recipients), 0), 'devices', coalesce(sum(b.devices), 0),
               'inbox', coalesce(sum(b.inbox), 0), 'capped', coalesce(sum(b.capped), 0),
               'pref_skipped', coalesce(sum(b.pref_skipped), 0))
      from private.integration_broadcasts b where b.created_at >= v_since),
    'linked', (
      select jsonb_build_object('accounts', count(distinct l.cust_id), 'profiles', count(distinct l.profile_id))
      from private.account_links l
      where l.seen_at > now() - make_interval(days => v_link)));
end;
$$;

create or replace function cs_api.integration_stats_daily(p_days integer default 30, p_key_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 400);
  v_from date := private.integration_day() - (v_days - 1);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('key_id', k.id, 'name', k.name, 'prefix', k.prefix, 'days', coalesce((
             select jsonb_agg(jsonb_build_object('day', d.day, 'received', d.received, 'queued', d.queued,
                                                 'devices', d.devices, 'no_recipient', d.no_recipient,
                                                 'duplicate', d.duplicate, 'invalid', d.invalid, 'posts', d.posts,
                                                 'posts_rejected', d.posts_rejected, 'accepted', d.accepted,
                                                 'inbox', d.inbox) order by d.day)
             from private.integration_daily d
             where d.key_id = k.id and d.day >= v_from), '[]'))
           order by k.created_at)
    from private.integration_keys k
    where p_key_id is null or k.id = p_key_id), '[]');
end;
$$;

create or replace function private.integration_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_receipts   integer;
  v_links      integer;
  v_broadcasts integer;
begin
  delete from private.integration_receipts
   where created_at < now() - make_interval(days => private.setting_num('integration.receipt_days', 7)::integer);
  get diagnostics v_receipts = row_count;
  delete from private.account_links
   where seen_at < now() - make_interval(days => private.setting_num('integration.account_link_days', 30)::integer);
  get diagnostics v_links = row_count;
  delete from private.integration_daily where day < private.integration_day() - 400;
  delete from private.integration_broadcast_caps where day < private.integration_day() - 1;
  delete from private.integration_broadcasts
   where status in ('done', 'failed')
     and created_at < now() - make_interval(days => private.setting_num('integration.broadcast_days', 90)::integer);
  get diagnostics v_broadcasts = row_count;
  return jsonb_build_object('receipts', v_receipts, 'links', v_links, 'broadcasts', v_broadcasts);
end;
$$;

drop function cs_api.community_room_messages(text, integer, timestamptz);

create function cs_api.community_room_messages(p_code text, p_limit integer default 50,
                                               p_before timestamptz default null, p_before_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'stock' and r.stock_code = upper(btrim(coalesce(p_code, '')));
  if v_room is null then
    perform private.api_error(404, 'room_not_found', 'Room saham tidak ditemukan');
  end if;
  return jsonb_build_object('room_id', v_room, 'items', coalesce((
    select jsonb_agg(x.v order by x.created_at desc, x.id desc)
    from (select m.created_at, m.id, jsonb_build_object(
            'id', m.id, 'created_at', m.created_at, 'edited_at', m.edited_at, 'body', left(m.body, 500),
            'attachments', jsonb_array_length(coalesce(m.attachments, '[]'::jsonb)),
            'moderation_status', m.moderation_status,
            'sender', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name)) as v
          from public.messages m
          join public.profiles p on p.id = m.sender_id
          where m.room_id = v_room and m.deleted_at is null
            and (p_before is null or m.created_at < p_before
                 or (p_before_id is not null and m.created_at = p_before and m.id < p_before_id))
          order by m.created_at desc, m.id desc
          limit least(greatest(coalesce(p_limit, 50), 1), 100)) x), '[]'));
end;
$$;

revoke execute on function private.notification_pref_type(text, text) from public;
revoke execute on function private.notification_pref_default_push(text) from public;
revoke execute on function private.push_allowed_for(uuid, text, text) from public;
revoke execute on function private.integration_target(jsonb) from public;
revoke execute on function private.integration_channels(jsonb) from public;
revoke execute on function private.integration_deliver(uuid, jsonb, text[], text, jsonb) from public;
revoke execute on function private.integration_broadcast_batch(uuid, integer) from public;
revoke execute on function private.integration_broadcast_tick() from public;
revoke execute on function private.integration_broadcast_view(private.integration_broadcasts) from public;
revoke execute on function cs_api.integration_broadcasts(uuid, integer) from public;
revoke execute on function cs_api.community_room_messages(text, integer, timestamptz, uuid) from public;

grant execute on function cs_api.integration_broadcasts(uuid, integer) to authenticated;
grant execute on function cs_api.community_room_messages(text, integer, timestamptz, uuid) to authenticated;
