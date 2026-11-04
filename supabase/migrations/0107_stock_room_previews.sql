insert into private.settings (key, value, description) values
  ('rooms.preview_poll_seconds', '15',
   'Jarak polling pratinjau room saham di daftar chat aplikasi (detik, sebelum jitter)')
on conflict (key) do nothing;

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
               'last_message_at', r.last_message_at,
               'last_message_preview', r.last_message_preview,
               'last_message_sender_id', r.last_message_sender_id,
               'unread_count', (select count(*)::integer from (
                                  select 1 from public.messages msg
                                  where msg.room_id = r.id
                                    and msg.created_at > m.last_read_at
                                    and msg.sender_id is distinct from m.user_id
                                    and msg.deleted_at is null
                                  limit 100) s),
               'cursor', '0|' || private.make_cursor(coalesce(r.last_message_at, r.created_at), r.id))
             order by r.id)
      from public.chat_members m
      join public.chat_rooms r on r.id = m.room_id
      where m.user_id = v_uid
        and m.room_id = any(coalesce(p_room_ids, '{}'))
        and r.type = 'stock'), '[]'::jsonb));
end;
$$;

revoke execute on function public.get_room_previews(uuid[]) from public, anon;
grant execute on function public.get_room_previews(uuid[]) to authenticated;
