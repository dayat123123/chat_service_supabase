create function public.get_unread_chat_count()
returns integer
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select count(*)::integer
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  where m.user_id = auth.uid()
    and not m.muted
    and r.type in ('direct', 'group')
    and r.last_message_at > m.last_read_at
    and exists (
      select 1 from public.messages msg
      where msg.room_id = m.room_id
        and msg.created_at > m.last_read_at
        and msg.sender_id is distinct from m.user_id
        and msg.deleted_at is null
    );
$$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_unread_chat_count() to authenticated;
