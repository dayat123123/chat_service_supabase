create table private.room_preview_queue (
  id        bigint generated always as identity primary key,
  room_id   uuid not null,
  queued_at timestamptz not null default now()
);
alter table private.room_preview_queue enable row level security;
revoke all on private.room_preview_queue from public, anon, authenticated;

create or replace function private.refresh_room_preview(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg public.messages;
begin
  perform 1 from public.chat_rooms r where r.id = p_room_id for no key update skip locked;
  if not found then
    return not exists (select 1 from public.chat_rooms r where r.id = p_room_id);
  end if;

  select * into v_msg
  from public.messages m
  where m.room_id = p_room_id and m.moderation_status = 'visible' and m.deleted_at is null
  order by m.created_at desc, m.id desc
  limit 1;
  if v_msg.id is not null then
    update public.chat_rooms r
       set last_message_at = v_msg.created_at,
           last_message_preview = case when v_msg.body = '' then '[lampiran]' else private.snippet(v_msg.body, 120) end,
           last_message_sender_id = v_msg.sender_id
     where r.id = p_room_id
       and (r.last_message_at is null or r.last_message_at < v_msg.created_at);
  end if;
  return true;
end;
$$;

create or replace function private.room_preview_tick()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rooms uuid[];
  v_room  uuid;
  v_done  integer := 0;
begin
  with taken as (delete from private.room_preview_queue returning room_id)
  select coalesce(array_agg(distinct t.room_id), '{}') into v_rooms from taken t;

  foreach v_room in array v_rooms loop
    if private.refresh_room_preview(v_room) then
      v_done := v_done + 1;
    else
      insert into private.room_preview_queue (room_id) values (v_room);
    end if;
  end loop;
  return v_done;
end;
$$;

create or replace procedure private.room_preview_worker(p_seconds integer default 9)
language plpgsql
as $$
declare
  v_until timestamptz := pg_catalog.clock_timestamp() + pg_catalog.make_interval(secs => p_seconds);
begin
  loop
    perform private.room_preview_tick();
    commit;
    exit when pg_catalog.clock_timestamp() >= v_until;
    perform pg_catalog.pg_sleep(1);
  end loop;
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
  v_target  uuid;
  v_preview text;
  v_locked  boolean;
begin
  v_preview := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;

  select * into v_room from public.chat_rooms where id = new.room_id;

  if new.moderation_status = 'visible' then
    v_locked := v_room.type is distinct from 'stock';
    if not v_locked then
      perform 1 from public.chat_rooms r where r.id = new.room_id for no key update skip locked;
      v_locked := found;
    end if;
    if v_locked then
      update public.chat_rooms
         set last_message_at = new.created_at,
             last_message_preview = v_preview,
             last_message_sender_id = new.sender_id
       where id = new.room_id
         and (last_message_at is null or last_message_at <= new.created_at);
    else
      insert into private.room_preview_queue (room_id) values (new.room_id);
    end if;
  end if;

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
  elsif v_room.type = 'stock' and new.sender_id is not null and new.deleted_at is null
        and new.moderation_status = 'visible' and position('@' in new.body) > 0 then
    for v_target in
      select p.id
      from unnest((private.extract_mentions(new.body))[1:private.setting_num('notifications.mention_room_max', 5)::integer])
           with ordinality as u(username, ord)
      join public.profiles p on p.username = u.username::extensions.citext
      where p.id <> new.sender_id
        and p.deleted_at is null
        and not private.is_banned(p.id)
        and not exists (select 1 from public.mutes m where m.muter_id = p.id and m.muted_id = new.sender_id)
      order by u.ord
    loop
      perform private.notify(
        v_target, new.sender_id, 'mention',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', 'stock',
          'room_name', v_room.name,
          'stock_code', v_room.stock_code,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'mention:room:' || new.room_id
      );
    end loop;
  end if;
  return null;
end;
$$;

revoke execute on function private.refresh_room_preview(uuid) from public;
revoke execute on function private.room_preview_tick() from public;
revoke execute on procedure private.room_preview_worker(integer) from public;

select cron.schedule('chat-room-preview', '10 seconds', 'call private.room_preview_worker()');
