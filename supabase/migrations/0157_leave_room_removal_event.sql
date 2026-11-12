create or replace function public.leave_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_room   public.chat_rooms;
  v_role   text;
  v_heir   uuid;
begin
  select * into v_room from public.chat_rooms where id = p_room_id;
  v_role := private.room_role(p_room_id);
  if not found or v_role is null then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_room.type = 'direct' then
    perform private.api_error(400, 'cannot_leave_direct', 'Room DM tidak bisa ditinggalkan');
  end if;
  if v_room.type = 'support' then
    perform private.api_error(400, 'cannot_leave_support', 'Chat CS tidak bisa ditinggalkan');
  end if;

  if v_room.type = 'group' then
    if v_role = 'owner' then
      select user_id into v_heir from public.chat_members
      where room_id = p_room_id and user_id <> auth.uid()
      order by (role = 'admin') desc, joined_at
      limit 1;
    end if;
    if v_role <> 'owner' or v_heir is not null then
      perform private.post_group_event(
        p_room_id, 'left',
        private.member_name(auth.uid()) || ' keluar'
          || case when v_heir is not null
                  then '. ' || private.member_name(v_heir) || ' sekarang pemilik grup' else '' end,
        case when v_heir is null then '{}'::jsonb
             else jsonb_build_object('new_owner_id', v_heir, 'new_owner_name', private.member_name(v_heir)) end
      );
    end if;
  end if;

  delete from public.chat_members where room_id = p_room_id and user_id = auth.uid();

  if v_room.type = 'group' and v_role = 'owner' then
    if v_heir is null then
      delete from public.chat_rooms where id = p_room_id;
    else
      update public.chat_members set role = 'owner' where room_id = p_room_id and user_id = v_heir;
    end if;
  end if;

  perform realtime.send(jsonb_build_object('room_id', p_room_id, 'reason', 'left'),
                        'room_removed', 'user:' || auth.uid()::text, true);
end;
$$;
