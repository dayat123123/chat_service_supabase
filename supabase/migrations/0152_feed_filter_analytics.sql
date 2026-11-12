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
                                   and private.stock_code_format(upper(e.value #>> '{}'))
    when e.key in ('post_id', 'room_id', 'target_id', 'notification_id') then
      jsonb_typeof(e.value) = 'string'
      and (e.value #>> '{}') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    when e.key = 'hashtag' then jsonb_typeof(e.value) = 'string' and (e.value #>> '{}') ~ '^[a-z0-9_]{2,50}$'
    when e.key = 'filter' then jsonb_typeof(e.value) = 'string' and (e.value #>> '{}') ~ '^[a-z][a-z0-9_]{1,31}$'
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
