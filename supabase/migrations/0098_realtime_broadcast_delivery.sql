create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  if auth.uid() is null or p_topic is null then
    return false;
  end if;
  if p_topic like 'cs:%' then
    return cs.can_access_topic(p_topic);
  end if;
  if p_topic ~* '^user:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return substring(p_topic from 6)::uuid = auth.uid();
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_room := substring(p_topic from 6)::uuid;
    if not exists (select 1 from public.chat_members where room_id = v_room and user_id = auth.uid()) then
      return false;
    end if;
    return not private.is_banned(auth.uid())
        or exists (select 1 from public.chat_rooms where id = v_room and type = 'support');
  end if;
  return p_topic = 'online' and not private.is_banned(auth.uid());
end;
$$;

drop policy if exists olt_realtime_send on realtime.messages;
create policy olt_realtime_send on realtime.messages
  for insert to authenticated
  with check (
    extension = 'presence'
    and (select realtime.topic()) not like 'cs:%'
    and (select realtime.topic()) not like 'user:%'
    and private.can_access_topic((select realtime.topic()))
  );

create or replace function private.message_event(p_message public.messages)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', p_message.id,
    'room_id', p_message.room_id,
    'sender_id', p_message.sender_id,
    'sender_username', s.username::text,
    'sender_display_name', s.display_name,
    'sender_avatar_url', s.avatar_url,
    'body', case when p_message.deleted_at is null then p_message.body end,
    'is_deleted', p_message.deleted_at is not null,
    'reply_to_id', p_message.reply_to_id,
    'reply_to_body', case when rt.deleted_at is null and rt.moderation_status = 'visible'
                          then private.snippet(rt.body, 200) end,
    'reply_to_sender_username', rs.username::text,
    'attachments', case when p_message.deleted_at is null then p_message.attachments else '[]'::jsonb end,
    'client_id', p_message.client_id,
    'edited_at', p_message.edited_at,
    'created_at', p_message.created_at,
    'cursor', private.make_cursor(p_message.created_at, p_message.id),
    'kind', p_message.kind,
    'payload', case when p_message.deleted_at is null then p_message.payload else '{}'::jsonb end,
    'session_id', p_message.session_id,
    'sender_role', p_message.sender_role))
  from (select 1) x
  left join public.profiles s on s.id = p_message.sender_id and p_message.session_id is null
  left join public.messages rt on rt.id = p_message.reply_to_id
  left join public.profiles rs on rs.id = rt.sender_id;
$$;

create or replace function private.message_block_scoped(p_room uuid, p_sender uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_sender is not null and exists (
    select 1
    from public.blocks b
    join public.chat_members m
      on m.room_id = p_room
     and m.user_id = case when b.blocker_id = p_sender then b.blocked_id else b.blocker_id end
    where b.blocker_id = p_sender or b.blocked_id = p_sender);
$$;

create or replace function private.broadcast_room_activity(p_message public.messages)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type     text;
  v_customer uuid;
  v_activity jsonb;
begin
  select r.type, r.customer_id into v_type, v_customer from public.chat_rooms r where r.id = p_message.room_id;
  if v_type is null or v_type not in ('direct', 'group', 'support') then
    return;
  end if;
  v_activity := jsonb_build_object(
    'room_id', p_message.room_id,
    'room_type', v_type,
    'message_id', p_message.id,
    'sender_id', p_message.sender_id,
    'created_at', p_message.created_at,
    'preview', case when p_message.body = '' then '[lampiran]' else private.snippet(p_message.body, 120) end);
  insert into realtime.messages (id, payload, event, topic, private, extension)
  select u.id, v_activity || jsonb_build_object('id', u.id), 'room_activity', 'user:' || u.user_id::text, true, 'broadcast'
  from (
    select gen_random_uuid() as id, m.user_id
    from public.chat_members m
    where v_type <> 'support'
      and m.room_id = p_message.room_id
      and (p_message.sender_id is null
           or m.user_id = p_message.sender_id
           or not exists (select 1 from public.blocks b
                          where (b.blocker_id = m.user_id and b.blocked_id = p_message.sender_id)
                             or (b.blocker_id = p_message.sender_id and b.blocked_id = m.user_id)))
    union all
    select gen_random_uuid(), v_customer
    where v_type = 'support' and v_customer is not null
  ) u;
exception when others then
  raise warning 'room_activity broadcast failed: %', sqlerrm;
end;
$$;

create or replace function private.broadcast_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_topic text := 'room:' || new.room_id::text;
  v_event jsonb;
begin
  if tg_op = 'UPDATE' then
    if old.moderation_status = 'visible' and new.moderation_status <> 'visible' then
      perform realtime.send(
        jsonb_build_object('room_id', new.room_id, 'message_id', new.id, 'user_id', new.sender_id),
        'message_hidden', v_topic, true);
      return null;
    end if;
    if new.moderation_status <> 'visible'
       or (old.moderation_status = 'visible'
           and (new.body, new.attachments, new.payload, new.edited_at, new.deleted_at)
               is not distinct from (old.body, old.attachments, old.payload, old.edited_at, old.deleted_at)) then
      return null;
    end if;
  elsif new.moderation_status <> 'visible' then
    return null;
  end if;

  if private.message_block_scoped(new.room_id, new.sender_id) then
    v_event := jsonb_build_object('id', new.id, 'room_id', new.room_id, 'created_at', new.created_at,
                                  'cursor', private.make_cursor(new.created_at, new.id), 'ref', true);
  else
    v_event := private.message_event(new);
  end if;
  perform realtime.send(v_event, 'message', v_topic, true);

  if new.session_id is not null then
    perform realtime.send(
      jsonb_build_object('id', new.id, 'room_id', new.room_id, 'ticket_id', new.session_id, 'client_id', new.client_id),
      'message', 'cs:room:' || new.room_id::text, true);
  end if;

  if tg_op = 'INSERT' then
    perform private.broadcast_room_activity(new);
  end if;
  return null;
end;
$$;

drop trigger if exists messages_60_broadcast on public.messages;
create trigger messages_60_broadcast
  after insert or update on public.messages
  for each row execute function private.broadcast_message();

create unlogged table if not exists private.typing_throttle (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  room_id uuid not null,
  typing  boolean not null,
  sent_at timestamptz not null
);
alter table private.typing_throttle enable row level security;
revoke all on private.typing_throttle from public, anon, authenticated;

create or replace function private.room_typing(p_room_id uuid, p_typing boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_typing boolean := coalesce(p_typing, false);
  v_type   text;
  v_prev   private.typing_throttle;
  v_name   text;
  v_shown  text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select r.type into v_type
  from public.chat_rooms r
  where r.id = p_room_id
    and exists (select 1 from public.chat_members m where m.room_id = r.id and m.user_id = v_uid);
  if v_type is null then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;

  select * into v_prev from private.typing_throttle where user_id = v_uid;
  if v_prev.room_id = p_room_id
     and ((v_prev.typing = v_typing and v_prev.sent_at > now() - interval '3 seconds')
          or (v_typing and v_prev.sent_at > now() - interval '1 second')) then
    return false;
  end if;
  insert into private.typing_throttle (user_id, room_id, typing, sent_at)
  values (v_uid, p_room_id, v_typing, now())
  on conflict (user_id) do update
    set room_id = excluded.room_id, typing = excluded.typing, sent_at = excluded.sent_at;

  select p.username::text, coalesce(case when v_type = 'support' then a.display_name end, p.display_name)
    into v_name, v_shown
  from public.profiles p
  left join cs.agents a on a.user_id = p.id
  where p.id = v_uid;

  perform realtime.send(
    jsonb_build_object('user_id', v_uid, 'username', v_name, 'display_name', v_shown, 'typing', v_typing),
    'typing', 'room:' || p_room_id::text, true);
  return true;
end;
$$;

create or replace function public.send_typing(p_room_id uuid, p_typing boolean default true)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.room_typing(p_room_id, p_typing);
end;
$$;

create or replace function cs_api.agent_typing(p_room_id uuid, p_typing boolean default true)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform cs.require_agent();
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
  end if;
  return private.room_typing(p_room_id, p_typing);
end;
$$;

revoke execute on function private.message_event(public.messages) from public;
revoke execute on function private.message_block_scoped(uuid, uuid) from public;
revoke execute on function private.broadcast_room_activity(public.messages) from public;
revoke execute on function private.broadcast_message() from public;
revoke execute on function private.room_typing(uuid, boolean) from public;
revoke execute on function public.send_typing(uuid, boolean) from public, anon;
grant execute on function public.send_typing(uuid, boolean) to authenticated;
revoke execute on function cs_api.agent_typing(uuid, boolean) from public, anon;
grant execute on function cs_api.agent_typing(uuid, boolean) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication_tables
             where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime drop table public.messages;
  end if;
end;
$$;
