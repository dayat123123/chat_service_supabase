drop function public.get_my_rooms();

create type public.chat_room_summary as (
  id                     uuid,
  type                   text,
  name                   text,
  stock_code             text,
  created_by             uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  last_message_status    text,
  created_at             timestamptz,
  my_role                text,
  muted                  boolean,
  last_read_at           timestamptz,
  unread_count           integer,
  member_count           integer,
  other_user_id          uuid,
  other_username         text,
  other_display_name     text,
  other_avatar_url       text,
  other_is_verified      boolean,
  cursor                 text
);

create function private.chat_room_summaries(p_room_ids uuid[])
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type,
         case when r.type = 'support' then coalesce(cs.support_name(), 'CS') else r.name end,
         r.stock_code, r.created_by,
         r.last_message_at, r.last_message_preview, r.last_message_sender_id,
         case
           when r.last_message_at is null or r.last_message_sender_id is distinct from m.user_id then null
           when r.type = 'stock' or rc.others = 0 then 'sent'
           when rc.unread = 0 then 'read'
           when rc.undelivered = 0 then 'delivered'
           else 'sent'
         end,
         r.created_at,
         m.role, m.muted, m.last_read_at,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = r.id
              and msg.created_at > m.last_read_at
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         rc.members,
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified,
         case when r.type = 'support' then '1' else '0' end || '|'
           || private.make_cursor(coalesce(r.last_message_at, r.created_at), r.id)
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  cross join lateral (
    select count(*)::integer as members,
           count(*) filter (where om.user_id <> m.user_id)::integer as others,
           count(*) filter (where om.user_id <> m.user_id and om.last_read_at < r.last_message_at)::integer as unread,
           count(*) filter (where om.user_id <> m.user_id and om.last_delivered_at < r.last_message_at)::integer as undelivered
    from public.chat_members om
    where om.room_id = r.id
  ) rc
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified
    from public.chat_members om
    join public.profiles p on p.id = om.user_id
    where r.type = 'direct' and om.room_id = r.id and om.user_id <> m.user_id
    limit 1
  ) o on true
  where m.user_id = auth.uid() and m.room_id = any(p_room_ids)
  order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc;
$$;

create function public.get_my_rooms(p_cursor text default null, p_limit integer default 30)
returns setof public.chat_room_summary
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit  integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_pinned boolean;
  v_ts     timestamptz;
  v_id     uuid;
  v_ids    uuid[];
begin
  if coalesce(p_cursor, '') <> '' then
    begin
      v_pinned := case split_part(p_cursor, '|', 1) when '1' then true when '0' then false end;
      v_ts := split_part(p_cursor, '|', 2)::timestamptz;
      v_id := split_part(p_cursor, '|', 3)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_pinned is null or v_ts is null or v_id is null then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  end if;

  select array_agg(x.id) into v_ids
  from (
    select r.id
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.user_id = auth.uid()
      and (v_ts is null
           or (r.type = 'support', coalesce(r.last_message_at, r.created_at), r.id) < (v_pinned, v_ts, v_id))
    order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc
    limit v_limit
  ) x;

  return query select * from private.chat_room_summaries(coalesce(v_ids, '{}'));
end;
$$;

create function public.get_my_room(p_room_id uuid)
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select * from private.chat_room_summaries(array[p_room_id]);
$$;

revoke execute on function private.chat_room_summaries(uuid[]) from public;
grant execute on function private.chat_room_summaries(uuid[]) to authenticated;
revoke execute on function public.get_my_rooms(text, integer) from public, anon;
grant execute on function public.get_my_rooms(text, integer) to authenticated;
revoke execute on function public.get_my_room(uuid) from public, anon;
grant execute on function public.get_my_room(uuid) to authenticated;
