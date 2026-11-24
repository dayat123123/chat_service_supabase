create index notifications_user_feed_idx on public.notifications (user_id, created_at desc, id desc)
  where type <> 'message';

create or replace function private.notification_in_chat(p_type text, p_payload jsonb)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_type = 'message'
         or (p_type = 'mention'
             and not p_payload ? 'post_id'
             and p_payload ->> 'room_id' ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
             and exists (select 1 from public.chat_members m
                         where m.room_id = (p_payload ->> 'room_id')::uuid and m.user_id = auth.uid()));
$$;

create or replace function public.get_notifications(p_cursor text default null, p_limit integer default 30)
returns table (
  id                 uuid,
  type               text,
  actor_id           uuid,
  actor_username     text,
  actor_display_name text,
  actor_avatar_url   text,
  payload            jsonb,
  event_count        integer,
  read_at            timestamptz,
  created_at         timestamptz,
  cursor             text,
  actor_count        integer,
  actors             jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ts  timestamptz;
  v_id  uuid;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_cursor is not null then
    begin
      v_ts := split_part(p_cursor, '|', 1)::timestamptz;
      v_id := split_part(p_cursor, '|', 2)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor');
    end;
  end if;

  return query
  select n.id, n.type, n.actor_id, a.username::text, a.display_name, a.avatar_url,
         n.payload || coalesce(pa.extra, '{}'::jsonb), n.event_count, n.read_at, n.created_at,
         to_char(n.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || n.id,
         coalesce(ac.total, case when n.actor_id is null then 0 else 1 end),
         coalesce(ac.actors,
                  case when a.id is null then '[]'::jsonb
                       else jsonb_build_array(jsonb_build_object('id', a.id, 'username', a.username::text,
                                                                 'display_name', a.display_name,
                                                                 'avatar_url', a.avatar_url)) end)
  from public.notifications n
  left join public.profiles a on a.id = n.actor_id
  left join lateral (
    select count(*)::integer as total,
           jsonb_agg(jsonb_build_object('id', x.id, 'username', x.username, 'display_name', x.display_name,
                                        'avatar_url', x.avatar_url) order by x.updated_at desc)
             filter (where x.rn <= 3) as actors
    from (
      select p.id, p.username::text as username, p.display_name, p.avatar_url, na.updated_at,
             row_number() over (order by na.updated_at desc) as rn
      from private.notification_actors na
      join public.profiles p on p.id = na.actor_id
      where na.notification_id = n.id
    ) x
    having count(*) > 0
  ) ac on true
  left join lateral (
    select jsonb_build_object('post_attachment', f.item) as extra
    from public.posts p
    cross join lateral (
      select e.item
      from jsonb_array_elements(p.attachments) with ordinality as e (item, pos)
      where jsonb_typeof(e.item) = 'object'
        and jsonb_typeof(e.item -> 'path') = 'string'
        and coalesce(e.item ->> 'mime', 'image/') like 'image/%'
      order by e.pos
      limit 1
    ) f
    where n.type in ('like', 'reply', 'mention', 'followed_post', 'announcement')
      and n.payload ->> 'post_id' ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      and p.id = (n.payload ->> 'post_id')::uuid
      and p.deleted_at is null
      and p.moderation_status = 'visible'
  ) pa on true
  where n.user_id = v_uid
    and n.type <> 'message'
    and not (n.type = 'mention' and private.notification_in_chat(n.type, n.payload))
    and (v_ts is null or (n.created_at, n.id) < (v_ts, v_id))
  order by n.created_at desc, n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

create or replace function public.get_notification_unread_count()
returns integer
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select count(*)::integer from public.notifications n
  where n.user_id = auth.uid()
    and n.read_at is null
    and n.type <> 'message'
    and not (n.type = 'mention' and private.notification_in_chat(n.type, n.payload));
$$;

create or replace function public.mark_room_read(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user      uuid := auth.uid();
  v_type      text;
  v_last      timestamptz;
  v_prev_read timestamptz;
  v_read      timestamptz;
  v_delivered timestamptz;
begin
  if v_user is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  select c.type, c.last_message_at, m.last_read_at
    into v_type, v_last, v_prev_read
    from public.chat_members m
    join public.chat_rooms c on c.id = m.room_id
   where m.room_id = p_room_id and m.user_id = v_user;
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;

  update public.chat_members
     set last_read_at = now(),
         last_delivered_at = greatest(last_delivered_at, now())
   where room_id = p_room_id and user_id = v_user
  returning last_read_at, last_delivered_at into v_read, v_delivered;

  update public.notifications
     set read_at = now()
   where user_id = v_user
     and read_at is null
     and (type = 'message' or (type = 'mention' and not payload ? 'post_id'))
     and payload ->> 'room_id' = p_room_id::text;

  if v_type <> 'stock' and v_last is not null and v_prev_read < v_last then
    perform private.broadcast_receipt(p_room_id, v_user, v_delivered, v_read);
  end if;
end;
$$;

revoke execute on function private.notification_in_chat(text, jsonb) from public;
grant execute on function private.notification_in_chat(text, jsonb) to authenticated, service_role;
