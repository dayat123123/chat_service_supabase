create or replace function public.get_message_ids(
  p_room_id uuid,
  p_after   text,
  p_limit   integer default 500
)
returns jsonb
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit   integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_ts      timestamptz;
  v_id      uuid;
  v_ids     uuid[];
  v_last_ts timestamptz;
  v_last_id uuid;
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_after) c;
  if v_ts is null then
    perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
  end if;

  select array_agg(x.id order by x.created_at, x.id),
         (array_agg(x.created_at order by x.created_at desc, x.id desc))[1],
         (array_agg(x.id order by x.created_at desc, x.id desc))[1]
    into v_ids, v_last_ts, v_last_id
  from (
    select m.id, m.created_at from public.messages m
    where m.room_id = p_room_id and (m.created_at, m.id) > (v_ts, v_id)
    order by m.created_at, m.id
    limit v_limit
  ) x;

  return jsonb_build_object(
    'ids', coalesce(to_jsonb(v_ids), '[]'::jsonb),
    'last', case when v_last_id is not null then private.make_cursor(v_last_ts, v_last_id) end,
    'more', coalesce(cardinality(v_ids), 0) >= v_limit
  );
end;
$$;

create or replace function public.get_messages_by_ids(
  p_room_id uuid,
  p_ids     uuid[]
)
returns setof public.chat_message
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_ids uuid[];
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if coalesce(cardinality(p_ids), 0) = 0 then
    return;
  end if;
  if cardinality(p_ids) > 100 then
    perform private.api_error(400, 'too_many_ids', 'Maksimal 100 pesan sekaligus');
  end if;

  select array_agg(m.id) into v_ids
  from public.messages m
  where m.room_id = p_room_id and m.id = any(p_ids);

  return query select * from private.chat_messages(coalesce(v_ids, '{}'));
end;
$$;

revoke execute on function public.get_message_ids(uuid, text, integer) from public, anon;
revoke execute on function public.get_messages_by_ids(uuid, uuid[]) from public, anon;
grant execute on function public.get_message_ids(uuid, text, integer) to authenticated;
grant execute on function public.get_messages_by_ids(uuid, uuid[]) to authenticated;
