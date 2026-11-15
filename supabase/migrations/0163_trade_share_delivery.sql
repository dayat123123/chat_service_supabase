insert into cs.cs_settings (key, value, description) values
  ('trade_share.eod_flush_time', '"16:30"', 'Jam (WIB) sapuan akhir hari untuk order yang baru terisi sebagian'),
  ('trade_share.daily_push_cap', '50', 'Push aktivitas trade maksimal per pelanggan per hari. Kotak notifikasi tetap terisi'),
  ('trade_share.retention_days', '30', 'Masa simpan status order, aktivitas, dan job pengiriman (hari)'),
  ('trade_share.fanout_batch', '2000', 'Jumlah pelanggan yang diproses per putaran pengiriman')
on conflict (key) do nothing;

create or replace function cs.trade_share_setting_keys()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['trade_share.enabled', 'trade_share.pilot_only', 'trade_share.min_account_age_days',
               'trade_share.reapply_cooldown_days', 'trade_share.min_delay_minutes', 'trade_share.max_delay_minutes',
               'trade_share.force_hide_price', 'trade_share.force_hide_lot', 'trade_share.four_eyes',
               'trade_share.max_subscriptions', 'trade_share.request_expiry_days',
               'trade_share.review_subscriber_threshold', 'trade_share.lot_size', 'trade_share.boards',
               'trade_share.eod_flush_time', 'trade_share.daily_push_cap', 'trade_share.retention_days',
               'trade_share.fanout_batch'];
$$;

create or replace function cs.trade_share_check_setting(p_key text, p_value jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_num numeric;
begin
  if p_key in ('trade_share.min_account_age_days', 'trade_share.reapply_cooldown_days',
               'trade_share.min_delay_minutes', 'trade_share.max_delay_minutes', 'trade_share.max_subscriptions',
               'trade_share.request_expiry_days', 'trade_share.review_subscriber_threshold', 'trade_share.lot_size',
               'trade_share.daily_push_cap', 'trade_share.retention_days', 'trade_share.fanout_batch') then
    if jsonb_typeof(p_value) <> 'number' then
      perform private.api_error(400, 'invalid_setting', 'Nilai harus angka');
    end if;
    v_num := (p_value #>> '{}')::numeric;
    if v_num <> trunc(v_num)
       or (p_key = 'trade_share.min_account_age_days' and v_num not between 0 and 3650)
       or (p_key = 'trade_share.reapply_cooldown_days' and v_num not between 0 and 3650)
       or (p_key = 'trade_share.min_delay_minutes' and v_num not between 1 and 1440)
       or (p_key = 'trade_share.max_delay_minutes' and v_num not between 1 and 1440)
       or (p_key = 'trade_share.max_subscriptions' and v_num not between 1 and 500)
       or (p_key = 'trade_share.request_expiry_days' and v_num not between 1 and 90)
       or (p_key = 'trade_share.review_subscriber_threshold' and v_num not between 1 and 10000000)
       or (p_key = 'trade_share.lot_size' and v_num not between 1 and 100000)
       or (p_key = 'trade_share.daily_push_cap' and v_num not between 0 and 1000)
       or (p_key = 'trade_share.retention_days' and v_num not between 1 and 400)
       or (p_key = 'trade_share.fanout_batch' and v_num not between 100 and 20000) then
      perform private.api_error(400, 'invalid_setting', 'Nilai di luar batas');
    end if;
  elsif p_key = 'trade_share.boards' then
    if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) = 0
       or exists (select 1 from jsonb_array_elements(p_value) b
                   where jsonb_typeof(b) <> 'string' or b #>> '{}' not in ('RG', 'TN', 'NG', 'ADV')) then
      perform private.api_error(400, 'invalid_setting', 'Board harus berisi RG, TN, NG, atau ADV');
    end if;
  elsif p_key = 'trade_share.eod_flush_time' then
    if jsonb_typeof(p_value) <> 'string' or p_value #>> '{}' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      perform private.api_error(400, 'invalid_setting', 'Jam harus berformat HH:MM');
    end if;
  end if;
end;
$$;

alter table public.notifications drop constraint notifications_type;
alter table public.notifications add constraint notifications_type
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share'));

alter table private.notification_prefs drop constraint notification_prefs_type_check;
alter table private.notification_prefs add constraint notification_prefs_type_check
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                  'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share',
                  'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'));

create or replace function private.notification_pref_types()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
               'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share',
               'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'];
$$;

create or replace function private.notification_pref_type(p_kind text, p_category text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_kind in ('reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
                    'followed_post', 'watchlist_digest', 'moderation', 'trade_activity', 'trade_share') then p_kind
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
  if new.type in ('trade_activity', 'trade_share') then
    return null;
  end if;
  if tg_op = 'INSERT'
     or (new.event_count > old.event_count and new.read_at is null
         and new.type not in ('like', 'follow', 'followed_post')) then
    perform private.notification_push(new);
  end if;
  return null;
end;
$$;

create table private.trade_activities (
  id            uuid primary key default gen_random_uuid(),
  trader_id     uuid not null references public.profiles (id) on delete cascade,
  order_ref     text not null,
  stock         text not null,
  side          text not null check (side in ('buy', 'sell')),
  shares        bigint not null check (shares > 0),
  total_shares  bigint not null check (total_shares > 0),
  order_shares  bigint,
  lot_size      integer not null,
  price         integer,
  average_price numeric,
  show_lot      boolean not null,
  partial       boolean not null,
  additional    boolean not null default false,
  fill_count    integer not null default 0,
  ordered_on    date,
  completed_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index trade_activities_trader_idx on private.trade_activities (trader_id, created_at desc, id desc);
create index trade_activities_created_idx on private.trade_activities (created_at);

create table private.trade_fanout_jobs (
  activity_id uuid primary key references private.trade_activities (id) on delete cascade,
  status      text not null default 'queued' check (status in ('queued', 'sending', 'done', 'cancelled')),
  cursor_id   uuid,
  recipients  integer not null default 0,
  pushed      integer not null default 0,
  capped      integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index trade_fanout_jobs_open_idx on private.trade_fanout_jobs (created_at) where status in ('queued', 'sending');

create table private.trade_share_push_caps (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  day        date not null,
  count      integer not null default 0,
  primary key (profile_id, day)
);

alter table private.trade_activities enable row level security;
alter table private.trade_fanout_jobs enable row level security;
alter table private.trade_share_push_caps enable row level security;
revoke all on private.trade_activities, private.trade_fanout_jobs, private.trade_share_push_caps
  from public, anon, authenticated;

create or replace function private.trade_share_local_day(p_at timestamptz default now())
returns date
language sql
stable
set search_path = ''
as $$
  select (p_at at time zone 'Asia/Jakarta')::date;
$$;

create or replace function private.trade_share_after_eod(p_order_day date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_order_day is null
      or private.trade_share_local_day() > p_order_day
      or (cs.is_business_day(private.trade_share_local_day())
          and (now() at time zone 'Asia/Jakarta')::time
              >= coalesce(nullif(cs.setting('trade_share.eod_flush_time') #>> '{}', ''), '16:30')::time);
$$;

create or replace function private.trade_share_name(p_profile uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text) from public.profiles p where p.id = p_profile;
$$;

create or replace function private.trade_activity_text(a private.trade_activities, p_lang text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with t as (
    select coalesce(private.trade_share_name(a.trader_id), case when p_lang = 'en' then 'A trader' else 'Trader' end) as name,
           case when p_lang = 'en' then ',' else '.' end as sep)
  select jsonb_build_object(
    'title', (select name from t) || case
               when p_lang = 'en' then case when a.side = 'buy' then ' bought $' else ' sold $' end
               else case when a.side = 'buy' then ' membeli $' else ' menjual $' end end || a.stock,
    'body', concat_ws(' · ',
      case when a.show_lot then
        case when a.additional then case when p_lang = 'en' then 'additional ' else 'tambahan ' end else '' end
        || private.trade_volume_text(a.shares, p_lang)
        || case when a.partial and a.order_shares is not null and not a.additional
                then case when p_lang = 'en' then ' of ' else ' dari ' end
                     || private.trade_volume_text(a.order_shares, p_lang) else '' end
        || case when a.price is not null then ' @ ' || private.trade_format_int(a.price, (select sep from t)) else '' end
      when a.price is not null then '@ ' || private.trade_format_int(a.price, (select sep from t))
      end,
      case when a.partial then case when p_lang = 'en' then 'partial' else 'sebagian' end end));
$$;

create or replace function private.trade_activity_payload(a private.trade_activities)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'activity_id', a.id,
    'trader_id', a.trader_id,
    'stock', a.stock,
    'side', a.side,
    'lots', case when a.show_lot then round(a.shares::numeric / a.lot_size, 2) end,
    'order_lots', case when a.show_lot and a.order_shares is not null
                       then round(a.order_shares::numeric / a.lot_size, 2) end,
    'shares', case when a.show_lot then a.shares end,
    'price', a.price,
    'partial', a.partial,
    'additional', a.additional,
    'completed_at', a.completed_at,
    'text', jsonb_build_object('id', private.trade_activity_text(a, 'id'), 'en', private.trade_activity_text(a, 'en'))));
$$;

create or replace function private.trade_share_flush(p_limit integer default 2000)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enabled   boolean := private.trade_share_enabled();
  v_hide_lot  boolean := private.trade_share_bool('trade_share.force_hide_lot');
  v_hide_px   boolean := private.trade_share_bool('trade_share.force_hide_price');
  v_lot       integer := greatest(private.trade_share_int('trade_share.lot_size', 100), 1);
  r           record;
  v_matched   bigint;
  v_new       bigint;
  v_full      boolean;
  v_terminal  boolean;
  v_report    boolean;
  v_price     integer;
  v_avg       numeric;
  v_activity  uuid;
  v_created   integer := 0;
  v_cancelled integer := 0;
begin
  if not v_enabled then
    update private.trade_orders set report_state = 'cancelled', updated_at = now() where report_state = 'pending';
    get diagnostics v_cancelled = row_count;
    update private.trade_fanout_jobs set status = 'cancelled', updated_at = now() where status in ('queued', 'sending');
    return jsonb_build_object('activities', 0, 'cancelled', v_cancelled);
  end if;
  for r in
    select o.*, s.status as sharer_status, s.delay_minutes, s.show_price, s.show_lot
    from private.trade_orders o
    join private.trade_sharers s on s.profile_id = o.profile_id
    where o.report_state = 'pending'
    order by o.last_change_at
    limit p_limit
    for update of o skip locked
  loop
    if r.sharer_status <> 'active' then
      update private.trade_orders set report_state = 'cancelled', updated_at = now() where order_ref = r.order_ref;
      v_cancelled := v_cancelled + 1;
      continue;
    end if;
    v_matched := greatest(r.traded_shares, r.fill_shares);
    v_new := v_matched - r.reported_shares;
    v_full := v_matched > 0 and r.order_shares is not null and r.order_shares > 0
              and (r.remain_shares = 0 or v_matched >= r.order_shares);
    v_terminal := v_full or r.status in ('withdrawn', 'rejected');
    if v_new <= 0 then
      if v_terminal then
        update private.trade_orders
           set report_state = case when r.reported_shares = 0 then 'cancelled'
                                   when v_full then 'reported' else 'partial_reported' end,
               updated_at = now()
         where order_ref = r.order_ref;
      end if;
      continue;
    end if;
    if now() < r.last_change_at + make_interval(mins => r.delay_minutes) then
      continue;
    end if;
    v_report := v_terminal or private.trade_share_after_eod(coalesce(r.order_date,
                                                                     private.trade_share_local_day(r.created_at)));
    if not v_report then
      continue;
    end if;
    v_avg := case when r.fill_priced > 0 then round(r.fill_value / r.fill_priced, 2) end;
    v_price := case when v_hide_px or not r.show_price then null
                    else coalesce(r.order_price, round(v_avg)::integer) end;
    insert into private.trade_activities (trader_id, order_ref, stock, side, shares, total_shares, order_shares,
                                          lot_size, price, average_price, show_lot, partial, additional, fill_count,
                                          ordered_on)
    values (r.profile_id, r.order_ref, r.stock, r.side, v_new, v_matched, r.order_shares, v_lot, v_price,
            case when v_hide_px or not r.show_price then null else v_avg end,
            r.show_lot and not v_hide_lot, not v_full, r.reported_shares > 0, r.fill_count, r.order_date)
    returning id into v_activity;
    insert into private.trade_fanout_jobs (activity_id) values (v_activity);
    update private.trade_orders
       set reported_shares = v_matched, report_state = case when v_full then 'reported' else 'partial_reported' end,
           updated_at = now()
     where order_ref = r.order_ref;
    v_created := v_created + 1;
  end loop;
  return jsonb_build_object('activities', v_created, 'cancelled', v_cancelled);
end;
$$;

create or replace function private.trade_share_push(p_user uuid, p_kind text, p_title jsonb, p_body jsonb,
                                                    p_data jsonb, p_collapse text, p_capped boolean)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cap   integer := private.trade_share_int('trade_share.daily_push_cap', 50);
  v_count integer;
begin
  if not coalesce(private.push_allowed(p_user, p_kind), false) then
    return 0;
  end if;
  if p_capped then
    insert into private.trade_share_push_caps as c (profile_id, day, count)
    values (p_user, private.trade_share_local_day(), 1)
    on conflict (profile_id, day) do update set count = c.count + 1
    returning c.count into v_count;
    if v_count > v_cap then
      return -1;
    end if;
  end if;
  return private.push_enqueue(p_user, p_kind, p_title, p_body,
                              coalesce(p_data, '{}') || jsonb_build_object('source', 'rendezvous_community', 'type', p_kind),
                              jsonb_build_object('collapse_key', p_collapse, 'priority', 'high'));
end;
$$;

create or replace function private.trade_share_fanout(p_budget integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_budget  integer := coalesce(p_budget, private.trade_share_int('trade_share.fanout_batch', 2000));
  j         private.trade_fanout_jobs;
  a         private.trade_activities;
  v_payload jsonb;
  v_text_id jsonb;
  v_text_en jsonb;
  v_sub     uuid;
  v_last    uuid;
  v_n       integer;
  v_push    integer;
  v_sent    integer := 0;
begin
  if not private.trade_share_enabled() then
    return jsonb_build_object('recipients', 0);
  end if;
  for j in select * from private.trade_fanout_jobs
            where status in ('queued', 'sending')
            order by created_at
            limit 50
            for update skip locked loop
    exit when v_budget <= 0;
    select * into a from private.trade_activities where id = j.activity_id;
    v_payload := private.trade_activity_payload(a);
    v_text_id := private.trade_activity_text(a, 'id');
    v_text_en := private.trade_activity_text(a, 'en');
    v_n := 0;
    v_last := j.cursor_id;
    for v_sub in
      select s.subscriber_id
      from private.trade_subscriptions s
      join public.profiles p on p.id = s.subscriber_id and p.deleted_at is null
      where s.trader_id = a.trader_id and s.status = 'active' and not s.muted
        and s.decided_at <= a.created_at
        and (j.cursor_id is null or s.subscriber_id > j.cursor_id)
      order by s.subscriber_id
      limit v_budget
    loop
      v_n := v_n + 1;
      v_last := v_sub;
      if private.is_blocked_pair(v_sub, a.trader_id) then
        continue;
      end if;
      perform private.notify(v_sub, a.trader_id, 'trade_activity', v_payload, null);
      v_push := private.trade_share_push(v_sub, 'trade_activity',
                                         jsonb_build_object('id', v_text_id ->> 'title', 'en', v_text_en ->> 'title'),
                                         jsonb_build_object('id', v_text_id ->> 'body', 'en', v_text_en ->> 'body'),
                                         jsonb_build_object('activity_id', a.id, 'trader_id', a.trader_id,
                                                            'stock', a.stock),
                                         'trade-activity:' || a.trader_id, true);
      update private.trade_fanout_jobs
         set recipients = recipients + 1,
             pushed = pushed + case when v_push > 0 then 1 else 0 end,
             capped = capped + case when v_push < 0 then 1 else 0 end
       where activity_id = j.activity_id;
    end loop;
    v_budget := v_budget - v_n;
    v_sent := v_sent + v_n;
    update private.trade_fanout_jobs
       set cursor_id = v_last,
           status = case when v_budget > 0 then 'done' else 'sending' end,
           updated_at = now()
     where activity_id = j.activity_id;
  end loop;
  return jsonb_build_object('recipients', v_sent);
end;
$$;

create or replace function private.trade_share_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_flush  jsonb;
  v_fanout jsonb;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('trade_share_tick', 0)) then
    return jsonb_build_object('skipped', true);
  end if;
  v_flush := private.trade_share_flush();
  v_fanout := private.trade_share_fanout();
  return v_flush || v_fanout;
end;
$$;

create or replace function private.trade_share_event_message(p_action text, p_reason text)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case p_action
    when 'approved' then '{"title": {"id": "Pengajuan berbagi trade disetujui", "en": "Trade sharing approved"}, "body": {"id": "Pelanggan Anda kini menerima notifikasi trade Anda", "en": "Your subscribers now receive your trade notifications"}}'::jsonb
    when 'rejected' then jsonb_build_object('title', '{"id": "Pengajuan berbagi trade ditolak", "en": "Trade sharing application rejected"}'::jsonb,
                                            'body', jsonb_build_object('id', coalesce(p_reason, ''), 'en', coalesce(p_reason, '')))
    when 'suspended' then jsonb_build_object('title', '{"id": "Berbagi trade ditangguhkan", "en": "Trade sharing suspended"}'::jsonb,
                                             'body', jsonb_build_object('id', coalesce(p_reason, ''), 'en', coalesce(p_reason, '')))
    when 'revoked' then jsonb_build_object('title', '{"id": "Izin berbagi trade dicabut", "en": "Trade sharing revoked"}'::jsonb,
                                           'body', jsonb_build_object('id', coalesce(p_reason, ''), 'en', coalesce(p_reason, '')))
    when 'reinstated' then '{"title": {"id": "Berbagi trade aktif kembali", "en": "Trade sharing reinstated"}, "body": {"id": "", "en": ""}}'::jsonb
    when 'suspension_ended' then '{"title": {"id": "Berbagi trade aktif kembali", "en": "Trade sharing reinstated"}, "body": {"id": "", "en": ""}}'::jsonb
    when 'auto_paused' then '{"title": {"id": "Berbagi trade dijeda", "en": "Trade sharing paused"}, "body": {"id": "Tidak ada rekening yang bisa dibagikan", "en": "No account can be shared"}}'::jsonb
    when 'auto_resumed' then '{"title": {"id": "Berbagi trade aktif kembali", "en": "Trade sharing resumed"}, "body": {"id": "Rekening Anda tertaut kembali", "en": "Your account is linked again"}}'::jsonb
  end;
$$;

create or replace function private.trade_share_event_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg jsonb := private.trade_share_event_message(new.action, new.reason);
begin
  if v_msg is null then
    return null;
  end if;
  perform private.notify(new.profile_id, null, 'trade_share',
                         jsonb_strip_nulls(jsonb_build_object('action', new.action, 'status', new.to_status,
                                                              'reason', new.reason, 'title', v_msg #>> '{title,id}',
                                                              'body', v_msg #>> '{body,id}')),
                         null);
  perform private.trade_share_push(new.profile_id, 'trade_share', v_msg -> 'title', v_msg -> 'body',
                                   jsonb_build_object('action', new.action, 'screen', 'trade_share_settings'),
                                   'trade-share:' || new.profile_id, false);
  return null;
end;
$$;

create trigger trade_share_events_notify
  after insert on private.trade_share_events
  for each row execute function private.trade_share_event_notify();

create or replace function private.trade_subscription_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    v_name := coalesce(private.trade_share_name(new.subscriber_id), 'Seseorang');
    perform private.notify(new.trader_id, new.subscriber_id, 'trade_share',
                           jsonb_build_object('action', 'subscription_request', 'subscriber_id', new.subscriber_id,
                                              'title', v_name || ' ingin berlangganan trade Anda'), null);
    perform private.trade_share_push(new.trader_id, 'trade_share',
                                     jsonb_build_object('id', v_name || ' ingin berlangganan trade Anda',
                                                        'en', v_name || ' wants to subscribe to your trades'),
                                     '{"id": "Ketuk untuk menyetujui atau menolak", "en": "Tap to approve or decline"}'::jsonb,
                                     jsonb_build_object('action', 'subscription_request', 'screen', 'trade_subscribers'),
                                     'trade-subscribers:' || new.trader_id, false);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'active' then
    v_name := coalesce(private.trade_share_name(new.trader_id), 'Trader');
    perform private.notify(new.subscriber_id, new.trader_id, 'trade_share',
                           jsonb_build_object('action', 'subscription_approved', 'trader_id', new.trader_id,
                                              'title', v_name || ' menyetujui langganan trade Anda'), null);
    perform private.trade_share_push(new.subscriber_id, 'trade_share',
                                     jsonb_build_object('id', v_name || ' menyetujui langganan trade Anda',
                                                        'en', v_name || ' approved your trade subscription'),
                                     '{"id": "", "en": ""}'::jsonb,
                                     jsonb_build_object('action', 'subscription_approved', 'trader_id', new.trader_id),
                                     'trade-subscription:' || new.trader_id, false);
  end if;
  return null;
end;
$$;

create trigger trade_subscriptions_notify
  after insert or update of status on private.trade_subscriptions
  for each row execute function private.trade_subscription_notify();

create or replace function public.trade_activity_feed(p_cursor text default null, p_limit integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 50);
  v_ts    timestamptz;
  v_id    uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not private.trade_share_enabled() then
    return '[]'::jsonb;
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
  return coalesce((
    select jsonb_agg(x.item order by x.created_at desc, x.id desc)
    from (
      select a.created_at, a.id,
             private.trade_activity_payload(a)
               || jsonb_build_object('trader', private.trade_share_public_profile(a.trader_id),
                                     'cursor', private.make_cursor(a.created_at, a.id)) as item
      from private.trade_activities a
      join private.trade_subscriptions s
        on s.trader_id = a.trader_id and s.subscriber_id = v_uid and s.status = 'active' and s.decided_at <= a.created_at
      where not private.is_blocked_pair(v_uid, a.trader_id)
        and (v_ts is null or (a.created_at, a.id) < (v_ts, v_id))
      order by a.created_at desc, a.id desc
      limit v_limit) x), '[]');
end;
$$;

create or replace function public.trade_activity_detail(p_activity uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  a     private.trade_activities;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into a from private.trade_activities where id = p_activity;
  if not found or private.is_blocked_pair(v_uid, a.trader_id)
     or not (a.trader_id = v_uid
             or exists (select 1 from private.trade_subscriptions s
                         where s.trader_id = a.trader_id and s.subscriber_id = v_uid and s.decided_at <= a.created_at)) then
    perform private.api_error(404, 'activity_not_found', 'Aktivitas tidak ditemukan');
  end if;
  return private.trade_activity_payload(a)
         || jsonb_build_object('trader', private.trade_share_public_profile(a.trader_id),
                               'disclaimer', '{"id": "Informasi ini bukan rekomendasi. Keputusan investasi sepenuhnya tanggung jawab Anda.", "en": "This is not a recommendation. Investment decisions are your own responsibility."}'::jsonb);
end;
$$;

select cron.schedule('trade-share-tick', '30 seconds', 'select private.trade_share_tick()');

revoke execute on function private.trade_share_local_day(timestamptz) from public;
revoke execute on function private.trade_share_after_eod(date) from public;
revoke execute on function private.trade_share_name(uuid) from public;
revoke execute on function private.trade_activity_text(private.trade_activities, text) from public;
revoke execute on function private.trade_activity_payload(private.trade_activities) from public;
revoke execute on function private.trade_share_flush(integer) from public;
revoke execute on function private.trade_share_push(uuid, text, jsonb, jsonb, jsonb, text, boolean) from public;
revoke execute on function private.trade_share_fanout(integer) from public;
revoke execute on function private.trade_share_tick() from public;
revoke execute on function private.trade_share_event_message(text, text) from public;
revoke execute on function private.trade_share_event_notify() from public;
revoke execute on function private.trade_subscription_notify() from public;

revoke execute on function public.trade_activity_feed(text, integer) from public, anon;
grant execute on function public.trade_activity_feed(text, integer) to authenticated;
revoke execute on function public.trade_activity_detail(uuid) from public, anon;
grant execute on function public.trade_activity_detail(uuid) to authenticated;
