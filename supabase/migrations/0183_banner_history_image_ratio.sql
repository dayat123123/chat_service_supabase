alter table private.app_banners
  add column image_ratio text,
  add constraint app_banners_image_ratio check (
    image_ratio is null or (image_ratio in ('portrait', 'square') and image_url is not null));

drop function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text, text,
                                       boolean, integer, text, text, text, text, text, integer, boolean);

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
  p_audience_days   integer default 7,
  p_notify          boolean default false,
  p_image_ratio     text default null
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
  v_ratio     text := nullif(lower(btrim(coalesce(p_image_ratio, ''))), '');
  v_cta       text := nullif(btrim(coalesce(p_cta_label, '')), '');
  v_frequency text := lower(btrim(coalesce(p_frequency, 'once')));
  v_audience  text := lower(btrim(coalesce(p_audience, 'all')));
  v_days      integer := coalesce(p_audience_days, 7);
  v_old       private.app_banners;
  v_new       private.app_banners;
  v_notice    uuid;
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
  if v_ratio is not null and v_ratio not in ('portrait', 'square') then
    perform private.api_error(400, 'invalid_image_ratio', 'Rasio gambar: portrait (4:5) atau square (1:1)');
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
  if v_audience = 'all' then
    v_days := 7;
  end if;

  if p_id is null then
    insert into private.app_banners (title, body, link_url, level, starts_at, ends_at, platforms, min_app_version,
                                     max_app_version, dismissible, priority, display, image_path, image_url, image_ratio,
                                     cta_label, frequency, audience, audience_days, created_by, updated_by)
    values (v_title, v_body, v_url, v_level, coalesce(p_starts_at, now()), p_ends_at, v_platforms, v_min, v_max,
            coalesce(p_dismissible, true), coalesce(p_priority, 0), v_display, v_image, v_image_url,
            case when v_image_url is not null then v_ratio end, v_cta,
            v_frequency, v_audience, v_days, v_me, v_me)
    returning * into v_new;
    if coalesce(p_notify, false) then
      v_notice := cs.banner_notice(v_new, v_me);
    end if;
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
           image_ratio = case when v_image_url is null then null
                              when v_ratio is not null then v_ratio
                              when v_image_url = v_old.image_url then v_old.image_ratio end,
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
    'notice', v_notice,
    'before', case when v_old.id is not null
                   then to_jsonb(v_old) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at' end,
    'after', to_jsonb(v_new) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at'));
  return private.app_banner_view(v_new);
end;
$$;

create or replace function private.app_banner_view(b private.app_banners)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', b.id, 'title', b.title, 'body', b.body, 'link_url', b.link_url, 'level', b.level,
    'display', b.display, 'image_path', b.image_path, 'image_url', b.image_url, 'cta_label', b.cta_label,
    'frequency', b.frequency, 'audience', b.audience, 'audience_days', b.audience_days,
    'starts_at', b.starts_at, 'ends_at', b.ends_at, 'platforms', to_jsonb(b.platforms),
    'min_app_version', b.min_app_version, 'max_app_version', b.max_app_version,
    'dismissible', b.dismissible, 'priority', b.priority,
    'status', case when b.ends_at is not null and b.ends_at <= now() then 'ended'
                   when b.starts_at > now() then 'scheduled'
                   else 'active' end,
    'stats', private.app_banner_stats(b.id),
    'created_by', cs.staff_ref(b.created_by), 'updated_by', cs.staff_ref(b.updated_by),
    'created_at', b.created_at, 'updated_at', b.updated_at)
    || jsonb_strip_nulls(jsonb_build_object('image_ratio', b.image_ratio))
    || coalesce((select jsonb_build_object('notice', cs.app_notice_view(x))
                 from private.app_notices x where x.banner_id = b.id
                 order by x.created_at desc limit 1), '{}'::jsonb);
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
    select max(e.created_at) filter (where e.event = 'impression') as seen_at,
           max(e.created_at) filter (where e.event = 'dismiss') as dismissed_at
    from private.app_banner_events e
    where p_user is not null
      and e.banner_id = x.id
      and e.user_id = p_user
      and e.event in ('impression', 'dismiss')
  ) h on true;
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
    'banners', private.client_banners(v_platform, v_version, v_user),
    'config', jsonb_build_object(
      'edit_minutes', private.setting_num('content.edit_minutes', 15),
      'message_reactions', to_jsonb(private.message_reaction_emojis()),
      'search_min_length', private.setting_num('search.min_query_length', 2),
      'notification_types', to_jsonb(private.notification_pref_types()),
      'notification_aggregate_minutes', private.setting_num('notifications.aggregate_minutes', 60),
      'trending_windows', '["24h", "7d"]'::jsonb,
      'account_rejoin_cooldown_hours', greatest(private.setting_num('account.rejoin_cooldown_hours', 72), 0),
      'viewer_id', v_user,
      'server_time', now()));
end;
$$;

create or replace function private.app_banner_maintenance()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_events integer;
  v_path   text;
begin
  delete from private.app_banner_events
   where id in (select e.id from private.app_banner_events e
                where e.created_at < now() - make_interval(days => private.setting_num('banners.events_retention_days', 180)::integer)
                  and not (e.user_id is not null
                           and e.event in ('impression', 'dismiss')
                           and exists (select 1 from private.app_banners b
                                       where b.id = e.banner_id and (b.ends_at is null or b.ends_at > now()))
                           and not exists (select 1 from private.app_banner_events n
                                           where n.banner_id = e.banner_id
                                             and n.user_id = e.user_id
                                             and n.event = e.event
                                             and n.day > e.day))
                limit 50000);
  get diagnostics v_events = row_count;
  delete from private.rate_limit_events e
   where e.action = 'banner_event' and e.created_at < now() - interval '1 day';
  for v_path in
    select o.name from storage.objects o
    where o.bucket_id = 'app-banners'
      and o.created_at < now() - interval '1 day'
      and not exists (select 1 from private.app_banners b where b.image_path = o.name)
    limit 1000
  loop
    perform private.queue_banner_image(v_path);
  end loop;
  return v_events;
end;
$$;

revoke execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                    text, boolean, integer, text, text, text, text, text, integer,
                                                    boolean, text) from public;
grant execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                   text, boolean, integer, text, text, text, text, text, integer,
                                                   boolean, text) to authenticated;
