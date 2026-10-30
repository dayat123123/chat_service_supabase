create or replace function cs_api.room_members(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.chat_rooms r
                 where r.id = p_room_id and r.type = 'support' and r.customer_id = auth.uid()) then
    perform cs.require_agent();
    if not cs.can_read_room(p_room_id) then
      perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
    end if;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'user_id', m.user_id, 'display_name', p.display_name, 'username', p.username, 'role', m.role,
             'is_staff', cs.is_staff(m.user_id), 'last_read_at', m.last_read_at,
             'last_delivered_at', m.last_delivered_at, 'joined_at', m.joined_at) order by m.joined_at)
    from public.chat_members m
    join public.profiles p on p.id = m.user_id
    where m.room_id = p_room_id), '[]');
end;
$$;

revoke execute on function cs_api.room_members(uuid) from public;
grant execute on function cs_api.room_members(uuid) to authenticated;
