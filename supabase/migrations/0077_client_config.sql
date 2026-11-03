create table private.feature_flags (
  key             text primary key check (key ~ '^[a-z][a-z0-9_.]{1,49}$' and key <> 'social.enabled'),
  enabled         boolean not null default false,
  percentage      integer not null default 100 check (percentage between 0 and 100),
  user_ids        uuid[] not null default '{}' check (cardinality(user_ids) <= 1000),
  platforms       text[] not null default '{}' check (platforms <@ array['android', 'ios', 'web']),
  min_app_version text check (min_app_version ~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$'),
  description     text check (char_length(description) <= 300),
  created_at      timestamptz not null default now(),
  updated_by      uuid,
  updated_at      timestamptz not null default now()
);
alter table private.feature_flags enable row level security;

insert into private.feature_flags (key, enabled, description) values
  ('search', true, 'Pencarian post, pengguna, saham, dan hashtag'),
  ('trending', true, 'Halaman trending, sentimen saham, dan hashtag populer'),
  ('bookmarks', true, 'Simpan postingan'),
  ('post_edit', true, 'Edit postingan dan komentar dalam batas waktu'),
  ('message_reactions', true, 'Reaksi emoji pada pesan chat'),
  ('share_post_to_chat', true, 'Bagikan postingan ke chat'),
  ('notification_prefs', true, 'Pengaturan notifikasi dan jam tenang'),
  ('analytics', true, 'Pengiriman event analitik dari aplikasi')
on conflict (key) do nothing;

create table private.kill_switch (
  singleton      boolean primary key default true check (singleton),
  social_enabled boolean not null default true,
  reason         text,
  changed_by     uuid,
  changed_at     timestamptz
);
alter table private.kill_switch enable row level security;
insert into private.kill_switch (singleton) values (true) on conflict do nothing;

create table private.client_versions (
  platform    text primary key check (platform in ('android', 'ios', 'web')),
  min_version text check (min_version ~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$'),
  updated_by  uuid,
  updated_at  timestamptz not null default now()
);
alter table private.client_versions enable row level security;
insert into private.client_versions (platform) values ('android'), ('ios'), ('web') on conflict do nothing;

create or replace function private.version_parts(p_version text)
returns integer[]
language sql
immutable
set search_path = ''
as $$
  select case when p_version ~ '^[0-9]{1,5}(\.[0-9]{1,5}){0,3}([+-][0-9A-Za-z.-]{0,40})?$' then (
    select array_agg(t.x::integer order by t.n) || array_fill(0, array[4 - count(*)::integer])
    from unnest(string_to_array(substring(p_version from '^[0-9.]+'), '.')) with ordinality as t(x, n))
  end;
$$;

create or replace function private.rollout_bucket(p_key text, p_user uuid)
returns integer
language sql
immutable
set search_path = ''
as $$
  select (('x' || substr(md5(p_key || ':' || p_user::text), 1, 8))::bit(32)::bigint % 100)::integer;
$$;

create or replace function private.flag_enabled(f private.feature_flags, p_user uuid, p_platform text, p_version text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select f.enabled
     and (cardinality(f.platforms) = 0 or coalesce(p_platform = any (f.platforms), false))
     and (f.min_app_version is null
          or coalesce(private.version_parts(p_version) >= private.version_parts(f.min_app_version), false))
     and (f.percentage >= 100
          or coalesce(p_user = any (f.user_ids), false)
          or (p_user is not null and private.rollout_bucket(f.key, p_user) < f.percentage));
$$;

create or replace function private.social_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select k.social_enabled from private.kill_switch k where k.singleton), true);
$$;

create or replace function private.feature_enabled(p_key text, p_user uuid default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select private.flag_enabled(f, p_user, null, null) from private.feature_flags f where f.key = p_key),
                  false);
$$;

create or replace function private.enforce_kill_switch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_end_user() or private.social_enabled() then
    return new;
  end if;
  if tg_op = 'UPDATE' and (new.deleted_at is not null or new.body is not distinct from old.body) then
    return new;
  end if;
  if tg_table_name = 'messages'
     and ((to_jsonb(new) ->> 'session_id') is not null
          or exists (select 1 from public.chat_rooms r where r.id = (to_jsonb(new) ->> 'room_id')::uuid
                     and r.type = 'support')) then
    return new;
  end if;
  perform private.api_error(503, 'social_disabled', 'Fitur komunitas sedang dinonaktifkan sementara');
  return new;
end;
$$;

create trigger posts_41_kill_switch
  before insert or update of body on public.posts
  for each row execute function private.enforce_kill_switch();
create trigger comments_41_kill_switch
  before insert or update of body on public.comments
  for each row execute function private.enforce_kill_switch();
create trigger messages_41_kill_switch
  before insert or update of body on public.messages
  for each row execute function private.enforce_kill_switch();

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
  if v_platform is not null and v_platform not in ('android', 'ios', 'web') then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, atau web');
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
$$;

create or replace function cs.feature_flags_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'kill_switch', (select jsonb_build_object('social_enabled', k.social_enabled, 'reason', k.reason,
                                              'changed_by', cs.staff_ref(k.changed_by), 'changed_at', k.changed_at)
                    from private.kill_switch k where k.singleton),
    'flags', coalesce((select jsonb_agg(jsonb_build_object(
                         'key', f.key, 'enabled', f.enabled, 'percentage', f.percentage, 'user_ids', to_jsonb(f.user_ids),
                         'platforms', to_jsonb(f.platforms), 'min_app_version', f.min_app_version,
                         'description', f.description, 'updated_by', cs.staff_ref(f.updated_by),
                         'updated_at', f.updated_at) order by f.key)
                       from private.feature_flags f), '[]'),
    'min_versions', coalesce((select jsonb_agg(jsonb_build_object(
                                'platform', v.platform, 'min_version', v.min_version,
                                'updated_by', cs.staff_ref(v.updated_by), 'updated_at', v.updated_at) order by v.platform)
                              from private.client_versions v), '[]'));
$$;

create or replace function cs_api.admin_feature_flags()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return cs.feature_flags_view();
end;
$$;

create or replace function cs_api.admin_set_feature_flag(
  p_key             text,
  p_enabled         boolean,
  p_percentage      integer default 100,
  p_user_ids        uuid[] default '{}',
  p_platforms       text[] default '{}',
  p_min_app_version text default null,
  p_description     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
        description = coalesce(excluded.description, f.description), updated_by = v_me, updated_at = now()
  returning * into v_new;

  perform cs.audit('feature_flag.set', null, null, jsonb_build_object(
    'key', v_key,
    'before', case when v_old.key is not null then to_jsonb(v_old) - 'updated_by' - 'updated_at' - 'created_at' end,
    'after', to_jsonb(v_new) - 'updated_by' - 'updated_at' - 'created_at'));
  return cs.feature_flags_view();
end;
$$;

create or replace function cs_api.admin_delete_feature_flag(p_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old private.feature_flags;
begin
  delete from private.feature_flags f where f.key = lower(btrim(coalesce(p_key, ''))) returning * into v_old;
  if v_old.key is null then
    perform private.api_error(404, 'flag_not_found', 'Flag tidak ditemukan');
  end if;
  perform cs.audit('feature_flag.delete', null, null, jsonb_build_object(
    'key', v_old.key, 'before', to_jsonb(v_old) - 'updated_by' - 'updated_at' - 'created_at'));
  return cs.feature_flags_view();
end;
$$;

create or replace function cs_api.admin_set_kill_switch(p_enabled boolean, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_reason text := btrim(regexp_replace(coalesce(p_reason, ''), '\s+', ' ', 'g'));
  v_old    boolean;
begin
  if p_enabled is null then
    perform private.api_error(400, 'invalid_kill_switch', 'Status fitur komunitas wajib diisi');
  end if;
  if char_length(v_reason) not between 10 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan wajib diisi (10-500 karakter)');
  end if;
  select k.social_enabled into v_old from private.kill_switch k where k.singleton for update;
  update private.kill_switch
     set social_enabled = p_enabled, reason = v_reason, changed_by = v_me, changed_at = now()
   where singleton;
  perform cs.audit('kill_switch.set', null, null, jsonb_build_object(
    'social_enabled', p_enabled, 'previous', v_old, 'reason', v_reason));
  return cs.feature_flags_view();
end;
$$;

create or replace function cs_api.admin_set_min_version(p_platform text, p_min_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_platform text := lower(btrim(coalesce(p_platform, '')));
  v_version  text := nullif(btrim(coalesce(p_min_version, '')), '');
  v_old      text;
begin
  if v_platform not in ('android', 'ios', 'web') then
    perform private.api_error(400, 'invalid_platform', 'Platform harus android, ios, atau web');
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
$$;

revoke execute on function private.version_parts(text) from public;
revoke execute on function private.rollout_bucket(text, uuid) from public;
revoke execute on function private.flag_enabled(private.feature_flags, uuid, text, text) from public;
revoke execute on function private.social_enabled() from public;
revoke execute on function private.feature_enabled(text, uuid) from public;
revoke execute on function private.enforce_kill_switch() from public;
revoke execute on function cs.feature_flags_view() from public;
revoke execute on function public.get_client_config(text, text) from public;
revoke execute on function cs_api.admin_feature_flags() from public;
revoke execute on function cs_api.admin_set_feature_flag(text, boolean, integer, uuid[], text[], text, text) from public;
revoke execute on function cs_api.admin_delete_feature_flag(text) from public;
revoke execute on function cs_api.admin_set_kill_switch(boolean, text) from public;
revoke execute on function cs_api.admin_set_min_version(text, text) from public;
grant execute on function public.get_client_config(text, text) to anon, authenticated;
grant execute on function cs_api.admin_feature_flags() to authenticated;
grant execute on function cs_api.admin_set_feature_flag(text, boolean, integer, uuid[], text[], text, text) to authenticated;
grant execute on function cs_api.admin_delete_feature_flag(text) to authenticated;
grant execute on function cs_api.admin_set_kill_switch(boolean, text) to authenticated;
grant execute on function cs_api.admin_set_min_version(text, text) to authenticated;
