create or replace function cs_api.community_room_messages(p_code text, p_limit integer default 50, p_before timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'stock' and r.stock_code = upper(btrim(coalesce(p_code, '')));
  if v_room is null then
    perform private.api_error(404, 'room_not_found', 'Room saham tidak ditemukan');
  end if;
  return jsonb_build_object('room_id', v_room, 'items', coalesce((
    select jsonb_agg(x.v order by x.created_at desc)
    from (select m.created_at, jsonb_build_object(
            'id', m.id, 'created_at', m.created_at, 'edited_at', m.edited_at, 'body', left(m.body, 500),
            'attachments', jsonb_array_length(coalesce(m.attachments, '[]'::jsonb)),
            'moderation_status', m.moderation_status,
            'sender', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name)) as v
          from public.messages m
          join public.profiles p on p.id = m.sender_id
          where m.room_id = v_room and m.deleted_at is null and (p_before is null or m.created_at < p_before)
          order by m.created_at desc
          limit least(greatest(coalesce(p_limit, 50), 1), 100)) x), '[]'));
end;
$$;

create or replace function cs_api.integration_official_accounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', o.profile_id, 'username', p.username, 'display_name', p.display_name,
                                        'avatar_url', p.avatar_url) order by p.display_name, p.username)
    from cs.official_accounts o
    join public.profiles p on p.id = o.profile_id
    where o.disabled_at is null and p.deleted_at is null), '[]');
end;
$$;

create or replace function cs.community_private_message(p_message uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.messages m join public.chat_rooms r on r.id = m.room_id
                 where m.id = p_message and r.type in ('direct', 'group'));
$$;

create or replace function cs.community_message_reviewable(p_message uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.reports r where r.target_type = 'message' and r.target_id = p_message)
      or exists (select 1 from private.content_flags f where f.target_type = 'message' and f.target_id = p_message)
      or exists (select 1 from public.messages m where m.id = p_message and m.moderation_status <> 'visible');
$$;

create or replace function cs_api.community_content(p_type text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.moderate,community.sanction}');
  v_result jsonb;
begin
  if p_type = 'post' then
    select jsonb_build_object(
      'type', 'post', 'id', x.id, 'body', x.body, 'attachments', x.attachments, 'sentiment', x.sentiment,
      'created_at', x.created_at, 'edited_at', x.edited_at, 'deleted_at', x.deleted_at,
      'moderation_status', x.moderation_status, 'like_count', x.like_count, 'comment_count', x.comment_count,
      'author', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name))
      into v_result
    from public.posts x join public.profiles p on p.id = x.author_id
    where x.id = p_id;
  elsif p_type = 'comment' then
    select jsonb_build_object(
      'type', 'comment', 'id', x.id, 'post_id', x.post_id, 'parent_id', x.parent_id, 'body', x.body,
      'created_at', x.created_at, 'edited_at', x.edited_at, 'deleted_at', x.deleted_at,
      'moderation_status', x.moderation_status, 'like_count', x.like_count,
      'author', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name))
      into v_result
    from public.comments x join public.profiles p on p.id = x.author_id
    where x.id = p_id;
  elsif p_type = 'message' then
    if cs.community_private_message(p_id) and not cs.community_message_reviewable(p_id) then
      perform private.api_error(403, 'private_message_forbidden',
                                'Pesan pribadi hanya bisa dibuka bila dilaporkan atau ditandai sistem');
    end if;
    select jsonb_build_object(
      'type', 'message', 'id', x.id, 'body', x.body, 'attachments', x.attachments,
      'created_at', x.created_at, 'edited_at', x.edited_at, 'deleted_at', x.deleted_at,
      'moderation_status', x.moderation_status,
      'room', jsonb_build_object('id', r.id, 'type', r.type, 'name', r.name, 'stock_code', r.stock_code),
      'author', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name))
      into v_result
    from public.messages x
    join public.chat_rooms r on r.id = x.room_id
    join public.profiles p on p.id = x.sender_id
    where x.id = p_id and r.type <> 'support';
  else
    perform private.api_error(400, 'invalid_target_type', 'Jenis konten harus post, comment, atau message');
  end if;
  if v_result is null then
    perform private.api_error(404, 'content_not_found', 'Konten tidak ditemukan');
  end if;
  if p_type = 'message' and cs.community_private_message(p_id) then
    perform cs.audit('community.private_message_view', null, null, jsonb_build_object('message', p_id));
  end if;
  return v_result;
end;
$$;

create or replace function cs_api.community_content_meta(p_targets jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate,community.sanction}');
begin
  if jsonb_typeof(p_targets) is distinct from 'array' or jsonb_array_length(p_targets) > 200 then
    perform private.api_error(400, 'invalid_targets', 'Daftar konten harus array, maksimal 200');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('type', t.type, 'id', t.id, 'edited_at', c.edited_at,
                                        'moderation_status', c.moderation_status, 'deleted', c.deleted_at is not null))
    from jsonb_to_recordset(p_targets) as t(type text, id uuid)
    cross join lateral (
      select x.edited_at, x.moderation_status, x.deleted_at from public.posts x where t.type = 'post' and x.id = t.id
      union all
      select x.edited_at, x.moderation_status, x.deleted_at from public.comments x where t.type = 'comment' and x.id = t.id
      union all
      select x.edited_at, x.moderation_status, x.deleted_at from public.messages x where t.type = 'message' and x.id = t.id
    ) c), '[]');
end;
$$;

create or replace function cs_api.integration_stats_daily(p_days integer default 30, p_key_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 400);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('key_id', k.id, 'name', k.name, 'prefix', k.prefix, 'days', coalesce((
             select jsonb_agg(jsonb_build_object('day', d.day, 'received', d.received, 'queued', d.queued,
                                                 'devices', d.devices, 'no_recipient', d.no_recipient,
                                                 'duplicate', d.duplicate, 'invalid', d.invalid, 'posts', d.posts,
                                                 'posts_rejected', d.posts_rejected) order by d.day)
             from private.integration_daily d
             where d.key_id = k.id and d.day > current_date - v_days), '[]'))
           order by k.created_at)
    from private.integration_keys k
    where p_key_id is null or k.id = p_key_id), '[]');
end;
$$;

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
  if not v_platforms <@ array['android', 'ios', 'web'] then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, atau web');
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

revoke execute on function cs_api.community_room_messages(text, integer, timestamptz) from public;
revoke execute on function cs_api.integration_official_accounts() from public;
revoke execute on function cs.community_private_message(uuid) from public;
revoke execute on function cs.community_message_reviewable(uuid) from public;
revoke execute on function cs_api.community_content(text, uuid) from public;
revoke execute on function cs_api.community_content_meta(jsonb) from public;
revoke execute on function cs_api.integration_stats_daily(integer, uuid) from public;

grant execute on function cs_api.community_room_messages(text, integer, timestamptz) to authenticated;
grant execute on function cs_api.integration_official_accounts() to authenticated;
grant execute on function cs_api.community_content(text, uuid) to authenticated;
grant execute on function cs_api.community_content_meta(jsonb) to authenticated;
grant execute on function cs_api.integration_stats_daily(integer, uuid) to authenticated;
