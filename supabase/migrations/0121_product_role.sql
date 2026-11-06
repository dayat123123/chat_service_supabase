alter table cs.agents drop constraint agents_roles_check;
alter table cs.agents add constraint agents_roles_check
  check (cardinality(roles) > 0 and roles <@ array['cs_agent', 'cs_super_admin', 'compliance', 'community', 'product']);

create or replace function cs.check_agent_input(p_display_name text, p_roles text[], p_team text, p_max integer)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if char_length(btrim(coalesce(p_display_name, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama CS 2–40 karakter');
  end if;
  if coalesce(cardinality(p_roles), 0) = 0
     or not (p_roles <@ '{cs_agent,cs_super_admin,compliance,community,product}'::text[]) then
    perform private.api_error(400, 'invalid_roles',
      'Peran harus cs_agent, cs_super_admin, compliance, community, atau product');
  end if;
  if p_team is not null and not exists (select 1 from cs.teams t where t.code = p_team and t.active) then
    perform private.api_error(400, 'invalid_team', 'Tim tidak dikenal');
  end if;
  if coalesce(p_max, 0) not between 1 and 20 then
    perform private.api_error(400, 'invalid_limit', 'Batas tiket aktif 1–20');
  end if;
end;
$$;

create or replace function private.can_manage_banners()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.has_role('{cs_super_admin,product}');
$$;

create or replace function cs_api.admin_feature_flags()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
begin
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
  v_me     uuid := cs.require_agent('{cs_super_admin,product}');
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
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin,product}');
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

create or replace function cs_api.admin_set_feature_flag(p_key text, p_enabled boolean, p_percentage integer DEFAULT 100, p_user_ids uuid[] DEFAULT '{}'::uuid[], p_platforms text[] DEFAULT '{}'::text[], p_min_app_version text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin,product}');
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
  v_me  uuid := cs.require_agent('{cs_super_admin,product}');
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
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
begin
  perform private.api_error(400, 'flag_not_deletable', 'Daftar fitur tetap; matikan fitur alih-alih menghapusnya');
  return null;
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
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
begin
  return coalesce((
    select jsonb_agg(private.app_banner_view(b)
                     order by (b.ends_at is not null and b.ends_at <= now()), b.priority desc, b.starts_at desc, b.id)
    from private.app_banners b), '[]');
end;
$$;

create or replace function cs_api.admin_banner_stats(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin,product}');
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
begin
  if not exists (select 1 from private.app_banners b where b.id = p_id) then
    perform private.api_error(404, 'banner_not_found', 'Banner tidak ditemukan');
  end if;
  return private.app_banner_stats(p_id) || jsonb_build_object(
    'id', p_id,
    'days', (select jsonb_agg(jsonb_build_object(
                      'day', d.day, 'impressions', coalesce(s.impressions, 0), 'clicks', coalesce(s.clicks, 0),
                      'dismissals', coalesce(s.dismissals, 0),
                      'ctr', case when coalesce(s.impressions, 0) > 0 then round(100.0 * s.clicks / s.impressions, 1) end)
                    order by d.day)
             from (select (v_today - g)::date as day from generate_series(0, 6) g) d
             left join (select e.day,
                               count(*) filter (where e.event = 'impression')::integer as impressions,
                               count(*) filter (where e.event = 'click')::integer as clicks,
                               count(*) filter (where e.event = 'dismiss')::integer as dismissals
                        from private.app_banner_events e
                        where e.banner_id = p_id and e.day > v_today - 7
                        group by e.day) s on s.day = d.day));
end;
$$;

create or replace function cs_api.admin_banner_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
begin
  return jsonb_build_object(
    'deep_link_schemes', to_jsonb(private.banner_link_schemes()),
    'forbidden_schemes', to_jsonb(private.banner_forbidden_schemes()),
    'max_schemes', 5,
    'updated_at', (select s.updated_at from cs.cs_settings s where s.key = 'banners.deep_link_schemes'),
    'updated_by', (select cs.staff_ref(s.updated_by) from cs.cs_settings s where s.key = 'banners.deep_link_schemes'));
end;
$$;

create or replace function cs_api.admin_set_banner_link_schemes(p_schemes text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin,product}');
  v_schemes text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                                from unnest(coalesce(p_schemes, '{}')) x where btrim(x) <> ''), '{}');
  v_old     jsonb := cs.setting('banners.deep_link_schemes');
begin
  if cardinality(v_schemes) > 5 then
    perform private.api_error(400, 'invalid_link_schemes', 'Maksimal 5 skema deep link');
  end if;
  if exists (select 1 from unnest(v_schemes) x where x !~ '^[a-z][a-z0-9+.-]{0,31}$') then
    perform private.api_error(400, 'invalid_link_schemes',
      'Skema diawali huruf, hanya huruf kecil, angka, +, titik, atau -, maksimal 32 karakter');
  end if;
  if v_schemes && private.banner_forbidden_schemes() then
    perform private.api_error(400, 'invalid_link_schemes',
      'Skema ' || array_to_string(array(select x from unnest(v_schemes) x
                                        where x = any (private.banner_forbidden_schemes())), ', ')
      || ' tidak boleh dipakai sebagai deep link');
  end if;
  perform cs.set_setting('banners.deep_link_schemes', to_jsonb(v_schemes), v_me);
  perform cs.audit('banner.link_schemes', null, null, jsonb_build_object('before', v_old, 'after', to_jsonb(v_schemes)));
  return cs_api.admin_banner_settings();
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
  p_priority        integer default 0,
  p_display         text default 'strip',
  p_image_url       text default null,
  p_cta_label       text default null,
  p_frequency       text default 'once',
  p_audience        text default 'all',
  p_audience_days   integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin,product}');
  v_title     text := btrim(coalesce(p_title, ''));
  v_body      text := btrim(coalesce(p_body, ''));
  v_url       text := nullif(btrim(coalesce(p_link_url, '')), '');
  v_level     text := lower(btrim(coalesce(p_level, 'info')));
  v_platforms text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                                  from unnest(coalesce(p_platforms, '{}')) x where btrim(x) <> ''), '{}');
  v_min       text := nullif(btrim(coalesce(p_min_app_version, '')), '');
  v_max       text := nullif(btrim(coalesce(p_max_app_version, '')), '');
  v_display   text := lower(btrim(coalesce(p_display, 'strip')));
  v_image_url text := nullif(btrim(coalesce(p_image_url, '')), '');
  v_image     text;
  v_cta       text := nullif(btrim(coalesce(p_cta_label, '')), '');
  v_frequency text := lower(btrim(coalesce(p_frequency, 'once')));
  v_audience  text := lower(btrim(coalesce(p_audience, 'all')));
  v_days      integer := coalesce(p_audience_days, 7);
  v_old       private.app_banners;
  v_new       private.app_banners;
begin
  if v_display not in ('strip', 'popup') then
    perform private.api_error(400, 'invalid_display', 'Tampilan banner: strip atau popup');
  end if;
  if char_length(v_title) not between 1 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul banner 1–80 karakter');
  end if;
  if char_length(v_body) > 300 then
    perform private.api_error(400, 'invalid_body', 'Isi banner maksimal 300 karakter');
  end if;
  if v_url is not null and not private.banner_link_valid(v_url) then
    perform private.api_error(400, 'invalid_link',
      'Tautan harus https://… atau deep link dengan skema yang diizinkan ('
      || coalesce(nullif(array_to_string(array(select s || '://' from unnest(private.banner_link_schemes()) s), ', '), ''), '-')
      || '), tanpa spasi, maksimal 500 karakter');
  end if;
  if v_cta is not null and char_length(v_cta) > 24 then
    perform private.api_error(400, 'invalid_cta', 'Label tombol maksimal 24 karakter');
  end if;
  if v_cta is not null and v_url is null then
    perform private.api_error(400, 'invalid_cta', 'Label tombol hanya bisa diisi bila ada tautan');
  end if;
  if v_frequency not in ('once', 'daily', 'every_open') then
    perform private.api_error(400, 'invalid_frequency', 'Frekuensi: once, daily, atau every_open');
  end if;
  if v_audience not in ('all', 'new_users') then
    perform private.api_error(400, 'invalid_audience', 'Sasaran: all atau new_users');
  end if;
  if v_days not between 1 and 90 then
    perform private.api_error(400, 'invalid_audience', 'Pengguna baru 1–90 hari');
  end if;
  if v_image_url is not null then
    if v_display <> 'popup' then
      perform private.api_error(400, 'invalid_image', 'Gambar hanya untuk banner popup');
    end if;
    v_image := substring(v_image_url from
      '^https?://[^\s/?#]+(?:/[^\s?#]*)?/storage/v1/object/public/app-banners/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(?:jpg|png|webp))$');
    if v_image is null or char_length(v_image_url) > 600
       or not exists (select 1 from storage.objects o where o.bucket_id = 'app-banners' and o.name = v_image) then
      perform private.api_error(400, 'invalid_image', 'Gambar banner tidak ditemukan, unggah ulang');
    end if;
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
  if v_display = 'strip' then
    v_frequency := 'once';
  end if;
  if v_audience = 'all' then
    v_days := 7;
  end if;

  if p_id is null then
    insert into private.app_banners (title, body, link_url, level, starts_at, ends_at, platforms, min_app_version,
                                     max_app_version, dismissible, priority, display, image_path, image_url, cta_label,
                                     frequency, audience, audience_days, created_by, updated_by)
    values (v_title, v_body, v_url, v_level, coalesce(p_starts_at, now()), p_ends_at, v_platforms, v_min, v_max,
            coalesce(p_dismissible, true), coalesce(p_priority, 0), v_display, v_image, v_image_url, v_cta,
            v_frequency, v_audience, v_days, v_me, v_me)
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
           priority = coalesce(p_priority, 0), display = v_display, image_path = v_image, image_url = v_image_url,
           cta_label = v_cta, frequency = v_frequency, audience = v_audience, audience_days = v_days,
           updated_by = v_me, updated_at = now()
     where id = p_id
    returning * into v_new;
    if v_old.image_path is distinct from v_new.image_path then
      perform private.queue_banner_image(v_old.image_path);
    end if;
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
  v_me  uuid := cs.require_agent('{cs_super_admin,product}');
  v_old private.app_banners;
begin
  delete from private.app_banners b where b.id = p_id returning * into v_old;
  if v_old.id is null then
    perform private.api_error(404, 'banner_not_found', 'Banner tidak ditemukan');
  end if;
  perform private.queue_banner_image(v_old.image_path);
  perform cs.audit('banner.delete', null, null, jsonb_build_object(
    'id', v_old.id, 'before', to_jsonb(v_old) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at'));
  return jsonb_build_object('id', v_old.id, 'deleted', true);
end;
$$;
