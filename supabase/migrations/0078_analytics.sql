insert into private.settings (key, value, description) values
  ('analytics.retention_months', '12', 'Event analitik disimpan selama sekian bulan (partisi bulanan dihapus otomatis)'),
  ('analytics.max_batch', '50', 'Maksimal event per panggilan track_events')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('analytics', 30, 60),
  ('analytics', 2000, 86400)
on conflict (action, window_seconds) do nothing;

create or replace function private.analytics_event_names()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['feed_open', 'post_create', 'comment_create', 'message_send', 'stock_tap', 'order_tap', 'search',
               'share_chart'];
$$;

create table private.analytics_events (
  id          bigint generated always as identity,
  created_at  timestamptz not null default now(),
  received_at timestamptz not null default now(),
  user_id     uuid not null,
  event       text not null check (event in ('feed_open', 'post_create', 'comment_create', 'message_send',
                                             'stock_tap', 'order_tap', 'search', 'share_chart')),
  platform    text check (platform in ('android', 'ios', 'web')),
  app_version text check (char_length(app_version) <= 40),
  props       jsonb not null default '{}' check (jsonb_typeof(props) = 'object' and pg_column_size(props) <= 2048),
  primary key (id, created_at)
) partition by range (created_at);
create index analytics_events_created_idx on private.analytics_events (created_at, user_id);
create index analytics_events_user_idx on private.analytics_events (user_id, created_at);
create index analytics_events_event_idx on private.analytics_events (event, created_at);
create table private.analytics_events_default partition of private.analytics_events default;
alter table private.analytics_events enable row level security;
alter table private.analytics_events_default enable row level security;

create or replace function private.analytics_ensure_partitions(p_months_ahead integer default 3)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start   timestamp;
  v_name    text;
  v_created integer := 0;
begin
  for i in -1 .. greatest(coalesce(p_months_ahead, 3), 0) loop
    v_start := date_trunc('month', now() at time zone 'UTC') + make_interval(months => i);
    v_name := format('analytics_events_p%s', to_char(v_start, 'YYYYMM'));
    continue when to_regclass('private.' || v_name) is not null;
    begin
      execute format('create table private.%I partition of private.analytics_events for values from (%L) to (%L)',
                     v_name, v_start at time zone 'UTC', (v_start + interval '1 month') at time zone 'UTC');
      execute format('alter table private.%I enable row level security', v_name);
      v_created := v_created + 1;
    exception when check_violation then
      raise warning 'private.analytics_ensure_partitions: partisi % dilewati, partisi default sudah berisi data bulan itu',
        v_name;
    end;
  end loop;
  return v_created;
end;
$$;

create or replace function private.analytics_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cutoff  timestamp := date_trunc('month', now() at time zone 'UTC')
                         - make_interval(months => private.setting_num('analytics.retention_months', 12)::integer);
  v_part    record;
  v_dropped integer := 0;
  v_deleted integer;
  v_created integer := private.analytics_ensure_partitions(3);
begin
  for v_part in
    select c.relname
    from pg_inherits i
    join pg_class c on c.oid = i.inhrelid
    where i.inhparent = 'private.analytics_events'::regclass
      and c.relname ~ '^analytics_events_p[0-9]{6}$'
      and to_date(substr(c.relname, 19), 'YYYYMM')::timestamp < v_cutoff
  loop
    execute format('drop table private.%I', v_part.relname);
    v_dropped := v_dropped + 1;
  end loop;
  delete from private.analytics_events_default where created_at < v_cutoff at time zone 'UTC';
  get diagnostics v_deleted = row_count;
  return jsonb_build_object('created', v_created, 'dropped_partitions', v_dropped, 'deleted_default', v_deleted);
end;
$$;

select private.analytics_ensure_partitions(3);
select cron.schedule('social-analytics', '25 2 * * *', 'select private.analytics_maintenance()');

create or replace function private.analytics_props(p_props jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(e.key, case when e.key = 'stock_code' then to_jsonb(upper(e.value #>> '{}'))
                                               else e.value end), '{}')
  from jsonb_each(case when jsonb_typeof(p_props) = 'object' then p_props else '{}'::jsonb end) e
  where case
    when e.key = 'stock_code' then jsonb_typeof(e.value) = 'string'
                                   and upper(e.value #>> '{}') ~ '^[A-Z][A-Z0-9]{1,11}$'
    when e.key in ('post_id', 'room_id', 'target_id', 'notification_id') then
      jsonb_typeof(e.value) = 'string'
      and (e.value #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    when e.key = 'hashtag' then jsonb_typeof(e.value) = 'string' and (e.value #>> '{}') ~ '^[a-z0-9_]{2,50}$'
    when e.key = 'source' then (e.value #>> '{}') = any (array['feed', 'post', 'comment', 'chat', 'search', 'profile',
                                 'notification', 'stock', 'hashtag', 'trending', 'push', 'deep_link', 'share', 'other'])
                               and jsonb_typeof(e.value) = 'string'
    when e.key = 'scope' then (e.value #>> '{}') = any (array['global', 'following', 'stock', 'user', 'hashtag',
                                 'bookmarks', 'trending']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'type' then (e.value #>> '{}') = any (array['all', 'posts', 'users', 'stocks', 'hashtags', 'direct',
                                 'group', 'stock', 'support', 'text', 'image', 'post']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'side' then (e.value #>> '{}') = any (array['buy', 'sell']) and jsonb_typeof(e.value) = 'string'
    when e.key = 'interval' then (e.value #>> '{}') = any (array['intraday', '1d', '1w', '1m', '3m', '6m', '1y', '5y',
                                 'all']) and jsonb_typeof(e.value) = 'string'
    when e.key in ('result_count', 'position', 'query_length', 'duration_ms') then
      jsonb_typeof(e.value) = 'number' and (e.value #>> '{}') ~ '^[0-9]{1,9}$'
    when e.key in ('has_attachment', 'has_poll', 'is_reply') then jsonb_typeof(e.value) = 'boolean'
    else false
  end;
$$;

create or replace function public.track_events(p_events jsonb, p_platform text default null,
                                               p_app_version text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_version  text := left(nullif(btrim(coalesce(p_app_version, '')), ''), 40);
  v_total    integer;
  v_accepted integer;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' then
    perform private.api_error(400, 'invalid_events', 'Event harus berupa array');
  end if;
  v_total := jsonb_array_length(p_events);
  if v_total > private.setting_num('analytics.max_batch', 50) then
    perform private.api_error(400, 'too_many_events',
      format('Maksimal %s event per kiriman', private.setting_num('analytics.max_batch', 50)));
  end if;
  if v_platform is not null and v_platform not in ('android', 'ios', 'web') then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, atau web');
  end if;
  if v_total = 0 then
    return jsonb_build_object('accepted', 0, 'dropped', 0);
  end if;
  perform private.consume_rate_limit(v_uid, 'analytics');
  if not private.feature_enabled('analytics', v_uid) then
    return jsonb_build_object('accepted', 0, 'dropped', v_total, 'disabled', true);
  end if;

  insert into private.analytics_events (created_at, user_id, event, platform, app_version, props)
  select case
           when x.ts is not null and x.ts between now() - interval '7 days' and now() + interval '5 minutes' then x.ts
           else now()
         end,
         v_uid, x.event, v_platform, v_version, private.analytics_props(x.props)
  from (
    select e.value ->> 'event' as event,
           e.value -> 'props' as props,
           case when (e.value ->> 'ts') ~ '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}(:?\d{2})?)$'
                then (e.value ->> 'ts')::timestamptz end as ts
    from jsonb_array_elements(p_events) e
    where jsonb_typeof(e.value) = 'object'
  ) x
  where x.event = any (private.analytics_event_names());
  get diagnostics v_accepted = row_count;
  return jsonb_build_object('accepted', v_accepted, 'dropped', v_total - v_accepted);
end;
$$;

create or replace function cs_api.admin_analytics(p_from date default null, p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_to    date := coalesce(p_to, (now() at time zone 'Asia/Jakarta')::date);
  v_from  date := coalesce(p_from, coalesce(p_to, (now() at time zone 'Asia/Jakarta')::date) - 29);
  v_start timestamptz;
  v_end   timestamptz;
  v_mau   integer;
  v_wau   integer;
  v_dau   jsonb;
  v_avg   numeric;
  v_ret   jsonb;
begin
  if v_from > v_to or v_to - v_from > 365 then
    perform private.api_error(400, 'invalid_range', 'Rentang tanggal maksimal 366 hari dan tanggal awal ≤ tanggal akhir');
  end if;
  v_start := v_from::timestamp at time zone 'Asia/Jakarta';
  v_end := (v_to + 1)::timestamp at time zone 'Asia/Jakarta';

  select coalesce(jsonb_agg(jsonb_build_object('date', d.day, 'users', coalesce(c.users, 0)) order by d.day), '[]'),
         coalesce(avg(coalesce(c.users, 0)), 0)
    into v_dau, v_avg
  from generate_series(v_from, v_to, interval '1 day') as d(day)
  left join (
    select (e.created_at at time zone 'Asia/Jakarta')::date as day, count(distinct e.user_id)::integer as users
    from private.analytics_events e
    where e.created_at >= v_start and e.created_at < v_end
    group by 1
  ) c on c.day = d.day::date;

  select count(distinct e.user_id)::integer into v_wau
  from private.analytics_events e where e.created_at >= v_end - interval '7 days' and e.created_at < v_end;
  select count(distinct e.user_id)::integer into v_mau
  from private.analytics_events e where e.created_at >= v_end - interval '30 days' and e.created_at < v_end;

  with cohort as (
    select p.id, date_trunc('week', p.created_at at time zone 'Asia/Jakarta')::date as cohort
    from public.profiles p
    where p.created_at >= v_start and p.created_at < v_end
      and p.deleted_at is null
      and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
  ), sizes as (
    select c.cohort, count(*)::integer as size from cohort c group by c.cohort
  ), activity as (
    select c.cohort, ((e.created_at at time zone 'Asia/Jakarta')::date - c.cohort) / 7 as week,
           count(distinct e.user_id)::integer as active
    from cohort c
    join private.analytics_events e
      on e.user_id = c.id
     and e.created_at >= c.cohort::timestamp at time zone 'Asia/Jakarta'
     and e.created_at < (c.cohort + 56)::timestamp at time zone 'Asia/Jakarta'
    group by 1, 2
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'cohort_week', s.cohort, 'users', s.size,
           'weeks', (select jsonb_agg(jsonb_build_object('week', g.n, 'active', coalesce(a.active, 0),
                                                         'pct', round(100.0 * coalesce(a.active, 0) / s.size, 1))
                                      order by g.n)
                     from generate_series(0, 7) as g(n)
                     left join activity a on a.cohort = s.cohort and a.week = g.n
                     where s.cohort + g.n * 7 <= (now() at time zone 'Asia/Jakarta')::date))
           order by s.cohort), '[]')
    into v_ret
  from sizes s;

  return jsonb_build_object(
    'from', v_from, 'to', v_to, 'timezone', 'Asia/Jakarta', 'generated_at', now(),
    'active_users', jsonb_build_object(
      'dau', v_dau, 'avg_dau', round(v_avg, 1), 'wau', v_wau, 'mau', v_mau,
      'stickiness_pct', case when v_mau > 0 then round(100 * v_avg / v_mau, 1) end),
    'retention', v_ret,
    'content', jsonb_build_object(
      'posts', (select count(*) from public.posts p where p.created_at >= v_start and p.created_at < v_end),
      'comments', (select count(*) from public.comments c where c.created_at >= v_start and c.created_at < v_end),
      'messages', (select count(*) from public.messages m
                   where m.created_at >= v_start and m.created_at < v_end and m.session_id is null),
      'likes', (select count(*) from public.reactions r where r.created_at >= v_start and r.created_at < v_end),
      'daily', coalesce((
        select jsonb_agg(jsonb_build_object('date', d.day::date,
                                            'posts', coalesce(p.n, 0), 'comments', coalesce(c.n, 0)) order by d.day)
        from generate_series(v_from, v_to, interval '1 day') as d(day)
        left join (select (x.created_at at time zone 'Asia/Jakarta')::date as day, count(*)::integer as n
                   from public.posts x where x.created_at >= v_start and x.created_at < v_end group by 1) p
          on p.day = d.day::date
        left join (select (x.created_at at time zone 'Asia/Jakarta')::date as day, count(*)::integer as n
                   from public.comments x where x.created_at >= v_start and x.created_at < v_end group by 1) c
          on c.day = d.day::date), '[]')),
    'top_stocks', coalesce((
      select jsonb_agg(jsonb_build_object('code', s.stock_code, 'posts', s.posts, 'authors', s.authors)
                       order by s.posts desc, s.stock_code)
      from (
        select ps.stock_code, count(*)::integer as posts, count(distinct p.author_id)::integer as authors
        from public.post_stocks ps
        join public.posts p on p.id = ps.post_id
        where ps.post_created_at >= v_start and ps.post_created_at < v_end
          and p.deleted_at is null and p.moderation_status = 'visible'
        group by ps.stock_code
        order by count(*) desc, ps.stock_code
        limit 10
      ) s), '[]'),
    'events', coalesce((
      select jsonb_object_agg(x.event, x.n)
      from (select e.event, count(*)::integer as n from private.analytics_events e
            where e.created_at >= v_start and e.created_at < v_end group by e.event) x), '{}'),
    'order_taps', (
      select jsonb_build_object(
        'taps', count(*) filter (where e.event = 'order_tap'),
        'users', count(distinct e.user_id) filter (where e.event = 'order_tap'),
        'stock_tap_users', count(distinct e.user_id) filter (where e.event = 'stock_tap'),
        'conversion_pct', case when count(distinct e.user_id) filter (where e.event = 'stock_tap') > 0
          then round(100.0 * count(distinct e.user_id) filter (where e.event = 'order_tap')
                     / count(distinct e.user_id) filter (where e.event = 'stock_tap'), 1) end,
        'by_source', coalesce((
          select jsonb_object_agg(s.source, s.n)
          from (select coalesce(o.props ->> 'source', 'other') as source, count(*)::integer as n
                from private.analytics_events o
                where o.event = 'order_tap' and o.created_at >= v_start and o.created_at < v_end
                group by 1) s), '{}'),
        'top_stocks', coalesce((
          select jsonb_agg(jsonb_build_object('code', s.code, 'taps', s.n) order by s.n desc, s.code)
          from (select o.props ->> 'stock_code' as code, count(*)::integer as n
                from private.analytics_events o
                where o.event = 'order_tap' and o.created_at >= v_start and o.created_at < v_end
                  and o.props ? 'stock_code'
                group by 1 order by 2 desc, 1 limit 10) s), '[]'))
      from private.analytics_events e
      where e.created_at >= v_start and e.created_at < v_end and e.event in ('order_tap', 'stock_tap')));
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
  delete from private.analytics_events where user_id = new.id;
  return null;
end;
$$;

create or replace function private.export_optional(p_kind text, p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_column text;
  v_result jsonb;
begin
  if p_kind = 'linked_accounts' then
    if to_regprocedure('private.account_links_export(uuid)') is null then
      return '[]';
    end if;
    execute 'select private.account_links_export($1)' into v_result using p_user;
    return coalesce(v_result, '[]');
  end if;
  if p_kind = 'appeals' then
    if to_regclass('public.appeals') is null then
      return '[]';
    end if;
    select a.attname into v_column
    from pg_attribute a
    where a.attrelid = 'public.appeals'::regclass and a.attnum > 0 and not a.attisdropped
      and a.attname in ('user_id', 'appellant_id', 'created_by')
    order by array_position(array['user_id', 'appellant_id', 'created_by'], a.attname::text)
    limit 1;
    if v_column is null then
      return '[]';
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(a) - %L order by a.created_at), ''[]'') from public.appeals a where a.%I = $1',
                   v_column, v_column)
      into v_result using p_user;
    return coalesce(v_result, '[]');
  end if;
  return '[]';
exception when undefined_column or undefined_table or undefined_function then
  return '[]';
end;
$$;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.consume_rate_limit(v_uid, 'data_export');
  perform private.log_personal_data_access(v_uid, 'self_export', '{all}');

  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'olt_user_id' from public.profiles p where p.id = v_uid),
    'email', (select up.email from private.user_private up where up.user_id = v_uid),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'body', body, 'sentiment', sentiment, 'attachments', attachments,
        'created_at', created_at, 'edited_at', edited_at) order by created_at)
      from public.posts where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'polls', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', pl.post_id, 'ends_at', pl.ends_at,
        'options', (select jsonb_agg(o.label order by o.position)
                    from public.post_poll_options o where o.post_id = pl.post_id))
        order by pl.created_at)
      from public.post_polls pl join public.posts p on p.id = pl.post_id
      where p.author_id = v_uid and p.deleted_at is null), '[]'::jsonb),
    'poll_votes', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', v.post_id, 'option', o.label, 'created_at', v.created_at) order by v.created_at)
      from public.post_poll_votes v join public.post_poll_options o on o.id = v.option_id
      where v.user_id = v_uid), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'post_id', post_id, 'parent_id', parent_id, 'body', body, 'created_at', created_at)
        order by created_at)
      from public.comments where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'room_id', room_id, 'body', body, 'attachments', attachments, 'created_at', created_at)
        order by created_at)
      from public.messages where sender_id = v_uid and deleted_at is null), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) - 'user_id') from public.reactions r
      where r.user_id = v_uid), '[]'::jsonb),
    'message_reactions', coalesce((select jsonb_agg(jsonb_build_object(
        'message_id', mr.message_id, 'emoji', mr.emoji, 'created_at', mr.created_at) order by mr.created_at)
      from public.message_reactions mr where mr.user_id = v_uid), '[]'::jsonb),
    'bookmarks', coalesce((select jsonb_agg(jsonb_build_object('post_id', b.post_id, 'created_at', b.created_at)
                                            order by b.created_at)
      from public.bookmarks b where b.user_id = v_uid), '[]'::jsonb),
    'following', coalesce((select jsonb_agg(f.following_id) from public.follows f
      where f.follower_id = v_uid), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(b.blocked_id) from public.blocks b
      where b.blocker_id = v_uid), '[]'::jsonb),
    'muted_users', coalesce((select jsonb_agg(m.muted_id) from public.mutes m
      where m.muter_id = v_uid), '[]'::jsonb),
    'muted_keywords', coalesce((select jsonb_agg(k.keyword) from public.muted_keywords k
      where k.user_id = v_uid), '[]'::jsonb),
    'muted_stocks', coalesce((select jsonb_agg(s.stock_code) from public.muted_stocks s
      where s.user_id = v_uid), '[]'::jsonb),
    'watchlist', coalesce((select jsonb_agg(w.stock_code) from public.stock_watchers w
      where w.user_id = v_uid), '[]'::jsonb),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
        'target_type', target_type, 'target_id', target_id, 'reason', reason,
        'status', status, 'created_at', created_at))
      from public.reports where reporter_id = v_uid), '[]'::jsonb),
    'consents', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', d.kind, 'version', d.version, 'title', d.title, 'accepted_at', c.accepted_at)
        order by c.accepted_at)
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb),
    'support_tickets', coalesce((select jsonb_agg(jsonb_build_object(
        'ticket_number', t.ticket_number, 'topic', t.topic, 'status', t.status, 'created_at', t.created_at,
        'closed_at', t.closed_at, 'rating', t.rating, 'rating_comment', t.rating_comment)
        order by t.created_at)
      from cs.tickets t where t.customer_id = v_uid), '[]'::jsonb),
    'push_devices', coalesce((select jsonb_agg(jsonb_build_object(
        'platform', d.platform, 'locale', d.locale, 'app_version', d.app_version,
        'created_at', d.created_at, 'last_seen_at', d.last_seen_at) order by d.created_at)
      from private.push_devices d where d.user_id = v_uid), '[]'::jsonb),
    'notification_preferences', private.notification_prefs_view(v_uid),
    'linked_accounts', private.export_optional('linked_accounts', v_uid),
    'appeals', private.export_optional('appeals', v_uid),
    'analytics_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'created_at', e.created_at, 'platform', e.platform, 'app_version', e.app_version,
        'props', e.props) order by e.created_at desc)
      from (select * from private.analytics_events a where a.user_id = v_uid order by a.created_at desc limit 5000) e),
      '[]'::jsonb)
  );
end;
$$;

revoke execute on function private.analytics_event_names() from public;
revoke execute on function private.analytics_ensure_partitions(integer) from public;
revoke execute on function private.analytics_maintenance() from public;
revoke execute on function private.analytics_props(jsonb) from public;
revoke execute on function private.export_optional(text, uuid) from public;
revoke execute on function public.track_events(jsonb, text, text) from public, anon;
revoke execute on function cs_api.admin_analytics(date, date) from public;
grant execute on function public.track_events(jsonb, text, text) to authenticated;
grant execute on function cs_api.admin_analytics(date, date) to authenticated;
