insert into cs.cs_settings (key, value, description) values
  ('trade_notify.enabled', 'false', 'Push trade match ke nasabah pemilik order lewat relay. Matikan bila notifEngine OLT masih mengirim push yang sama')
on conflict (key) do nothing;

create table private.trade_share_excluded_stocks (
  stock      text primary key check (stock ~ '^[A-Z0-9-]{1,12}$'),
  reason     text not null check (char_length(btrim(reason)) between 3 and 500),
  until      timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now()
);

create table private.trade_relay_config (
  singleton           boolean primary key default true check (singleton),
  iproxy_addr         text check (iproxy_addr ~ '^tcp://[A-Za-z0-9._-]{1,253}:[0-9]{1,5}$'),
  identity            text not null default 'social_trade_relay' check (identity ~ '^[A-Za-z0-9._-]{3,63}$'),
  heartbeat_seconds   integer not null default 4 check (heartbeat_seconds between 1 and 60),
  aes_mode            text not null default 'ecb' check (aes_mode in ('ecb', 'cbc')),
  aes_key_secret_id   uuid,
  aes_iv_secret_id    uuid,
  aes_key_fingerprint text,
  aes_key_length      integer,
  aes_updated_at      timestamptz,
  reconnect_generation bigint not null default 0,
  restart_generation  bigint not null default 0,
  last_command_at     timestamptz,
  version             bigint not null default 1,
  accounts_version    bigint not null default 1,
  updated_at          timestamptz not null default now(),
  updated_by          uuid
);
insert into private.trade_relay_config (singleton) values (true);

create table private.trade_relay_status (
  instance          text primary key check (char_length(instance) between 1 and 200),
  version           text check (char_length(version) <= 40),
  connected         boolean not null default false,
  state             text check (char_length(state) <= 40),
  last_packet_at    timestamptz,
  last_realtime_at  timestamptz,
  counters          jsonb not null default '{}',
  last_error        text check (char_length(last_error) <= 500),
  applied_reconnect bigint,
  applied_restart   bigint,
  started_at        timestamptz,
  reported_at       timestamptz not null default now()
);

create table private.trade_orders (
  order_ref       text primary key check (order_ref ~ '^[0-9a-f]{64}$'),
  profile_id      uuid not null references public.profiles (id) on delete cascade,
  cust_id         text not null,
  stock           text not null,
  side            text not null check (side in ('buy', 'sell')),
  board           text not null,
  order_date      date,
  status          text check (status in ('rejected', 'open', 'matched', 'amending', 'withdrawing', 'withdrawn', 'amended')),
  order_price     integer,
  order_shares    bigint,
  remain_shares   bigint,
  traded_shares   bigint not null default 0,
  fill_shares     bigint not null default 0,
  fill_value      numeric not null default 0,
  fill_priced     bigint not null default 0,
  fill_count      integer not null default 0,
  amend_count     integer not null default 0,
  out_of_order    integer not null default 0,
  last_seq        text,
  first_fill_at   timestamptz,
  last_fill_at    timestamptz,
  last_change_at  timestamptz not null default now(),
  reported_shares bigint not null default 0,
  report_state    text not null default 'pending'
                  check (report_state in ('pending', 'reported', 'partial_reported', 'cancelled')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index trade_orders_profile_idx on private.trade_orders (profile_id, created_at desc);
create index trade_orders_pending_idx on private.trade_orders (last_change_at) where report_state = 'pending';
create index trade_orders_created_idx on private.trade_orders (created_at);

create table private.trade_fills (
  key        text primary key check (key ~ '^[0-9a-f]{64}$'),
  order_ref  text not null references private.trade_orders (order_ref) on delete cascade,
  traded_at  timestamptz not null,
  price      integer,
  shares     bigint not null check (shares > 0),
  created_at timestamptz not null default now()
);
create index trade_fills_order_idx on private.trade_fills (order_ref);
create index trade_fills_created_idx on private.trade_fills (created_at);

create table private.trade_notify_receipts (
  key        text primary key check (key ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now()
);
create index trade_notify_receipts_created_idx on private.trade_notify_receipts (created_at);

create table private.trade_relay_daily (
  day    date not null,
  metric text not null check (metric ~ '^[a-z][a-z0-9_.]{1,60}$'),
  count  bigint not null default 0,
  primary key (day, metric)
);

alter table private.trade_share_excluded_stocks enable row level security;
alter table private.trade_relay_config enable row level security;
alter table private.trade_relay_status enable row level security;
alter table private.trade_orders enable row level security;
alter table private.trade_fills enable row level security;
alter table private.trade_notify_receipts enable row level security;
alter table private.trade_relay_daily enable row level security;
revoke all on private.trade_share_excluded_stocks, private.trade_relay_config, private.trade_relay_status,
              private.trade_orders, private.trade_fills, private.trade_notify_receipts, private.trade_relay_daily
  from public, anon, authenticated;

create or replace function private.trade_relay_bump_accounts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'cs_settings' then
    if not exists (select 1 from new_rows n where n.key in ('trade_share.enabled', 'trade_notify.enabled',
                                                             'trade_share.boards', 'trade_share.force_hide_price',
                                                             'trade_share.force_hide_lot')) then
      return null;
    end if;
  elsif tg_table_name = 'account_links' then
    if not exists (select 1 from new_rows) then
      return null;
    end if;
  end if;
  update private.trade_relay_config set accounts_version = accounts_version + 1 where singleton;
  return null;
end;
$$;

create trigger account_links_trade_relay_insert
  after insert on private.account_links
  referencing new table as new_rows
  for each statement execute function private.trade_relay_bump_accounts();
create trigger account_links_trade_relay_delete
  after delete on private.account_links
  referencing old table as new_rows
  for each statement execute function private.trade_relay_bump_accounts();
create trigger trade_sharer_accounts_relay
  after insert or update or delete on private.trade_sharer_accounts
  for each statement execute function private.trade_relay_bump_accounts();
create trigger trade_sharers_relay
  after insert or update or delete on private.trade_sharers
  for each statement execute function private.trade_relay_bump_accounts();
create trigger cs_settings_trade_relay
  after update on cs.cs_settings
  referencing new table as new_rows
  for each statement execute function private.trade_relay_bump_accounts();

create or replace function private.trade_relay_accounts()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with days as (select private.setting_num('integration.account_link_days', 30)::integer as d)
  select jsonb_build_object(
    'sharers', case when private.trade_share_enabled() then coalesce((
      select jsonb_agg(a.cust_id order by a.cust_id)
      from private.trade_sharer_accounts a
      join private.trade_sharers s on s.profile_id = a.profile_id and s.status = 'active'
      where a.state = 'active'), '[]') else '[]' end,
    'owners', case when private.trade_share_bool('trade_notify.enabled') then coalesce((
      select jsonb_agg(distinct l.cust_id)
      from private.account_links l
      join public.profiles p on p.id = l.profile_id and p.deleted_at is null
      where l.seen_at > now() - make_interval(days => (select d from days))), '[]') else '[]' end,
    'boards', coalesce(cs.setting('trade_share.boards'), '["RG"]'));
$$;

create or replace function private.trade_relay_secret(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v text;
begin
  if p_id is null then
    return null;
  end if;
  begin
    select d.decrypted_secret into v from vault.decrypted_secrets d where d.id = p_id;
  exception when others then
    v := null;
  end;
  return v;
end;
$$;

create or replace function public.trade_relay_config(p_instance text, p_known_version bigint default null,
                                                     p_known_accounts bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c private.trade_relay_config;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 200 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance tidak valid');
  end if;
  select * into c from private.trade_relay_config where singleton;
  return jsonb_build_object(
    'enabled', private.trade_share_enabled() or private.trade_share_bool('trade_notify.enabled'),
    'version', c.version,
    'accounts_version', c.accounts_version,
    'reconnect_generation', c.reconnect_generation,
    'restart_generation', c.restart_generation)
  || case when p_known_version is distinct from c.version then jsonb_build_object(
       'iproxy_addr', c.iproxy_addr,
       'identity', c.identity,
       'heartbeat_seconds', c.heartbeat_seconds,
       'aes', case when c.aes_key_secret_id is not null then jsonb_build_object(
         'mode', c.aes_mode,
         'key', private.trade_relay_secret(c.aes_key_secret_id),
         'iv', private.trade_relay_secret(c.aes_iv_secret_id)) end) else '{}' end
  || case when p_known_accounts is distinct from c.accounts_version
          then jsonb_build_object('accounts', private.trade_relay_accounts()) else '{}' end;
end;
$$;

create or replace function public.trade_relay_status(p_instance text, p_status jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 200 or jsonb_typeof(p_status) is distinct from 'object'
     or pg_column_size(p_status) > 16384 then
    perform private.api_error(400, 'invalid_status', 'Status relay tidak valid');
  end if;
  insert into private.trade_relay_status as s (instance, version, connected, state, last_packet_at, last_realtime_at,
                                               counters, last_error, applied_reconnect, applied_restart, started_at,
                                               reported_at)
  values (p_instance, left(p_status ->> 'version', 40), coalesce((p_status ->> 'connected')::boolean, false),
          left(p_status ->> 'state', 40), (p_status ->> 'last_packet_at')::timestamptz,
          (p_status ->> 'last_realtime_at')::timestamptz,
          case when jsonb_typeof(p_status -> 'counters') = 'object' then p_status -> 'counters' else '{}' end,
          left(nullif(btrim(p_status ->> 'last_error'), ''), 500), (p_status ->> 'applied_reconnect')::bigint,
          (p_status ->> 'applied_restart')::bigint, (p_status ->> 'started_at')::timestamptz, now())
  on conflict (instance) do update
     set version = excluded.version, connected = excluded.connected, state = excluded.state,
         last_packet_at = excluded.last_packet_at, last_realtime_at = excluded.last_realtime_at,
         counters = excluded.counters, last_error = excluded.last_error,
         applied_reconnect = excluded.applied_reconnect, applied_restart = excluded.applied_restart,
         started_at = excluded.started_at, reported_at = now();
end;
$$;

create or replace function private.trade_format_int(p_value bigint, p_sep text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_value < 0 then '-' else '' end
      || regexp_replace(reverse(regexp_replace(reverse(abs(p_value)::text), '([0-9]{3})(?=[0-9])', '\1' || p_sep, 'g')),
                        '^$', '0');
$$;

create or replace function private.trade_volume_text(p_shares bigint, p_lang text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with v as (select greatest(private.trade_share_int('trade_share.lot_size', 100), 1) as lot)
  select case
    when p_shares % (select lot from v) = 0
      then private.trade_format_int(p_shares / (select lot from v), case when p_lang = 'en' then ',' else '.' end)
           || case when p_lang = 'en' then case when p_shares / (select lot from v) = 1 then ' lot' else ' lots' end
                   else ' lot' end
    else private.trade_format_int(p_shares, case when p_lang = 'en' then ',' else '.' end)
         || case when p_lang = 'en' then ' shares' else ' lembar' end
  end;
$$;

create or replace function private.trade_notify_owner(p_cust text, p_key text, p_order_ref text, p_stock text,
                                                      p_side text, p_shares bigint, p_price integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days    integer := private.setting_num('integration.account_link_days', 30)::integer;
  v_profile uuid;
  v_count   integer := 0;
  v_title   jsonb;
  v_body    jsonb;
begin
  insert into private.trade_notify_receipts (key) values (p_key) on conflict do nothing;
  if not found then
    return -1;
  end if;
  v_title := jsonb_build_object(
    'id', case when p_side = 'buy' then 'Order beli ' else 'Order jual ' end || p_stock || ' match',
    'en', case when p_side = 'buy' then 'Buy order ' else 'Sell order ' end || p_stock || ' matched');
  v_body := jsonb_build_object(
    'id', private.trade_volume_text(p_shares, 'id')
          || case when p_price is not null then ' @ ' || private.trade_format_int(p_price, '.') else '' end,
    'en', private.trade_volume_text(p_shares, 'en')
          || case when p_price is not null then ' @ ' || private.trade_format_int(p_price, ',') else '' end);
  for v_profile in
    select l.profile_id
    from private.account_links l
    join public.profiles p on p.id = l.profile_id and p.deleted_at is null
    where l.cust_id = p_cust and l.seen_at > now() - make_interval(days => v_days)
  loop
    if coalesce(private.push_allowed(v_profile, 'olt.trade.matched'), false) then
      v_count := v_count + private.push_enqueue(
        v_profile, 'olt.trade.matched', v_title, v_body,
        jsonb_build_object('screen', '/trade-list', 'type', 'trade_matched', 'stock', p_stock, 'side', p_side),
        jsonb_build_object('collapse_key', 'trade:' || left(p_order_ref, 32), 'ref', 'trade:' || left(p_key, 32)));
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function private.trade_order_apply(p_profile uuid, e jsonb, p_price integer)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o         private.trade_orders;
  v_status  text := e ->> 'status';
  v_traded  bigint := (e ->> 'traded_shares')::bigint;
  v_remain  bigint := (e ->> 'remain_shares')::bigint;
  v_shares  bigint := (e ->> 'order_shares')::bigint;
  v_old     text;
  v_allowed boolean;
  v_amend   boolean := false;
  v_changed boolean;
begin
  select * into o from private.trade_orders where order_ref = e ->> 'order_ref' for update;
  if not found then
    insert into private.trade_orders (order_ref, profile_id, cust_id, stock, side, board, order_date, status,
                                      order_price, order_shares, remain_shares, traded_shares, last_seq)
    values (e ->> 'order_ref', p_profile, e ->> 'cust_id', e ->> 'stock', e ->> 'side', e ->> 'board',
            (e ->> 'order_date')::date, v_status, p_price, v_shares, v_remain, v_traded, e ->> 'seq');
    return 'accepted';
  end if;
  if o.last_seq is not distinct from e ->> 'seq' then
    return 'duplicate';
  end if;
  v_old := o.status;
  v_changed := o.order_price is distinct from p_price or o.remain_shares is distinct from v_remain;
  v_allowed := case
    when v_old is null then true
    when v_status = 'rejected' then v_old in ('open', 'amending', 'withdrawing')
    when v_status = 'open' then v_old in ('amending', 'amended', 'withdrawing', 'withdrawn')
                                or (v_old = 'open' and (v_traded > o.traded_shares
                                                        or (v_traded = o.traded_shares and v_changed)))
    when v_status = 'matched' then v_old in ('open', 'amending') or (v_old = 'matched' and v_traded > o.traded_shares)
    when v_status = 'amending' then v_old = 'open'
    when v_status = 'withdrawing' then v_old = 'open'
    when v_status = 'withdrawn' then v_old in ('open', 'amending', 'withdrawing')
    when v_status = 'amended' then v_old in ('open', 'amending')
    else false
  end;
  v_amend := v_allowed and v_status in ('open', 'matched')
             and (v_old in ('amending', 'amended') or (v_old = 'open' and v_status = 'open'
                                                       and v_traded = o.traded_shares and v_changed));
  update private.trade_orders
     set status = case when v_allowed then v_status else status end,
         order_price = case when v_allowed then p_price else order_price end,
         order_shares = case when v_allowed then coalesce(v_shares, order_shares) else order_shares end,
         remain_shares = case when v_traded >= traded_shares then v_remain else remain_shares end,
         traded_shares = greatest(traded_shares, v_traded),
         amend_count = amend_count + case when v_amend then 1 else 0 end,
         out_of_order = out_of_order + case when v_allowed then 0 else 1 end,
         order_date = coalesce(order_date, (e ->> 'order_date')::date),
         last_seq = e ->> 'seq',
         last_change_at = case when v_allowed or v_traded > traded_shares then now() else last_change_at end,
         report_state = case when report_state in ('reported', 'partial_reported')
                                  and greatest(traded_shares, v_traded) > reported_shares then 'pending'
                             else report_state end,
         updated_at = now()
   where order_ref = o.order_ref;
  return case when v_allowed or v_traded > o.traded_shares then 'accepted' else 'ignored' end;
end;
$$;

create or replace function private.trade_fill_apply(p_profile uuid, e jsonb, p_price integer)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shares bigint := (e ->> 'shares')::bigint;
  v_at     timestamptz := (e ->> 'traded_at')::timestamptz;
begin
  insert into private.trade_orders (order_ref, profile_id, cust_id, stock, side, board)
  values (e ->> 'order_ref', p_profile, e ->> 'cust_id', e ->> 'stock', e ->> 'side', e ->> 'board')
  on conflict (order_ref) do nothing;
  insert into private.trade_fills (key, order_ref, traded_at, price, shares)
  values (e ->> 'key', e ->> 'order_ref', v_at, p_price, v_shares)
  on conflict (key) do nothing;
  if not found then
    return 'duplicate';
  end if;
  update private.trade_orders
     set fill_shares = fill_shares + v_shares,
         fill_value = fill_value + coalesce(p_price::numeric * v_shares, 0),
         fill_priced = fill_priced + case when p_price is not null then v_shares else 0 end,
         fill_count = fill_count + 1,
         first_fill_at = least(coalesce(first_fill_at, v_at), v_at),
         last_fill_at = greatest(coalesce(last_fill_at, v_at), v_at),
         last_change_at = now(),
         report_state = case when report_state in ('reported', 'partial_reported')
                                  and greatest(traded_shares, fill_shares + v_shares) > reported_shares then 'pending'
                             else report_state end,
         updated_at = now()
   where order_ref = e ->> 'order_ref';
  return 'accepted';
end;
$$;

create or replace function private.trade_relay_event_error(e jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  if jsonb_typeof(e) is distinct from 'object' then return 'not_object'; end if;
  if coalesce(e ->> 'kind', '') not in ('order', 'fill') then return 'invalid_kind'; end if;
  if private.integration_cust_id(e -> 'cust_id') is null then return 'invalid_cust_id'; end if;
  if coalesce(e ->> 'order_ref', '') !~ '^[0-9a-f]{64}$' then return 'invalid_order_ref'; end if;
  if coalesce(e ->> 'stock', '') !~ '^[A-Z0-9-]{1,12}$' then return 'invalid_stock'; end if;
  if coalesce(e ->> 'side', '') not in ('buy', 'sell') then return 'invalid_side'; end if;
  if coalesce(e ->> 'board', '') !~ '^[A-Z]{1,6}$' then return 'invalid_board'; end if;
  if (e ? 'price' and jsonb_typeof(e -> 'price') <> 'null'
      and (jsonb_typeof(e -> 'price') <> 'number' or (e ->> 'price')::numeric not between 0 and 2147483647
           or (e ->> 'price')::numeric <> trunc((e ->> 'price')::numeric)))
     or (e ? 'order_price' and jsonb_typeof(e -> 'order_price') <> 'null'
         and (jsonb_typeof(e -> 'order_price') <> 'number'
              or (e ->> 'order_price')::numeric not between 0 and 2147483647
              or (e ->> 'order_price')::numeric <> trunc((e ->> 'order_price')::numeric))) then
    return 'invalid_price';
  end if;
  if e ->> 'kind' = 'fill' then
    if coalesce(e ->> 'key', '') !~ '^[0-9a-f]{64}$' then return 'invalid_key'; end if;
    if jsonb_typeof(e -> 'shares') <> 'number' or (e ->> 'shares')::numeric not between 1 and 9e15
       or (e ->> 'shares')::numeric <> trunc((e ->> 'shares')::numeric) then
      return 'invalid_shares';
    end if;
    perform (e ->> 'traded_at')::timestamptz;
    if e ->> 'traded_at' is null then return 'invalid_traded_at'; end if;
  else
    if coalesce(e ->> 'seq', '') !~ '^[0-9a-f]{64}$' then return 'invalid_seq'; end if;
    if coalesce(e ->> 'status', '') not in ('rejected', 'open', 'matched', 'amending', 'withdrawing', 'withdrawn',
                                           'amended') then
      return 'invalid_status';
    end if;
    if jsonb_typeof(e -> 'order_shares') <> 'number' or jsonb_typeof(e -> 'remain_shares') <> 'number'
       or jsonb_typeof(e -> 'traded_shares') <> 'number'
       or (e ->> 'order_shares')::numeric not between 0 and 9e15
       or (e ->> 'remain_shares')::numeric not between 0 and 9e15
       or (e ->> 'traded_shares')::numeric not between 0 and 9e15
       or (e ->> 'order_shares')::numeric <> trunc((e ->> 'order_shares')::numeric)
       or (e ->> 'remain_shares')::numeric <> trunc((e ->> 'remain_shares')::numeric)
       or (e ->> 'traded_shares')::numeric <> trunc((e ->> 'traded_shares')::numeric) then
      return 'invalid_volume';
    end if;
    if e ->> 'order_date' is not null then
      perform (e ->> 'order_date')::date;
    end if;
  end if;
  return null;
exception when others then
  return 'invalid_value';
end;
$$;

create or replace function public.trade_relay_events(p_instance text, p_events jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_share   boolean := private.trade_share_enabled();
  v_notify  boolean := private.trade_share_bool('trade_notify.enabled');
  v_boards  text[] := coalesce((select array_agg(b) from jsonb_array_elements_text(cs.setting('trade_share.boards')) b),
                               '{RG}');
  v_hide    boolean := private.trade_share_bool('trade_share.force_hide_price');
  v_results jsonb := '[]';
  v_counts  jsonb := '{}';
  e         jsonb;
  v_index   bigint;
  v_error   text;
  v_cust    text;
  v_result  text;
  v_owner   text;
  v_sp      uuid;
  v_show    boolean;
  v_price   integer;
  v_pushed  integer;
  v_day     date := (now() at time zone 'Asia/Jakarta')::date;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 200 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance tidak valid');
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' or jsonb_array_length(p_events) not between 1 and 500 then
    perform private.api_error(400, 'invalid_batch', 'events harus array berisi 1–500 event');
  end if;
  for e, v_index in select x.value, x.ord - 1 from jsonb_array_elements(p_events) with ordinality as x(value, ord) loop
    v_error := private.trade_relay_event_error(e);
    if v_error is not null then
      v_results := v_results || jsonb_build_object('index', v_index, 'status', 'invalid', 'error', v_error);
      v_counts := jsonb_set(v_counts, '{invalid}', to_jsonb(coalesce((v_counts ->> 'invalid')::bigint, 0) + 1));
      continue;
    end if;
    v_cust := private.integration_cust_id(e -> 'cust_id');
    e := jsonb_set(e, '{cust_id}', to_jsonb(v_cust));
    v_price := case when jsonb_typeof(e -> 'price') = 'number' then (e ->> 'price')::integer
                    when jsonb_typeof(e -> 'order_price') = 'number' then (e ->> 'order_price')::integer end;
    v_result := null;
    v_owner := null;
    if v_notify and e ->> 'kind' = 'fill' then
      v_pushed := private.trade_notify_owner(v_cust, e ->> 'key', e ->> 'order_ref', e ->> 'stock', e ->> 'side',
                                             (e ->> 'shares')::bigint, v_price);
      v_owner := case when v_pushed < 0 then 'duplicate' else 'accepted' end;
      if v_pushed > 0 then
        v_counts := jsonb_set(v_counts, '{owner_push}',
                              to_jsonb(coalesce((v_counts ->> 'owner_push')::bigint, 0) + v_pushed));
      end if;
    end if;
    v_sp := null;
    v_show := null;
    if v_share then
      select s.profile_id, s.show_price into v_sp, v_show
      from private.trade_sharer_accounts a
      join private.trade_sharers s on s.profile_id = a.profile_id
      where a.cust_id = v_cust and a.state = 'active' and s.status = 'active'
      limit 1;
    end if;
    if v_sp is null then
      v_result := coalesce(v_owner, 'dropped');
      v_error := case when v_owner is null then 'not_shared' end;
    elsif not (e ->> 'board' = any (v_boards)) then
      v_result := coalesce(v_owner, 'dropped');
      v_error := case when v_owner is null then 'board_not_shared' end;
    elsif exists (select 1 from private.trade_share_excluded_stocks x
                   where x.stock = e ->> 'stock' and (x.until is null or x.until > now())) then
      v_result := coalesce(v_owner, 'dropped');
      v_error := case when v_owner is null then 'stock_excluded' end;
    else
      if v_hide or not v_show then
        v_price := null;
      end if;
      if e ->> 'kind' = 'order' then
        v_result := private.trade_order_apply(v_sp, e, v_price);
      else
        v_result := private.trade_fill_apply(v_sp, e, v_price);
      end if;
      if v_result in ('duplicate', 'ignored') and v_owner = 'accepted' then
        v_result := 'accepted';
      end if;
      v_error := null;
    end if;
    v_results := v_results || jsonb_strip_nulls(jsonb_build_object('index', v_index, 'status', v_result,
                                                                   'reason', v_error));
    v_counts := jsonb_set(v_counts, array[coalesce(v_error, v_result)],
                          to_jsonb(coalesce((v_counts ->> coalesce(v_error, v_result))::bigint, 0) + 1));
  end loop;
  insert into private.trade_relay_daily (day, metric, count)
  select v_day, k, v::bigint from jsonb_each_text(v_counts) c(k, v)
  on conflict (day, metric) do update set count = private.trade_relay_daily.count + excluded.count;
  return jsonb_build_object('results', v_results, 'counts', v_counts);
end;
$$;

create or replace function cs.trade_relay_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'iproxy_addr', c.iproxy_addr,
    'identity', c.identity,
    'heartbeat_seconds', c.heartbeat_seconds,
    'aes', jsonb_build_object('configured', c.aes_key_secret_id is not null, 'mode', c.aes_mode,
                              'fingerprint', c.aes_key_fingerprint, 'key_length', c.aes_key_length,
                              'has_iv', c.aes_iv_secret_id is not null, 'updated_at', c.aes_updated_at),
    'reconnect_generation', c.reconnect_generation,
    'restart_generation', c.restart_generation,
    'last_command_at', c.last_command_at,
    'version', c.version,
    'updated_at', c.updated_at,
    'updated_by', c.updated_by,
    'trade_notify_enabled', private.trade_share_bool('trade_notify.enabled'),
    'trade_share_enabled', private.trade_share_enabled(),
    'instances', coalesce((select jsonb_agg(jsonb_build_object(
        'instance', s.instance, 'version', s.version, 'connected', s.connected, 'state', s.state,
        'last_packet_at', s.last_packet_at, 'last_realtime_at', s.last_realtime_at, 'counters', s.counters,
        'last_error', s.last_error, 'applied_reconnect', s.applied_reconnect, 'applied_restart', s.applied_restart,
        'started_at', s.started_at, 'reported_at', s.reported_at) order by s.reported_at desc)
      from private.trade_relay_status s where s.reported_at > now() - interval '1 day'), '[]'),
    'today', coalesce((select jsonb_object_agg(d.metric, d.count) from private.trade_relay_daily d
                        where d.day = (now() at time zone 'Asia/Jakarta')::date), '{}'))
  from private.trade_relay_config c where c.singleton;
$$;

create or replace function cs_api.trade_relay_get()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_relay.operate}');
begin
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_relay_update(p_iproxy_addr text, p_identity text, p_heartbeat_seconds integer,
                                                     p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := private.trade_share_reason(p_reason, true);
  c        private.trade_relay_config;
  v_addr   text := nullif(btrim(coalesce(p_iproxy_addr, '')), '');
  v_ident  text := coalesce(nullif(btrim(coalesce(p_identity, '')), ''), 'social_trade_relay');
begin
  if v_addr is not null and v_addr !~ '^tcp://[A-Za-z0-9._-]{1,253}:[0-9]{1,5}$' then
    perform private.api_error(400, 'invalid_iproxy_addr', 'Alamat harus berbentuk tcp://host:port');
  end if;
  if v_addr is not null and split_part(v_addr, ':', 3)::integer not between 1 and 65535 then
    perform private.api_error(400, 'invalid_iproxy_addr', 'Port tidak valid');
  end if;
  if v_ident !~ '^[A-Za-z0-9._-]{3,63}$' then
    perform private.api_error(400, 'invalid_identity', 'Identity 3–63 karakter huruf, angka, titik, garis bawah, atau strip');
  end if;
  if coalesce(p_heartbeat_seconds, 4) not between 1 and 60 then
    perform private.api_error(400, 'invalid_heartbeat', 'Interval heartbeat 1–60 detik');
  end if;
  select * into c from private.trade_relay_config where singleton for update;
  update private.trade_relay_config
     set iproxy_addr = v_addr, identity = v_ident, heartbeat_seconds = coalesce(p_heartbeat_seconds, 4),
         version = version + 1, updated_at = now(), updated_by = v_me
   where singleton;
  perform cs.audit('trade_relay.config', null, null, jsonb_build_object(
    'reason', v_reason,
    'iproxy_addr', jsonb_build_object('from', c.iproxy_addr, 'to', v_addr),
    'identity', jsonb_build_object('from', c.identity, 'to', v_ident),
    'heartbeat_seconds', jsonb_build_object('from', c.heartbeat_seconds, 'to', coalesce(p_heartbeat_seconds, 4))));
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_relay_set_aes(p_mode text, p_key text, p_iv text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := private.trade_share_reason(p_reason, true);
  c        private.trade_relay_config;
  v_mode   text := coalesce(p_mode, 'ecb');
begin
  if v_mode not in ('ecb', 'cbc') then
    perform private.api_error(400, 'invalid_aes_mode', 'Mode harus ecb atau cbc');
  end if;
  if p_key is null or p_key !~ '^[\x21-\x7e]+$' or char_length(p_key) not in (16, 24, 32) then
    perform private.api_error(400, 'invalid_aes_key', 'Kunci harus 16, 24, atau 32 karakter ASCII');
  end if;
  if v_mode = 'cbc' and (p_iv is null or p_iv !~ '^[\x21-\x7e]{16}$') then
    perform private.api_error(400, 'invalid_aes_iv', 'IV harus 16 karakter ASCII untuk mode CBC');
  end if;
  if p_iv is not null and p_iv !~ '^[\x21-\x7e]{16}$' then
    perform private.api_error(400, 'invalid_aes_iv', 'IV harus 16 karakter ASCII');
  end if;
  select * into c from private.trade_relay_config where singleton for update;
  if c.aes_key_secret_id is null then
    delete from vault.secrets s where s.name = 'trade_relay.aes_key';
    c.aes_key_secret_id := vault.create_secret(p_key, 'trade_relay.aes_key', 'Kunci AES paket realtime OLT');
  else
    perform vault.update_secret(c.aes_key_secret_id, p_key);
  end if;
  if p_iv is not null then
    if c.aes_iv_secret_id is null then
      delete from vault.secrets s where s.name = 'trade_relay.aes_iv';
      c.aes_iv_secret_id := vault.create_secret(p_iv, 'trade_relay.aes_iv', 'IV AES paket realtime OLT');
    else
      perform vault.update_secret(c.aes_iv_secret_id, p_iv);
    end if;
  elsif c.aes_iv_secret_id is not null then
    delete from vault.secrets s where s.id = c.aes_iv_secret_id;
    c.aes_iv_secret_id := null;
  end if;
  update private.trade_relay_config
     set aes_mode = v_mode, aes_key_secret_id = c.aes_key_secret_id, aes_iv_secret_id = c.aes_iv_secret_id,
         aes_key_fingerprint = left(encode(sha256(convert_to(p_key, 'UTF8')), 'hex'), 8),
         aes_key_length = char_length(p_key), aes_updated_at = now(), version = version + 1,
         updated_at = now(), updated_by = v_me
   where singleton;
  perform cs.audit('trade_relay.aes_set', null, null, jsonb_build_object(
    'reason', v_reason, 'mode', v_mode, 'key_length', char_length(p_key), 'has_iv', p_iv is not null,
    'fingerprint', left(encode(sha256(convert_to(p_key, 'UTF8')), 'hex'), 8)));
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_relay_clear_aes(p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := private.trade_share_reason(p_reason, true);
  c        private.trade_relay_config;
begin
  select * into c from private.trade_relay_config where singleton for update;
  if c.aes_key_secret_id is null then
    perform private.api_error(404, 'aes_not_configured', 'Kunci AES belum diatur');
  end if;
  delete from vault.secrets s where s.id in (c.aes_key_secret_id, c.aes_iv_secret_id);
  update private.trade_relay_config
     set aes_key_secret_id = null, aes_iv_secret_id = null, aes_key_fingerprint = null, aes_key_length = null,
         aes_updated_at = now(), version = version + 1, updated_at = now(), updated_by = v_me
   where singleton;
  perform cs.audit('trade_relay.aes_cleared', null, null, jsonb_build_object('reason', v_reason));
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_relay_command(p_action text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_relay.operate}');
  v_reason text := private.trade_share_reason(p_reason, true);
  c        private.trade_relay_config;
begin
  if p_action is null or p_action not in ('reconnect', 'restart') then
    perform private.api_error(400, 'invalid_action', 'Perintah harus reconnect atau restart');
  end if;
  select * into c from private.trade_relay_config where singleton for update;
  if c.last_command_at is not null and c.last_command_at > now() - interval '1 minute' then
    perform private.api_error(429, 'command_rate_limited', 'Tunggu satu menit sebelum perintah berikutnya');
  end if;
  update private.trade_relay_config
     set reconnect_generation = reconnect_generation + case when p_action = 'reconnect' then 1 else 0 end,
         restart_generation = restart_generation + case when p_action = 'restart' then 1 else 0 end,
         last_command_at = now()
   where singleton;
  perform cs.audit('trade_relay.command', null, null, jsonb_build_object('action', p_action, 'reason', v_reason));
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_notify_set_enabled(p_enabled boolean, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  perform cs.set_setting('trade_notify.enabled', to_jsonb(coalesce(p_enabled, false)), v_me);
  perform cs.audit('trade_notify.enabled', null, null,
                   jsonb_build_object('enabled', coalesce(p_enabled, false), 'reason', v_reason));
  return cs.trade_relay_view();
end;
$$;

create or replace function cs_api.trade_share_excluded_stocks()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('stock', x.stock, 'reason', x.reason, 'until', x.until,
                                                       'active', x.until is null or x.until > now(),
                                                       'created_by', x.created_by, 'created_at', x.created_at)
                                    order by x.stock)
                   from private.trade_share_excluded_stocks x), '[]');
end;
$$;

create or replace function cs_api.trade_share_exclude_stock(p_stock text, p_reason text, p_until timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.manage}');
  v_stock  text := upper(btrim(coalesce(p_stock, '')));
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  if v_stock !~ '^[A-Z0-9-]{1,12}$' then
    perform private.api_error(400, 'invalid_stock', 'Kode saham tidak valid');
  end if;
  if p_until is not null and p_until <= now() then
    perform private.api_error(400, 'invalid_until', 'Batas waktu harus di masa depan');
  end if;
  insert into private.trade_share_excluded_stocks (stock, reason, until, created_by)
  values (v_stock, v_reason, p_until, v_me)
  on conflict (stock) do update set reason = excluded.reason, until = excluded.until;
  perform cs.audit('trade_share.exclude_stock', null, null,
                   jsonb_build_object('stock', v_stock, 'reason', v_reason, 'until', p_until));
  return cs_api.trade_share_excluded_stocks();
end;
$$;

create or replace function cs_api.trade_share_unexclude_stock(p_stock text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_trade('{trade_share.manage}');
  v_stock  text := upper(btrim(coalesce(p_stock, '')));
  v_reason text := private.trade_share_reason(p_reason, true);
begin
  delete from private.trade_share_excluded_stocks where stock = v_stock;
  if not found then
    perform private.api_error(404, 'not_excluded', 'Saham tidak ada di daftar dikecualikan');
  end if;
  perform cs.audit('trade_share.unexclude_stock', null, null, jsonb_build_object('stock', v_stock, 'reason', v_reason));
  return cs_api.trade_share_excluded_stocks();
end;
$$;

revoke execute on function private.trade_relay_bump_accounts() from public;
revoke execute on function private.trade_relay_accounts() from public;
revoke execute on function private.trade_relay_secret(uuid) from public;
revoke execute on function private.trade_format_int(bigint, text) from public;
revoke execute on function private.trade_volume_text(bigint, text) from public;
revoke execute on function private.trade_notify_owner(text, text, text, text, text, bigint, integer) from public;
revoke execute on function private.trade_order_apply(uuid, jsonb, integer) from public;
revoke execute on function private.trade_fill_apply(uuid, jsonb, integer) from public;
revoke execute on function private.trade_relay_event_error(jsonb) from public;
revoke execute on function cs.trade_relay_view() from public;

revoke execute on function public.trade_relay_config(text, bigint, bigint) from public, anon, authenticated;
grant execute on function public.trade_relay_config(text, bigint, bigint) to service_role;
revoke execute on function public.trade_relay_status(text, jsonb) from public, anon, authenticated;
grant execute on function public.trade_relay_status(text, jsonb) to service_role;
revoke execute on function public.trade_relay_events(text, jsonb) from public, anon, authenticated;
grant execute on function public.trade_relay_events(text, jsonb) to service_role;

revoke execute on function cs_api.trade_relay_get() from public;
grant execute on function cs_api.trade_relay_get() to authenticated;
revoke execute on function cs_api.trade_relay_update(text, text, integer, text) from public;
grant execute on function cs_api.trade_relay_update(text, text, integer, text) to authenticated;
revoke execute on function cs_api.trade_relay_set_aes(text, text, text, text) from public;
grant execute on function cs_api.trade_relay_set_aes(text, text, text, text) to authenticated;
revoke execute on function cs_api.trade_relay_clear_aes(text) from public;
grant execute on function cs_api.trade_relay_clear_aes(text) to authenticated;
revoke execute on function cs_api.trade_relay_command(text, text) from public;
grant execute on function cs_api.trade_relay_command(text, text) to authenticated;
revoke execute on function cs_api.trade_notify_set_enabled(boolean, text) from public;
grant execute on function cs_api.trade_notify_set_enabled(boolean, text) to authenticated;
revoke execute on function cs_api.trade_share_excluded_stocks() from public;
grant execute on function cs_api.trade_share_excluded_stocks() to authenticated;
revoke execute on function cs_api.trade_share_exclude_stock(text, text, timestamptz) from public;
grant execute on function cs_api.trade_share_exclude_stock(text, text, timestamptz) to authenticated;
revoke execute on function cs_api.trade_share_unexclude_stock(text, text) from public;
grant execute on function cs_api.trade_share_unexclude_stock(text, text) to authenticated;
