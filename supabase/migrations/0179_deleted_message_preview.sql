create function private.message_delete_preview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
begin
  update public.chat_rooms r
     set last_message_preview = '[pesan dihapus]'
   where r.id = new.room_id
     and r.last_message_at = new.created_at
     and r.last_message_sender_id is not distinct from new.sender_id
     and r.last_message_preview is distinct from '[pesan dihapus]'
  returning r.type into v_type;
  if v_type in ('direct', 'group') then
    insert into realtime.messages (id, payload, event, topic, private, extension)
    select u.id,
           jsonb_build_object('id', u.id, 'room_id', new.room_id, 'room_type', v_type, 'message_id', new.id,
                              'sender_id', new.sender_id, 'created_at', new.created_at, 'preview', '[pesan dihapus]'),
           'room_activity', 'user:' || u.user_id::text, true, 'broadcast'
    from (select gen_random_uuid() as id, m.user_id from public.chat_members m where m.room_id = new.room_id) u;
  end if;
  return null;
end;
$$;

create trigger messages_62_delete_preview
  after update of deleted_at on public.messages
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function private.message_delete_preview();

update public.chat_rooms r
   set last_message_preview = '[pesan dihapus]'
 where r.last_message_preview is distinct from '[pesan dihapus]'
   and exists (select 1 from public.messages m
               where m.room_id = r.id
                 and m.created_at = r.last_message_at
                 and m.sender_id is not distinct from r.last_message_sender_id
                 and m.deleted_at is not null);

revoke execute on function private.message_delete_preview() from public;
