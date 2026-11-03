create or replace function private.client_platforms()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['android', 'ios', 'web', 'windows', 'macos', 'linux'];
$$;

alter table private.feature_flags drop constraint feature_flags_platforms_check;
alter table private.feature_flags add constraint feature_flags_platforms_check
  check (platforms <@ array['android', 'ios', 'web', 'windows', 'macos', 'linux']);
alter table private.client_versions drop constraint client_versions_platform_check;
alter table private.client_versions add constraint client_versions_platform_check
  check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux'));
alter table private.analytics_events drop constraint analytics_events_platform_check;
alter table private.analytics_events add constraint analytics_events_platform_check
  check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux'));
insert into private.client_versions (platform) values ('windows'), ('macos'), ('linux') on conflict do nothing;

create or replace function public.get_dm_request_state(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_req private.dm_requests;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.chat_members m where m.room_id = p_room_id and m.user_id = v_uid) then
    perform private.api_error(404, 'room_not_found', 'Room tidak ditemukan');
  end if;
  select * into v_req from private.dm_requests r where r.room_id = p_room_id;
  if not found or v_req.status = 'accepted' then
    return jsonb_build_object('is_request', false);
  end if;
  if v_req.sender_id = v_uid then
    return jsonb_build_object(
      'is_request', true, 'role', 'sender', 'status', 'pending',
      'sent', (select count(*) from public.messages m
               where m.room_id = p_room_id and m.sender_id = v_uid and m.deleted_at is null),
      'max_messages', private.setting_num('dm.request_max_messages', 3));
  end if;
  return jsonb_build_object('is_request', true, 'role', 'recipient', 'status', v_req.status);
end;
$$;

create or replace function public.get_my_moderated_content(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'type', c.type, 'id', c.id, 'state', c.state, 'excerpt', c.excerpt, 'decided_at', c.decided_at,
             'appeal', (select jsonb_build_object('id', a.id, 'status', a.status, 'created_at', a.created_at,
                                                  'decided_at', a.decided_at, 'decision_note', a.decision_note)
                        from public.appeals a
                        where a.user_id = v_uid and a.target_type = c.type and a.target_id = c.id
                        order by a.created_at desc limit 1))
           order by c.decided_at desc)
    from (
      select * from (
        select 'post'::text as type, p.id, 'hidden'::text as state, left(p.body, 280) as excerpt,
               coalesce(p.moderated_at, p.updated_at) as decided_at
        from public.posts p
        where p.author_id = v_uid and p.deleted_at is null and p.moderation_status = 'hidden'
        union all
        select 'comment', c.id, 'hidden', left(c.body, 280), coalesce(c.moderated_at, c.updated_at)
        from public.comments c
        where c.author_id = v_uid and c.deleted_at is null and c.moderation_status = 'hidden'
        union all
        select 'message', m.id, 'hidden', left(m.body, 280), coalesce(m.moderated_at, m.created_at)
        from public.messages m
        where m.sender_id = v_uid and m.deleted_at is null and m.moderation_status = 'hidden' and m.session_id is null
        union all
        select a.target_type, a.target_id, 'removed', left(a.body, 280), a.deleted_at
        from private.content_archive a
        where a.author_id = v_uid and a.reason = 'moderator_remove' and a.target_type in ('post', 'comment', 'message')
      ) u
      where u.decided_at > now() - interval '90 days'
      order by u.decided_at desc
      limit v_limit
    ) c), '[]');
end;
$$;

create or replace function public.get_client_config(p_platform text DEFAULT NULL::text, p_app_version text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user     uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_version  text := nullif(btrim(coalesce(p_app_version, '')), '');
  v_min      text;
begin
  if v_platform is not null and v_platform <> all (private.client_platforms()) then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_version is not null and private.version_parts(v_version) is null then
    perform private.api_error(400, 'invalid_version', 'Versi aplikasi harus berformat angka, mis. 2.4.1');
  end if;
  select v.min_version into v_min from private.client_versions v where v.platform = v_platform;

  return jsonb_build_object(
    'social_enabled', private.social_enabled(),
    'flags', coalesce((select jsonb_object_agg(f.key, private.flag_enabled(f, v_user, v_platform, v_version))
                       from private.feature_flags f), '{}'),
    'min_version', coalesce((select jsonb_object_agg(v.platform, v.min_version) from private.client_versions v), '{}'),
    'update_required', coalesce(v_min is not null and v_version is not null
                                and private.version_parts(v_version) < private.version_parts(v_min), false),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'server_time', now()));
end;
$function$;

create or replace function cs_api.admin_set_feature_flag(p_key text, p_enabled boolean, p_percentage integer DEFAULT 100, p_user_ids uuid[] DEFAULT '{}'::uuid[], p_platforms text[] DEFAULT '{}'::text[], p_min_app_version text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin}');
  v_key       text := lower(btrim(coalesce(p_key, '')));
  v_platforms text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                                  from unnest(coalesce(p_platforms, '{}')) x where btrim(x) <> ''), '{}');
  v_users     uuid[] := coalesce((select array_agg(distinct u order by u)
                                  from unnest(coalesce(p_user_ids, '{}')) u where u is not null), '{}');
  v_version   text := nullif(btrim(coalesce(p_min_app_version, '')), '');
  v_old       private.feature_flags;
  v_new       private.feature_flags;
begin
  if v_key = 'social.enabled' then
    perform private.api_error(400, 'use_kill_switch', 'Gunakan kill switch untuk mematikan fitur komunitas');
  end if;
  if v_key !~ '^[a-z][a-z0-9_.]{1,49}$' then
    perform private.api_error(400, 'invalid_flag_key', 'Kunci flag: huruf kecil, angka, titik, garis bawah (2-50)');
  end if;
  if p_enabled is null then
    perform private.api_error(400, 'invalid_flag', 'enabled wajib diisi');
  end if;
  if coalesce(p_percentage, 100) not between 0 and 100 then
    perform private.api_error(400, 'invalid_percentage', 'Persentase harus 0-100');
  end if;
  if not v_platforms <@ private.client_platforms() then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if cardinality(v_users) > 1000 then
    perform private.api_error(400, 'too_many_users', 'Maksimal 1000 pengguna per flag');
  end if;
  if v_version is not null and v_version !~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$' then
    perform private.api_error(400, 'invalid_version', 'Versi minimum harus berformat angka, mis. 2.4.0');
  end if;
  if char_length(coalesce(p_description, '')) > 300 then
    perform private.api_error(400, 'invalid_description', 'Deskripsi maksimal 300 karakter');
  end if;

  select * into v_old from private.feature_flags f where f.key = v_key for update;
  insert into private.feature_flags as f (key, enabled, percentage, user_ids, platforms, min_app_version, description,
                                          updated_by, updated_at)
  values (v_key, p_enabled, coalesce(p_percentage, 100), v_users, v_platforms, v_version,
          nullif(btrim(coalesce(p_description, '')), ''), v_me, now())
  on conflict (key) do update
    set enabled = excluded.enabled, percentage = excluded.percentage, user_ids = excluded.user_ids,
        platforms = excluded.platforms, min_app_version = excluded.min_app_version,
        description = case when p_description is null then f.description else excluded.description end, updated_by = v_me, updated_at = now()
  returning * into v_new;

  perform cs.audit('feature_flag.set', null, null, jsonb_build_object(
    'key', v_key,
    'before', case when v_old.key is not null then to_jsonb(v_old) - 'updated_by' - 'updated_at' - 'created_at' end,
    'after', to_jsonb(v_new) - 'updated_by' - 'updated_at' - 'created_at'));
  return cs.feature_flags_view();
end;
$function$;

create or replace function cs_api.admin_set_min_version(p_platform text, p_min_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_platform text := lower(btrim(coalesce(p_platform, '')));
  v_version  text := nullif(btrim(coalesce(p_min_version, '')), '');
  v_old      text;
begin
  if v_platform <> all (private.client_platforms()) then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_version is not null and v_version !~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$' then
    perform private.api_error(400, 'invalid_version', 'Versi minimum harus berformat angka, mis. 2.4.0');
  end if;
  select v.min_version into v_old from private.client_versions v where v.platform = v_platform for update;
  update private.client_versions
     set min_version = v_version, updated_by = v_me, updated_at = now()
   where platform = v_platform;
  perform cs.audit('client.min_version_set', null, null, jsonb_build_object(
    'platform', v_platform, 'before', v_old, 'after', v_version));
  return cs.feature_flags_view();
end;
$function$;

create or replace function public.track_events(p_events jsonb, p_platform text DEFAULT NULL::text, p_app_version text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid      uuid := auth.uid();
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_version  text := left(nullif(btrim(coalesce(p_app_version, '')), ''), 40);
  v_total    integer;
  v_accepted integer;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' then
    perform private.api_error(400, 'invalid_events', 'Event harus berupa array');
  end if;
  v_total := jsonb_array_length(p_events);
  if v_total > private.setting_num('analytics.max_batch', 50) then
    perform private.api_error(400, 'too_many_events',
      format('Maksimal %s event per kiriman', private.setting_num('analytics.max_batch', 50)));
  end if;
  if v_platform is not null and v_platform <> all (private.client_platforms()) then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if v_total = 0 then
    return jsonb_build_object('accepted', 0, 'dropped', 0);
  end if;
  perform private.consume_rate_limit(v_uid, 'analytics');
  if not private.feature_enabled('analytics', v_uid) then
    return jsonb_build_object('accepted', 0, 'dropped', v_total, 'disabled', true);
  end if;

  insert into private.analytics_events (created_at, user_id, event, platform, app_version, props)
  select case
           when x.ts is not null and x.ts between now() - interval '7 days' and now() + interval '5 minutes' then x.ts
           else now()
         end,
         v_uid, x.event, v_platform, v_version, private.analytics_props(x.props)
  from (
    select e.value ->> 'event' as event,
           e.value -> 'props' as props,
           case when (e.value ->> 'ts') ~ '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}(:?\d{2})?)$'
                then (e.value ->> 'ts')::timestamptz end as ts
    from jsonb_array_elements(p_events) e
    where jsonb_typeof(e.value) = 'object'
  ) x
  where x.event = any (private.analytics_event_names());
  get diagnostics v_accepted = row_count;
  return jsonb_build_object('accepted', v_accepted, 'dropped', v_total - v_accepted);
end;
$function$;


revoke execute on function private.client_platforms() from public;
grant execute on function private.client_platforms() to anon, authenticated;
revoke execute on function public.get_dm_request_state(uuid) from public, anon;
revoke execute on function public.get_my_moderated_content(integer) from public, anon;
grant execute on function public.get_dm_request_state(uuid) to authenticated;
grant execute on function public.get_my_moderated_content(integer) to authenticated;
