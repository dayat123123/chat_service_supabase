insert into cs.cs_settings (key, value, description) values
  ('banners.notice_four_eyes', 'false',
   'Notifikasi info dari Banner & Popup wajib disetujui staf lain (Super Admin atau Fitur & Banner) sebelum dikirim')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer', 'ticket.reminder_hours', 'guest.enabled',
                   'notifications.watchlist_digest_time', 'banners.notice_four_eyes')
      or p_key like 'messages.%';
$$;

CREATE OR REPLACE FUNCTION cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_day   text;
  v_hours jsonb;
  v_lang  text;
  v_min   integer := 1;
  v_max   integer := 240;
  v_error text := 'Batas alert 1–240 menit';
begin
  case
    when p_key = 'assignment.mode' then
      if jsonb_typeof(p_value) <> 'string' or p_value #>> '{}' not in ('claim', 'auto_assign') then
        perform private.api_error(400, 'invalid_setting', 'Mode penugasan harus claim atau auto_assign');
      end if;
    when p_key in ('community.four_eyes', 'guest.enabled', 'banners.notice_four_eyes') then
      if jsonb_typeof(p_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
      end if;
    when p_key = 'notifications.watchlist_digest_time' then
      if jsonb_typeof(p_value) <> 'string' or (p_value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        perform private.api_error(400, 'invalid_setting', 'Jam harus HH:MM, 00:00–23:59 WIB');
      end if;
    when p_key in ('ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'alerts.unclaimed_minutes',
                   'alerts.p1_unclaimed_minutes') then
      if p_key = 'ticket.auto_release_offline_minutes' then
        v_min := 0;
        v_max := 1440;
        v_error := 'Lepas otomatis 0–1440 menit (0 = mati)';
      elsif p_key = 'ticket.auto_close_days' then
        v_max := 30;
        v_error := 'Tutup otomatis 1–30 hari';
      end if;
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_error);
      end if;
    when p_key = 'ticket.reminder_hours' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 0 and 72 then
        perform private.api_error(400, 'invalid_setting', 'Pengingat 0–72 jam (0 = mati)');
      end if;
    when p_key = 'accounts.max_per_customer' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 1 and 200 then
        perform private.api_error(400, 'invalid_setting', 'Batas rekening per nasabah 1–200');
      end if;
    when p_key = 'service.hours' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{1,2,3,4,5,6,7}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Jam layanan harus berisi hari 1–7');
      end if;
      for v_day, v_hours in select * from jsonb_each(p_value) loop
        if jsonb_typeof(v_hours) = 'null' then
          continue;
        end if;
        if jsonb_typeof(v_hours) <> 'array' or jsonb_array_length(v_hours) <> 2
           or (v_hours ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_hours ->> 1) !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$'
           or (v_hours ->> 0) >= (v_hours ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam layanan hari ' || v_day || ' harus HH:MM–HH:MM dan jam buka sebelum jam tutup');
        end if;
      end loop;
    when p_key like 'messages.%' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{en,id}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Pesan otomatis harus punya teks id dan en');
      end if;
      foreach v_lang in array array['id', 'en'] loop
        if jsonb_typeof(p_value -> v_lang) <> 'string' or char_length(btrim(p_value ->> v_lang)) not between 2 and 500 then
          perform private.api_error(400, 'invalid_setting', 'Teks pesan 2–500 karakter');
        end if;
        if not (cs.placeholders(p_value ->> v_lang) <@ cs.placeholders(p_old ->> v_lang)) then
          perform private.api_error(400, 'invalid_setting',
            'Variabel yang boleh dipakai: ' || coalesce(nullif(array_to_string(cs.placeholders(p_old ->> v_lang), ', '), ''), '-'));
        end if;
      end loop;
    else
      perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end case;
end;
$function$;

create table private.app_notices (
  id            uuid primary key default gen_random_uuid(),
  banner_id     uuid references private.app_banners (id) on delete set null,
  title         text not null check (char_length(btrim(title)) between 1 and 80),
  body          text not null default '' check (char_length(body) <= 300),
  link_url      text check (link_url is null or char_length(link_url) <= 500),
  cta_label     text check (cta_label is null or char_length(cta_label) <= 24),
  image_url     text check (image_url is null or char_length(image_url) <= 600),
  level         text not null default 'info' check (level in ('info', 'warning', 'critical')),
  audience      text not null default 'all' check (audience in ('all', 'new_users')),
  audience_days integer not null default 7 check (audience_days between 1 and 90),
  status        text not null default 'queued'
                check (status in ('pending', 'scheduled', 'queued', 'sending', 'sent', 'rejected', 'cancelled', 'failed')),
  send_at       timestamptz not null default now(),
  created_by    uuid references cs.agents (user_id),
  reviewed_by   uuid references cs.agents (user_id),
  reviewed_at   timestamptz,
  review_note   text check (review_note is null or char_length(review_note) <= 500),
  cursor_id     uuid,
  targeted      integer not null default 0,
  recipients    integer not null default 0,
  error         text check (error is null or char_length(error) <= 500),
  created_at    timestamptz not null default now(),
  started_at    timestamptz,
  finished_at   timestamptz
);
create index app_notices_due_idx on private.app_notices (send_at, id) where status in ('scheduled', 'queued', 'sending');
create index app_notices_banner_idx on private.app_notices (banner_id, created_at desc);
create index notifications_notice_idx on public.notifications ((payload ->> 'notice_id')) where payload ? 'notice_id';
alter table private.app_notices enable row level security;
revoke all on private.app_notices from public, anon, authenticated;

update cs.community_campaigns
   set status = 'cancelled', review_note = 'Dipindah ke notifikasi info Banner & Popup', updated_at = now(),
       version = version + 1
 where banner_id is not null and status in ('draft', 'pending', 'scheduled');
drop function cs.banner_campaign(private.app_banners, uuid);
drop function private.default_official_account();

create function private.notice_four_eyes()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((cs.setting('banners.notice_four_eyes') #>> '{}')::boolean, false);
$$;

create function private.notice_audience_ids(p_audience text, p_days integer, p_after uuid, p_limit integer)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(x.id order by x.id), '{}')
  from (
    select p.id from public.profiles p
    where p.deleted_at is null
      and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
      and (p_audience <> 'new_users' or p.created_at >= now() - make_interval(days => p_days))
      and (p_after is null or p.id > p_after)
    order by p.id
    limit p_limit
  ) x;
$$;

create function private.notice_audience_count(p_audience text, p_days integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.profiles p
  where p.deleted_at is null
    and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
    and (p_audience <> 'new_users' or p.created_at >= now() - make_interval(days => p_days));
$$;

create function cs.app_notice_view(n private.app_notices)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', n.id, 'banner_id', n.banner_id, 'title', n.title, 'body', n.body, 'link_url', n.link_url,
    'cta_label', n.cta_label, 'image_url', n.image_url, 'level', n.level,
    'audience', n.audience, 'audience_days', n.audience_days, 'status', n.status, 'send_at', n.send_at,
    'created_by', cs.staff_ref(n.created_by), 'reviewed_by', cs.staff_ref(n.reviewed_by),
    'reviewed_at', n.reviewed_at, 'review_note', n.review_note,
    'targeted', n.targeted, 'recipients', n.recipients,
    'opened', (select count(distinct e.user_id)::integer
               from private.notification_events e
               join public.notifications x on x.id = e.notification_id
               where x.payload ->> 'notice_id' = n.id::text and e.event = 'opened'),
    'tapped', (select count(distinct e.user_id)::integer
               from private.notification_events e
               join public.notifications x on x.id = e.notification_id
               where x.payload ->> 'notice_id' = n.id::text and e.event = 'tapped'),
    'error', n.error, 'created_at', n.created_at, 'started_at', n.started_at, 'finished_at', n.finished_at);
$$;

create function cs.banner_notice(p_banner private.app_banners, p_me uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_four boolean := private.notice_four_eyes();
  v_at   timestamptz := greatest(p_banner.starts_at, now());
  v_id   uuid;
begin
  insert into private.app_notices (banner_id, title, body, link_url, cta_label, image_url, level, audience,
                                   audience_days, status, send_at, created_by)
  values (p_banner.id, p_banner.title, p_banner.body, p_banner.link_url, p_banner.cta_label, p_banner.image_url,
          p_banner.level, p_banner.audience, p_banner.audience_days,
          case when v_four then 'pending' when v_at > now() then 'scheduled' else 'queued' end,
          v_at, p_me)
  returning id into v_id;
  perform cs.audit('banner.notice_create', null, null, jsonb_build_object(
    'notice', v_id, 'banner', p_banner.id, 'four_eyes', v_four,
    'recipients_estimate', private.notice_audience_count(p_banner.audience, p_banner.audience_days)));
  return v_id;
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
  p_audience_days   integer default 7,
  p_notify          boolean default false
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
                                     max_app_version, dismissible, priority, display, image_path, image_url, cta_label,
                                     frequency, audience, audience_days, created_by, updated_by)
    values (v_title, v_body, v_url, v_level, coalesce(p_starts_at, now()), p_ends_at, v_platforms, v_min, v_max,
            coalesce(p_dismissible, true), coalesce(p_priority, 0), v_display, v_image, v_image_url, v_cta,
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
    || coalesce((select jsonb_build_object('notice', cs.app_notice_view(x))
                 from private.app_notices x where x.banner_id = b.id
                 order by x.created_at desc limit 1), '{}'::jsonb);
$$;

create function private.cancel_banner_notices()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.app_notices
     set status = 'cancelled', finished_at = now(), banner_id = null
   where banner_id = old.id and status in ('pending', 'scheduled', 'queued');
  return old;
end;
$$;
create trigger app_banners_cancel_notices
  before delete on private.app_banners
  for each row execute function private.cancel_banner_notices();

create function cs_api.admin_banner_notices(p_limit integer default 50)
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
    select jsonb_agg(cs.app_notice_view(n) order by (n.status = 'pending') desc, n.created_at desc)
    from (select * from private.app_notices order by (status = 'pending') desc, created_at desc
          limit least(greatest(coalesce(p_limit, 50), 1), 200)) n), '[]');
end;
$$;

create function cs_api.admin_banner_notice_preview(p_audience text default 'all', p_audience_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin,product}');
  v_audience text := lower(btrim(coalesce(p_audience, 'all')));
  v_days     integer := coalesce(p_audience_days, 7);
begin
  if v_audience not in ('all', 'new_users') then
    perform private.api_error(400, 'invalid_audience', 'Sasaran: all atau new_users');
  end if;
  if v_days not between 1 and 90 then
    perform private.api_error(400, 'invalid_audience', 'Pengguna baru 1–90 hari');
  end if;
  return jsonb_build_object('recipients', private.notice_audience_count(v_audience, v_days),
                            'four_eyes', private.notice_four_eyes());
end;
$$;

create function cs_api.admin_review_banner_notice(p_id uuid, p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin,product}');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  n      private.app_notices;
begin
  select * into n from private.app_notices where id = p_id for update;
  if not found then
    perform private.api_error(404, 'notice_not_found', 'Notifikasi tidak ditemukan');
  end if;
  if n.status <> 'pending' then
    perform private.api_error(409, 'invalid_status', 'Notifikasi ini tidak sedang menunggu persetujuan');
  end if;
  if n.created_by = v_me then
    perform private.api_error(403, 'four_eyes', 'Notifikasi harus disetujui staf lain, bukan pembuatnya');
  end if;
  if coalesce(p_approve, false) then
    update private.app_notices
       set status = case when send_at > now() then 'scheduled' else 'queued' end,
           send_at = greatest(send_at, now()), reviewed_by = v_me, reviewed_at = now(), review_note = v_note
     where id = n.id
    returning * into n;
    perform cs.audit('banner.notice_approve', null, null, jsonb_build_object('notice', n.id, 'banner', n.banner_id));
  else
    if char_length(coalesce(v_note, '')) not between 5 and 500 then
      perform private.api_error(400, 'note_required', 'Alasan penolakan 5–500 karakter');
    end if;
    update private.app_notices
       set status = 'rejected', reviewed_by = v_me, reviewed_at = now(), review_note = v_note, finished_at = now()
     where id = n.id
    returning * into n;
    perform cs.audit('banner.notice_reject', null, null,
                     jsonb_build_object('notice', n.id, 'banner', n.banner_id, 'note', v_note));
  end if;
  return cs.app_notice_view(n);
end;
$$;

create function cs_api.admin_cancel_banner_notice(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,product}');
  n    private.app_notices;
begin
  select * into n from private.app_notices where id = p_id for update;
  if not found then
    perform private.api_error(404, 'notice_not_found', 'Notifikasi tidak ditemukan');
  end if;
  if n.status not in ('pending', 'scheduled', 'queued', 'sending') then
    perform private.api_error(409, 'invalid_status', 'Notifikasi ini sudah selesai dan tidak bisa dibatalkan');
  end if;
  update private.app_notices set status = 'cancelled', finished_at = now() where id = n.id returning * into n;
  perform cs.audit('banner.notice_cancel', null, null,
                   jsonb_build_object('notice', n.id, 'banner', n.banner_id, 'recipients', n.recipients));
  return cs.app_notice_view(n);
end;
$$;

create function private.app_notice_payload(n private.app_notices)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'notice_id', n.id, 'banner_id', n.banner_id, 'title', n.title, 'body', n.body, 'level', n.level,
    'link_url', case when private.banner_link_visible(n.link_url) then n.link_url end,
    'cta_label', case when private.banner_link_visible(n.link_url) then n.cta_label end,
    'image_url', n.image_url, 'sent_at', coalesce(n.started_at, now())));
$$;

create function private.app_notice_batch(p_id uuid, p_size integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n       private.app_notices;
  v_size  integer := greatest(coalesce(p_size, 1), 1);
  v_ids   uuid[];
  v_count integer := 0;
  v_done  boolean;
begin
  select * into n from private.app_notices
   where id = p_id and status in ('queued', 'sending') and send_at <= now()
  for update skip locked;
  if not found then
    return 0;
  end if;
  if n.started_at is null then
    update private.app_notices set started_at = now() where id = n.id returning * into n;
  end if;
  v_ids := private.notice_audience_ids(n.audience, n.audience_days, n.cursor_id, v_size);
  with ins as (
    insert into public.notifications (user_id, type, payload)
    select u, 'announcement', private.app_notice_payload(n) from unnest(v_ids) u
    returning 1)
  select count(*)::integer into v_count from ins;
  v_done := cardinality(v_ids) < v_size;
  update private.app_notices
     set status = case when v_done then 'sent' else 'sending' end,
         cursor_id = coalesce(v_ids[cardinality(v_ids)], cursor_id),
         targeted = targeted + cardinality(v_ids),
         recipients = recipients + v_count,
         finished_at = case when v_done then now() end
   where id = n.id;
  return cardinality(v_ids);
end;
$$;

create function private.app_notice_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_budget   integer := greatest(private.setting_num('integration.broadcast_batch_size', 2000)::integer, 1);
  v_profiles integer := 0;
  v_jobs     integer := 0;
  v_count    integer;
  r          record;
begin
  update private.app_notices set status = 'queued' where status = 'scheduled' and send_at <= now();
  for r in
    select n.id from private.app_notices n
    where n.status in ('queued', 'sending') and n.send_at <= now()
    order by n.send_at, n.id
  loop
    exit when v_budget <= 0;
    begin
      v_count := private.app_notice_batch(r.id, v_budget);
    exception when others then
      update private.app_notices
         set status = 'failed', error = left(coalesce(nullif(sqlerrm, ''), 'error'), 500),
             started_at = coalesce(started_at, now()), finished_at = now()
       where id = r.id;
      v_count := 0;
    end;
    v_jobs := v_jobs + 1;
    v_profiles := v_profiles + v_count;
    v_budget := v_budget - v_count;
  end loop;
  return jsonb_build_object('jobs', v_jobs, 'profiles', v_profiles);
end;
$$;

select cron.schedule('app-notices', '15 seconds', 'select private.app_notice_tick()');

create function public.get_app_notice(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_note public.notifications;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_note from public.notifications x
   where x.user_id = v_uid and x.payload ->> 'notice_id' = p_id::text
   order by x.created_at desc
   limit 1;
  if v_note.id is null then
    perform private.api_error(404, 'notice_not_found', 'Informasi ini tidak tersedia');
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'id', p_id, 'notification_id', v_note.id, 'title', v_note.payload ->> 'title', 'body', v_note.payload ->> 'body',
    'level', v_note.payload ->> 'level',
    'link_url', case when private.banner_link_visible(v_note.payload ->> 'link_url') then v_note.payload ->> 'link_url' end,
    'cta_label', case when private.banner_link_visible(v_note.payload ->> 'link_url') then v_note.payload ->> 'cta_label' end,
    'image_url', v_note.payload ->> 'image_url', 'sent_at', coalesce(v_note.payload ->> 'sent_at', v_note.created_at::text)));
end;
$$;

revoke execute on function private.notice_four_eyes() from public;
revoke execute on function private.notice_audience_ids(text, integer, uuid, integer) from public;
revoke execute on function private.notice_audience_count(text, integer) from public;
revoke execute on function cs.app_notice_view(private.app_notices) from public;
revoke execute on function cs.banner_notice(private.app_banners, uuid) from public;
revoke execute on function private.cancel_banner_notices() from public;
revoke execute on function private.app_notice_payload(private.app_notices) from public;
revoke execute on function private.app_notice_batch(uuid, integer) from public;
revoke execute on function private.app_notice_tick() from public;
revoke execute on function cs_api.admin_banner_notices(integer) from public;
revoke execute on function cs_api.admin_banner_notice_preview(text, integer) from public;
revoke execute on function cs_api.admin_review_banner_notice(uuid, boolean, text) from public;
revoke execute on function cs_api.admin_cancel_banner_notice(uuid) from public;
revoke execute on function public.get_app_notice(uuid) from public, anon;
grant execute on function cs_api.admin_banner_notices(integer) to authenticated;
grant execute on function cs_api.admin_banner_notice_preview(text, integer) to authenticated;
grant execute on function cs_api.admin_review_banner_notice(uuid, boolean, text) to authenticated;
grant execute on function cs_api.admin_cancel_banner_notice(uuid) to authenticated;
grant execute on function public.get_app_notice(uuid) to authenticated;
