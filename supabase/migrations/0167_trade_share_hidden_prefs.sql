create or replace function private.notification_pref_types()
returns text[]
language sql
stable
set search_path = ''
as $$
  select array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
               'followed_post', 'watchlist_digest', 'moderation']
         || case when private.trade_share_enabled() then array['trade_activity', 'trade_share'] else array[]::text[] end
         || array['olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'];
$$;

revoke execute on function private.notification_pref_types() from public;
