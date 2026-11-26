insert into private.rate_limits (action, max_count, window_seconds) values ('post_share', 60, 3600)
on conflict (action, window_seconds) do nothing;

create or replace function private.share_max_targets()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 10;
$$;

create or replace function public.get_share_limits()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'max_targets', private.share_max_targets(),
    'per_hour', coalesce((select l.max_count from private.rate_limits l where l.action = 'post_share' and l.window_seconds = 3600), 60));
$$;

create or replace function private.consume_share_rate()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.consume_rate_limit(auth.uid(), 'post_share');
end;
$$;

create or replace function private.shared_message(p_client_id uuid)
returns table (message_id uuid, room_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.room_id from public.messages m where m.sender_id = auth.uid() and m.client_id = p_client_id;
$$;

create or replace function private.share_room_kind(p_room uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.type from public.chat_rooms r
  where r.id = p_room
    and exists (select 1 from public.chat_members m where m.room_id = r.id and m.user_id = auth.uid());
$$;

create or replace function private.check_duplicate_content(
  p_table regclass, p_user_column text, p_user uuid, p_text text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_norm  text := lower(regexp_replace(btrim(coalesce(p_text, '')), '\s+', ' ', 'g'));
  v_count integer;
begin
  if char_length(v_norm) < private.setting_num('content.duplicate_min_length', 10)
     or coalesce(current_setting('olt.share_batch', true), '') = 'on' then
    return;
  end if;
  execute format(
    'select count(*) from %s where %I = $1 and deleted_at is null'
    ' and created_at > now() - make_interval(secs => $2)'
    ' and lower(regexp_replace(btrim(body), ''\s+'', '' '', ''g'')) = $3',
    p_table, p_user_column)
  into v_count
  using p_user, private.setting_num('content.duplicate_window_seconds', 300)::double precision, v_norm;

  if v_count >= private.setting_num('content.duplicate_max', 3) - 1 then
    perform private.api_error(422, 'duplicate_content',
      'Konten yang sama sudah dikirim berulang kali. Coba lagi beberapa menit lagi.');
  end if;
end;
$$;

create or replace function public.search_share_targets(p_query text, p_limit integer default 20)
returns table (kind text, room_id uuid, user_id uuid, username text, display_name text, avatar_url text,
               is_verified boolean, is_official boolean, group_name text, stock_code text, can_send boolean,
               reason text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := auth.uid();
  v_raw   text := btrim(coalesce(p_query, ''));
  v_term  text := replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_');
  v_code  text := case when btrim(coalesce(p_query, '')) ~ '^\$?[A-Za-z]{4}$' then private.stock_code(p_query) end;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_exempt boolean;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_raw = '' then
    return;
  end if;
  v_exempt := private.official_dm_exempt(v_me);

  return query
  with stocks as (
    select s.code, s.rank
    from (
      select v_code as code, 0 as rank where v_code is not null and private.stock_code_format(v_code)
      union all
      select i.code, 1 from private.market_instruments i
      where i.enabled and (i.code ilike v_term || '%' or i.name ilike '%' || v_term || '%')
      union all
      select r.stock_code, 2 from public.chat_rooms r
      where r.type = 'stock' and r.stock_code ilike v_term || '%'
    ) s
  ), stock_rows as (
    select distinct on (s.code) s.code, s.rank from stocks s order by s.code, s.rank
  ), users as (
    select p.id, p.username::text as uname, p.display_name, p.avatar_url, p.is_verified,
           private.is_official_account(p.id) as official, p.follower_count,
           (select r.id from public.chat_rooms r
            where r.direct_key = least(v_me::text, p.id::text) || ':' || greatest(v_me::text, p.id::text)
              and exists (select 1 from public.chat_members m where m.room_id = r.id and m.user_id = v_me)) as dm
    from public.profiles p
    where (p.username::text ilike v_term || '%' or p.display_name ilike '%' || v_term || '%')
      and p.id <> v_me
      and p.deleted_at is null
      and not p.is_guest
      and not cs.is_staff(p.id)
      and p.id not in (select private.blocked_user_ids())
    order by (lower(p.username::text) = lower(v_raw)) desc, p.follower_count desc, p.username
    limit v_limit
  ), user_rows as (
    select u.*,
           case
             when u.dm is not null then case when private.can_send_message(u.dm) then null else 'cannot_send' end
             when private.dm_evaluate(v_me, u.id) = 'denied' then 'dm_not_allowed'
           end as block_reason,
           u.dm is null and private.dm_evaluate(v_me, u.id) = 'pending' as request
    from users u
    where not u.official or v_exempt or u.dm is not null
  ), group_rows as (
    select r.id, r.name, m.role, r.only_admins_send
    from public.chat_rooms r
    join public.chat_members m on m.room_id = r.id and m.user_id = v_me
    where r.type = 'group' and r.name ilike '%' || v_term || '%'
    order by r.last_message_at desc nulls last, r.name
    limit v_limit
  ), merged as (
    select 0 as bucket, s.rank as rank, 'stock'::text as kind,
           (select r.id from public.chat_rooms r
            where r.type = 'stock' and r.stock_code = s.code
              and exists (select 1 from public.chat_members m where m.room_id = r.id and m.user_id = v_me)) as room_id,
           null::uuid as user_id, null::text as username, null::text as display_name, null::text as avatar_url,
           null::boolean as is_verified, null::boolean as is_official, null::text as group_name, s.code as stock_code,
           private.stock_room_enabled(s.code) as can_send,
           case when not private.stock_room_enabled(s.code) then 'room_disabled' end as reason,
           s.code as sort_key
    from stock_rows s
    union all
    select 1, case when lower(u.uname) = lower(v_raw) then 0 else 1 end, 'user', u.dm, u.id, u.uname, u.display_name,
           u.avatar_url, u.is_verified, u.official, null, null,
           u.block_reason is null, coalesce(u.block_reason, case when u.request then 'message_request' end),
           lpad((1000000000 - least(u.follower_count, 999999999))::text, 10, '0') || u.uname
    from user_rows u
    union all
    select 2, 1, 'group', g.id, null, null, null, null, null, null, g.name, null,
           not (g.only_admins_send and g.role = 'member'),
           case when g.only_admins_send and g.role = 'member' then 'group_admins_only' end,
           g.name
    from group_rows g
  )
  select m.kind, m.room_id, m.user_id, m.username, m.display_name, m.avatar_url, m.is_verified, m.is_official,
         m.group_name, m.stock_code, m.can_send, m.reason
  from merged m
  order by m.rank, m.bucket, m.sort_key
  limit v_limit;
end;
$$;

create or replace function public.share_post_to_targets(p_post_id uuid, p_targets jsonb, p_body text default null)
returns table (target_index integer, kind text, target text, room_id uuid, status text, error_code text,
               message_id uuid)
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_me      uuid := auth.uid();
  v_max     integer := private.share_max_targets();
  v_attach  jsonb := jsonb_build_array(jsonb_build_object('type', 'post', 'post_id', p_post_id));
  v_seen    uuid[] := '{}';
  v_clients uuid[] := '{}';
  t         jsonb;
  v_index   bigint;
  v_kind    text;
  v_target  text;
  v_client  uuid;
  v_room    uuid;
  v_msg     uuid;
  v_type    text;
  v_state   text;
  v_code    text;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_post_id is null then
    perform private.api_error(400, 'invalid_post', 'Postingan wajib diisi');
  end if;
  if jsonb_typeof(p_targets) is distinct from 'array' or jsonb_array_length(p_targets) = 0 then
    perform private.api_error(400, 'invalid_targets', 'Pilih minimal satu tujuan');
  end if;
  if jsonb_array_length(p_targets) > v_max then
    perform private.api_error(400, 'too_many_targets', format('Maksimal %s tujuan sekali kirim', v_max));
  end if;

  for t, v_index in select e.value, e.ord - 1 from jsonb_array_elements(p_targets) with ordinality as e(value, ord) loop
    v_kind := case when jsonb_typeof(t) <> 'object' then null
                   when t ? 'room_id' and not (t ? 'user_id') and not (t ? 'stock_code') then 'room'
                   when t ? 'user_id' and not (t ? 'room_id') and not (t ? 'stock_code') then 'user'
                   when t ? 'stock_code' and not (t ? 'room_id') and not (t ? 'user_id') then 'stock' end;
    v_target := case v_kind when 'room' then t ->> 'room_id' when 'user' then t ->> 'user_id'
                            when 'stock' then upper(btrim(t ->> 'stock_code')) end;
    v_room := null;
    v_msg := null;
    begin
      v_client := (t ->> 'client_id')::uuid;
    exception when others then
      v_client := null;
    end;

    if v_kind is null or v_client is null or coalesce(v_target, '') = '' then
      target_index := v_index; kind := v_kind; target := v_target; room_id := null; status := 'failed';
      error_code := 'invalid_target'; message_id := null;
      return next;
      continue;
    end if;
    if v_client = any (v_clients) then
      target_index := v_index; kind := v_kind; target := v_target; room_id := null; status := 'failed';
      error_code := 'duplicate_target'; message_id := null;
      return next;
      continue;
    end if;
    v_clients := v_clients || v_client;

    select s.message_id, s.room_id into v_msg, v_room from private.shared_message(v_client) s;
    if v_msg is not null then
      v_seen := v_seen || v_room;
      target_index := v_index; kind := v_kind; target := v_target; room_id := v_room; status := 'sent';
      error_code := null; message_id := v_msg;
      return next;
      continue;
    end if;

    begin
      case v_kind
        when 'room' then
          v_room := v_target::uuid;
          v_type := private.share_room_kind(v_room);
          if v_type is null then
            perform private.api_error(403, 'not_member', 'Anda bukan anggota chat ini');
          elsif v_type not in ('direct', 'group', 'stock') then
            perform private.api_error(400, 'invalid_target', 'Postingan tidak bisa dibagikan ke chat ini');
          end if;
        when 'user' then
          v_room := public.get_or_create_direct_room(v_target::uuid);
        else
          v_room := public.join_stock_room(v_target);
      end case;
      if v_room = any (v_seen) then
        perform private.api_error(409, 'duplicate_target', 'Chat ini sudah dipilih');
      end if;
      perform private.consume_share_rate();
      perform set_config('olt.share_batch', 'on', true);
      select m.id into v_msg from public.send_message(v_room, coalesce(p_body, ''), v_client, null, v_attach) m;
      perform set_config('olt.share_batch', '', true);
      v_seen := v_seen || v_room;
      target_index := v_index; kind := v_kind; target := v_target; room_id := v_room; status := 'sent';
      error_code := null; message_id := v_msg;
    exception
      when invalid_text_representation then
        target_index := v_index; kind := v_kind; target := v_target; room_id := null; status := 'failed';
        error_code := 'invalid_target'; message_id := null;
      when others then
        get stacked diagnostics v_state = returned_sqlstate, v_code = message_text;
        perform set_config('olt.share_batch', '', true);
        if v_state = 'PGRST' then
          begin
            v_code := coalesce(v_code::jsonb ->> 'message', 'rate_limited');
          exception when others then
            v_code := 'rate_limited';
          end;
        elsif v_state !~ '^PT' then
          raise;
        end if;
        target_index := v_index; kind := v_kind; target := v_target; room_id := null; status := 'failed';
        error_code := v_code; message_id := null;
    end;
    return next;
  end loop;
end;
$$;

revoke execute on function private.share_max_targets() from public;
revoke execute on function private.consume_share_rate() from public;
revoke execute on function private.shared_message(uuid) from public;
revoke execute on function private.share_room_kind(uuid) from public;
revoke execute on function public.get_share_limits() from public, anon;
revoke execute on function public.search_share_targets(text, integer) from public, anon;
revoke execute on function public.share_post_to_targets(uuid, jsonb, text) from public, anon;

grant execute on function private.share_max_targets() to authenticated;
grant execute on function private.consume_share_rate() to authenticated;
grant execute on function private.shared_message(uuid) to authenticated;
grant execute on function private.share_room_kind(uuid) to authenticated;
grant execute on function public.get_share_limits() to authenticated;
grant execute on function public.search_share_targets(text, integer) to authenticated;
grant execute on function public.share_post_to_targets(uuid, jsonb, text) to authenticated;
