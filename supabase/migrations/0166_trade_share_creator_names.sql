create or replace function cs_api.trade_share_excluded_accounts()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('cust_id', x.cust_id, 'reason', x.reason,
                                                       'created_by', x.created_by, 'created_by_name', cs.trade_share_agent_name(x.created_by),
                                                       'created_at', x.created_at)
                                    order by x.cust_id)
                   from private.trade_share_excluded_accounts x), '[]');
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
                                                       'created_by', x.created_by, 'created_by_name', cs.trade_share_agent_name(x.created_by),
                                                       'created_at', x.created_at)
                                    order by x.stock)
                   from private.trade_share_excluded_stocks x), '[]');
end;
$$;


create or replace function cs_api.trade_share_pilot_invites()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('profile', cs.trade_share_profile_ref(i.profile_id),
                                                       'created_by', i.created_by, 'created_by_name', cs.trade_share_agent_name(i.created_by),
                                                       'created_at', i.created_at)
                                    order by i.created_at desc)
                   from private.trade_share_pilot_invites i), '[]');
end;
$$;

