create table private.app_banners (
  id              uuid primary key default gen_random_uuid(),
  title           text not null check (char_length(btrim(title)) between 1 and 80),
  body            text not null default '' check (char_length(body) <= 300),
  link_url        text check (link_url ~ '^https?://[^\s]+$' and char_length(link_url) <= 500),
  level           text not null default 'info' check (level in ('info', 'warning', 'critical')),
  starts_at       timestamptz not null default now(),
  ends_at         timestamptz,
  platforms       text[] not null default '{}'
                  check (platforms <@ array['android', 'ios', 'web', 'windows', 'macos', 'linux']),
  min_app_version text check (min_app_version is null or private.version_parts(min_app_version) is not null),
  max_app_version text check (max_app_version is null or private.version_parts(max_app_version) is not null),
  dismissible     boolean not null default true,
  priority        integer not null default 0 check (priority between 0 and 1000),
  created_by      uuid references cs.agents (user_id),
  updated_by      uuid references cs.agents (user_id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint app_banners_schedule check (ends_at is null or ends_at > starts_at),
  constraint app_banners_versions check (min_app_version is null or max_app_version is null
                                         or private.version_parts(min_app_version) <= private.version_parts(max_app_version))
);
create index app_banners_active_idx on private.app_banners (starts_at, ends_at);
alter table private.app_banners enable row level security;

create or replace function private.app_banner_view(b private.app_banners)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', b.id, 'title', b.title, 'body', b.body, 'link_url', b.link_url, 'level', b.level,
    'starts_at', b.starts_at, 'ends_at', b.ends_at, 'platforms', to_jsonb(b.platforms),
    'min_app_version', b.min_app_version, 'max_app_version', b.max_app_version,
    'dismissible', b.dismissible, 'priority', b.priority,
    'status', case when b.ends_at is not null and b.ends_at <= now() then 'ended'
                   when b.starts_at > now() then 'scheduled'
                   else 'active' end,
    'created_by', cs.staff_ref(b.created_by), 'updated_by', cs.staff_ref(b.updated_by),
    'created_at', b.created_at, 'updated_at', b.updated_at);
$$;

create or replace function private.client_banners(p_platform text, p_version text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'title', x.title, 'body', x.body, 'link_url', x.link_url, 'level', x.level,
           'dismissible', x.dismissible, 'priority', x.priority, 'starts_at', x.starts_at, 'ends_at', x.ends_at)
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
    order by b.priority desc, b.starts_at desc, b.id
    limit 10
  ) x;
$$;

create or replace function public.get_client_config(p_platform text default null, p_app_version text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    'banners', private.client_banners(v_platform, v_version),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'server_time', now()));
end;
$$;

create or replace function cs_api.admin_banners()
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
    select jsonb_agg(private.app_banner_view(b)
                     order by (b.ends_at is not null and b.ends_at <= now()), b.priority desc, b.starts_at desc, b.id)
    from private.app_banners b), '[]');
end;
$$;

create or replace function cs_api.admin_save_banner(
  p_id              uuid,
  p_title           text,
  p_body            text default '',
  p_link_url        text default null,
  p_level           text default 'info',
  p_starts_at       timestamptz default null,
  p_ends_at         timestamptz default null,
  p_platforms       text[] default '{}',
  p_min_app_version text default null,
  p_max_app_version text default null,
  p_dismissible     boolean default true,
  p_priority        integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin}');
  v_title     text := btrim(coalesce(p_title, ''));
  v_body      text := btrim(coalesce(p_body, ''));
  v_url       text := nullif(btrim(coalesce(p_link_url, '')), '');
  v_level     text := lower(btrim(coalesce(p_level, 'info')));
  v_platforms text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                                  from unnest(coalesce(p_platforms, '{}')) x where btrim(x) <> ''), '{}');
  v_min       text := nullif(btrim(coalesce(p_min_app_version, '')), '');
  v_max       text := nullif(btrim(coalesce(p_max_app_version, '')), '');
  v_old       private.app_banners;
  v_new       private.app_banners;
begin
  if char_length(v_title) not between 1 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul banner 1–80 karakter');
  end if;
  if char_length(v_body) > 300 then
    perform private.api_error(400, 'invalid_body', 'Isi banner maksimal 300 karakter');
  end if;
  if v_url is not null and (v_url !~ '^https?://[^\s]+$' or char_length(v_url) > 500) then
    perform private.api_error(400, 'invalid_link', 'Tautan harus http(s):// dan maksimal 500 karakter');
  end if;
  if v_level not in ('info', 'warning', 'critical') then
    perform private.api_error(400, 'invalid_level', 'Level banner: info, warning, atau critical');
  end if;
  if not v_platforms <@ private.client_platforms() then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, web, windows, macos, atau linux');
  end if;
  if (v_min is not null and v_min !~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$')
     or (v_max is not null and v_max !~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$') then
    perform private.api_error(400, 'invalid_version', 'Versi harus berformat angka, mis. 2.4.0');
  end if;
  if v_min is not null and v_max is not null and private.version_parts(v_min) > private.version_parts(v_max) then
    perform private.api_error(400, 'invalid_version', 'Versi minimum tidak boleh lebih tinggi dari versi maksimum');
  end if;
  if coalesce(p_priority, 0) not between 0 and 1000 then
    perform private.api_error(400, 'invalid_priority', 'Prioritas 0–1000');
  end if;
  if p_ends_at is not null and p_ends_at <= coalesce(p_starts_at, now()) then
    perform private.api_error(400, 'invalid_schedule', 'Waktu selesai harus setelah waktu mulai');
  end if;

  if p_id is null then
    insert into private.app_banners (title, body, link_url, level, starts_at, ends_at, platforms, min_app_version,
                                     max_app_version, dismissible, priority, created_by, updated_by)
    values (v_title, v_body, v_url, v_level, coalesce(p_starts_at, now()), p_ends_at, v_platforms, v_min, v_max,
            coalesce(p_dismissible, true), coalesce(p_priority, 0), v_me, v_me)
    returning * into v_new;
  else
    select * into v_old from private.app_banners b where b.id = p_id for update;
    if not found then
      perform private.api_error(404, 'banner_not_found', 'Banner tidak ditemukan');
    end if;
    update private.app_banners
       set title = v_title, body = v_body, link_url = v_url, level = v_level,
           starts_at = coalesce(p_starts_at, v_old.starts_at), ends_at = p_ends_at, platforms = v_platforms,
           min_app_version = v_min, max_app_version = v_max, dismissible = coalesce(p_dismissible, true),
           priority = coalesce(p_priority, 0), updated_by = v_me, updated_at = now()
     where id = p_id
    returning * into v_new;
  end if;

  perform cs.audit('banner.save', null, null, jsonb_build_object(
    'id', v_new.id,
    'before', case when v_old.id is not null
                   then to_jsonb(v_old) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at' end,
    'after', to_jsonb(v_new) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at'));
  return private.app_banner_view(v_new);
end;
$$;

create or replace function cs_api.admin_delete_banner(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old private.app_banners;
begin
  delete from private.app_banners b where b.id = p_id returning * into v_old;
  if v_old.id is null then
    perform private.api_error(404, 'banner_not_found', 'Banner tidak ditemukan');
  end if;
  perform cs.audit('banner.delete', null, null, jsonb_build_object(
    'id', v_old.id, 'before', to_jsonb(v_old) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at'));
  return jsonb_build_object('id', v_old.id, 'deleted', true);
end;
$$;

revoke execute on function private.app_banner_view(private.app_banners) from public;
revoke execute on function private.client_banners(text, text) from public;
revoke execute on function cs_api.admin_banners() from public;
revoke execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                    text, boolean, integer) from public;
revoke execute on function cs_api.admin_delete_banner(uuid) from public;

grant execute on function cs_api.admin_banners() to authenticated;
grant execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                   text, boolean, integer) to authenticated;
grant execute on function cs_api.admin_delete_banner(uuid) to authenticated;
