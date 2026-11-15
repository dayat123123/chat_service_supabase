insert into private.settings (key, value, description) values
  ('health.trade_relay_stale_seconds', '120', 'Relay trade dianggap mati bila tidak melapor selama sekian detik'),
  ('health.trade_relay_silent_minutes', '30', 'Relay trade dianggap diam bila tidak ada paket realtime selama sekian menit di jam bursa')
on conflict (key) do nothing;

create table private.trade_share_flags (
  id          bigint generated always as identity primary key,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('review_threshold', 'subscriber_surge', 'quick_flip', 'shared_link')),
  details     jsonb not null default '{}',
  created_at  timestamptz not null default now(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  note        text check (char_length(note) <= 1000)
);
create unique index trade_share_flags_open_idx on private.trade_share_flags (profile_id, kind) where reviewed_at is null;
create index trade_share_flags_created_idx on private.trade_share_flags (created_at desc);
alter table private.trade_share_flags enable row level security;
revoke all on private.trade_share_flags from public, anon, authenticated;

create or replace function private.trade_share_kill_switch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.key = 'trade_share.enabled' and new.value = 'false'::jsonb and old.value is distinct from new.value then
    update private.trade_orders set report_state = 'cancelled', updated_at = now() where report_state = 'pending';
    update private.trade_fanout_jobs set status = 'cancelled', updated_at = now() where status in ('queued', 'sending');
  end if;
  return null;
end;
$$;

create trigger cs_settings_trade_share_kill_switch
  after update on cs.cs_settings
  for each row execute function private.trade_share_kill_switch();

create or replace function private.trade_share_detect_flags()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_threshold integer := private.trade_share_int('trade_share.review_subscriber_threshold', 1000);
  v_count     integer := 0;
  v_n         integer;
begin
  insert into private.trade_share_flags (profile_id, kind, details)
  select s.trader_id, 'review_threshold', jsonb_build_object('active', count(*), 'threshold', v_threshold)
  from private.trade_subscriptions s
  where s.status = 'active'
  group by s.trader_id
  having count(*) >= v_threshold
  on conflict (profile_id, kind) where reviewed_at is null do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  insert into private.trade_share_flags (profile_id, kind, details)
  select x.trader_id, 'subscriber_surge', jsonb_build_object('active', x.now_count, 'seven_days_ago', x.before_count)
  from (select s.trader_id,
               count(*) filter (where s.status = 'active') as now_count,
               count(*) filter (where s.status = 'active' and s.decided_at <= now() - interval '7 days') as before_count
        from private.trade_subscriptions s
        group by s.trader_id) x
  where x.now_count >= 3 * greatest(x.before_count, 10)
  on conflict (profile_id, kind) where reviewed_at is null do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  insert into private.trade_share_flags (profile_id, kind, details)
  select b.trader_id, 'quick_flip',
         jsonb_build_object('stock', b.stock, 'bought_at', b.completed_at, 'sold_at', s.completed_at,
                            'minutes', round(extract(epoch from s.completed_at - b.completed_at) / 60))
  from private.trade_activities b
  join lateral (select x.completed_at from private.trade_activities x
                 where x.trader_id = b.trader_id and x.stock = b.stock and x.side = 'sell'
                   and x.completed_at > b.completed_at and x.completed_at <= b.completed_at + interval '60 minutes'
                 order by x.completed_at limit 1) s on true
  where b.side = 'buy' and b.completed_at > now() - interval '1 day'
  on conflict (profile_id, kind) where reviewed_at is null do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  insert into private.trade_share_flags (profile_id, kind, details)
  select a.profile_id, 'shared_link', jsonb_build_object('cust_id', a.cust_id)
  from private.trade_sharer_accounts a
  where a.state = 'shared_link'
  on conflict (profile_id, kind) where reviewed_at is null do nothing;
  get diagnostics v_n = row_count;
  return v_count + v_n;
end;
$$;

create or replace function private.trade_share_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days     integer := private.trade_share_int('trade_share.retention_days', 30);
  v_expired  integer;
  v_resumed  integer;
  v_orders   integer;
  v_acts     integer;
  v_flags    integer;
  v_profile  uuid;
begin
  v_expired := private.trade_share_expire_requests();
  v_resumed := private.trade_share_end_suspensions();
  for v_profile in select distinct a.profile_id from private.trade_sharer_accounts a loop
    perform private.trade_share_refresh(v_profile);
  end loop;
  delete from private.trade_orders
   where created_at < now() - make_interval(days => v_days) and report_state <> 'pending';
  get diagnostics v_orders = row_count;
  delete from private.trade_orders where created_at < now() - make_interval(days => v_days + 7);
  delete from private.trade_activities where created_at < now() - make_interval(days => v_days);
  get diagnostics v_acts = row_count;
  delete from private.trade_notify_receipts where created_at < now() - interval '7 days';
  delete from private.trade_share_push_caps where day < private.trade_share_local_day() - 2;
  delete from private.trade_relay_daily where day < current_date - 400;
  delete from private.trade_relay_status where reported_at < now() - interval '7 days';
  delete from private.trade_share_flags where reviewed_at < now() - interval '400 days';
  update private.trade_relay_config set accounts_version = accounts_version + 1 where singleton;
  v_flags := private.trade_share_detect_flags();
  return jsonb_build_object('expired_requests', v_expired, 'ended_suspensions', v_resumed, 'orders_deleted', v_orders,
                            'activities_deleted', v_acts, 'flags', v_flags);
end;
$$;

create or replace function private.health_checks_trade_relay()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with c as (select * from private.trade_relay_config where singleton),
  st as (select * from private.trade_relay_status order by reported_at desc limit 1),
  active as (
    select (private.trade_share_enabled() or private.trade_share_bool('trade_notify.enabled'))
           and (select iproxy_addr from c) is not null as is_on)
  select 'trade_relay:down', 'critical', 'Relay trade tidak melapor',
         format('Laporan terakhir %s', coalesce(to_char((select reported_at from st) at time zone 'Asia/Jakarta',
                                                         'YYYY-MM-DD HH24:MI:SS'), 'belum pernah'))
  where (select is_on from active)
    and coalesce((select reported_at from st), '-infinity'::timestamptz)
        < now() - make_interval(secs => private.setting_num('health.trade_relay_stale_seconds', 120))
  union all
  select 'trade_relay:disconnected', 'critical', 'Relay trade tidak terhubung ke iProxy',
         coalesce((select last_error from st), 'Koneksi ZMQ terputus')
  where (select is_on from active) and cs.is_market_hours(now())
    and exists (select 1 from st where not st.connected and st.reported_at > now() - interval '5 minutes')
  union all
  select 'trade_relay:silent', 'warning', 'Relay trade tidak menerima paket realtime',
         format('Paket realtime terakhir %s', coalesce(to_char((select last_realtime_at from st) at time zone 'Asia/Jakarta',
                                                               'YYYY-MM-DD HH24:MI:SS'), 'belum pernah'))
  where (select is_on from active) and cs.is_market_hours(now())
    and exists (select 1 from st where st.connected and st.reported_at > now() - interval '5 minutes'
                  and coalesce(st.last_realtime_at, '-infinity'::timestamptz)
                      < now() - make_interval(mins => private.setting_num('health.trade_relay_silent_minutes', 30)::integer))
  union all
  select 'trade_relay:decode_errors', 'warning', 'Relay trade menerima banyak paket rusak',
         format('%s paket rusak dari %s paket hari ini', (st.counters ->> 'decode_errors'), (st.counters ->> 'received'))
  from st
  where (select is_on from active) and st.reported_at > now() - interval '5 minutes'
    and coalesce((st.counters ->> 'decode_errors')::bigint, 0) > 100
    and coalesce((st.counters ->> 'decode_errors')::numeric, 0) > 0.01 * greatest(coalesce((st.counters ->> 'received')::numeric, 0), 1)
  union all
  select 'trade_relay:overflow', 'warning', 'Antrean relay trade penuh',
         format('%s event dibuang karena antrean penuh', (st.counters ->> 'buffer_overflow'))
  from st
  where (select is_on from active) and st.reported_at > now() - interval '5 minutes'
    and coalesce((st.counters ->> 'buffer_overflow')::bigint, 0) > 0
  union all
  select 'trade_relay:encrypted_no_key', 'warning', 'Paket terenkripsi tanpa kunci AES',
         format('%s paket terenkripsi dibuang karena kunci AES belum diatur', (st.counters ->> 'encrypted_no_key'))
  from st
  where (select is_on from active) and st.reported_at > now() - interval '5 minutes'
    and coalesce((st.counters ->> 'encrypted_no_key')::bigint, 0) > 0;
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
    union all select * from private.health_checks_trade_relay()
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
$$;

create or replace function cs_api.trade_share_flags(p_status text default 'open', p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
begin
  if coalesce(p_status, '') not in ('open', 'reviewed') then
    perform private.api_error(400, 'invalid_status', 'Status harus open atau reviewed');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', f.id, 'profile', cs.trade_share_profile_ref(f.profile_id),
                                        'kind', f.kind, 'details', f.details, 'created_at', f.created_at,
                                        'reviewed_by', f.reviewed_by, 'reviewed_at', f.reviewed_at, 'note', f.note)
                     order by f.created_at desc)
    from (select * from private.trade_share_flags x
           where (p_status = 'open') = (x.reviewed_at is null)
           order by x.created_at desc
           limit v_limit) f), '[]');
end;
$$;

create or replace function cs_api.trade_share_review_flag(p_id bigint, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_trade('{trade_share.review}');
  v_note text := private.trade_share_reason(p_note, true);
  f      private.trade_share_flags;
begin
  update private.trade_share_flags set reviewed_by = v_me, reviewed_at = now(), note = v_note
   where id = p_id and reviewed_at is null
   returning * into f;
  if not found then
    perform private.api_error(404, 'flag_not_found', 'Penanda tidak ditemukan atau sudah ditinjau');
  end if;
  perform cs.audit('trade_share.flag_review', null, f.profile_id,
                   jsonb_build_object('flag', p_id, 'kind', f.kind, 'note', v_note));
  return cs_api.trade_share_flags('open');
end;
$$;

create or replace function cs_api.trade_share_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_day date := private.trade_share_local_day();
begin
  return jsonb_build_object(
    'enabled', private.trade_share_enabled(),
    'pilot_only', private.trade_share_bool('trade_share.pilot_only'),
    'traders', (select jsonb_object_agg(x.status, x.n) from (select status, count(*) as n from private.trade_sharers
                                                             group by status) x),
    'subscriptions', (select jsonb_build_object(
                        'active', count(*) filter (where status = 'active'),
                        'pending', count(*) filter (where status = 'pending' and expires_at > now()),
                        'muted', count(*) filter (where status = 'active' and muted))
                      from private.trade_subscriptions),
    'activities_today', (select count(*) from private.trade_activities where private.trade_share_local_day(created_at) = v_day),
    'activities_7d', (select count(*) from private.trade_activities where created_at > now() - interval '7 days'),
    'deliveries_today', (select jsonb_build_object('recipients', coalesce(sum(j.recipients), 0),
                                                   'pushed', coalesce(sum(j.pushed), 0),
                                                   'capped', coalesce(sum(j.capped), 0))
                         from private.trade_fanout_jobs j where private.trade_share_local_day(j.created_at) = v_day),
    'pending_orders', (select count(*) from private.trade_orders where report_state = 'pending'),
    'open_flags', (select count(*) from private.trade_share_flags where reviewed_at is null),
    'relay_today', coalesce((select jsonb_object_agg(d.metric, d.count) from private.trade_relay_daily d where d.day = v_day), '{}'),
    'relay_health', coalesce((select jsonb_agg(jsonb_build_object('key', h.key, 'severity', h.severity, 'title', h.title,
                                                                  'detail', h.detail))
                              from private.health_checks_trade_relay() h), '[]'),
    'top_traders', coalesce((select jsonb_agg(jsonb_build_object('profile', cs.trade_share_profile_ref(t.trader_id),
                                                                 'subscribers', t.n) order by t.n desc)
                             from (select trader_id, count(*) as n from private.trade_subscriptions
                                    where status = 'active' group by trader_id order by count(*) desc limit 10) t), '[]'));
end;
$$;

create or replace function private.trade_share_csv(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select '"' || replace(coalesce(case when p_value ~ '^[=+@-]' then '''' || p_value else p_value end, ''), '"', '""') || '"';
$$;

create or replace function cs_api.trade_share_export(p_from date, p_to date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_trade('{trade_share.manage}');
  v_csv  text;
  v_rows integer;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    perform private.api_error(400, 'invalid_range', 'Rentang tanggal maksimal 93 hari');
  end if;
  select count(*), string_agg(concat_ws(',',
           private.trade_share_csv(to_char(a.completed_at at time zone 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI:SS')),
           private.trade_share_csv(p.username::text), private.trade_share_csv(a.stock), private.trade_share_csv(a.side),
           private.trade_share_csv(round(a.shares::numeric / a.lot_size, 2)::text),
           private.trade_share_csv(case when a.order_shares is not null then round(a.order_shares::numeric / a.lot_size, 2)::text end),
           private.trade_share_csv(a.price::text), private.trade_share_csv(a.average_price::text),
           private.trade_share_csv(a.partial::text), private.trade_share_csv(a.additional::text),
           private.trade_share_csv(coalesce(j.recipients, 0)::text), private.trade_share_csv(coalesce(j.pushed, 0)::text)),
           E'\n' order by a.completed_at)
    into v_rows, v_csv
  from private.trade_activities a
  join public.profiles p on p.id = a.trader_id
  left join private.trade_fanout_jobs j on j.activity_id = a.id
  where private.trade_share_local_day(a.completed_at) between p_from and p_to;
  perform cs.audit('trade_share.export', null, null, jsonb_build_object('from', p_from, 'to', p_to, 'rows', v_rows));
  return jsonb_build_object(
    'filename', format('berbagi-trade-%s-%s.csv', p_from, p_to),
    'rows', v_rows,
    'csv', 'waktu_wib,trader,saham,sisi,lot_match,lot_order,harga_order,harga_rata_rata,sebagian,tambahan,penerima,push'
           || case when v_csv is not null then E'\n' || v_csv else '' end);
end;
$$;

create or replace function private.trade_share_export_user(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'trader', (select jsonb_build_object('status', s.status, 'show_price', s.show_price, 'show_lot', s.show_lot,
                                         'delay_minutes', s.delay_minutes, 'subscribe_mode', s.subscribe_mode,
                                         'applied_at', s.applied_at, 'decided_at', s.decided_at,
                                         'accounts', (select coalesce(jsonb_agg(a.cust_id order by a.cust_id), '[]')
                                                        from private.trade_sharer_accounts a where a.profile_id = s.profile_id))
               from private.trade_sharers s where s.profile_id = p_user),
    'history', coalesce((select jsonb_agg(jsonb_build_object('action', e.action, 'from_status', e.from_status,
                                                             'to_status', e.to_status, 'reason', e.reason,
                                                             'created_at', e.created_at) order by e.id)
                         from private.trade_share_events e where e.profile_id = p_user), '[]'),
    'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('trader_id', s.trader_id, 'status', s.status,
                                                                   'muted', s.muted, 'requested_at', s.requested_at,
                                                                   'ended_at', s.ended_at) order by s.requested_at)
                               from private.trade_subscriptions s where s.subscriber_id = p_user), '[]'),
    'activities', coalesce((select jsonb_agg(private.trade_activity_payload(a) order by a.created_at)
                            from private.trade_activities a where a.trader_id = p_user), '[]'));
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
    'dm_policy', private.dm_policy(v_uid),
    'linked_accounts', private.export_optional('linked_accounts', v_uid),
    'appeals', private.export_optional('appeals', v_uid),
    'analytics_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'created_at', e.created_at, 'platform', e.platform, 'app_version', e.app_version,
        'props', e.props) order by e.created_at desc)
      from (select * from private.analytics_events a where a.user_id = v_uid order by a.created_at desc limit 5000) e),
      '[]'::jsonb),
    'post_drafts', coalesce((select jsonb_agg(private.post_draft_view(d) order by d.updated_at desc)
      from public.post_drafts d where d.user_id = v_uid), '[]'::jsonb),
    'notification_events', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.event, 'source_type', e.source_type, 'source_id', e.source_id,
        'notification_id', e.notification_id, 'created_at', e.created_at) order by e.created_at desc)
      from (select * from private.notification_events ne where ne.user_id = v_uid
            order by ne.created_at desc limit 5000) e), '[]'::jsonb),
    'trade_share', private.trade_share_export_user(v_uid)
  );
end;
$$;

select cron.schedule('trade-share-maintenance', '*/15 * * * *', 'select private.trade_share_maintenance()');

revoke execute on function private.trade_share_kill_switch() from public;
revoke execute on function private.trade_share_detect_flags() from public;
revoke execute on function private.trade_share_maintenance() from public;
revoke execute on function private.health_checks_trade_relay() from public;
revoke execute on function private.health_current() from public;
revoke execute on function private.trade_share_csv(text) from public;
revoke execute on function private.trade_share_export_user(uuid) from public;
revoke execute on function cs_api.trade_share_flags(text, integer) from public;
grant execute on function cs_api.trade_share_flags(text, integer) to authenticated;
revoke execute on function cs_api.trade_share_review_flag(bigint, text) from public;
grant execute on function cs_api.trade_share_review_flag(bigint, text) to authenticated;
revoke execute on function cs_api.trade_share_dashboard() from public;
grant execute on function cs_api.trade_share_dashboard() to authenticated;
revoke execute on function cs_api.trade_share_export(date, date) from public;
grant execute on function cs_api.trade_share_export(date, date) to authenticated;
