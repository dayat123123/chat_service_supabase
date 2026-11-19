create index notifications_banner_idx on public.notifications (user_id, (payload ->> 'banner_id'))
  where payload ? 'banner_id';

create or replace function public.record_banner_event(p_banner_id uuid, p_event text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_recorded boolean := false;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if cs.current_customer_id() is null then
    perform private.api_error(403, 'customer_required', 'Hanya nasabah yang mencatat tayangan banner');
  end if;
  if coalesce(p_event, '') not in ('impression', 'click', 'dismiss') then
    perform private.api_error(400, 'invalid_event', 'Event harus impression, click, atau dismiss');
  end if;
  perform private.consume_rate_limit(v_uid, 'banner_event');

  insert into private.app_banner_events (banner_id, user_id, event, day)
  select b.id, v_uid, p_event, (now() at time zone 'Asia/Jakarta')::date
  from private.app_banners b
  where b.id = p_banner_id
    and b.starts_at <= now()
    and (b.ends_at is null or b.ends_at > now())
    and (b.audience = 'all'
         or exists (select 1 from public.profiles p
                    where p.id = v_uid and p.created_at >= now() - make_interval(days => b.audience_days)))
  on conflict (banner_id, user_id, event, day) do nothing;
  v_recorded := found;
  if p_event = 'click'
     or (p_event = 'impression'
         and exists (select 1 from private.app_banners b where b.id = p_banner_id and b.display = 'popup')) then
    update public.notifications n
       set read_at = now()
     where n.user_id = v_uid
       and n.read_at is null
       and n.type = 'announcement'
       and n.payload ? 'banner_id'
       and n.payload ->> 'banner_id' = p_banner_id::text;
  end if;

  return jsonb_build_object('recorded', v_recorded);
end;
$$;

create or replace function private.client_banners(p_platform text, p_version text, p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'title', x.title, 'body', x.body,
           'link_url', case when private.banner_link_visible(x.link_url) then x.link_url end,
           'level', x.level, 'dismissible', x.dismissible, 'priority', x.priority,
           'starts_at', x.starts_at, 'ends_at', x.ends_at,
           'display', x.display, 'image_url', x.image_url,
           'cta_label', case when private.banner_link_visible(x.link_url) then x.cta_label end,
           'frequency', x.frequency)
           || jsonb_strip_nulls(jsonb_build_object('image_ratio', x.image_ratio, 'seen_at', h.seen_at,
                                                   'dismissed_at', h.dismissed_at))
           order by x.priority desc, x.starts_at desc, x.id), '[]')
  from (
    select b.*
    from private.app_banners b
    where b.starts_at <= now()
      and (b.ends_at is null or b.ends_at > now())
      and (cardinality(b.platforms) = 0 or p_platform = any (b.platforms))
      and (b.min_app_version is null
           or (p_version is not null and private.version_parts(p_version) >= private.version_parts(b.min_app_version)))
      and (b.max_app_version is null
           or (p_version is not null and private.version_parts(p_version) <= private.version_parts(b.max_app_version)))
      and (b.audience = 'all'
           or (p_user is not null
               and exists (select 1 from public.profiles p
                           where p.id = p_user
                             and p.created_at >= now() - make_interval(days => b.audience_days))))
    order by b.priority desc, b.starts_at desc, b.id
    limit 10
  ) x
  left join lateral (
    select greatest(max(e.created_at) filter (where e.event = 'impression'),
                    (select max(ne.created_at)
                     from public.notifications nt
                     join private.notification_events ne on ne.notification_id = nt.id and ne.user_id = p_user
                     where p_user is not null
                       and nt.user_id = p_user
                       and nt.payload ? 'banner_id'
                       and nt.payload ->> 'banner_id' = x.id::text
                       and ne.event in ('opened', 'tapped'))) as seen_at,
           max(e.created_at) filter (where e.event = 'dismiss') as dismissed_at
    from private.app_banner_events e
    where p_user is not null
      and e.banner_id = x.id
      and e.user_id = p_user
      and e.event in ('impression', 'dismiss')
  ) h on true;
$$;
