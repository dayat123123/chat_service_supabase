insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('app-banners', 'app-banners', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('banner_event', 120, 60)
on conflict (action, window_seconds) do nothing;

insert into cs.cs_settings (key, value, description) values
  ('banners.deep_link_schemes', '["olt"]',
   'Skema deep link aplikasi yang boleh dipakai sebagai tautan banner, mis. olt untuk olt://promo/akhir-tahun')
on conflict (key) do nothing;

create or replace function private.banner_forbidden_schemes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['http', 'https', 'javascript', 'vbscript', 'data', 'file', 'filesystem', 'blob', 'about', 'intent',
               'content'];
$$;

create or replace function private.banner_link_schemes()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select array_agg(x order by x)
                   from jsonb_array_elements_text(
                          case when jsonb_typeof(cs.setting('banners.deep_link_schemes')) = 'array'
                               then cs.setting('banners.deep_link_schemes') else '["olt"]' end) x
                   where x ~ '^[a-z][a-z0-9+.-]{0,31}$' and x <> all (private.banner_forbidden_schemes())), '{}');
$$;

create or replace function private.banner_link_valid(p_url text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_url is not null
     and char_length(p_url) <= 500
     and (p_url ~ '^https://[^\s/?#]+[^\s]*$'
          or (p_url ~ '^[a-z][a-z0-9+.-]{0,31}://[^\s]+$'
              and split_part(p_url, '://', 1) = any (private.banner_link_schemes())));
$$;

create or replace function private.banner_link_visible(p_url text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_url is not null
     and (p_url ~ '^https?://[^\s]+$' or private.banner_link_valid(p_url));
$$;

alter table private.app_banners drop constraint app_banners_link_url_check;
alter table private.app_banners
  add column display       text not null default 'strip' check (display in ('strip', 'popup')),
  add column image_path    text check (image_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'),
  add column image_url     text check (char_length(image_url) <= 600),
  add column cta_label     text check (char_length(btrim(cta_label)) between 1 and 24),
  add column frequency     text not null default 'once' check (frequency in ('once', 'daily', 'every_open')),
  add column audience      text not null default 'all' check (audience in ('all', 'new_users')),
  add column audience_days integer not null default 7 check (audience_days between 1 and 90),
  add constraint app_banners_link_url_check
    check (link_url ~ '^[a-z][a-z0-9+.-]{0,31}://[^\s]+$' and char_length(link_url) <= 500
           and split_part(link_url, '://', 1) not in ('javascript', 'vbscript', 'data', 'file', 'filesystem', 'blob',
                                                      'about', 'intent', 'content')),
  add constraint app_banners_image
    check ((image_path is null) = (image_url is null)
           and (image_path is null or display = 'popup')
           and (image_url is null or image_url ~ ('^https?://[^\s/?#]+(/[^\s?#]*)?/storage/v1/object/public/app-banners/'
                                                  || replace(image_path, '.', '\.') || '$'))),
  add constraint app_banners_cta check (cta_label is null or link_url is not null);

create table private.app_banner_events (
  id         bigint generated always as identity primary key,
  banner_id  uuid not null references private.app_banners (id) on delete cascade,
  user_id    uuid references public.profiles (id) on delete set null,
  event      text not null check (event in ('impression', 'click', 'dismiss')),
  day        date not null,
  created_at timestamptz not null default now(),
  constraint app_banner_events_once unique (banner_id, user_id, event, day)
);
create index app_banner_events_day_idx on private.app_banner_events (banner_id, day, event);
create index app_banner_events_created_idx on private.app_banner_events (created_at);
alter table private.app_banner_events enable row level security;
revoke all on private.app_banner_events from anon, authenticated;

create or replace function private.can_manage_banners()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.has_role('{cs_super_admin}');
$$;

create policy olt_app_banners_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'app-banners'
              and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
              and (select private.can_manage_banners()));

create policy olt_app_banners_read on storage.objects for select to authenticated
  using (bucket_id = 'app-banners' and (select private.can_manage_banners()));

create or replace function private.app_banner_stats(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'impressions', s.impressions, 'clicks', s.clicks, 'dismissals', s.dismissals, 'unique_viewers', s.viewers,
    'ctr', case when s.impressions > 0 then round(100.0 * s.clicks / s.impressions, 1) end)
  from (select count(*) filter (where e.event = 'impression')::integer as impressions,
               count(*) filter (where e.event = 'click')::integer as clicks,
               count(*) filter (where e.event = 'dismiss')::integer as dismissals,
               count(distinct e.user_id) filter (where e.event = 'impression')::integer as viewers
        from private.app_banner_events e
        where e.banner_id = p_id) s;
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
    'created_at', b.created_at, 'updated_at', b.updated_at);
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
    'banners', private.client_banners(v_platform, v_version, v_user),
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

drop function private.client_banners(text, text);

create or replace function public.record_banner_event(p_banner_id uuid, p_event text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_recorded boolean := false;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if cs.current_customer_id() is null then
    perform private.api_error(403, 'customer_required', 'Hanya nasabah yang mencatat tayangan banner');
  end if;
  if coalesce(p_event, '') not in ('impression', 'click', 'dismiss') then
    perform private.api_error(400, 'invalid_event', 'Event harus impression, click, atau dismiss');
  end if;
  perform private.consume_rate_limit(v_uid, 'banner_event');

  insert into private.app_banner_events (banner_id, user_id, event, day)
  select b.id, v_uid, p_event, (now() at time zone 'Asia/Jakarta')::date
  from private.app_banners b
  where b.id = p_banner_id
    and b.starts_at <= now()
    and (b.ends_at is null or b.ends_at > now())
    and (b.audience = 'all'
         or exists (select 1 from public.profiles p
                    where p.id = v_uid and p.created_at >= now() - make_interval(days => b.audience_days)))
  on conflict (banner_id, user_id, event, day) do nothing;
  v_recorded := found;

  return jsonb_build_object('recorded', v_recorded);
end;
$$;

create or replace function private.queue_banner_image(p_path text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select 'app-banners', p_path || '/', 'banner_image'
  where p_path is not null
    and not exists (select 1 from private.app_banners b where b.image_path = p_path)
    and not exists (select 1 from private.storage_cleanup_queue q
                    where q.bucket_id = 'app-banners' and q.prefix = p_path || '/' and q.done_at is null);
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

select cron.schedule('app-banner-maintenance', '47 3 * * *', 'select private.app_banner_maintenance()');

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

create or replace function cs_api.admin_banner_stats(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
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
  v_me uuid := cs.require_agent('{cs_super_admin}');
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
  v_me      uuid := cs.require_agent('{cs_super_admin}');
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

drop function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text, text, boolean,
                                       integer);

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
  v_me        uuid := cs.require_agent('{cs_super_admin}');
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
  v_me  uuid := cs.require_agent('{cs_super_admin}');
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

revoke execute on function private.banner_forbidden_schemes() from public;
revoke execute on function private.banner_link_schemes() from public;
revoke execute on function private.banner_link_valid(text) from public;
revoke execute on function private.banner_link_visible(text) from public;
revoke execute on function private.can_manage_banners() from public;
revoke execute on function private.app_banner_stats(uuid) from public;
revoke execute on function private.app_banner_view(private.app_banners) from public;
revoke execute on function private.client_banners(text, text, uuid) from public;
revoke execute on function private.queue_banner_image(text) from public;
revoke execute on function private.app_banner_maintenance() from public;
revoke execute on function public.record_banner_event(uuid, text) from public, anon;
revoke execute on function cs_api.admin_banner_stats(uuid) from public;
revoke execute on function cs_api.admin_banner_settings() from public;
revoke execute on function cs_api.admin_set_banner_link_schemes(text[]) from public;
revoke execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                    text, boolean, integer, text, text, text, text, text, integer) from public;

grant execute on function private.can_manage_banners() to authenticated;
grant execute on function public.record_banner_event(uuid, text) to authenticated;
grant execute on function cs_api.admin_banner_stats(uuid) to authenticated;
grant execute on function cs_api.admin_banner_settings() to authenticated;
grant execute on function cs_api.admin_set_banner_link_schemes(text[]) to authenticated;
grant execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                   text, boolean, integer, text, text, text, text, text, integer)
  to authenticated;
