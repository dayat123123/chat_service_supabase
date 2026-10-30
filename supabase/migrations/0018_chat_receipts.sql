alter table public.chat_members add column if not exists last_delivered_at timestamptz;
update public.chat_members set last_delivered_at = last_read_at where last_delivered_at is null;
alter table public.chat_members alter column last_delivered_at set default now();
alter table public.chat_members alter column last_delivered_at set not null;

revoke update (last_read_at) on public.chat_members from authenticated;

create or replace function private.broadcast_receipt(
  p_room_id      uuid,
  p_user_id      uuid,
  p_delivered_at timestamptz,
  p_read_at      timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'user_id', p_user_id,
      'last_delivered_at', p_delivered_at,
      'last_read_at', p_read_at
    ),
    'receipt',
    'room:' || p_room_id::text,
    true
  );
end;
$$;

create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room    public.chat_rooms;
  v_member  record;
  v_preview text;
begin
  v_preview := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;

  update public.chat_rooms
     set last_message_at = new.created_at,
         last_message_preview = v_preview,
         last_message_sender_id = new.sender_id
   where id = new.room_id
   returning * into v_room;

  update public.chat_members
     set last_read_at = greatest(last_read_at, new.created_at),
         last_delivered_at = greatest(last_delivered_at, new.created_at)
   where room_id = new.room_id and user_id = new.sender_id;

  if v_room.type in ('direct', 'group') then
    for v_member in
      select user_id from public.chat_members
      where room_id = new.room_id and user_id is distinct from new.sender_id and not muted
    loop
      perform private.notify(
        v_member.user_id, new.sender_id, 'message',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', v_room.type,
          'room_name', v_room.name,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'message:room:' || new.room_id
      );
    end loop;
  end if;
  return null;
end;
$$;

create or replace function public.mark_room_read(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user      uuid := auth.uid();
  v_type      text;
  v_last      timestamptz;
  v_prev_read timestamptz;
  v_read      timestamptz;
  v_delivered timestamptz;
begin
  if v_user is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  select c.type, c.last_message_at, m.last_read_at
    into v_type, v_last, v_prev_read
    from public.chat_members m
    join public.chat_rooms c on c.id = m.room_id
   where m.room_id = p_room_id and m.user_id = v_user;
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;

  update public.chat_members
     set last_read_at = now(),
         last_delivered_at = greatest(last_delivered_at, now())
   where room_id = p_room_id and user_id = v_user
  returning last_read_at, last_delivered_at into v_read, v_delivered;

  update public.notifications
     set read_at = now()
   where user_id = v_user
     and read_at is null
     and type = 'message'
     and payload ->> 'room_id' = p_room_id::text;

  if v_type <> 'stock' and v_last is not null and v_prev_read < v_last then
    perform private.broadcast_receipt(p_room_id, v_user, v_delivered, v_read);
  end if;
end;
$$;

create or replace function public.mark_rooms_delivered(p_room_ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user  uuid := auth.uid();
  v_count integer := 0;
  r       record;
begin
  if v_user is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  for r in
    update public.chat_members m
       set last_delivered_at = now()
      from public.chat_rooms c
     where c.id = m.room_id
       and m.user_id = v_user
       and c.type <> 'stock'
       and c.last_message_at is not null
       and m.last_delivered_at < c.last_message_at
       and (p_room_ids is null or m.room_id = any (p_room_ids))
    returning m.room_id, m.last_delivered_at, m.last_read_at
  loop
    perform private.broadcast_receipt(r.room_id, v_user, r.last_delivered_at, r.last_read_at);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

drop function if exists public.get_my_rooms();
create function public.get_my_rooms()
returns table (
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
  other_is_verified      boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type, r.name, r.stock_code, r.created_by,
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
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified
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
  where m.user_id = auth.uid()
  order by coalesce(r.last_message_at, r.created_at) desc;
$$;

drop function if exists public.get_room_members(uuid);
create function public.get_room_members(p_room_id uuid)
returns table (
  user_id           uuid,
  username          text,
  display_name      text,
  avatar_url        text,
  is_verified       boolean,
  role              text,
  last_read_at      timestamptz,
  last_delivered_at timestamptz,
  joined_at         timestamptz
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.user_id, p.username::text, p.display_name, p.avatar_url, p.is_verified,
         m.role, m.last_read_at, m.last_delivered_at, m.joined_at
  from public.chat_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = p_room_id
  order by m.joined_at
  limit 500;
$$;

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.mark_room_read(uuid) to authenticated;
grant execute on function public.mark_rooms_delivered(uuid[]) to authenticated;
grant execute on function public.get_my_rooms() to authenticated;
grant execute on function public.get_room_members(uuid) to authenticated;
