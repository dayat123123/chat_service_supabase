insert into private.rate_limits (action, max_count, window_seconds) values
  ('notification_event', 120, 60)
on conflict (action, window_seconds) do nothing;

create table private.notification_events (
  id              bigint generated always as identity primary key,
  user_id         uuid references public.profiles (id) on delete set null,
  event           text not null check (event in ('opened', 'tapped')),
  source_type     text not null check (source_type in ('campaign', 'broadcast', 'notification')),
  source_id       uuid not null,
  notification_id uuid,
  created_at      timestamptz not null default now(),
  constraint notification_events_once unique (user_id, source_type, source_id, event)
);
create index notification_events_source_idx on private.notification_events (source_type, source_id, event);
create index notification_events_created_idx on private.notification_events (created_at);
alter table private.notification_events enable row level security;

create or replace function private.notification_event_stats(p_type text, p_id uuid, p_recipients integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'opened', s.opened,
    'tapped', s.tapped,
    'open_rate', case when coalesce(p_recipients, 0) > 0 then round(100.0 * s.opened / p_recipients, 1) end,
    'tap_rate', case when coalesce(p_recipients, 0) > 0 then round(100.0 * s.tapped / p_recipients, 1) end)
  from (select count(*) filter (where e.event = 'opened')::integer as opened,
               count(*) filter (where e.event = 'tapped')::integer as tapped
        from private.notification_events e
        where e.source_type = p_type and e.source_id = p_id) s;
$$;

create or replace function public.report_notification_event(p_event text, p_notification_id uuid default null,
                                                            p_campaign_id uuid default null,
                                                            p_broadcast_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_note      public.notifications;
  v_campaign  uuid;
  v_broadcast uuid;
  v_type      text;
  v_source    uuid;
  v_recorded  boolean := false;
  v_read      boolean := false;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if coalesce(p_event, '') not in ('opened', 'tapped') then
    perform private.api_error(400, 'invalid_event', 'Event harus opened atau tapped');
  end if;
  if p_notification_id is null and p_campaign_id is null and p_broadcast_id is null then
    perform private.api_error(400, 'missing_source', 'Sertakan notification_id, campaign_id, atau broadcast_id');
  end if;
  perform private.consume_rate_limit(v_uid, 'notification_event');

  if p_notification_id is not null then
    select * into v_note from public.notifications n where n.id = p_notification_id and n.user_id = v_uid;
  end if;
  v_campaign := coalesce(p_campaign_id,
                         case when v_note.payload ->> 'campaign_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                              then (v_note.payload ->> 'campaign_id')::uuid end);
  v_broadcast := coalesce(p_broadcast_id,
                          case when v_note.payload ->> 'broadcast_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                               then (v_note.payload ->> 'broadcast_id')::uuid end);
  if v_campaign is not null and not exists (
       select 1 from cs.community_campaigns c where c.id = v_campaign and c.status in ('sending', 'sent')) then
    v_campaign := null;
  end if;
  if v_broadcast is not null and not exists (
       select 1 from private.integration_broadcasts b where b.id = v_broadcast and b.status <> 'queued') then
    v_broadcast := null;
  end if;

  if v_campaign is not null then
    v_type := 'campaign';
    v_source := v_campaign;
  elsif v_broadcast is not null then
    v_type := 'broadcast';
    v_source := v_broadcast;
  elsif v_note.id is not null then
    v_type := 'notification';
    v_source := v_note.id;
  end if;

  if v_type is not null then
    with ins as (
      insert into private.notification_events (user_id, event, source_type, source_id, notification_id)
      select v_uid, e.event, v_type, v_source, v_note.id
      from unnest(case when p_event = 'tapped' then array['opened', 'tapped'] else array['opened'] end) as e(event)
      on conflict (user_id, source_type, source_id, event) do nothing
      returning event)
    select coalesce(bool_or(ins.event = p_event), false) into v_recorded from ins;
  end if;

  if v_note.id is not null and v_note.read_at is null then
    update public.notifications set read_at = now() where id = v_note.id and read_at is null;
    v_read := found;
  end if;

  return jsonb_build_object('recorded', v_recorded, 'source', v_type, 'source_id', v_source, 'read', v_read);
end;
$$;

alter table cs.community_campaigns
  add column audience_days     integer check (audience_days between 1 and 365),
  add column audience_platform text check (audience_platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux')),
  add column audience_account  uuid references cs.official_accounts (profile_id);
alter table cs.community_campaigns drop constraint community_campaigns_audience_check;
alter table cs.community_campaigns drop constraint community_campaigns_audience;
alter table cs.community_campaigns add constraint community_campaigns_audience_check
  check (audience in ('all', 'stock', 'new_users', 'inactive', 'platform', 'followers'));
alter table cs.community_campaigns add constraint community_campaigns_audience
  check ((audience = 'stock') = (audience_stock is not null)
         and (audience in ('new_users', 'inactive')) = (audience_days is not null)
         and (audience = 'platform') = (audience_platform is not null)
         and (audience = 'followers') = (audience_account is not null));

create or replace function private.profile_last_active(p_profile uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select greatest(
    (select p.created_at from public.profiles p where p.id = p_profile),
    (select up.last_login_at from private.user_private up where up.user_id = p_profile),
    (select max(d.last_seen_at) from private.push_devices d where d.user_id = p_profile),
    (select max(e.created_at) from private.analytics_events e where e.user_id = p_profile));
$$;

create or replace function private.profile_last_platform(p_profile uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select e.platform from private.analytics_events e
  where e.user_id = p_profile and e.platform is not null
  order by e.created_at desc
  limit 1;
$$;

create or replace function cs.community_audience_match(p_profile uuid, p_audience text, p_stock text, p_days integer,
                                                       p_platform text, p_account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_audience
    when 'all' then true
    when 'stock' then exists (select 1 from public.stock_watchers w where w.user_id = p_profile and w.stock_code = p_stock)
    when 'new_users' then exists (select 1 from public.profiles p
                                  where p.id = p_profile and p.created_at > now() - make_interval(days => p_days))
    when 'inactive' then coalesce(private.profile_last_active(p_profile) <= now() - make_interval(days => p_days), false)
    when 'platform' then exists (select 1 from private.push_devices d where d.user_id = p_profile and d.platform = p_platform)
                         or coalesce(private.profile_last_platform(p_profile) = p_platform, false)
    when 'followers' then exists (select 1 from public.follows f where f.follower_id = p_profile and f.following_id = p_account)
    else false
  end;
$$;

create or replace function cs.community_audience_check(p_audience text, p_stock text, p_days integer, p_platform text,
                                                       p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_aud      text := lower(btrim(coalesce(p_audience, 'all')));
  v_stock    text := nullif(upper(btrim(coalesce(p_stock, ''))), '');
  v_platform text := nullif(lower(btrim(coalesce(p_platform, ''))), '');
begin
  if v_aud not in ('all', 'stock', 'new_users', 'inactive', 'platform', 'followers') then
    perform private.api_error(400, 'invalid_audience',
      'Penerima: all, stock, new_users, inactive, platform, atau followers');
  end if;
  if v_aud = 'stock' and coalesce(v_stock, '') !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_audience', 'Penerima: semua pengguna atau pemantau saham dengan kode valid');
  end if;
  if v_aud in ('new_users', 'inactive') and coalesce(p_days, 0) not between 1 and 365 then
    perform private.api_error(400, 'invalid_audience', 'Jumlah hari penerima 1–365');
  end if;
  if v_aud = 'platform' and (v_platform is null or v_platform <> all (private.client_platforms())) then
    perform private.api_error(400, 'invalid_audience', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_aud = 'followers' and (p_account is null or not cs.official_active(p_account)) then
    perform private.api_error(400, 'invalid_audience', 'Pilih akun resmi aktif untuk penerima pengikut');
  end if;
  return jsonb_build_object(
    'audience', v_aud,
    'stock', case when v_aud = 'stock' then v_stock end,
    'days', case when v_aud in ('new_users', 'inactive') then p_days end,
    'platform', case when v_aud = 'platform' then v_platform end,
    'account', case when v_aud = 'followers' then p_account end);
end;
$$;

drop function cs_api.community_audience_size(text, text);
drop function cs.community_audience_count(text, text);

create or replace function cs.community_audience_count(p_audience text, p_stock text, p_days integer, p_platform text,
                                                       p_account uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.profiles p
  where p.deleted_at is null
    and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
    and cs.community_audience_match(p.id, p_audience, p_stock, p_days, p_platform, p_account);
$$;

create or replace function cs_api.community_audience_size(p_audience text, p_stock text default null,
                                                          p_days integer default null, p_platform text default null,
                                                          p_account_id uuid default null)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_community('{community.post,community.publish}');
  v_aud jsonb := cs.community_audience_check(p_audience, p_stock, p_days, p_platform, p_account_id);
begin
  return cs.community_audience_count(v_aud ->> 'audience', v_aud ->> 'stock', (v_aud ->> 'days')::integer,
                                     v_aud ->> 'platform', (v_aud ->> 'account')::uuid);
end;
$$;

create or replace function cs.community_campaign_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id, 'account', cs.community_account_ref(m.account_id), 'title', m.title, 'body', m.body,
    'link_post', case when m.link_post_id is not null then (
                   select jsonb_build_object('id', c.id, 'title', c.title, 'body', left(c.body, 140), 'post_id', c.post_id)
                   from cs.community_posts c where c.id = m.link_post_id) end,
    'link_url', m.link_url, 'audience', m.audience, 'audience_stock', m.audience_stock,
    'audience_days', m.audience_days, 'audience_platform', m.audience_platform,
    'audience_account', case when m.audience_account is not null then cs.community_account_ref(m.audience_account) end,
    'status', m.status, 'send_at', m.send_at,
    'created_by', cs.staff_ref(m.created_by), 'created_at', m.created_at, 'updated_at', m.updated_at,
    'submitted_at', m.submitted_at, 'reviewed_by', cs.staff_ref(m.reviewed_by), 'reviewed_at', m.reviewed_at,
    'review_note', m.review_note, 'started_at', m.started_at, 'finished_at', m.finished_at,
    'recipients', m.recipients, 'version', m.version)
    || private.notification_event_stats('campaign', m.id, m.recipients)
  from cs.community_campaigns m
  where m.id = p_id;
$$;

create or replace function cs.community_send_batch(p_id uuid, p_size integer default 5000)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  m       cs.community_campaigns;
  v_post  uuid;
  v_count integer;
  v_last  text;
begin
  select * into m from cs.community_campaigns where id = p_id for update;
  if m.status is distinct from 'sending' then
    return 0;
  end if;
  select c.post_id into v_post from cs.community_posts c where c.id = m.link_post_id;

  with batch as (
    select p.id
    from public.profiles p
    where p.deleted_at is null
      and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
      and (m.last_user_id is null or p.id > m.last_user_id)
      and cs.community_audience_match(p.id, m.audience, m.audience_stock, m.audience_days, m.audience_platform,
                                      m.audience_account)
    order by p.id
    limit greatest(p_size, 1)
  ), sent as (
    insert into public.notifications (user_id, actor_id, type, payload)
    select b.id, m.account_id, 'announcement',
           jsonb_strip_nulls(jsonb_build_object('campaign_id', m.id, 'title', m.title, 'body', m.body,
                                                'post_id', v_post, 'url', m.link_url))
    from batch b
    returning user_id
  )
  select count(*)::integer, max(user_id::text) into v_count, v_last from sent;

  update cs.community_campaigns
     set recipients = recipients + v_count,
         last_user_id = coalesce(v_last::uuid, last_user_id),
         status = case when v_count < greatest(p_size, 1) then 'sent' else status end,
         finished_at = case when v_count < greatest(p_size, 1) then now() end,
         updated_at = now()
   where id = m.id
  returning * into m;
  if m.status = 'sent' then
    perform cs.audit('community.campaign_sent', null, null,
                     jsonb_build_object('campaign', m.id, 'recipients', m.recipients));
  end if;
  return v_count;
end;
$$;

drop function cs_api.community_save_campaign(uuid, uuid, text, text, uuid, text, text, text, timestamptz, integer);

create or replace function cs_api.community_save_campaign(
  p_id                  uuid,
  p_account_id          uuid,
  p_title               text,
  p_body                text,
  p_link_post_id        uuid default null,
  p_link_url            text default null,
  p_audience            text default 'all',
  p_audience_stock      text default null,
  p_send_at             timestamptz default null,
  p_version             integer default null,
  p_audience_days       integer default null,
  p_audience_platform   text default null,
  p_audience_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.post}');
  v_title text := btrim(coalesce(p_title, ''));
  v_body  text := btrim(coalesce(p_body, ''));
  v_url   text := nullif(btrim(coalesce(p_link_url, '')), '');
  v_at    timestamptz := case when p_send_at > now() then p_send_at end;
  v_aud   jsonb;
  m       cs.community_campaigns;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if char_length(v_title) not between 3 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul notifikasi 3–80 karakter');
  end if;
  if char_length(v_body) not between 3 and 240 then
    perform private.api_error(400, 'invalid_body', 'Isi notifikasi 3–240 karakter');
  end if;
  perform private.validate_text(v_title || ' ' || v_body, 'message');
  perform private.apply_content_policy(v_title || ' ' || v_body);
  if p_link_post_id is not null and v_url is not null then
    perform private.api_error(400, 'invalid_link', 'Pilih satu tujuan: postingan atau tautan');
  end if;
  if p_link_post_id is not null and not exists (
       select 1 from cs.community_posts c join public.posts p on p.id = c.post_id
       where c.id = p_link_post_id and c.status = 'published' and p.deleted_at is null) then
    perform private.api_error(400, 'invalid_link', 'Postingan tujuan harus sudah terbit');
  end if;
  if v_url is not null and (v_url !~ '^https://[^\s]+$' or char_length(v_url) > 500) then
    perform private.api_error(400, 'invalid_link', 'Tautan harus https:// dan maksimal 500 karakter');
  end if;
  v_aud := cs.community_audience_check(p_audience, p_audience_stock, p_audience_days, p_audience_platform,
                                       p_audience_account_id);

  if p_id is null then
    insert into cs.community_campaigns (account_id, title, body, link_post_id, link_url, audience, audience_stock,
                                        audience_days, audience_platform, audience_account, send_at, created_by)
    values (p_account_id, v_title, v_body, p_link_post_id, v_url, v_aud ->> 'audience', v_aud ->> 'stock',
            (v_aud ->> 'days')::integer, v_aud ->> 'platform', (v_aud ->> 'account')::uuid, v_at, v_me)
    returning * into m;
  else
    select * into m from cs.community_campaigns where id = p_id for update;
    if not found then
      perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
    end if;
    if m.created_by <> v_me then
      perform private.api_error(403, 'not_campaign_owner', 'Hanya pembuat yang bisa mengubah draf ini');
    end if;
    if m.status not in ('draft', 'rejected') then
      perform private.api_error(409, 'invalid_status', 'Notifikasi ini tidak bisa diubah lagi');
    end if;
    perform cs.check_version(m.version, p_version);
    update cs.community_campaigns
       set account_id = p_account_id, title = v_title, body = v_body, link_post_id = p_link_post_id, link_url = v_url,
           audience = v_aud ->> 'audience', audience_stock = v_aud ->> 'stock',
           audience_days = (v_aud ->> 'days')::integer, audience_platform = v_aud ->> 'platform',
           audience_account = (v_aud ->> 'account')::uuid, send_at = v_at, status = 'draft',
           updated_at = now(), version = version + 1
     where id = m.id
    returning * into m;
  end if;
  perform cs.audit('community.campaign_save', null, null, jsonb_build_object('campaign', m.id, 'audience', v_aud));
  return cs.community_campaign_view(m.id);
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
  v_me         uuid := cs.require_community('{community.post,community.publish}');
  v_recipients integer;
begin
  select c.recipients into v_recipients from cs.community_campaigns c where c.id = p_id;
  if not found then
    perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
  end if;
  return cs.push_ref_view('campaign:' || p_id) || jsonb_build_object('state', cs.push_state())
         || private.notification_event_stats('campaign', p_id, v_recipients);
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
  v_message    jsonb;
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
  v_message := b.message
               || jsonb_build_object('data', coalesce(b.message -> 'data', '{}') || jsonb_build_object('broadcast_id', b.id))
               || case when jsonb_typeof(b.message -> 'inbox') = 'object'
                       then jsonb_build_object('inbox', (b.message -> 'inbox') || jsonb_build_object('broadcast_id', b.id))
                       else '{}'::jsonb end;
  foreach v_profile in array v_ids loop
    if b.category <> 'important'
       and coalesce((select c.count from private.integration_broadcast_caps c
                     where c.profile_id = v_profile and c.day = v_day), 0) >= v_cap then
      v_capped := v_capped + 1;
      continue;
    end if;
    select * into d from private.integration_deliver(v_profile, v_message, b.channels, b.category, v_options);
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
    'created_at', b.created_at, 'started_at', b.started_at, 'finished_at', b.finished_at)
    || private.notification_event_stats('broadcast', b.id, b.recipients);
$$;

revoke execute on function private.notification_event_stats(text, uuid, integer) from public;
revoke execute on function public.report_notification_event(text, uuid, uuid, uuid) from public, anon;
revoke execute on function private.profile_last_active(uuid) from public;
revoke execute on function private.profile_last_platform(uuid) from public;
revoke execute on function cs.community_audience_match(uuid, text, text, integer, text, uuid) from public;
revoke execute on function cs.community_audience_check(text, text, integer, text, uuid) from public;
revoke execute on function cs.community_audience_count(text, text, integer, text, uuid) from public;
revoke execute on function cs_api.community_audience_size(text, text, integer, text, uuid) from public;
revoke execute on function cs_api.community_save_campaign(uuid, uuid, text, text, uuid, text, text, text, timestamptz,
                                                          integer, integer, text, uuid) from public;

grant execute on function public.report_notification_event(text, uuid, uuid, uuid) to authenticated;
grant execute on function cs_api.community_audience_size(text, text, integer, text, uuid) to authenticated;
grant execute on function cs_api.community_save_campaign(uuid, uuid, text, text, uuid, text, text, text, timestamptz,
                                                         integer, integer, text, uuid) to authenticated;
