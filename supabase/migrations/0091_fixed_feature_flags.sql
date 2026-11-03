create or replace function private.known_feature_flags()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['search', 'trending', 'bookmarks', 'post_edit', 'message_reactions', 'share_post_to_chat',
               'notification_prefs', 'analytics'];
$$;

delete from private.feature_flags where not (key = any (private.known_feature_flags()));

insert into private.feature_flags (key, enabled, percentage, user_ids, platforms, description) values
  ('search', true, 100, '{}', '{}', 'Pencarian post, pengguna, saham, dan hashtag'),
  ('trending', true, 100, '{}', '{}', 'Halaman trending, sentimen saham, dan hashtag populer'),
  ('bookmarks', true, 100, '{}', '{}', 'Simpan postingan'),
  ('post_edit', true, 100, '{}', '{}', 'Edit postingan dan komentar dalam batas waktu'),
  ('message_reactions', true, 100, '{}', '{}', 'Reaksi emoji pada pesan chat'),
  ('share_post_to_chat', true, 100, '{}', '{}', 'Bagikan postingan ke chat'),
  ('notification_prefs', true, 100, '{}', '{}', 'Pengaturan notifikasi dan jam tenang'),
  ('analytics', true, 100, '{}', '{}', 'Pengiriman event analitik dari aplikasi')
on conflict (key) do nothing;

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
                         'updated_at', f.updated_at)
                         order by array_position(private.known_feature_flags(), f.key))
                       from private.feature_flags f
                       where f.key = any (private.known_feature_flags())), '[]'),
    'min_versions', coalesce((select jsonb_agg(jsonb_build_object(
                                'platform', v.platform, 'min_version', v.min_version,
                                'updated_by', cs.staff_ref(v.updated_by), 'updated_at', v.updated_at) order by v.platform)
                              from private.client_versions v), '[]'));
$$;

create or replace function cs_api.admin_set_feature_flag(p_key text, p_enabled boolean, p_percentage integer DEFAULT 100, p_user_ids uuid[] DEFAULT '{}'::uuid[], p_platforms text[] DEFAULT '{}'::text[], p_min_app_version text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
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
  if not (v_key = any (private.known_feature_flags())) then
    perform private.api_error(400, 'unknown_flag', 'Flag tidak dikenal aplikasi');
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
$$;

create or replace function cs_api.admin_toggle_feature_flag(p_key text, p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_key text := lower(btrim(coalesce(p_key, '')));
  v_old private.feature_flags;
  v_new private.feature_flags;
begin
  if not (v_key = any (private.known_feature_flags())) then
    perform private.api_error(400, 'unknown_flag', 'Flag tidak dikenal aplikasi');
  end if;
  if p_enabled is null then
    perform private.api_error(400, 'invalid_flag', 'enabled wajib diisi');
  end if;

  select * into v_old from private.feature_flags f where f.key = v_key for update;
  insert into private.feature_flags as f (key, enabled, updated_by, updated_at)
  values (v_key, p_enabled, v_me, now())
  on conflict (key) do update
    set enabled = excluded.enabled, updated_by = v_me, updated_at = now()
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
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  perform private.api_error(400, 'flag_not_deletable', 'Daftar fitur tetap; matikan fitur alih-alih menghapusnya');
  return null;
end;
$$;

revoke execute on function private.known_feature_flags() from public;
revoke execute on function cs_api.admin_toggle_feature_flag(text, boolean) from public;
grant execute on function cs_api.admin_toggle_feature_flag(text, boolean) to authenticated;
