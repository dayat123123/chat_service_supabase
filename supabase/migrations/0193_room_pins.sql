alter table public.chat_members add column pinned_at timestamptz;

create index chat_members_pinned_idx on public.chat_members (user_id, pinned_at desc) where pinned_at is not null;

alter type public.chat_room_summary add attribute pinned_at timestamptz;

insert into private.settings (key, value, description) values
  ('rooms.pin_limit', '3', 'Jumlah chat maksimal yang bisa disematkan per pengguna, di luar chat CS')
on conflict (key) do nothing;

create or replace function private.room_list_cursor(p_type text, p_pinned_at timestamptz, p_last_message_at timestamptz,
                                                    p_created_at timestamptz, p_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select case
           when p_type = 'support' then '1|' || private.make_cursor(coalesce(p_last_message_at, p_created_at), p_id)
           when p_pinned_at is not null then '1|' || private.make_cursor('epoch'::timestamptz, '00000000-0000-0000-0000-000000000000')
           else '0|' || private.make_cursor(coalesce(p_last_message_at, p_created_at), p_id)
         end;
$$;

create or replace function public.set_room_pinned(p_room_id uuid, p_pinned boolean)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_type   text;
  v_old    timestamptz;
  v_new    timestamptz;
  v_limit  integer := greatest(private.setting_num('rooms.pin_limit', 3)::integer, 0);
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_pinned is null then
    perform private.api_error(400, 'invalid_pinned', 'p_pinned wajib true atau false');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('room_pin:' || v_uid::text, 0));

  select r.type, m.pinned_at into v_type, v_old
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  where m.room_id = p_room_id and m.user_id = v_uid
    and private.room_listed(m.hidden_at, r.last_message_at)
    and (r.type <> 'direct' or not private.dm_request_hidden(r.id, v_uid))
  for update of m;
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_type = 'support' then
    perform private.api_error(400, 'cannot_pin', 'Chat CS selalu berada di atas');
  end if;

  if p_pinned then
    if v_old is not null then
      return v_old;
    end if;
    if (select count(*) from public.chat_members m
        join public.chat_rooms r on r.id = m.room_id
        where m.user_id = v_uid and m.pinned_at is not null and r.type <> 'support') >= v_limit then
      perform private.api_error(409, 'pin_limit', format('Maksimal %s chat bisa disematkan', v_limit));
    end if;
    v_new := clock_timestamp();
  else
    if v_old is null then
      return null;
    end if;
    v_new := null;
  end if;

  update public.chat_members set pinned_at = v_new where room_id = p_room_id and user_id = v_uid;

  perform realtime.send(jsonb_build_object('room_id', p_room_id, 'pinned_at', v_new),
                        'room_pinned', 'user:' || v_uid::text, true);
  return v_new;
end;
$$;

create or replace function public.hide_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_type text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select r.type into v_type
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  where m.room_id = p_room_id and m.user_id = v_uid;
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_type = 'support' then
    perform private.api_error(400, 'cannot_hide_support', 'Chat CS tidak bisa dihapus');
  end if;

  update public.chat_members
     set hidden_at = now(), cleared_at = now(), pinned_at = null
   where room_id = p_room_id and user_id = v_uid;

  update public.notifications
     set read_at = now()
   where user_id = v_uid
     and read_at is null
     and type in ('message', 'mention')
     and payload ->> 'room_id' = p_room_id::text;

  perform realtime.send(jsonb_build_object('room_id', p_room_id, 'reason', 'hidden'),
                        'room_removed', 'user:' || v_uid::text, true);
end;
$$;

create or replace function private.chat_room_summaries(p_room_ids uuid[])
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type,
         case when r.type = 'support' then coalesce(cs.support_name(), 'CS') else r.name end,
         r.stock_code, r.created_by,
         case when v.shown then r.last_message_at end,
         case when v.shown then r.last_message_preview end,
         case when v.shown then r.last_message_sender_id end,
         case
           when not v.shown or r.last_message_at is null or r.last_message_sender_id is distinct from m.user_id then null
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
              and msg.created_at > coalesce(m.cleared_at, '-infinity')
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         rc.members,
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified,
         private.room_list_cursor(r.type, m.pinned_at, r.last_message_at, r.created_at, r.id),
         r.description, r.avatar_url,
         case when r.type = 'group' then r.only_admins_send end,
         case when r.type = 'group' then r.only_admins_edit end,
         case when r.type <> 'support' then m.pinned_at end
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  cross join lateral (
    select m.cleared_at is null or coalesce(r.last_message_at > m.cleared_at, false) as shown
  ) v
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
  order by (r.type = 'support') desc,
           case when r.type <> 'support' then m.pinned_at end desc nulls last,
           coalesce(r.last_message_at, r.created_at) desc, r.id desc;
$$;

create or replace function public.get_my_rooms(p_cursor text default null, p_limit integer default 30)
returns setof public.chat_room_summary
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit   integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_support boolean;
  v_ts      timestamptz;
  v_id      uuid;
  v_pinned  uuid[];
  v_ids     uuid[];
begin
  if coalesce(p_cursor, '') <> '' then
    begin
      v_support := case split_part(p_cursor, '|', 1) when '1' then true when '0' then false end;
      v_ts := split_part(p_cursor, '|', 2)::timestamptz;
      v_id := split_part(p_cursor, '|', 3)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_support is null or v_ts is null or v_id is null then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  else
    select array_agg(r.id) into v_pinned
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.user_id = auth.uid()
      and m.pinned_at is not null
      and r.type <> 'support'
      and (r.type <> 'direct' or not private.dm_request_hidden(r.id, m.user_id))
      and private.room_listed(m.hidden_at, r.last_message_at);
  end if;

  select array_agg(x.id) into v_ids
  from (
    select r.id
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.user_id = auth.uid()
      and (r.type = 'support' or m.pinned_at is null)
      and (v_ts is null
           or (r.type = 'support', coalesce(r.last_message_at, r.created_at), r.id) < (v_support, v_ts, v_id))
      and (r.type <> 'direct' or not private.dm_request_hidden(r.id, m.user_id))
      and private.room_listed(m.hidden_at, r.last_message_at)
    order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc
    limit v_limit
  ) x;

  return query select * from private.chat_room_summaries(coalesce(v_pinned, '{}') || coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.get_room_previews(p_room_ids uuid[])
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
  if coalesce(cardinality(p_room_ids), 0) > 50 then
    perform private.api_error(400, 'too_many_rooms', 'Maksimal 50 room sekaligus');
  end if;

  return jsonb_build_object(
    'poll_seconds', private.setting_num('rooms.preview_poll_seconds', 15),
    'rooms', coalesce((
      select jsonb_agg(jsonb_build_object(
               'room_id', r.id,
               'last_message_at', case when v.shown then r.last_message_at end,
               'last_message_preview', case when v.shown then r.last_message_preview end,
               'last_message_sender_id', case when v.shown then r.last_message_sender_id end,
               'unread_count', (select count(*)::integer from (
                                  select 1 from public.messages msg
                                  where msg.room_id = r.id
                                    and msg.created_at > m.last_read_at
                                    and msg.created_at > coalesce(m.cleared_at, '-infinity')
                                    and msg.sender_id is distinct from m.user_id
                                    and msg.deleted_at is null
                                  limit 100) s),
               'cursor', private.room_list_cursor(r.type, m.pinned_at, r.last_message_at, r.created_at, r.id),
               'pinned_at', m.pinned_at)
             order by r.id)
      from public.chat_members m
      join public.chat_rooms r on r.id = m.room_id
      cross join lateral (
        select m.cleared_at is null or coalesce(r.last_message_at > m.cleared_at, false) as shown
      ) v
      where m.user_id = v_uid
        and m.room_id = any(coalesce(p_room_ids, '{}'))
        and r.type = 'stock'), '[]'::jsonb));
end;
$$;

revoke execute on function private.room_list_cursor(text, timestamptz, timestamptz, timestamptz, uuid) from public;
grant execute on function private.room_list_cursor(text, timestamptz, timestamptz, timestamptz, uuid) to authenticated, service_role;
revoke execute on function public.set_room_pinned(uuid, boolean) from public, anon;
grant execute on function public.set_room_pinned(uuid, boolean) to authenticated;
