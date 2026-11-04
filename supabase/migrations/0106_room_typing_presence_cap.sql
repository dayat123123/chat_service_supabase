insert into private.settings (key, value, description) values
  ('rooms.typing_aggregate_members', '50',
   'Room non-CS dengan anggota sebanyak ini atau lebih menyiarkan ringkasan typing (typing_summary), bukan typing per orang'),
  ('rooms.typing_summary_seconds', '3',
   'Jarak minimal antar ringkasan typing per room (detik)'),
  ('rooms.typing_off_members', '2000',
   'Room non-CS dengan anggota sebanyak ini atau lebih tidak menyiarkan typing sama sekali'),
  ('rooms.presence_max_members', '50',
   'Presence ditolak di DM dan grup dengan anggota sebanyak ini atau lebih'),
  ('rooms.presence_stock_members', '0',
   'Presence ditolak di room saham dengan anggota sebanyak ini atau lebih (0 = selalu ditolak)')
on conflict (key) do nothing;

create index if not exists typing_throttle_room_idx on private.typing_throttle (room_id, sent_at);

create unlogged table if not exists private.typing_rooms (
  room_id uuid primary key references public.chat_rooms (id) on delete cascade,
  sent_at timestamptz not null
);
alter table private.typing_rooms enable row level security;
revoke all on private.typing_rooms from public, anon, authenticated;

create or replace function private.room_has_members(p_room uuid, p_count integer)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_count, 0) <= 0
      or (select count(*) from (select 1 from public.chat_members m where m.room_id = p_room limit p_count) s) >= p_count;
$$;

create or replace function private.room_typing_summary(p_room_id uuid, p_uid uuid, p_typing boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_interval interval := make_interval(secs => greatest(private.setting_num('rooms.typing_summary_seconds', 3), 1));
  v_prev     private.typing_throttle;
  v_count    integer;
begin
  if not p_typing or private.is_banned(p_uid) or private.room_mute_until(p_room_id, p_uid) is not null then
    return false;
  end if;

  select * into v_prev from private.typing_throttle where user_id = p_uid;
  if not coalesce(v_prev.room_id = p_room_id and v_prev.typing and v_prev.sent_at > now() - interval '1 second', false) then
    insert into private.typing_throttle (user_id, room_id, typing, sent_at)
    values (p_uid, p_room_id, true, now())
    on conflict (user_id) do update
      set room_id = excluded.room_id, typing = excluded.typing, sent_at = excluded.sent_at;
  end if;

  insert into private.typing_rooms (room_id, sent_at) values (p_room_id, '-infinity')
  on conflict (room_id) do nothing;
  perform 1 from private.typing_rooms t
  where t.room_id = p_room_id and t.sent_at <= now() - v_interval
  for update skip locked;
  if not found then
    return false;
  end if;
  update private.typing_rooms set sent_at = now() where room_id = p_room_id;

  if private.room_has_members(p_room_id, private.setting_num('rooms.typing_off_members', 2000)::integer) then
    return false;
  end if;

  select count(*)::integer into v_count
  from private.typing_throttle t
  where t.room_id = p_room_id and t.typing and t.sent_at > now() - 2 * v_interval;

  perform realtime.send(
    jsonb_build_object(
      'room_id', p_room_id,
      'count', least(greatest(v_count, 1), 99),
      'ttl_ms', (extract(epoch from 2 * v_interval) * 1000)::integer),
    'typing_summary', 'room:' || p_room_id::text, true);
  return true;
end;
$$;

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

  if v_type <> 'support'
     and private.room_has_members(p_room_id, private.setting_num('rooms.typing_aggregate_members', 50)::integer) then
    return private.room_typing_summary(p_room_id, v_uid, v_typing);
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

create or replace function private.can_track_presence(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room uuid;
  v_type text;
begin
  if p_topic is null or p_topic !~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return true;
  end if;
  v_room := substring(p_topic from 6)::uuid;
  select r.type into v_type from public.chat_rooms r where r.id = v_room;
  if v_type is null or v_type = 'support' then
    return true;
  end if;
  if v_type = 'stock' then
    return not private.room_has_members(v_room, private.setting_num('rooms.presence_stock_members', 0)::integer);
  end if;
  return not private.room_has_members(v_room, private.setting_num('rooms.presence_max_members', 50)::integer);
end;
$$;

drop policy if exists olt_realtime_send on realtime.messages;
create policy olt_realtime_send on realtime.messages
  for insert to authenticated
  with check (
    extension = 'presence'
    and (select realtime.topic()) not like 'cs:%'
    and (select realtime.topic()) not like 'user:%'
    and not (select private.staff_on_public_edge())
    and private.can_access_topic((select realtime.topic()))
    and private.can_track_presence((select realtime.topic()))
  );

revoke execute on function private.room_has_members(uuid, integer) from public;
revoke execute on function private.room_typing_summary(uuid, uuid, boolean) from public;
revoke execute on function private.room_typing(uuid, boolean) from public;
revoke all on function private.can_track_presence(text) from public;
grant execute on function private.can_track_presence(text) to authenticated;
