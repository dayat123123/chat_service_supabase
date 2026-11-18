alter table cs.community_campaigns
  add column banner_id uuid references private.app_banners (id) on delete set null;

create function private.default_official_account()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.profile_id
    from cs.official_accounts o
   where cs.official_active(o.profile_id)
   order by o.created_at, o.profile_id
   limit 1
$$;

create function cs.banner_campaign(p_banner private.app_banners, p_me uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account uuid := private.default_official_account();
  v_title   text := btrim(p_banner.title);
  v_body    text := btrim(coalesce(p_banner.body, ''));
  v_url     text := case when p_banner.link_url ~ '^https://[^\s]+$' then p_banner.link_url end;
  v_aud     jsonb;
  v_id      uuid;
begin
  if v_account is null then
    perform private.api_error(400, 'no_official_account',
      'Belum ada akun resmi aktif untuk mengirim notifikasi. Buat akun resmi di Komunitas → Akun resmi, atau matikan Kirim juga sebagai notifikasi');
  end if;
  if char_length(v_title) < 3 then
    perform private.api_error(400, 'notification_title_short',
      'Judul minimal 3 karakter bila banner dikirim juga sebagai notifikasi');
  end if;
  if char_length(v_body) < 3 then
    v_body := v_title;
  elsif char_length(v_body) > 240 then
    v_body := left(v_body, 239) || '…';
  end if;
  perform private.validate_text(v_title || ' ' || v_body, 'message');
  perform private.apply_content_policy(v_title || ' ' || v_body);
  v_aud := case
    when p_banner.audience = 'new_users'
      then cs.community_audience_check('new_users', null, p_banner.audience_days, null, null)
    when cardinality(p_banner.platforms) = 1
      then cs.community_audience_check('platform', null, null, p_banner.platforms[1], null)
    else cs.community_audience_check('all', null, null, null, null)
  end;

  insert into cs.community_campaigns (account_id, title, body, link_url, audience, audience_stock, audience_days,
                                      audience_platform, audience_account, send_at, created_by, status,
                                      submitted_at, banner_id)
  values (v_account, v_title, v_body, v_url, v_aud ->> 'audience', v_aud ->> 'stock', (v_aud ->> 'days')::integer,
          v_aud ->> 'platform', (v_aud ->> 'account')::uuid,
          case when p_banner.starts_at > now() then p_banner.starts_at end, p_me, 'pending', now(), p_banner.id)
  returning id into v_id;

  perform cs.audit('community.campaign_save', null, null,
                   jsonb_build_object('campaign', v_id, 'audience', v_aud, 'banner', p_banner.id));
  perform cs.audit('community.campaign_submit', null, null, jsonb_build_object('campaign', v_id, 'banner', p_banner.id));
  return v_id;
end;
$$;

drop function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text, text, boolean,
                                       integer, text, text, text, text, text, integer);

create function cs_api.admin_save_banner(
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
  v_campaign  uuid;
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
    if coalesce(p_notify, false) then
      v_campaign := cs.banner_campaign(v_new, v_me);
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
    'campaign', v_campaign,
    'before', case when v_old.id is not null
                   then to_jsonb(v_old) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at' end,
    'after', to_jsonb(v_new) - 'created_by' - 'updated_by' - 'created_at' - 'updated_at'));
  return private.app_banner_view(v_new)
         || case when v_campaign is null then '{}'::jsonb else jsonb_build_object('campaign_id', v_campaign) end;
end;
$$;

delete from public.feed_filters where key not in ('latest', 'top', 'media', 'polls');
insert into public.feed_filters (key, label_en, label_id, sort, content, icon, position) values
  ('latest', 'Latest', 'Terbaru', 'latest', null, 'schedule', 0),
  ('top', 'Top', 'Teratas', 'top', null, 'trending_up', 1),
  ('media', 'Chart & Media', 'Grafik & Media', 'latest', 'media', 'image', 2),
  ('polls', 'Polls', 'Polling', 'latest', 'poll', 'poll', 3)
on conflict (key) do update
  set label_en = excluded.label_en, label_id = excluded.label_id, sort = excluded.sort,
      content = excluded.content, icon = excluded.icon, position = excluded.position;
alter table public.feed_filters
  add constraint feed_filters_builtin check (key in ('latest', 'top', 'media', 'polls'));

drop function cs_api.admin_save_feed_filter(text, text, text, text, text, text, integer, boolean);
drop function cs_api.admin_reorder_feed_filters(text[]);
drop function cs_api.admin_delete_feed_filter(text);

create function cs_api.admin_set_feed_filter_enabled(p_key text, p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin,product}');
  v_key text := lower(btrim(coalesce(p_key, '')));
  v_on  boolean := coalesce(p_enabled, true);
  v_old public.feed_filters;
begin
  select * into v_old from public.feed_filters where key = v_key for update;
  if not found then
    perform private.api_error(404, 'filter_not_found', 'Filter feed tidak ditemukan');
  end if;
  if v_old.enabled is distinct from v_on then
    update public.feed_filters set enabled = v_on, updated_at = now(), updated_by = v_me where key = v_key;
    perform cs.audit('feed_filter.enabled', null, null, jsonb_build_object('key', v_key, 'enabled', v_on));
  end if;
  return cs_api.admin_feed_filters();
end;
$$;

revoke execute on function private.default_official_account() from public;
revoke execute on function cs.banner_campaign(private.app_banners, uuid) from public;
revoke execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                    text, boolean, integer, text, text, text, text, text, integer,
                                                    boolean) from public;
revoke execute on function cs_api.admin_set_feed_filter_enabled(text, boolean) from public;
grant execute on function cs_api.admin_save_banner(uuid, text, text, text, text, timestamptz, timestamptz, text[], text,
                                                   text, boolean, integer, text, text, text, text, text, integer,
                                                   boolean) to authenticated;
grant execute on function cs_api.admin_set_feed_filter_enabled(text, boolean) to authenticated;
