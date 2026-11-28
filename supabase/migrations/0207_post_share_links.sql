insert into cs.cs_settings (key, value, description) values
  ('share.links',
   '{"enabled": false, "base_url": "", "preview": true, "app_name": "OLT", "app_scheme": "olt", "android": [], "ios_app_ids": [], "android_store_url": "", "ios_store_url": "", "windows_download_url": ""}',
   'Tautan berbagi post: domain publik, pratinjau isi, skema aplikasi, identitas App Links (Android) dan Universal Links (iOS), serta tautan unduh')
on conflict (key) do nothing;

insert into private.rate_limits (action, max_count, window_seconds) values ('post_share_link', 120, 3600)
on conflict (action, window_seconds) do nothing;

create table private.post_share_codes (
  code       text primary key,
  post_id    uuid not null unique references public.posts(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint post_share_codes_code check (code ~ '^[A-Za-z0-9]{10}$')
);
create index post_share_codes_created_by_idx on private.post_share_codes (created_by);
alter table private.post_share_codes enable row level security;
revoke all on private.post_share_codes from public, anon, authenticated;

create or replace function private.share_links_defaults()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select '{"enabled": false, "base_url": "", "preview": true, "app_name": "OLT", "app_scheme": "olt", "android": [], "ios_app_ids": [], "android_store_url": "", "ios_store_url": "", "windows_download_url": ""}'::jsonb;
$$;

create or replace function private.share_links_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.share_links_defaults() || coalesce(
    (select s.value from cs.cs_settings s where s.key = 'share.links' and jsonb_typeof(s.value) = 'object'), '{}');
$$;

create or replace function private.share_links_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (c ->> 'enabled')::boolean is true and coalesce(c ->> 'base_url', '') <> ''
  from (select private.share_links_config() as c) x;
$$;

create or replace function private.share_link_url(p_code text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when private.share_links_ready()
              then (private.share_links_config() ->> 'base_url') || '/p/' || p_code end;
$$;

create or replace function private.new_share_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(substr('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
                           (get_byte(b, i) % 62) + 1, 1), '' order by i)
  from (select extensions.gen_random_bytes(10) as b) r
  cross join generate_series(0, 9) i;
$$;

create or replace function private.post_shareable(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.posts p
    join public.profiles pr on pr.id = p.author_id
    where p.id = p_post
      and p.deleted_at is null
      and p.moderation_status = 'visible'
      and pr.deleted_at is null
      and not pr.is_guest
      and not private.has_active_sanction(pr.id, '{ban}'));
$$;

create or replace function public.post_share_link(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := auth.uid();
  v_code text;
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
    'app_url', (private.share_links_config() ->> 'app_scheme') || '://p/' || v_code);
end;
$$;

create or replace function public.resolve_post_share(p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.post_id
  from private.post_share_codes c
  where auth.uid() is not null
    and p_code ~ '^[A-Za-z0-9]{10}$'
    and c.code = p_code
    and private.post_shareable(c.post_id);
$$;

create or replace function public.share_link_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.share_links_config() || jsonb_build_object('ready', private.share_links_ready());
$$;

create or replace function public.share_post_preview(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_config jsonb := private.share_links_config();
  v_post   uuid;
  v_row    record;
  v_image  jsonb;
  v_avatar text;
begin
  if not private.share_links_ready() then
    return jsonb_build_object('status', 'disabled');
  end if;
  if p_code is null or p_code !~ '^[A-Za-z0-9]{10}$' then
    return jsonb_build_object('status', 'not_found');
  end if;
  select c.post_id into v_post from private.post_share_codes c where c.code = p_code;
  if v_post is null then
    return jsonb_build_object('status', 'not_found');
  end if;
  if not private.post_shareable(v_post) then
    return jsonb_build_object('status', 'unavailable', 'code', p_code);
  end if;
  if (v_config ->> 'preview')::boolean is not true then
    return jsonb_build_object('status', 'ok', 'code', p_code, 'preview', false);
  end if;

  select p.body, p.created_at, p.attachments, p.like_count, p.comment_count,
         pr.username::text as username, pr.display_name, pr.avatar_url, pr.is_verified,
         private.is_official_account(pr.id) as official
    into v_row
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  where p.id = v_post;

  select a into v_image
  from jsonb_array_elements(case when jsonb_typeof(v_row.attachments) = 'array' then v_row.attachments else '[]' end) a
  where a ->> 'mime' like 'image/%'
    and coalesce(a ->> 'path', '') ~ '^posts/[0-9a-f-]{36}/[A-Za-z0-9._-]{1,120}$'
  limit 1;

  v_avatar := substring(coalesce(v_row.avatar_url, '') from '/storage/v1/object/public/avatars/([A-Za-z0-9._/-]{1,200})$');
  if v_avatar like '%..%' then
    v_avatar := null;
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'code', p_code,
    'preview', true,
    'author', jsonb_build_object(
      'username', v_row.username,
      'display_name', coalesce(nullif(btrim(v_row.display_name), ''), v_row.username),
      'verified', v_row.is_verified,
      'official', v_row.official,
      'avatar_path', v_avatar),
    'body', left(regexp_replace(btrim(v_row.body), '\s+', ' ', 'g'), 300),
    'truncated', char_length(regexp_replace(btrim(v_row.body), '\s+', ' ', 'g')) > 300,
    'created_at', v_row.created_at,
    'like_count', v_row.like_count,
    'comment_count', v_row.comment_count,
    'image', case when v_image is not null then jsonb_build_object(
      'path', v_image ->> 'path',
      'width', case when jsonb_typeof(v_image -> 'width') = 'number' then v_image -> 'width' end,
      'height', case when jsonb_typeof(v_image -> 'height') = 'number' then v_image -> 'height' end) end);
end;
$$;

create or replace function cs.share_links_https(p_value jsonb, p_key text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  if p_value is null or p_value = 'null'::jsonb then
    return '';
  end if;
  if jsonb_typeof(p_value) <> 'string' then
    perform private.api_error(400, 'invalid_share_links', 'Tautan unduh harus berupa teks');
  end if;
  v_text := btrim(p_value #>> '{}');
  if v_text <> '' and (char_length(v_text) > 300 or v_text !~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[^\s<>"''`\\]*)?$') then
    perform private.api_error(400, 'invalid_share_store_url',
      format('Tautan %s harus diawali https://, tanpa spasi, maksimal 300 karakter', p_key));
  end if;
  return v_text;
end;
$$;

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
    'windows_download_url', cs.share_links_https(p_config -> 'windows_download_url', 'unduhan Windows'));
end;
$$;

create or replace function cs_api.share_links()
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
      'config', private.share_links_config(),
      'ready', private.share_links_ready(),
      'version', s.version,
      'updated_at', s.updated_at,
      'updated_by', a.display_name,
      'codes', (select count(*) from private.post_share_codes),
      'codes_7d', (select count(*) from private.post_share_codes c where c.created_at > now() - interval '7 days'))
    from cs.cs_settings s
    left join cs.agents a on a.user_id = s.updated_by
    where s.key = 'share.links');
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
  v_old jsonb := private.share_links_config();
  v_new jsonb := cs.check_share_links(p_config);
begin
  if v_new is distinct from v_old then
    perform cs.set_setting('share.links', v_new, v_me);
    perform cs.audit('setting.share_links', null, null, jsonb_build_object('before', v_old, 'after', v_new));
  end if;
  return cs_api.share_links();
end;
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
                       from private.feature_flags f), '{}')
             || jsonb_build_object('post_links', private.share_links_ready()),
    'min_version', coalesce((select jsonb_object_agg(v.platform, v.min_version) from private.client_versions v), '{}'),
    'update_required', coalesce(v_min is not null and v_version is not null
                                and private.version_parts(v_version) < private.version_parts(v_min), false),
    'banners', private.client_banners(v_platform, v_version, v_user),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'post_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'account_rejoin_cooldown_hours', greatest(private.setting_num('account.rejoin_cooldown_hours', 72), 0),
      'viewer_id', v_user,
      'server_time', now()));
end;
$$;

create or replace function private.health_service_label(p_service text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_service
    when 'media' then 'Upload media'
    when 'sentinel' then 'Pemantau sistem'
    when 'backup' then 'Backup'
    when 'notifier' then 'Notifier push'
    when 'janitor' then 'Pembersih storage'
    when 'auth-bridge' then 'Auth bridge'
    when 'nasabah-gateway' then 'Gateway nasabah'
    when 'rest' then 'API (PostgREST)'
    when 'auth' then 'Login staf (GoTrue)'
    when 'storage' then 'Storage'
    when 'realtime' then 'Realtime'
    when 'functions' then 'Edge Functions'
    when 'imgproxy' then 'Imgproxy'
    when 'kong' then 'Kong'
    when 'valkey' then 'Valkey'
    when 'pgbouncer' then 'PgBouncer'
    when 'db' then 'Database'
    when 'cs-console' then 'Web CS'
    when 'integration' then 'Gateway integrasi'
    when 'link-preview' then 'Pratinjau link'
    when 'classifier' then 'Klasifikasi gambar'
    when 'clamav' then 'Pemindai antivirus'
    when 'research' then 'Riset'
    when 'share-link' then 'Tautan berbagi'
    else p_service
  end;
$$;

update private.settings
   set value = (select jsonb_agg(distinct x order by x)
                from jsonb_array_elements_text(value || '["share-link"]') x)
 where key = 'health.expected_services';

revoke execute on function private.share_links_defaults() from public;
revoke execute on function private.share_links_config() from public;
revoke execute on function private.share_links_ready() from public;
revoke execute on function private.share_link_url(text) from public;
revoke execute on function private.new_share_code() from public;
revoke execute on function private.post_shareable(uuid) from public;
revoke execute on function public.post_share_link(uuid) from public, anon;
revoke execute on function public.resolve_post_share(text) from public, anon;
revoke execute on function public.share_link_config() from public, anon, authenticated;
revoke execute on function public.share_post_preview(text) from public, anon, authenticated;
revoke execute on function cs.share_links_https(jsonb, text) from public;
revoke execute on function cs.check_share_links(jsonb) from public;
revoke execute on function cs_api.share_links() from public;
revoke execute on function cs_api.admin_save_share_links(jsonb) from public;

grant execute on function public.post_share_link(uuid) to authenticated;
grant execute on function public.resolve_post_share(text) to authenticated;
grant execute on function public.share_link_config() to service_role;
grant execute on function public.share_post_preview(text) to service_role;
grant execute on function cs_api.share_links() to authenticated;
grant execute on function cs_api.admin_save_share_links(jsonb) to authenticated;
