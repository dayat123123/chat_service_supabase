create or replace function private.staff_on_public_edge()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-olt-edge' = 'public', false)
     and cs.is_staff((select auth.uid()));
$$;

revoke all on function private.staff_on_public_edge() from public;
grant execute on function private.staff_on_public_edge() to authenticated;

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
  return false;
end;
$$;

drop policy if exists olt_realtime_receive on realtime.messages;
create policy olt_realtime_receive on realtime.messages
  for select to authenticated
  using (
    not (select private.staff_on_public_edge())
    and private.can_access_topic((select realtime.topic()))
  );

drop policy if exists olt_realtime_send on realtime.messages;
create policy olt_realtime_send on realtime.messages
  for insert to authenticated
  with check (
    extension = 'presence'
    and (select realtime.topic()) not like 'cs:%'
    and (select realtime.topic()) not like 'user:%'
    and not (select private.staff_on_public_edge())
    and private.can_access_topic((select realtime.topic()))
  );

drop policy if exists cs_staff_public_edge on storage.objects;
create policy cs_staff_public_edge on storage.objects
  as restrictive
  for all
  to authenticated
  using (not (select private.staff_on_public_edge()))
  with check (not (select private.staff_on_public_edge()));

create or replace function private.reject_staff_postgres_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.claims ->> 'sub' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and cs.is_staff((new.claims ->> 'sub')::uuid) then
    raise exception 'Akun CS tidak bisa berlangganan postgres_changes' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.reject_staff_postgres_changes() from public;

drop trigger if exists cs_staff_postgres_changes on realtime.subscription;
create trigger cs_staff_postgres_changes
  before insert on realtime.subscription
  for each row execute function private.reject_staff_postgres_changes();
