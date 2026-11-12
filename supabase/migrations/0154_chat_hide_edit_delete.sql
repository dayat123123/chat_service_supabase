alter table public.chat_members
  add column hidden_at timestamptz,
  add column cleared_at timestamptz;

alter table private.content_edits drop constraint content_edits_target_type_check;
alter table private.content_edits
  add constraint content_edits_target_type_check check (target_type in ('post', 'comment', 'message'));

create or replace function private.room_cleared_at(p_room_id uuid, p_user_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select m.cleared_at from public.chat_members m
                   where m.room_id = p_room_id and m.user_id = p_user_id), '-infinity'::timestamptz);
$$;

create or replace function private.room_listed(p_hidden_at timestamptz, p_last_message_at timestamptz)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_hidden_at is null or coalesce(p_last_message_at > p_hidden_at, false);
$$;

create or replace function public.hide_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_type text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select r.type into v_type
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  where m.room_id = p_room_id and m.user_id = v_uid;
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_type = 'support' then
    perform private.api_error(400, 'cannot_hide_support', 'Chat CS tidak bisa dihapus');
  end if;

  update public.chat_members
     set hidden_at = now(), cleared_at = now()
   where room_id = p_room_id and user_id = v_uid;

  update public.notifications
     set read_at = now()
   where user_id = v_uid
     and read_at is null
     and type in ('message', 'mention')
     and payload ->> 'room_id' = p_room_id::text;

  perform realtime.send(jsonb_build_object('room_id', p_room_id, 'reason', 'hidden'),
                        'room_removed', 'user:' || v_uid::text, true);
end;
$$;

create or replace function public.delete_group(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_room     public.chat_rooms;
  v_members  uuid[];
  v_archived integer;
  v_event    jsonb;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_room from public.chat_rooms r where r.id = p_room_id for update;
  if not found then
    perform private.api_error(404, 'room_not_found', 'Room tidak ditemukan');
  end if;
  if v_room.type <> 'group' then
    perform private.api_error(400, 'not_group', 'Hanya grup yang bisa dihapus');
  end if;
  if private.room_role(p_room_id) is distinct from 'owner' then
    perform private.api_error(403, 'forbidden', 'Hanya pemilik grup yang bisa menghapus grup');
  end if;

  select array_agg(m.user_id) into v_members from public.chat_members m where m.room_id = p_room_id;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by)
  select 'message', m.id, m.sender_id, m.body, m.attachments, v_uid
  from public.messages m
  where m.room_id = p_room_id
    and m.deleted_at is null
    and m.kind <> 'group_event'
    and (m.body <> '' or jsonb_array_length(m.attachments) > 0);
  get diagnostics v_archived = row_count;

  perform private.audit('chat.group_delete', 'chat_room', p_room_id::text,
    jsonb_build_object('name', v_room.name, 'members', coalesce(cardinality(v_members), 0),
                       'archived_messages', v_archived));

  v_event := jsonb_build_object('room_id', p_room_id, 'reason', 'group_deleted', 'actor_id', v_uid,
                                'actor_name', private.member_name(v_uid));
  perform realtime.send(v_event, 'room_deleted', 'room:' || p_room_id::text, true);
  insert into realtime.messages (id, payload, event, topic, private, extension)
  select gen_random_uuid(), v_event, 'room_removed', 'user:' || u::text, true, 'broadcast'
  from unnest(coalesce(v_members, '{}')) u;

  delete from public.notifications n
   where n.type = 'message' and n.payload ->> 'room_id' = p_room_id::text;

  delete from public.chat_rooms where id = p_room_id;
end;
$$;

create or replace function private.guard_message_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
begin
  if new.deleted_at is not null or old.deleted_at is not null or new.body is not distinct from old.body then
    return new;
  end if;
  if private.is_end_user() then
    select r.type into v_type from public.chat_rooms r where r.id = old.room_id;
    if old.session_id is not null or v_type = 'support' then
      perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa diubah');
    end if;
    if old.kind <> 'text' or old.sender_id is null or jsonb_array_length(old.attachments) > 0 then
      perform private.api_error(400, 'not_editable', 'Hanya pesan teks yang bisa diedit');
    end if;
    if old.created_at < now() - make_interval(mins => private.setting_num('content.edit_minutes', 15)::integer) then
      perform private.api_error(409, 'edit_window_closed',
        format('Pesan hanya bisa diedit %s menit setelah dikirim', private.setting_num('content.edit_minutes', 15)));
    end if;
    if regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g') = '' then
      perform private.api_error(400, 'empty_body', 'Pesan tidak boleh kosong');
    end if;
  end if;
  insert into private.content_edits (target_type, target_id, author_id, body, edited_by, retain_until)
  values ('message', old.id, old.sender_id, old.body, auth.uid(),
          now() + make_interval(days => private.setting_num('retention.archive_days', 1825)::integer));
  return new;
end;
$$;

create trigger messages_22_edit
  before update of body on public.messages
  for each row execute function private.guard_message_edit();

create or replace function private.message_edit_preview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_preview text := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;
begin
  update public.chat_rooms r
     set last_message_preview = v_preview
   where r.id = new.room_id
     and r.last_message_at = new.created_at
     and r.last_message_sender_id is not distinct from new.sender_id
     and r.last_message_preview is distinct from v_preview;
  if found then
    perform realtime.send(
      jsonb_build_object('room_id', new.room_id, 'message_id', new.id, 'preview', v_preview, 'edited_at', new.edited_at),
      'message_edited', 'room:' || new.room_id::text, true);
  end if;
  return null;
end;
$$;

create trigger messages_61_edit_preview
  after update of body on public.messages
  for each row
  when (new.deleted_at is null and old.deleted_at is null and new.body is distinct from old.body
        and new.moderation_status = 'visible')
  execute function private.message_edit_preview();

create or replace function public.edit_message(p_message_id uuid, p_body text)
returns setof public.chat_message
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_body text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_msg  public.messages;
  v_type text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_msg from public.messages m where m.id = p_message_id for update;
  if not found or not exists (select 1 from public.chat_members cm
                              where cm.room_id = v_msg.room_id and cm.user_id = v_uid) then
    perform private.api_error(404, 'not_found', 'Pesan tidak ditemukan');
  end if;
  if v_msg.sender_id is distinct from v_uid then
    perform private.api_error(403, 'forbidden', 'Hanya pengirim yang bisa mengedit pesan ini');
  end if;
  select r.type into v_type from public.chat_rooms r where r.id = v_msg.room_id;
  if v_msg.session_id is not null or v_type = 'support' then
    perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa diubah');
  end if;
  if v_msg.deleted_at is not null or v_msg.kind <> 'text' or jsonb_array_length(v_msg.attachments) > 0 then
    perform private.api_error(400, 'not_editable', 'Hanya pesan teks yang bisa diedit');
  end if;
  if v_msg.created_at < now() - make_interval(mins => private.setting_num('content.edit_minutes', 15)::integer) then
    perform private.api_error(409, 'edit_window_closed',
      format('Pesan hanya bisa diedit %s menit setelah dikirim', private.setting_num('content.edit_minutes', 15)));
  end if;
  if v_body = '' then
    perform private.api_error(400, 'empty_body', 'Pesan tidak boleh kosong');
  end if;
  if char_length(v_body) > 4000 then
    perform private.api_error(400, 'body_too_long', 'Pesan maksimal 4000 karakter');
  end if;
  if v_body is distinct from v_msg.body then
    perform private.consume_rate_limit(v_uid, 'content_edit');
    update public.messages set body = v_body where id = v_msg.id;
  end if;
  return query select * from private.chat_messages(array[v_msg.id]);
end;
$$;

create or replace function private.chat_messages(p_ids uuid[])
returns setof public.chat_message
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.id, m.room_id, m.sender_id,
         s.username::text, s.display_name, s.avatar_url,
         case when m.deleted_at is null then m.body end,
         m.deleted_at is not null,
         m.reply_to_id,
         case when rt.deleted_at is null and rt.created_at > me.cleared then private.snippet(rt.body, 200) end,
         case when rt.created_at > me.cleared then rs.username::text end,
         case when m.deleted_at is null then m.attachments else '[]'::jsonb end,
         m.client_id, m.edited_at, m.created_at,
         private.make_cursor(m.created_at, m.id),
         m.kind,
         case when m.deleted_at is null then m.payload else '{}'::jsonb end,
         m.session_id,
         m.sender_role,
         case when m.deleted_at is null then private.message_reaction_summary(m.id, auth.uid()) else '[]'::jsonb end,
         case when m.deleted_at is null then private.shared_post_preview(m.attachments, auth.uid()) end,
         case when m.deleted_at is null and m.sender_id = auth.uid() then m.moderation_status end
  from public.messages m
  cross join lateral (select private.room_cleared_at(m.room_id, auth.uid()) as cleared) me
  left join public.profiles s on s.id = m.sender_id
  left join public.messages rt on rt.id = m.reply_to_id
  left join public.profiles rs on rs.id = rt.sender_id
  where m.id = any(p_ids)
    and m.created_at > me.cleared
  order by m.created_at desc, m.id desc;
$$;

create or replace function public.get_messages(p_room_id uuid, p_cursor text default null, p_limit integer default 30,
                                               p_after text default null)
returns setof public.chat_message
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit   integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_cleared timestamptz := private.room_cleared_at(p_room_id, auth.uid());
  v_ts      timestamptz;
  v_id      uuid;
  v_ids     uuid[];
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;

  if p_after is not null and p_after <> '' then
    select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_after) c;
    select array_agg(x.id) into v_ids
    from (
      select m.id from public.messages m
      where m.room_id = p_room_id and (m.created_at, m.id) > (v_ts, v_id) and m.created_at > v_cleared
      order by m.created_at, m.id
      limit v_limit
    ) x;
  else
    select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
    select array_agg(x.id) into v_ids
    from (
      select m.id from public.messages m
      where m.room_id = p_room_id
        and m.created_at > v_cleared
        and (v_ts is null or (m.created_at, m.id) < (v_ts, v_id))
      order by m.created_at desc, m.id desc
      limit v_limit
    ) x;
  end if;

  return query select * from private.chat_messages(coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.get_message_ids(p_room_id uuid, p_after text, p_limit integer default 500)
returns jsonb
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit   integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_cleared timestamptz := private.room_cleared_at(p_room_id, auth.uid());
  v_ts      timestamptz;
  v_id      uuid;
  v_ids     uuid[];
  v_last_ts timestamptz;
  v_last_id uuid;
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_after) c;
  if v_ts is null then
    perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
  end if;

  select array_agg(x.id order by x.created_at, x.id),
         (array_agg(x.created_at order by x.created_at desc, x.id desc))[1],
         (array_agg(x.id order by x.created_at desc, x.id desc))[1]
    into v_ids, v_last_ts, v_last_id
  from (
    select m.id, m.created_at from public.messages m
    where m.room_id = p_room_id and (m.created_at, m.id) > (v_ts, v_id) and m.created_at > v_cleared
    order by m.created_at, m.id
    limit v_limit
  ) x;

  return jsonb_build_object(
    'ids', coalesce(to_jsonb(v_ids), '[]'::jsonb),
    'last', case when v_last_id is not null then private.make_cursor(v_last_ts, v_last_id) end,
    'more', coalesce(cardinality(v_ids), 0) >= v_limit
  );
end;
$$;

create or replace function public.get_messages_by_ids(p_room_id uuid, p_ids uuid[])
returns setof public.chat_message
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_ids uuid[];
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if coalesce(cardinality(p_ids), 0) = 0 then
    return;
  end if;
  if cardinality(p_ids) > 100 then
    perform private.api_error(400, 'too_many_ids', 'Maksimal 100 pesan sekaligus');
  end if;

  select array_agg(m.id) into v_ids
  from public.messages m
  where m.room_id = p_room_id and m.id = any(p_ids)
    and m.created_at > private.room_cleared_at(p_room_id, auth.uid());

  return query select * from private.chat_messages(coalesce(v_ids, '{}'));
end;
$$;

create or replace function private.chat_room_summaries(p_room_ids uuid[])
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type,
         case when r.type = 'support' then coalesce(cs.support_name(), 'CS') else r.name end,
         r.stock_code, r.created_by,
         case when v.shown then r.last_message_at end,
         case when v.shown then r.last_message_preview end,
         case when v.shown then r.last_message_sender_id end,
         case
           when not v.shown or r.last_message_at is null or r.last_message_sender_id is distinct from m.user_id then null
           when r.type = 'stock' or rc.others = 0 then 'sent'
           when rc.unread = 0 then 'read'
           when rc.undelivered = 0 then 'delivered'
           else 'sent'
         end,
         r.created_at,
         m.role, m.muted, m.last_read_at,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = r.id
              and msg.created_at > m.last_read_at
              and msg.created_at > coalesce(m.cleared_at, '-infinity')
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         rc.members,
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified,
         case when r.type = 'support' then '1' else '0' end || '|'
           || private.make_cursor(coalesce(r.last_message_at, r.created_at), r.id),
         r.description, r.avatar_url,
         case when r.type = 'group' then r.only_admins_send end,
         case when r.type = 'group' then r.only_admins_edit end
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  cross join lateral (
    select m.cleared_at is null or coalesce(r.last_message_at > m.cleared_at, false) as shown
  ) v
  cross join lateral (
    select count(*)::integer as members,
           count(*) filter (where om.user_id <> m.user_id)::integer as others,
           count(*) filter (where om.user_id <> m.user_id and om.last_read_at < r.last_message_at)::integer as unread,
           count(*) filter (where om.user_id <> m.user_id and om.last_delivered_at < r.last_message_at)::integer as undelivered
    from public.chat_members om
    where om.room_id = r.id
  ) rc
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified
    from public.chat_members om
    join public.profiles p on p.id = om.user_id
    where r.type = 'direct' and om.room_id = r.id and om.user_id <> m.user_id
    limit 1
  ) o on true
  where m.user_id = auth.uid() and m.room_id = any(p_room_ids)
  order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc;
$$;

create or replace function public.get_my_rooms(p_cursor text default null, p_limit integer default 30)
returns setof public.chat_room_summary
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit  integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_pinned boolean;
  v_ts     timestamptz;
  v_id     uuid;
  v_ids    uuid[];
begin
  if coalesce(p_cursor, '') <> '' then
    begin
      v_pinned := case split_part(p_cursor, '|', 1) when '1' then true when '0' then false end;
      v_ts := split_part(p_cursor, '|', 2)::timestamptz;
      v_id := split_part(p_cursor, '|', 3)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end;
    if v_pinned is null or v_ts is null or v_id is null then
      perform private.api_error(400, 'invalid_cursor', 'Cursor tidak valid');
    end if;
  end if;

  select array_agg(x.id) into v_ids
  from (
    select r.id
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.user_id = auth.uid()
      and (v_ts is null
           or (r.type = 'support', coalesce(r.last_message_at, r.created_at), r.id) < (v_pinned, v_ts, v_id))
      and (r.type <> 'direct' or not private.dm_request_hidden(r.id, m.user_id))
      and private.room_listed(m.hidden_at, r.last_message_at)
    order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc
    limit v_limit
  ) x;

  return query select * from private.chat_room_summaries(coalesce(v_ids, '{}'));
end;
$$;

create or replace function public.get_my_room(p_room_id uuid)
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select * from private.chat_room_summaries(array(
    select m.room_id
    from public.chat_members m
    join public.chat_rooms r on r.id = m.room_id
    where m.room_id = p_room_id and m.user_id = auth.uid()
      and private.room_listed(m.hidden_at, r.last_message_at)));
$$;

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
               'last_message_at', case when v.shown then r.last_message_at end,
               'last_message_preview', case when v.shown then r.last_message_preview end,
               'last_message_sender_id', case when v.shown then r.last_message_sender_id end,
               'unread_count', (select count(*)::integer from (
                                  select 1 from public.messages msg
                                  where msg.room_id = r.id
                                    and msg.created_at > m.last_read_at
                                    and msg.created_at > coalesce(m.cleared_at, '-infinity')
                                    and msg.sender_id is distinct from m.user_id
                                    and msg.deleted_at is null
                                  limit 100) s),
               'cursor', '0|' || private.make_cursor(coalesce(r.last_message_at, r.created_at), r.id))
             order by r.id)
      from public.chat_members m
      join public.chat_rooms r on r.id = m.room_id
      cross join lateral (
        select m.cleared_at is null or coalesce(r.last_message_at > m.cleared_at, false) as shown
      ) v
      where m.user_id = v_uid
        and m.room_id = any(coalesce(p_room_ids, '{}'))
        and r.type = 'stock'), '[]'::jsonb));
end;
$$;

create or replace function public.get_unread_counts()
returns table (room_id uuid, unread_count integer)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.room_id,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = m.room_id
              and msg.created_at > m.last_read_at
              and msg.created_at > coalesce(m.cleared_at, '-infinity')
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s)
  from public.chat_members m
  where m.user_id = auth.uid()
    and not private.dm_request_pending(m.room_id, m.user_id);
$$;

create or replace function public.get_unread_chat_count()
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
    and r.last_message_at > coalesce(m.cleared_at, '-infinity')
    and not (r.type = 'direct' and private.dm_request_pending(r.id, m.user_id))
    and exists (
      select 1 from public.messages msg
      where msg.room_id = m.room_id
        and msg.created_at > m.last_read_at
        and msg.created_at > coalesce(m.cleared_at, '-infinity')
        and msg.sender_id is distinct from m.user_id
        and msg.deleted_at is null
    );
$$;

create or replace function public.get_or_create_direct_room(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_me    uuid := auth.uid();
  v_key   text;
  v_room  uuid;
  v_state text;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_other_user_id is null or p_other_user_id = v_me then
    perform private.api_error(400, 'invalid_user', 'Tidak bisa membuat DM dengan diri sendiri');
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  if private.is_blocked_pair(v_me, p_other_user_id) then
    perform private.api_error(403, 'blocked', 'Tidak bisa mengirim pesan ke user ini');
  end if;

  v_key := least(v_me::text, p_other_user_id::text) || ':' || greatest(v_me::text, p_other_user_id::text);
  select id into v_room from public.chat_rooms where direct_key = v_key;
  if v_room is null and private.is_official_account(p_other_user_id) and not private.official_dm_exempt(v_me) then
    perform private.official_no_dm_error();
  end if;
  if v_room is null or not exists (select 1 from private.dm_requests q where q.room_id = v_room) then
    v_state := private.dm_evaluate(v_me, p_other_user_id);
    if v_state = 'denied' then
      perform private.api_error(403, 'dm_not_allowed', 'Pengguna ini tidak menerima pesan langsung dari Anda');
    end if;
  end if;

  insert into public.chat_rooms (type, direct_key, created_by)
  values ('direct', v_key, v_me)
  on conflict (direct_key) where direct_key is not null do nothing
  returning id into v_room;

  if v_room is null then
    select id into v_room from public.chat_rooms where direct_key = v_key;
  end if;

  insert into public.chat_members (room_id, user_id)
  values (v_room, v_me), (v_room, p_other_user_id)
  on conflict do nothing;

  update public.chat_members set hidden_at = null
   where room_id = v_room and user_id = v_me and hidden_at is not null;

  if v_state is not null then
    insert into private.dm_requests (room_id, sender_id, recipient_id, status, responded_at)
    values (v_room, v_me, p_other_user_id, v_state, case when v_state = 'accepted' then now() end)
    on conflict (room_id) do nothing;
  end if;
  return v_room;
end;
$$;

create or replace function public.join_stock_room(p_stock_code text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_code text := private.stock_code(p_stock_code);
  v_room uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if v_code is null then
    perform private.api_error(400, 'invalid_stock_code', 'Kode saham atau indeks tidak valid');
  end if;
  if not private.stock_room_enabled(v_code) then
    perform private.api_error(403, 'room_disabled', 'Room diskusi untuk kode ini sedang ditutup');
  end if;

  select id into v_room from public.chat_rooms where type = 'stock' and stock_code = v_code;
  if v_room is null then
    perform private.consume_rate_limit(auth.uid(), 'stock_room_create');
    insert into public.chat_rooms (type, name, stock_code, created_by)
    values ('stock', v_code, v_code, auth.uid())
    on conflict (stock_code) where type = 'stock' do nothing
    returning id into v_room;
    if v_room is null then
      select id into v_room from public.chat_rooms where type = 'stock' and stock_code = v_code;
    end if;
  end if;

  insert into public.chat_members (room_id, user_id) values (v_room, auth.uid())
  on conflict (room_id, user_id) do update set hidden_at = null
  where public.chat_members.hidden_at is not null;
  return v_room;
end;
$$;

create or replace function cs_api.community_edit_history(p_target_type text, p_target_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  if p_target_type not in ('post', 'comment', 'message') then
    perform private.api_error(400, 'invalid_target', 'Jenis konten harus post, comment, atau message');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('body', e.body, 'edited_at', e.edited_at, 'edited_by', e.edited_by)
                     order by e.edited_at)
    from private.content_edits e
    where e.target_type = p_target_type and e.target_id = p_target_id), '[]');
end;
$$;

create or replace function private.analytics_event_names()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['feed_open', 'post_create', 'comment_create', 'message_send', 'stock_tap', 'order_tap', 'search',
               'share_chart', 'hide_room', 'delete_group', 'edit_message'];
$$;

revoke execute on function private.room_cleared_at(uuid, uuid) from public;
revoke execute on function private.room_listed(timestamptz, timestamptz) from public;
grant execute on function private.room_cleared_at(uuid, uuid) to authenticated, service_role;
grant execute on function private.room_listed(timestamptz, timestamptz) to authenticated, service_role;
revoke execute on function private.guard_message_edit() from public;
revoke execute on function private.message_edit_preview() from public;
revoke execute on function public.hide_room(uuid) from public, anon;
grant execute on function public.hide_room(uuid) to authenticated;
revoke execute on function public.delete_group(uuid) from public, anon;
grant execute on function public.delete_group(uuid) to authenticated;
revoke execute on function public.edit_message(uuid, text) from public, anon;
grant execute on function public.edit_message(uuid, text) to authenticated;
