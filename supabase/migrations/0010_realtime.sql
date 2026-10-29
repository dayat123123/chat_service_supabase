-- 0010_realtime.sql
-- 1. Publikasi postgres_changes untuk tabel yang dipantau client.
--    Realtime tetap mengecek RLS per subscriber.
-- 2. Otorisasi channel private (broadcast & presence):
--      online       -> presence status online, semua user login
--      room:<uuid>  -> typing indicator & read receipt, hanya anggota room

do $$
declare
  v_table text;
begin
  foreach v_table in array array['messages', 'posts', 'comments', 'reactions', 'notifications'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = v_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    end if;
  end loop;
end;
$$;

create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_topic is null then
    return false;
  end if;
  if p_topic = 'online' then
    return true;
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return exists (
      select 1 from public.chat_members
      where room_id = substring(p_topic from 6)::uuid and user_id = auth.uid()
    );
  end if;
  return false;
end;
$$;

revoke all on function private.can_access_topic(text) from public;
grant execute on function private.can_access_topic(text) to authenticated;

drop policy if exists olt_realtime_receive on realtime.messages;
create policy olt_realtime_receive on realtime.messages
  for select to authenticated
  using (private.can_access_topic((select realtime.topic())));

drop policy if exists olt_realtime_send on realtime.messages;
create policy olt_realtime_send on realtime.messages
  for insert to authenticated
  with check (private.can_access_topic((select realtime.topic())));
