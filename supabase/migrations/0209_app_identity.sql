create or replace function private.app_identity_defaults()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select '{"app_name": "OLT", "android": [], "ios_app_ids": [], "android_store_url": "", "ios_store_url": "", "windows_download_url": "", "macos_download_url": ""}'::jsonb;
$$;

insert into cs.cs_settings (key, value, description)
select 'app.identity',
       private.app_identity_defaults() || jsonb_strip_nulls(jsonb_build_object(
         'app_name', s.value -> 'app_name',
         'android', s.value -> 'android',
         'ios_app_ids', s.value -> 'ios_app_ids',
         'android_store_url', s.value -> 'android_store_url',
         'ios_store_url', s.value -> 'ios_store_url',
         'windows_download_url', s.value -> 'windows_download_url',
         'macos_download_url', s.value -> 'macos_download_url')),
       'Identitas aplikasi OLT: nama, Android (package + fingerprint SHA-256), App ID iOS/Mac, dan tautan unduh. Dipakai tautan berbagi; skema aplikasi ada di banners.deep_link_schemes'
from cs.cs_settings s
where s.key = 'share.links' and jsonb_typeof(s.value) = 'object'
on conflict (key) do nothing;

insert into cs.cs_settings (key, value, description)
values ('app.identity', private.app_identity_defaults(),
        'Identitas aplikasi OLT: nama, Android (package + fingerprint SHA-256), App ID iOS/Mac, dan tautan unduh. Dipakai tautan berbagi; skema aplikasi ada di banners.deep_link_schemes')
on conflict (key) do nothing;

update cs.cs_settings
   set value = jsonb_build_object(
         'enabled', coalesce((value ->> 'enabled')::boolean, false),
         'base_url', coalesce(value ->> 'base_url', ''),
         'preview', coalesce((value ->> 'preview')::boolean, true)),
       description = 'Tautan berbagi post: aktif, domain publik, dan pratinjau isi. Identitas aplikasi ada di app.identity, skema di banners.deep_link_schemes'
 where key = 'share.links' and jsonb_typeof(value) = 'object';

create or replace function private.banner_link_schemes()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select array_agg(x order by n)
                   from jsonb_array_elements_text(
                          case when jsonb_typeof(cs.setting('banners.deep_link_schemes')) = 'array'
                               then cs.setting('banners.deep_link_schemes') else '["olt"]' end) with ordinality t(x, n)
                   where x ~ '^[a-z][a-z0-9+.-]{0,31}$' and x <> all (private.banner_forbidden_schemes())), '{}');
$$;

create or replace function cs_api.admin_set_banner_link_schemes(p_schemes text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin}');
  v_schemes text[] := coalesce((select array_agg(x order by n)
                                from (select lower(btrim(x)) as x, min(n) as n
                                      from unnest(coalesce(p_schemes, '{}')) with ordinality t(x, n)
                                      where btrim(x) <> ''
                                      group by lower(btrim(x))) s), '{}');
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

create or replace function private.app_scheme()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((private.banner_link_schemes())[1], '');
$$;

create or replace function private.app_identity()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.app_identity_defaults() || coalesce(
    (select s.value from cs.cs_settings s where s.key = 'app.identity' and jsonb_typeof(s.value) = 'object'), '{}');
$$;

create or replace function private.share_links_defaults()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select '{"enabled": false, "base_url": "", "preview": true}'::jsonb;
$$;

create or replace function private.share_links_settings()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.share_links_defaults() || coalesce(
    (select jsonb_strip_nulls(jsonb_build_object(
              'enabled', s.value -> 'enabled', 'base_url', s.value -> 'base_url', 'preview', s.value -> 'preview'))
     from cs.cs_settings s where s.key = 'share.links' and jsonb_typeof(s.value) = 'object'), '{}');
$$;

create or replace function private.share_links_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.share_links_settings() || private.app_identity() || jsonb_build_object('app_scheme', private.app_scheme());
$$;

create or replace function public.post_share_link(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := auth.uid();
  v_code   text;
  v_scheme text := private.app_scheme();
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated', 'Silakan masuk terlebih dahulu');
  end if;
  if not private.share_links_ready() then
    perform private.api_error(403, 'share_links_disabled', 'Tautan berbagi belum diaktifkan');
  end if;
  if p_post_id is null
     or not private.post_shareable(p_post_id)
     or not exists (select 1 from public.posts p
                    where p.id = p_post_id
                      and not (p.author_id in (select private.blocked_user_ids()))) then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;

  select c.code into v_code from private.post_share_codes c where c.post_id = p_post_id;
  if v_code is null then
    perform private.consume_rate_limit(v_me, 'post_share_link');
    loop
      v_code := private.new_share_code();
      begin
        insert into private.post_share_codes (code, post_id, created_by) values (v_code, p_post_id, v_me)
        on conflict (post_id) do nothing;
        exit;
      exception when unique_violation then
        null;
      end;
    end loop;
    select c.code into v_code from private.post_share_codes c where c.post_id = p_post_id;
  end if;

  return jsonb_build_object(
    'code', v_code,
    'url', private.share_link_url(v_code),
    'app_url', case when v_scheme <> '' then v_scheme || '://p/' || v_code end);
end;
$$;

create or replace function cs.check_share_links(p_config jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_base text;
begin
  if p_config is null or jsonb_typeof(p_config) <> 'object' then
    perform private.api_error(400, 'invalid_share_links', 'Pengaturan tautan berbagi harus berupa objek');
  end if;
  if jsonb_typeof(p_config -> 'enabled') is distinct from 'boolean'
     or jsonb_typeof(p_config -> 'preview') is distinct from 'boolean' then
    perform private.api_error(400, 'invalid_share_links', 'Saklar aktif dan pratinjau harus benar/salah');
  end if;
  v_base := regexp_replace(btrim(coalesce(p_config ->> 'base_url', '')), '/+$', '');
  if v_base <> '' and (char_length(v_base) > 200
     or v_base !~ '^https?://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?$') then
    perform private.api_error(400, 'invalid_share_base_url',
      'Domain tautan harus berupa http:// atau https:// diikuti host (dan port), tanpa path');
  end if;
  if (p_config ->> 'enabled')::boolean and v_base = '' then
    perform private.api_error(400, 'share_base_url_required', 'Isi domain tautan sebelum mengaktifkan tautan berbagi');
  end if;
  return jsonb_build_object('enabled', (p_config ->> 'enabled')::boolean, 'base_url', v_base,
                            'preview', (p_config ->> 'preview')::boolean);
end;
$$;

create or replace function cs.check_app_identity(p_identity jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_name    text;
  v_android jsonb := '[]';
  v_ios     jsonb := '[]';
  v_item    jsonb;
  v_package text;
  v_prints  jsonb;
  v_print   text;
  v_id      text;
begin
  if p_identity is null or jsonb_typeof(p_identity) <> 'object' then
    perform private.api_error(400, 'invalid_app_identity', 'Identitas aplikasi harus berupa objek');
  end if;

  v_name := btrim(coalesce(p_identity ->> 'app_name', ''));
  if char_length(v_name) not between 1 and 40 or v_name ~ '[[:cntrl:]<>]' then
    perform private.api_error(400, 'invalid_share_app_name', 'Nama aplikasi 1–40 karakter, tanpa < atau >');
  end if;

  if jsonb_typeof(coalesce(p_identity -> 'android', '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_identity -> 'android', '[]')) > 5 then
    perform private.api_error(400, 'invalid_share_android', 'Maksimal 5 aplikasi Android');
  end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_identity -> 'android', '[]')) loop
    v_package := btrim(coalesce(v_item ->> 'package', ''));
    if char_length(v_package) > 150 or v_package !~ '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$' then
      perform private.api_error(400, 'invalid_share_android_package', 'Package name Android tidak valid, mis. com.perusahaan.app');
    end if;
    if jsonb_typeof(v_item -> 'sha256') is distinct from 'array'
       or jsonb_array_length(v_item -> 'sha256') not between 1 and 5 then
      perform private.api_error(400, 'invalid_share_android_fingerprint', 'Isi 1–5 fingerprint SHA-256 per aplikasi Android');
    end if;
    v_prints := '[]';
    for v_print in select upper(btrim(x)) from jsonb_array_elements_text(v_item -> 'sha256') x loop
      if v_print !~ '^([0-9A-F]{2}:){31}[0-9A-F]{2}$' then
        perform private.api_error(400, 'invalid_share_android_fingerprint',
          'Fingerprint SHA-256 harus 32 pasang heksadesimal dipisah titik dua, mis. AB:CD:…');
      end if;
      if not v_prints ? v_print then
        v_prints := v_prints || to_jsonb(v_print);
      end if;
    end loop;
    v_android := v_android || jsonb_build_array(jsonb_build_object('package', v_package, 'sha256', v_prints));
  end loop;

  if jsonb_typeof(coalesce(p_identity -> 'ios_app_ids', '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_identity -> 'ios_app_ids', '[]')) > 5 then
    perform private.api_error(400, 'invalid_share_ios', 'Maksimal 5 App ID iOS/Mac');
  end if;
  for v_id in select btrim(x) from jsonb_array_elements_text(coalesce(p_identity -> 'ios_app_ids', '[]')) x loop
    if char_length(v_id) > 160 or v_id !~ '^[A-Z0-9]{10}\.[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*$' then
      perform private.api_error(400, 'invalid_share_ios_app_id', 'App ID harus TEAMID.bundle.id, mis. ABCDE12345.com.perusahaan.app');
    end if;
    if not v_ios ? v_id then
      v_ios := v_ios || to_jsonb(v_id);
    end if;
  end loop;

  return jsonb_build_object(
    'app_name', v_name,
    'android', v_android,
    'ios_app_ids', v_ios,
    'android_store_url', cs.share_links_https(p_identity -> 'android_store_url', 'Play Store'),
    'ios_store_url', cs.share_links_https(p_identity -> 'ios_store_url', 'App Store'),
    'windows_download_url', cs.share_links_https(p_identity -> 'windows_download_url', 'unduhan Windows'),
    'macos_download_url', cs.share_links_https(p_identity -> 'macos_download_url', 'unduhan Mac'));
end;
$$;

create or replace function cs_api.admin_save_share_links(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old jsonb := private.share_links_settings();
  v_new jsonb := cs.check_share_links(p_config);
begin
  if v_new is distinct from v_old then
    perform cs.set_setting('share.links', v_new, v_me);
    perform cs.audit('setting.share_links', null, null, jsonb_build_object('before', v_old, 'after', v_new));
  end if;
  return cs_api.share_links();
end;
$$;

create or replace function cs_api.app_identity()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return (
    select jsonb_build_object(
      'identity', private.app_identity(),
      'app_scheme', private.app_scheme(),
      'version', s.version,
      'updated_at', s.updated_at,
      'updated_by', a.display_name)
    from cs.cs_settings s
    left join cs.agents a on a.user_id = s.updated_by
    where s.key = 'app.identity');
end;
$$;

create or replace function cs_api.admin_save_app_identity(p_identity jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old jsonb := private.app_identity();
  v_new jsonb := cs.check_app_identity(p_identity);
begin
  if v_new is distinct from v_old then
    perform cs.set_setting('app.identity', v_new, v_me);
    perform cs.audit('setting.app_identity', null, null, jsonb_build_object('before', v_old, 'after', v_new));
  end if;
  return cs_api.app_identity();
end;
$$;

revoke execute on function private.app_identity_defaults() from public;
revoke execute on function private.app_identity() from public;
revoke execute on function private.app_scheme() from public;
revoke execute on function private.share_links_settings() from public;
revoke execute on function cs.check_app_identity(jsonb) from public;
revoke execute on function cs_api.app_identity() from public;
revoke execute on function cs_api.admin_save_app_identity(jsonb) from public;

grant execute on function cs_api.app_identity() to authenticated;
grant execute on function cs_api.admin_save_app_identity(jsonb) to authenticated;
