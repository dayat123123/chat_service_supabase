create or replace function private.share_links_defaults()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select '{"enabled": false, "base_url": "", "preview": true, "app_name": "OLT", "app_scheme": "olt", "android": [], "ios_app_ids": [], "android_store_url": "", "ios_store_url": "", "windows_download_url": "", "macos_download_url": ""}'::jsonb;
$$;

update cs.cs_settings
   set value = value || '{"macos_download_url": ""}',
       description = 'Tautan berbagi post: domain publik, pratinjau isi, skema aplikasi, identitas App Links (Android) dan Universal Links (iOS/macOS), serta tautan unduh Android, iOS, Windows, dan Mac'
 where key = 'share.links'
   and jsonb_typeof(value) = 'object'
   and not value ? 'macos_download_url';

create or replace function cs.check_share_links(p_config jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_base    text;
  v_name    text;
  v_scheme  text;
  v_android jsonb := '[]';
  v_ios     jsonb := '[]';
  v_item    jsonb;
  v_package text;
  v_prints  jsonb;
  v_print   text;
  v_id      text;
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

  v_name := btrim(coalesce(p_config ->> 'app_name', ''));
  if char_length(v_name) not between 1 and 40 or v_name ~ '[[:cntrl:]<>]' then
    perform private.api_error(400, 'invalid_share_app_name', 'Nama aplikasi 1–40 karakter, tanpa < atau >');
  end if;

  v_scheme := lower(btrim(coalesce(p_config ->> 'app_scheme', '')));
  if v_scheme !~ '^[a-z][a-z0-9+.-]{1,30}$'
     or v_scheme in ('http', 'https', 'file', 'ftp', 'javascript', 'data', 'blob', 'about', 'mailto', 'tel', 'intent', 'content') then
    perform private.api_error(400, 'invalid_share_app_scheme', 'Skema aplikasi 2–31 huruf kecil/angka, mis. olt');
  end if;

  if jsonb_typeof(coalesce(p_config -> 'android', '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_config -> 'android', '[]')) > 5 then
    perform private.api_error(400, 'invalid_share_android', 'Maksimal 5 aplikasi Android');
  end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_config -> 'android', '[]')) loop
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

  if jsonb_typeof(coalesce(p_config -> 'ios_app_ids', '[]')) <> 'array'
     or jsonb_array_length(coalesce(p_config -> 'ios_app_ids', '[]')) > 5 then
    perform private.api_error(400, 'invalid_share_ios', 'Maksimal 5 App ID iOS');
  end if;
  for v_id in select btrim(x) from jsonb_array_elements_text(coalesce(p_config -> 'ios_app_ids', '[]')) x loop
    if char_length(v_id) > 160 or v_id !~ '^[A-Z0-9]{10}\.[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*$' then
      perform private.api_error(400, 'invalid_share_ios_app_id', 'App ID iOS harus TEAMID.bundle.id, mis. ABCDE12345.com.perusahaan.app');
    end if;
    if not v_ios ? v_id then
      v_ios := v_ios || to_jsonb(v_id);
    end if;
  end loop;

  return jsonb_build_object(
    'enabled', (p_config ->> 'enabled')::boolean,
    'base_url', v_base,
    'preview', (p_config ->> 'preview')::boolean,
    'app_name', v_name,
    'app_scheme', v_scheme,
    'android', v_android,
    'ios_app_ids', v_ios,
    'android_store_url', cs.share_links_https(p_config -> 'android_store_url', 'Play Store'),
    'ios_store_url', cs.share_links_https(p_config -> 'ios_store_url', 'App Store'),
    'windows_download_url', cs.share_links_https(p_config -> 'windows_download_url', 'unduhan Windows'),
    'macos_download_url', cs.share_links_https(p_config -> 'macos_download_url', 'unduhan Mac'));
end;
$$;
