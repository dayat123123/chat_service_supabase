create or replace function private.integration_target(p_target jsonb)
returns jsonb
language plpgsql
stable
security definer
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
  if v_keys = array['olt_user_id'] then
    if jsonb_typeof(p_target -> 'olt_user_id') not in ('string', 'number')
       or btrim(p_target ->> 'olt_user_id') !~ '^[A-Za-z0-9._-]{1,64}$' then
      return null;
    end if;
    return jsonb_build_object('olt_user_id', btrim(p_target ->> 'olt_user_id'));
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
    v_stock := private.stock_code(p_target ->> 'stock');
    return case when v_stock is not null
                then jsonb_build_object('audience', 'stock_watchers', 'stock', v_stock) end;
  end if;
  return null;
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
  v_user     text;
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
      if not (v_target ? 'cust_id' or v_target ? 'olt_user_id') and not 'notify_broadcast' = any (k.scopes) then
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
    v_user := v_target ->> 'olt_user_id';
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

    if v_cust is null and v_user is null then
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
      where v_cust is not null and l.cust_id = v_cust and l.seen_at > now() - make_interval(days => v_days)
      union
      select p.id
      from public.profiles p
      where v_user is not null and p.olt_user_id = v_user and p.deleted_at is null
      order by 1
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
