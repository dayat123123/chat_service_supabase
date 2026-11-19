alter table private.app_banners
  drop constraint app_banners_title_check,
  drop constraint app_banners_body_check,
  add constraint app_banners_title_length check (char_length(btrim(title)) between 1 and 120),
  add constraint app_banners_body_length check (char_length(body) <= case when display = 'strip' then 300 else 5000 end);

alter table private.app_notices
  drop constraint app_notices_title_check,
  drop constraint app_notices_body_check,
  add constraint app_notices_title_length check (char_length(btrim(title)) between 1 and 120),
  add constraint app_notices_body_length check (char_length(body) <= 5000);

alter table cs.community_campaigns
  drop constraint community_campaigns_title_check,
  drop constraint community_campaigns_body_check,
  add constraint community_campaigns_title_length check (char_length(btrim(title)) between 3 and 120),
  add constraint community_campaigns_body_length check (char_length(btrim(body)) between 1 and 500);

create or replace function private.notice_preview(p_body text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when char_length(p_body) > 280 then rtrim(left(p_body, 279)) || '…' else p_body end;
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
  if char_length(v_title) not between 1 and 120 then
    perform private.api_error(400, 'invalid_title', 'Judul banner 1–120 karakter');
  end if;
  if v_display = 'strip' and char_length(v_body) > 300 then
    perform private.api_error(400, 'invalid_body', 'Isi strip maksimal 300 karakter');
  end if;
  if char_length(v_body) > 5000 then
    perform private.api_error(400, 'invalid_body', 'Isi popup maksimal 5000 karakter');
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

create or replace function cs_api.community_save_campaign(
  p_id                  uuid,
  p_account_id          uuid,
  p_title               text,
  p_body                text,
  p_link_post_id        uuid default null,
  p_link_url            text default null,
  p_audience            text default 'all',
  p_audience_stock      text default null,
  p_send_at             timestamptz default null,
  p_version             integer default null,
  p_audience_days       integer default null,
  p_audience_platform   text default null,
  p_audience_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.post}');
  v_title text := btrim(coalesce(p_title, ''));
  v_body  text := btrim(coalesce(p_body, ''));
  v_url   text := nullif(btrim(coalesce(p_link_url, '')), '');
  v_at    timestamptz := case when p_send_at > now() then p_send_at end;
  v_aud   jsonb;
  m       cs.community_campaigns;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if char_length(v_title) not between 3 and 120 then
    perform private.api_error(400, 'invalid_title', 'Judul notifikasi 3–120 karakter');
  end if;
  if char_length(v_body) not between 3 and 500 then
    perform private.api_error(400, 'invalid_body', 'Isi notifikasi 3–500 karakter');
  end if;
  perform private.validate_text(v_title || ' ' || v_body, 'message');
  perform private.apply_content_policy(v_title || ' ' || v_body);
  if p_link_post_id is not null and v_url is not null then
    perform private.api_error(400, 'invalid_link', 'Pilih satu tujuan: postingan atau tautan');
  end if;
  if p_link_post_id is not null and not exists (
       select 1 from cs.community_posts c join public.posts p on p.id = c.post_id
       where c.id = p_link_post_id and c.status = 'published' and p.deleted_at is null) then
    perform private.api_error(400, 'invalid_link', 'Postingan tujuan harus sudah terbit');
  end if;
  if v_url is not null and (v_url !~ '^https://[^\s]+$' or char_length(v_url) > 500) then
    perform private.api_error(400, 'invalid_link', 'Tautan harus https:// dan maksimal 500 karakter');
  end if;
  v_aud := cs.community_audience_check(p_audience, p_audience_stock, p_audience_days, p_audience_platform,
                                       p_audience_account_id);

  if p_id is null then
    insert into cs.community_campaigns (account_id, title, body, link_post_id, link_url, audience, audience_stock,
                                        audience_days, audience_platform, audience_account, send_at, created_by)
    values (p_account_id, v_title, v_body, p_link_post_id, v_url, v_aud ->> 'audience', v_aud ->> 'stock',
            (v_aud ->> 'days')::integer, v_aud ->> 'platform', (v_aud ->> 'account')::uuid, v_at, v_me)
    returning * into m;
  else
    select * into m from cs.community_campaigns where id = p_id for update;
    if not found then
      perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
    end if;
    if m.created_by <> v_me then
      perform private.api_error(403, 'not_campaign_owner', 'Hanya pembuat yang bisa mengubah draf ini');
    end if;
    if m.status not in ('draft', 'rejected') then
      perform private.api_error(409, 'invalid_status', 'Notifikasi ini tidak bisa diubah lagi');
    end if;
    perform cs.check_version(m.version, p_version);
    update cs.community_campaigns
       set account_id = p_account_id, title = v_title, body = v_body, link_post_id = p_link_post_id, link_url = v_url,
           audience = v_aud ->> 'audience', audience_stock = v_aud ->> 'stock',
           audience_days = (v_aud ->> 'days')::integer, audience_platform = v_aud ->> 'platform',
           audience_account = (v_aud ->> 'account')::uuid, send_at = v_at, status = 'draft',
           updated_at = now(), version = version + 1
     where id = m.id
    returning * into m;
  end if;
  perform cs.audit('community.campaign_save', null, null, jsonb_build_object('campaign', m.id, 'audience', v_aud));
  return cs.community_campaign_view(m.id);
end;
$$;

create or replace function private.app_notice_payload(n private.app_notices)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'notice_id', n.id, 'banner_id', n.banner_id, 'title', n.title, 'body', private.notice_preview(n.body),
    'body_truncated', case when char_length(n.body) > 280 then true end, 'level', n.level,
    'link_url', case when private.banner_link_visible(n.link_url) then n.link_url end,
    'cta_label', case when private.banner_link_visible(n.link_url) then n.cta_label end,
    'image_url', n.image_url, 'sent_at', coalesce(n.started_at, now())));
$$;

create or replace function public.get_app_notice(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := case when coalesce(auth.role(), '') = 'authenticated' then auth.uid() end;
  v_note public.notifications;
  v_full private.app_notices;
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
  select * into v_full from private.app_notices a where a.id = p_id;
  return jsonb_strip_nulls(jsonb_build_object(
    'id', p_id, 'notification_id', v_note.id,
    'title', coalesce(v_full.title, v_note.payload ->> 'title'),
    'body', coalesce(v_full.body, v_note.payload ->> 'body'),
    'level', v_note.payload ->> 'level',
    'link_url', case when private.banner_link_visible(v_note.payload ->> 'link_url') then v_note.payload ->> 'link_url' end,
    'cta_label', case when private.banner_link_visible(v_note.payload ->> 'link_url') then v_note.payload ->> 'cta_label' end,
    'image_url', v_note.payload ->> 'image_url', 'sent_at', coalesce(v_note.payload ->> 'sent_at', v_note.created_at::text)));
end;
$$;

revoke execute on function private.notice_preview(text) from public;
