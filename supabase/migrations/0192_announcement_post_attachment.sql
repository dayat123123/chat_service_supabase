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
    and (v_ts is null or (n.created_at, n.id) < (v_ts, v_id))
  order by n.created_at desc, n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;
