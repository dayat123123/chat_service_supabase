create table private.trade_subscriptions (
  subscriber_id    uuid not null references public.profiles (id) on delete cascade,
  trader_id        uuid not null references public.profiles (id) on delete cascade,
  status           text not null check (status in ('pending', 'active', 'declined', 'expired', 'ended')),
  muted            boolean not null default false,
  risk_document_id uuid references public.legal_documents (id),
  requested_at     timestamptz not null default now(),
  decided_at       timestamptz,
  expires_at       timestamptz,
  ended_at         timestamptz,
  end_reason       text check (end_reason in ('cancelled', 'unfollowed', 'blocked', 'removed_by_trader',
                                              'trader_stopped', 'deleted')),
  updated_at       timestamptz not null default now(),
  primary key (subscriber_id, trader_id),
  constraint trade_subscriptions_not_self check (subscriber_id <> trader_id),
  constraint trade_subscriptions_pending_expiry check ((status = 'pending') = (expires_at is not null))
);
create index trade_subscriptions_trader_idx on private.trade_subscriptions (trader_id, status, requested_at desc);
create index trade_subscriptions_subscriber_idx on private.trade_subscriptions (subscriber_id, status, requested_at desc);
create index trade_subscriptions_expiry_idx on private.trade_subscriptions (expires_at) where status = 'pending';

alter table private.trade_subscriptions enable row level security;
revoke all on private.trade_subscriptions from public, anon, authenticated;

create or replace function private.trade_share_subscriber_counts(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'active', count(*) filter (where s.status = 'active'),
    'pending', count(*) filter (where s.status = 'pending' and s.expires_at > now()))
  from private.trade_subscriptions s
  where s.trader_id = p_profile;
$$;

create or replace function private.trade_share_public_profile(p_profile uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', p.id, 'username', p.username::text, 'display_name', p.display_name,
                            'avatar_url', p.avatar_url, 'is_verified', p.is_verified,
                            'is_official', private.is_official_account(p.id))
  from public.profiles p where p.id = p_profile;
$$;

create or replace function private.trade_share_is_sharing(p_trader uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.trade_share_enabled()
     and exists (select 1 from private.trade_sharers s
                  where s.profile_id = p_trader and s.status in ('active', 'paused'));
$$;

create or replace function private.trade_share_subscribe_block(p_subscriber uuid, p_trader uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not private.trade_share_enabled() then 'feature_disabled'
    when p_subscriber = p_trader then 'self'
    when not private.trade_share_is_sharing(p_trader) then 'not_sharing'
    when not exists (select 1 from public.profiles p
                      where p.id = p_subscriber and p.deleted_at is null and not p.is_guest
                        and not cs.is_staff(p.id)) then 'not_customer'
    when not exists (select 1 from private.account_links l
                      where l.profile_id = p_subscriber
                        and l.seen_at > now() - make_interval(
                              days => private.setting_num('integration.account_link_days', 30)::integer))
      then 'no_linked_account'
    when private.has_active_sanction(p_subscriber, '{mute,ban}') then 'sanctioned'
    when private.is_blocked_pair(p_subscriber, p_trader) then 'blocked'
    when not exists (select 1 from public.follows f where f.follower_id = p_subscriber and f.following_id = p_trader)
      then 'not_following'
    else null
  end;
$$;

create or replace function private.trade_share_subscription_view(p_subscriber uuid, p_trader uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when s.subscriber_id is null then null else jsonb_build_object(
    'status', case when s.status = 'pending' and s.expires_at <= now() then 'expired' else s.status end,
    'muted', s.muted,
    'requested_at', s.requested_at,
    'decided_at', s.decided_at,
    'expires_at', s.expires_at,
    'ended_at', s.ended_at,
    'end_reason', s.end_reason) end
  from (select 1) x
  left join private.trade_subscriptions s on s.subscriber_id = p_subscriber and s.trader_id = p_trader;
$$;

create or replace function private.trade_share_profile_view(p_subscriber uuid, p_trader uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_risk  public.legal_documents := private.trade_share_latest_document('trade_share_risk');
  v_block text := private.trade_share_subscribe_block(p_subscriber, p_trader);
  v_mode  text;
begin
  if not private.trade_share_enabled() then
    return jsonb_build_object('enabled', false, 'sharing', false);
  end if;
  select s.subscribe_mode into v_mode from private.trade_sharers s where s.profile_id = p_trader;
  return jsonb_build_object(
    'enabled', true,
    'sharing', private.trade_share_is_sharing(p_trader),
    'subscribe_mode', case when private.trade_share_is_sharing(p_trader) then v_mode end,
    'subscription', private.trade_share_subscription_view(p_subscriber, p_trader),
    'can_subscribe', v_block is null and v_risk.id is not null,
    'blocked_reason', coalesce(v_block, case when v_risk.id is null then 'risk_unavailable' end),
    'risk_document', case when v_risk.id is not null then jsonb_build_object(
      'id', v_risk.id, 'version', v_risk.version, 'title', v_risk.title, 'body', v_risk.body,
      'effective_at', v_risk.effective_at,
      'accepted', exists (select 1 from public.user_consents c
                           where c.user_id = p_subscriber and c.document_id = v_risk.id)) end);
end;
$$;

create or replace function private.trade_share_end_subscription(p_subscriber uuid, p_trader uuid, p_reason text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.trade_subscriptions
     set status = 'ended', ended_at = now(), end_reason = p_reason, expires_at = null, updated_at = now()
   where subscriber_id = p_subscriber and trader_id = p_trader and status in ('pending', 'active');
  return found;
end;
$$;

create or replace function public.get_trade_share_profile(p_trader uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_trader is null
     or not exists (select 1 from public.profiles p where p.id = p_trader and p.deleted_at is null and not p.is_guest)
     or private.is_blocked_pair(v_uid, p_trader) then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  return private.trade_share_profile_view(v_uid, p_trader);
end;
$$;

create or replace function public.request_trade_subscription(p_trader uuid, p_risk_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_block text;
  v_risk  public.legal_documents := private.trade_share_latest_document('trade_share_risk');
  v_mode  text;
  v_max   integer := private.trade_share_int('trade_share.max_subscriptions', 20);
  v_days  integer := private.trade_share_int('trade_share.request_expiry_days', 14);
  s       private.trade_subscriptions;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('trade_subscription:' || v_uid::text, 0));
  v_block := private.trade_share_subscribe_block(v_uid, p_trader);
  if v_block is not null then
    perform private.api_error(403, 'cannot_subscribe', v_block);
  end if;
  if v_risk.id is null then
    perform private.api_error(409, 'risk_unavailable', 'Pernyataan risiko belum tersedia');
  end if;
  if p_risk_document_id is distinct from v_risk.id then
    perform private.api_error(409, 'risk_outdated', 'Pernyataan risiko sudah berubah, baca ulang');
  end if;
  select * into s from private.trade_subscriptions where subscriber_id = v_uid and trader_id = p_trader for update;
  if found and (s.status = 'active' or (s.status = 'pending' and s.expires_at > now())) then
    perform private.api_error(409, 'already_subscribed', 'Langganan sudah ada');
  end if;
  if (select count(*) from private.trade_subscriptions x
       where x.subscriber_id = v_uid
         and (x.status = 'active' or (x.status = 'pending' and x.expires_at > now()))) >= v_max then
    perform private.api_error(409, 'subscription_limit', format('Maksimal %s trader', v_max));
  end if;
  select t.subscribe_mode into v_mode from private.trade_sharers t where t.profile_id = p_trader;
  insert into public.user_consents (user_id, document_id) values (v_uid, v_risk.id) on conflict do nothing;
  insert into private.trade_subscriptions (subscriber_id, trader_id, status, muted, risk_document_id, requested_at,
                                           decided_at, expires_at)
  values (v_uid, p_trader, case when v_mode = 'approval' then 'pending' else 'active' end, false, v_risk.id, now(),
          case when v_mode = 'approval' then null else now() end,
          case when v_mode = 'approval' then now() + make_interval(days => v_days) end)
  on conflict (subscriber_id, trader_id) do update
     set status = excluded.status, muted = false, risk_document_id = excluded.risk_document_id,
         requested_at = now(), decided_at = excluded.decided_at, expires_at = excluded.expires_at,
         ended_at = null, end_reason = null, updated_at = now();
  return private.trade_share_profile_view(v_uid, p_trader);
end;
$$;

create or replace function public.cancel_trade_subscription(p_trader uuid)
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
  if not private.trade_share_end_subscription(v_uid, p_trader, 'cancelled') then
    perform private.api_error(404, 'subscription_not_found', 'Langganan tidak ditemukan');
  end if;
  return private.trade_share_profile_view(v_uid, p_trader);
end;
$$;

create or replace function public.mute_trade_subscription(p_trader uuid, p_muted boolean)
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
  update private.trade_subscriptions set muted = coalesce(p_muted, false), updated_at = now()
   where subscriber_id = v_uid and trader_id = p_trader and status = 'active';
  if not found then
    perform private.api_error(404, 'subscription_not_found', 'Langganan tidak ditemukan');
  end if;
  return private.trade_share_profile_view(v_uid, p_trader);
end;
$$;

create or replace function public.my_trade_subscriptions(p_cursor text default null, p_limit integer default 30)
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
  v_rows  jsonb;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
  select coalesce(jsonb_agg(r.item order by r.at desc, r.trader_id desc), '[]') into v_rows
  from (
    select s.requested_at as at, s.trader_id,
           jsonb_build_object('trader', private.trade_share_public_profile(s.trader_id),
                              'sharing', private.trade_share_is_sharing(s.trader_id),
                              'cursor', private.make_cursor(s.requested_at, s.trader_id))
             || private.trade_share_subscription_view(v_uid, s.trader_id) as item
    from private.trade_subscriptions s
    join public.profiles p on p.id = s.trader_id and p.deleted_at is null
    where s.subscriber_id = v_uid
      and (s.status = 'active' or (s.status = 'pending' and s.expires_at > now()))
      and (v_ts is null or (s.requested_at, s.trader_id) < (v_ts, v_id))
    order by s.requested_at desc, s.trader_id desc
    limit v_limit) r;
  return v_rows;
end;
$$;

create or replace function public.my_trade_subscribers(p_status text default 'active', p_cursor text default null,
                                                       p_limit integer default 30)
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
  if coalesce(p_status, '') not in ('active', 'pending') then
    perform private.api_error(400, 'invalid_status', 'Status harus active atau pending');
  end if;
  if not exists (select 1 from private.trade_sharers t where t.profile_id = v_uid) then
    perform private.api_error(403, 'not_trader', 'Hanya trader yang bisa melihat pelanggannya');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
  return coalesce((
    select jsonb_agg(r.item order by r.at desc, r.subscriber_id desc)
    from (
      select s.requested_at as at, s.subscriber_id,
             jsonb_build_object('subscriber', private.trade_share_public_profile(s.subscriber_id),
                                'status', s.status, 'requested_at', s.requested_at, 'decided_at', s.decided_at,
                                'expires_at', s.expires_at,
                                'cursor', private.make_cursor(s.requested_at, s.subscriber_id)) as item
      from private.trade_subscriptions s
      join public.profiles p on p.id = s.subscriber_id and p.deleted_at is null
      where s.trader_id = v_uid and s.status = p_status
        and (p_status <> 'pending' or s.expires_at > now())
        and (v_ts is null or (s.requested_at, s.subscriber_id) < (v_ts, v_id))
      order by s.requested_at desc, s.subscriber_id desc
      limit v_limit) r), '[]');
end;
$$;

create or replace function public.decide_trade_subscription(p_subscriber uuid, p_approve boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  s     private.trade_subscriptions;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into s from private.trade_subscriptions where subscriber_id = p_subscriber and trader_id = v_uid for update;
  if not found or s.status <> 'pending' then
    perform private.api_error(404, 'request_not_found', 'Permintaan tidak ditemukan');
  end if;
  if s.expires_at <= now() then
    update private.trade_subscriptions set status = 'expired', expires_at = null, updated_at = now()
     where subscriber_id = p_subscriber and trader_id = v_uid;
    return jsonb_build_object('status', 'expired');
  end if;
  if coalesce(p_approve, false) then
    if private.trade_share_subscribe_block(p_subscriber, v_uid) is not null then
      perform private.api_error(409, 'cannot_subscribe', private.trade_share_subscribe_block(p_subscriber, v_uid));
    end if;
    update private.trade_subscriptions set status = 'active', decided_at = now(), expires_at = null, updated_at = now()
     where subscriber_id = p_subscriber and trader_id = v_uid;
    return jsonb_build_object('status', 'active');
  end if;
  update private.trade_subscriptions set status = 'declined', decided_at = now(), expires_at = null, updated_at = now()
   where subscriber_id = p_subscriber and trader_id = v_uid;
  return jsonb_build_object('status', 'declined');
end;
$$;

create or replace function public.remove_trade_subscriber(p_subscriber uuid)
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
  if not private.trade_share_end_subscription(p_subscriber, v_uid, 'removed_by_trader') then
    perform private.api_error(404, 'subscription_not_found', 'Langganan tidak ditemukan');
  end if;
  return jsonb_build_object('status', 'ended');
end;
$$;

create or replace function private.trade_share_expire_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update private.trade_subscriptions set status = 'expired', expires_at = null, updated_at = now()
   where status = 'pending' and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.trade_share_unfollow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.trade_share_end_subscription(old.follower_id, old.following_id, 'unfollowed');
  return null;
end;
$$;

create trigger follows_trade_share_unfollow
  after delete on public.follows
  for each row execute function private.trade_share_unfollow();

create or replace function private.trade_share_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.trade_share_end_subscription(new.blocker_id, new.blocked_id, 'blocked');
  perform private.trade_share_end_subscription(new.blocked_id, new.blocker_id, 'blocked');
  return null;
end;
$$;

create trigger blocks_trade_share
  after insert on public.blocks
  for each row execute function private.trade_share_block();

create or replace function private.trade_share_trader_stopped()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('revoked', 'withdrawn', 'rejected') and old.status is distinct from new.status then
    update private.trade_subscriptions
       set status = 'ended', ended_at = now(), end_reason = 'trader_stopped', expires_at = null, updated_at = now()
     where trader_id = new.profile_id and status in ('pending', 'active');
  end if;
  return null;
end;
$$;

create trigger trade_sharers_stop_subscriptions
  after update of status on private.trade_sharers
  for each row execute function private.trade_share_trader_stopped();

create or replace function private.trade_subscriptions_forget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    delete from private.trade_subscriptions where subscriber_id = new.id or trader_id = new.id;
  end if;
  return null;
end;
$$;

create trigger profiles_72_trade_subscriptions_forget
  after update of deleted_at on public.profiles
  for each row execute function private.trade_subscriptions_forget();

create or replace function cs_api.trade_share_subscribers(p_trader uuid, p_status text default 'active',
                                                          p_before timestamptz default null, p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if p_status is not null and p_status not in ('pending', 'active', 'declined', 'expired', 'ended') then
    perform private.api_error(400, 'invalid_status', 'Status tidak dikenal');
  end if;
  perform cs.audit('trade_share.subscribers_view', null, p_trader, jsonb_build_object('status', p_status));
  return coalesce((
    select jsonb_agg(jsonb_build_object('subscriber', cs.trade_share_profile_ref(s.subscriber_id),
                                        'status', s.status, 'muted', s.muted, 'requested_at', s.requested_at,
                                        'decided_at', s.decided_at, 'expires_at', s.expires_at,
                                        'ended_at', s.ended_at, 'end_reason', s.end_reason)
                     order by s.requested_at desc)
    from (select * from private.trade_subscriptions x
           where x.trader_id = p_trader
             and (p_status is null or x.status = p_status)
             and (p_before is null or x.requested_at < p_before)
           order by x.requested_at desc
           limit v_limit) s), '[]');
end;
$$;

revoke execute on function private.trade_share_public_profile(uuid) from public;
revoke execute on function private.trade_share_is_sharing(uuid) from public;
revoke execute on function private.trade_share_subscribe_block(uuid, uuid) from public;
revoke execute on function private.trade_share_subscription_view(uuid, uuid) from public;
revoke execute on function private.trade_share_profile_view(uuid, uuid) from public;
revoke execute on function private.trade_share_end_subscription(uuid, uuid, text) from public;
revoke execute on function private.trade_share_expire_requests() from public;
revoke execute on function private.trade_share_unfollow() from public;
revoke execute on function private.trade_share_block() from public;
revoke execute on function private.trade_share_trader_stopped() from public;
revoke execute on function private.trade_subscriptions_forget() from public;

revoke execute on function public.get_trade_share_profile(uuid) from public, anon;
grant execute on function public.get_trade_share_profile(uuid) to authenticated;
revoke execute on function public.request_trade_subscription(uuid, uuid) from public, anon;
grant execute on function public.request_trade_subscription(uuid, uuid) to authenticated;
revoke execute on function public.cancel_trade_subscription(uuid) from public, anon;
grant execute on function public.cancel_trade_subscription(uuid) to authenticated;
revoke execute on function public.mute_trade_subscription(uuid, boolean) from public, anon;
grant execute on function public.mute_trade_subscription(uuid, boolean) to authenticated;
revoke execute on function public.my_trade_subscriptions(text, integer) from public, anon;
grant execute on function public.my_trade_subscriptions(text, integer) to authenticated;
revoke execute on function public.my_trade_subscribers(text, text, integer) from public, anon;
grant execute on function public.my_trade_subscribers(text, text, integer) to authenticated;
revoke execute on function public.decide_trade_subscription(uuid, boolean) from public, anon;
grant execute on function public.decide_trade_subscription(uuid, boolean) to authenticated;
revoke execute on function public.remove_trade_subscriber(uuid) from public, anon;
grant execute on function public.remove_trade_subscriber(uuid) to authenticated;
revoke execute on function cs_api.trade_share_subscribers(uuid, text, timestamptz, integer) from public;
grant execute on function cs_api.trade_share_subscribers(uuid, text, timestamptz, integer) to authenticated;
