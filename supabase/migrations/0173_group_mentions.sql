create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room      public.chat_rooms;
  v_member    record;
  v_target    uuid;
  v_preview   text;
  v_locked    boolean;
  v_mentioned uuid[] := '{}';
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

  if v_room.type in ('direct', 'group') and new.kind <> 'group_event' then
    if v_room.type = 'group' and new.sender_id is not null and new.deleted_at is null
       and new.moderation_status = 'visible' and position('@' in new.body) > 0 then
      v_mentioned := array(
        select p.id
        from unnest((private.extract_mentions(new.body))[1:private.setting_num('notifications.mention_room_max', 5)::integer])
             with ordinality as u(username, ord)
        join public.profiles p on p.username = u.username::extensions.citext
        join public.chat_members cm on cm.room_id = new.room_id and cm.user_id = p.id
        where p.id <> new.sender_id
          and p.deleted_at is null
          and not exists (select 1 from public.mutes m where m.muter_id = p.id and m.muted_id = new.sender_id)
          and private.mention_allowed(new.sender_id, p.id)
        order by u.ord);
    end if;
    for v_member in
      select cm.user_id from public.chat_members cm
      where cm.room_id = new.room_id and cm.user_id is distinct from new.sender_id
        and (not cm.muted or cm.user_id = any(v_mentioned))
    loop
      if v_member.user_id = any(v_mentioned) then
        perform private.notify(
          v_member.user_id, new.sender_id, 'mention',
          jsonb_build_object(
            'room_id', new.room_id,
            'room_type', 'group',
            'room_name', v_room.name,
            'message_id', new.id,
            'snippet', v_preview
          ),
          'mention:room:' || new.room_id
        );
      else
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
      end if;
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
