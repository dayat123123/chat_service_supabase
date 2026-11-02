alter table cs.agents drop constraint agents_roles_check;
alter table cs.agents add constraint agents_roles_check
  check (cardinality(roles) > 0 and roles <@ array['cs_agent', 'cs_super_admin', 'compliance', 'community']);

alter table cs.agents add column community_permissions text[] not null default '{}';
alter table cs.agents add constraint agents_community_permissions_check
  check (community_permissions <@ array['community.post', 'community.publish', 'community.moderate',
                                        'community.sanction', 'community.accounts']);

insert into cs.cs_settings (key, value, description) values
  ('community.four_eyes', 'true',
   'Postingan dan notifikasi resmi wajib disetujui staf lain (bukan pembuatnya) sebelum terbit'),
  ('community.push_ready', 'false',
   'Push notification ke HP sudah dikonfigurasi (Firebase). Diubah tim operasional, bukan dari web')
on conflict (key) do nothing;

alter table public.notifications drop constraint notifications_type;
alter table public.notifications add constraint notifications_type
  check (type in ('reply', 'mention', 'like', 'follow', 'message', 'announcement'));

create or replace function cs.community_permission_codes()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['community.post', 'community.publish', 'community.moderate', 'community.sanction', 'community.accounts'];
$$;

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
     or not (p_roles <@ '{cs_agent,cs_super_admin,compliance,community}'::text[]) then
    perform private.api_error(400, 'invalid_roles', 'Peran harus cs_agent, cs_super_admin, compliance, atau community');
  end if;
  if p_team is not null and not exists (select 1 from cs.teams t where t.code = p_team and t.active) then
    perform private.api_error(400, 'invalid_team', 'Tim tidak dikenal');
  end if;
  if coalesce(p_max, 0) not between 1 and 20 then
    perform private.api_error(400, 'invalid_limit', 'Batas tiket aktif 1–20');
  end if;
end;
$$;

create or replace function cs.has_community(p_permissions text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from cs.agents a
    where a.user_id = cs.current_agent_id() and a.disabled_at is null and a.community_permissions && p_permissions);
$$;

create or replace function cs.require_community(p_permissions text[])
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  if not cs.has_community(p_permissions) then
    perform private.api_error(403, 'community_forbidden', 'Izin komunitas Anda tidak cukup untuk aksi ini');
  end if;
  return v_me;
end;
$$;

create or replace function cs.agent_admin_view(p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.user_id,
    'agent_code', a.agent_code,
    'display_name', a.display_name,
    'email', u.email,
    'roles', to_jsonb(a.roles),
    'team', tm.code,
    'max_active_tickets', a.max_active_tickets,
    'disabled_at', a.disabled_at,
    'status', coalesce(st.status, 'offline'),
    'active_tickets', cs.active_ticket_count(a.user_id),
    'totp', exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'),
    'nasabah_permissions', to_jsonb(a.nasabah_permissions),
    'community_permissions', to_jsonb(a.community_permissions),
    'created_at', a.created_at)
  from cs.agents a
  left join cs.agent_status st on st.agent_id = a.user_id
  left join cs.teams tm on tm.id = a.team_id
  left join auth.users u on u.id = a.user_id
  where a.user_id = p_agent;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent();
  v_ready boolean := cs.nasabah_ready();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'nasabah_permissions', case when v_ready then to_jsonb(a.nasabah_permissions) else '[]'::jsonb end,
      'community_permissions', to_jsonb(a.community_permissions),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes'),
        'nasabah_ready', v_ready,
        'community_four_eyes', coalesce((cs.setting('community.four_eyes') #>> '{}')::boolean, true),
        'community_push_ready', coalesce((cs.setting('community.push_ready') #>> '{}')::boolean, false)))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.admin_set_community_permissions(p_agent_id uuid, p_permissions text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_perms text[] := coalesce((select array_agg(distinct p order by p) from unnest(coalesce(p_permissions, '{}')) p), '{}');
begin
  if not (v_perms <@ cs.community_permission_codes()) then
    perform private.api_error(400, 'invalid_permission', 'Izin komunitas tidak dikenal');
  end if;
  if not exists (select 1 from cs.agents where user_id = p_agent_id) then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  update cs.agents set community_permissions = v_perms where user_id = p_agent_id;
  perform cs.audit('agent.community_permissions', null, null,
                   jsonb_build_object('agent', p_agent_id, 'permissions', to_jsonb(v_perms)));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes')
      or p_key like 'messages.%';
$$;

create or replace function cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
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
    when p_key = 'community.four_eyes' then
      if jsonb_typeof(p_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
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
$$;

create or replace function cs.four_eyes()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((cs.setting('community.four_eyes') #>> '{}')::boolean, true);
$$;

create table cs.official_accounts (
  profile_id  uuid primary key references public.profiles (id) on delete restrict,
  created_by  uuid references cs.agents (user_id),
  created_at  timestamptz not null default now(),
  disabled_at timestamptz
);
alter table cs.official_accounts enable row level security;

create or replace function cs.official_active(p_account uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.official_accounts o where o.profile_id = p_account and o.disabled_at is null);
$$;

create or replace function cs.can_upload_official(p_folder text, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_folder ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then exists (select 1 from cs.official_accounts o where o.profile_id = p_folder::uuid)
           and cs.has_community(array[p_permission])
    else false
  end;
$$;

create policy olt_official_post_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = 'posts'
              and cs.can_upload_official((storage.foldername(name))[2], 'community.post'));

create policy olt_official_avatar_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars'
              and cs.can_upload_official((storage.foldername(name))[1], 'community.accounts'));

create or replace function cs.official_account_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id, 'username', p.username, 'display_name', p.display_name, 'bio', p.bio,
    'avatar_url', p.avatar_url, 'follower_count', p.follower_count, 'post_count', p.post_count,
    'created_at', o.created_at, 'created_by', cs.agent_name(o.created_by), 'disabled_at', o.disabled_at)
  from cs.official_accounts o
  join public.profiles p on p.id = o.profile_id
  where o.profile_id = p_id;
$$;

create or replace function cs_api.community_accounts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return coalesce((
    select jsonb_agg(cs.official_account_view(o.profile_id)
                     order by o.disabled_at nulls first, p.display_name)
    from cs.official_accounts o
    join public.profiles p on p.id = o.profile_id), '[]');
end;
$$;

create or replace function cs_api.community_save_account(p_id uuid, p_username text, p_display_name text,
                                                          p_bio text default null, p_avatar_url text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.accounts}');
  v_username text := btrim(coalesce(p_username, ''));
  v_name     text := btrim(coalesce(p_display_name, ''));
  v_bio      text := nullif(btrim(coalesce(p_bio, '')), '');
  v_avatar   text := nullif(btrim(coalesce(p_avatar_url, '')), '');
  v_id       uuid := p_id;
begin
  if v_username !~ '^[A-Za-z0-9_]{3,30}$' then
    perform private.api_error(400, 'invalid_username', 'Username 3–30 karakter: huruf, angka, atau garis bawah');
  end if;
  if char_length(v_name) not between 2 and 60 then
    perform private.api_error(400, 'invalid_name', 'Nama akun 2–60 karakter');
  end if;
  if char_length(coalesce(v_bio, '')) > 300 then
    perform private.api_error(400, 'invalid_bio', 'Bio maksimal 300 karakter');
  end if;
  if exists (select 1 from public.profiles p
             where p.username = v_username::extensions.citext and p.id is distinct from v_id) then
    perform private.api_error(409, 'username_taken', 'Username sudah dipakai');
  end if;

  if v_id is null then
    if v_avatar is not null then
      perform private.api_error(400, 'invalid_avatar', 'Unggah foto setelah akun dibuat');
    end if;
    v_id := gen_random_uuid();
    insert into public.profiles (id, olt_user_id, username, display_name, bio, is_verified, trust_level)
    values (v_id, 'official:' || v_id, v_username, v_name, v_bio, true, 3);
    insert into cs.official_accounts (profile_id, created_by) values (v_id, v_me);
    perform cs.audit('community.account_create', null, v_id,
                     jsonb_build_object('account', v_id, 'username', v_username));
  else
    if not exists (select 1 from cs.official_accounts o where o.profile_id = v_id) then
      perform private.api_error(404, 'account_not_found', 'Akun resmi tidak ditemukan');
    end if;
    if v_avatar is not null
       and v_avatar !~ ('^https?://[^/]+/storage/v1/object/public/avatars/' || v_id::text || '/[A-Za-z0-9._-]+$') then
      perform private.api_error(400, 'invalid_avatar', 'Foto akun harus diunggah lewat web CS');
    end if;
    update public.profiles
       set username = v_username, display_name = v_name, bio = v_bio, avatar_url = v_avatar
     where id = v_id;
    perform cs.audit('community.account_update', null, v_id,
                     jsonb_build_object('account', v_id, 'username', v_username));
  end if;
  return cs.official_account_view(v_id);
end;
$$;

create or replace function cs_api.community_set_account_disabled(p_id uuid, p_disabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.accounts}');
begin
  update cs.official_accounts
     set disabled_at = case when p_disabled then coalesce(disabled_at, now()) end
   where profile_id = p_id;
  if not found then
    perform private.api_error(404, 'account_not_found', 'Akun resmi tidak ditemukan');
  end if;
  perform cs.audit(case when p_disabled then 'community.account_disable' else 'community.account_enable' end,
                   null, p_id, jsonb_build_object('account', p_id));
  return cs.official_account_view(p_id);
end;
$$;

create or replace function cs.community_user_row(p public.profiles)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
    'is_verified', p.is_verified, 'trust_level', p.trust_level, 'created_at', p.created_at,
    'deleted', p.deleted_at is not null,
    'is_official', exists (select 1 from cs.official_accounts o where o.profile_id = p.id),
    'is_staff', p.olt_user_id like 'cs-staff:%',
    'banned', private.is_banned(p.id),
    'muted', private.has_active_sanction(p.id, '{mute}'));
$$;

create or replace function cs_api.community_find_users(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.moderate,community.sanction,community.accounts}');
  v_text text := btrim(coalesce(p_query, ''));
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(ltrim(v_text, '@'), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(cs.community_user_row(x) order by x.username)
    from (select p.* from public.profiles p
          where p.olt_user_id not like 'cs-staff:%'
            and (p.username::text ilike v_like or p.display_name ilike v_like)
          order by (p.username::text ilike ltrim(v_text, '@')) desc, p.username
          limit 20) x), '[]');
end;
$$;

create or replace function cs_api.community_set_verified(p_user_id uuid, p_verified boolean, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_community('{community.accounts}');
  v_profile public.profiles;
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 300 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–300 karakter');
  end if;
  select * into v_profile from public.profiles where id = p_user_id for update;
  if not found or v_profile.olt_user_id like 'cs-staff:%' then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  if exists (select 1 from cs.official_accounts o where o.profile_id = p_user_id) then
    perform private.api_error(400, 'official_account', 'Akun resmi selalu terverifikasi');
  end if;
  update public.profiles set is_verified = coalesce(p_verified, false) where id = p_user_id
  returning * into v_profile;
  perform cs.audit('community.verify_user', null, p_user_id,
                   jsonb_build_object('verified', v_profile.is_verified, 'reason', btrim(p_reason)));
  return cs.community_user_row(v_profile);
end;
$$;

create table cs.community_posts (
  id           uuid primary key default gen_random_uuid(),
  account_id   uuid not null references cs.official_accounts (profile_id),
  kind         text not null default 'post' check (kind in ('post', 'announcement')),
  title        text,
  body         text not null check (char_length(body) between 1 and 2000),
  attachments  jsonb not null default '[]' check (jsonb_typeof(attachments) = 'array'),
  pin_scope    text check (pin_scope in ('global', 'stock')),
  pin_stock    text check (pin_stock ~ '^[A-Z][A-Z0-9]{1,11}$'),
  pin_until    timestamptz,
  notify       boolean not null default false,
  status       text not null default 'draft'
               check (status in ('draft', 'pending', 'scheduled', 'published', 'rejected', 'cancelled', 'failed')),
  publish_at   timestamptz,
  post_id      uuid references public.posts (id),
  campaign_id  uuid,
  created_by   uuid not null references cs.agents (user_id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_by  uuid references cs.agents (user_id),
  reviewed_at  timestamptz,
  review_note  text,
  published_at timestamptz,
  unpinned_at  timestamptz,
  error        text,
  version      integer not null default 1,
  constraint community_posts_title check (
    (kind = 'announcement' and char_length(btrim(title)) between 3 and 80) or (kind = 'post' and title is null)),
  constraint community_posts_pin check (
    (pin_scope is null and pin_stock is null) or (pin_scope = 'global' and pin_stock is null)
    or (pin_scope = 'stock' and pin_stock is not null)),
  constraint community_posts_published check ((status = 'published') = (post_id is not null))
);
create index community_posts_status_idx on cs.community_posts (status, publish_at);
create index community_posts_pinned_idx on cs.community_posts (pin_scope, pin_stock)
  where status = 'published' and pin_scope is not null and unpinned_at is null;
alter table cs.community_posts enable row level security;

create table cs.community_campaigns (
  id             uuid primary key default gen_random_uuid(),
  account_id     uuid not null references cs.official_accounts (profile_id),
  title          text not null check (char_length(btrim(title)) between 3 and 80),
  body           text not null check (char_length(btrim(body)) between 1 and 240),
  link_post_id   uuid references cs.community_posts (id),
  link_url       text check (link_url ~ '^https://[^\s]+$' and char_length(link_url) <= 500),
  audience       text not null default 'all' check (audience in ('all', 'stock')),
  audience_stock text check (audience_stock ~ '^[A-Z][A-Z0-9]{1,11}$'),
  status         text not null default 'draft'
                 check (status in ('draft', 'pending', 'scheduled', 'sending', 'sent', 'rejected', 'cancelled')),
  send_at        timestamptz,
  created_by     uuid not null references cs.agents (user_id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  submitted_at   timestamptz,
  reviewed_by    uuid references cs.agents (user_id),
  reviewed_at    timestamptz,
  review_note    text,
  started_at     timestamptz,
  finished_at    timestamptz,
  recipients     integer not null default 0,
  last_user_id   uuid,
  version        integer not null default 1,
  constraint community_campaigns_audience check ((audience = 'stock') = (audience_stock is not null)),
  constraint community_campaigns_link check (link_post_id is null or link_url is null)
);
create index community_campaigns_status_idx on cs.community_campaigns (status, send_at);
alter table cs.community_campaigns enable row level security;

alter table cs.community_posts add constraint community_posts_campaign_fkey
  foreign key (campaign_id) references cs.community_campaigns (id);

create or replace function cs.staff_ref(p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_agent is not null then jsonb_build_object('id', p_agent, 'name', cs.agent_name(p_agent)) end;
$$;

create or replace function cs.community_account_ref(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url)
  from public.profiles p where p.id = p_account;
$$;

create or replace function cs.community_post_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id, 'account', cs.community_account_ref(c.account_id), 'kind', c.kind, 'title', c.title,
    'body', c.body, 'attachments', c.attachments,
    'pin_scope', c.pin_scope, 'pin_stock', c.pin_stock, 'pin_until', c.pin_until,
    'pinned', c.status = 'published' and c.pin_scope is not null and c.unpinned_at is null
              and (c.pin_until is null or c.pin_until > now()) and p.deleted_at is null,
    'notify', c.notify, 'status', c.status, 'publish_at', c.publish_at, 'post_id', c.post_id,
    'post', case when p.id is not null then jsonb_build_object(
              'like_count', p.like_count, 'comment_count', p.comment_count,
              'deleted', p.deleted_at is not null, 'moderation_status', p.moderation_status) end,
    'campaign', (select jsonb_build_object('id', m.id, 'status', m.status, 'recipients', m.recipients)
                 from cs.community_campaigns m where m.id = c.campaign_id),
    'created_by', cs.staff_ref(c.created_by), 'created_at', c.created_at, 'updated_at', c.updated_at,
    'submitted_at', c.submitted_at, 'reviewed_by', cs.staff_ref(c.reviewed_by), 'reviewed_at', c.reviewed_at,
    'review_note', c.review_note, 'published_at', c.published_at, 'error', c.error, 'version', c.version)
  from cs.community_posts c
  left join public.posts p on p.id = c.post_id
  where c.id = p_id;
$$;

create or replace function cs.community_campaign_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id, 'account', cs.community_account_ref(m.account_id), 'title', m.title, 'body', m.body,
    'link_post', case when m.link_post_id is not null then (
                   select jsonb_build_object('id', c.id, 'title', c.title, 'body', left(c.body, 140), 'post_id', c.post_id)
                   from cs.community_posts c where c.id = m.link_post_id) end,
    'link_url', m.link_url, 'audience', m.audience, 'audience_stock', m.audience_stock,
    'status', m.status, 'send_at', m.send_at,
    'created_by', cs.staff_ref(m.created_by), 'created_at', m.created_at, 'updated_at', m.updated_at,
    'submitted_at', m.submitted_at, 'reviewed_by', cs.staff_ref(m.reviewed_by), 'reviewed_at', m.reviewed_at,
    'review_note', m.review_note, 'started_at', m.started_at, 'finished_at', m.finished_at,
    'recipients', m.recipients, 'version', m.version)
  from cs.community_campaigns m
  where m.id = p_id;
$$;

create or replace function cs.community_audience_count(p_audience text, p_stock text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.profiles p
  where p.deleted_at is null
    and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
    and (p_audience = 'all'
         or exists (select 1 from public.stock_watchers w where w.user_id = p.id and w.stock_code = p_stock));
$$;

create or replace function cs.check_version(p_current integer, p_expected integer)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_expected is not null and p_expected <> p_current then
    perform private.api_error(409, 'stale_version', 'Data sudah diubah staf lain. Muat ulang lalu coba lagi');
  end if;
end;
$$;

create or replace function cs_api.community_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return jsonb_build_object(
    'pending_posts', (select count(*) from cs.community_posts where status = 'pending'),
    'scheduled_posts', (select count(*) from cs.community_posts where status = 'scheduled'),
    'pending_campaigns', (select count(*) from cs.community_campaigns where status = 'pending'),
    'open_reports', (select count(distinct (r.target_type, r.target_id)) from public.reports r
                     where r.status in ('open', 'reviewing')),
    'accounts', (select count(*) from cs.official_accounts where disabled_at is null),
    'four_eyes', cs.four_eyes(),
    'push_ready', coalesce((cs.setting('community.push_ready') #>> '{}')::boolean, false));
end;
$$;

create or replace function cs_api.community_posts(p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return coalesce((
    select jsonb_agg(cs.community_post_view(x.id) order by x.sort_at desc, x.id)
    from (select c.id, coalesce(c.published_at, c.publish_at, c.updated_at) as sort_at
          from cs.community_posts c
          where p_status is null or c.status = p_status
          order by coalesce(c.published_at, c.publish_at, c.updated_at) desc
          limit 300) x), '[]');
end;
$$;

create or replace function cs_api.community_save_post(
  p_id          uuid,
  p_account_id  uuid,
  p_kind        text,
  p_title       text,
  p_body        text,
  p_attachments jsonb default '[]',
  p_pin_scope   text default null,
  p_pin_stock   text default null,
  p_pin_until   timestamptz default null,
  p_notify      boolean default false,
  p_publish_at  timestamptz default null,
  p_version     integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.post}');
  v_kind   text := coalesce(p_kind, 'post');
  v_title  text := nullif(btrim(coalesce(p_title, '')), '');
  v_body   text := btrim(coalesce(p_body, ''));
  v_scope  text := nullif(btrim(coalesce(p_pin_scope, '')), '');
  v_stock  text := nullif(upper(btrim(coalesce(p_pin_stock, ''))), '');
  v_media  jsonb := coalesce(p_attachments, '[]');
  v_at     timestamptz := case when p_publish_at > now() then p_publish_at end;
  c        cs.community_posts;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if v_kind not in ('post', 'announcement') then
    perform private.api_error(400, 'invalid_kind', 'Jenis harus postingan atau pengumuman');
  end if;
  if v_kind = 'announcement' then
    if char_length(coalesce(v_title, '')) not between 3 and 80 then
      perform private.api_error(400, 'invalid_title', 'Judul pengumuman 3–80 karakter');
    end if;
    v_scope := coalesce(v_scope, 'global');
  else
    v_title := null;
  end if;
  if char_length(v_body) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Isi postingan 1–2000 karakter');
  end if;
  perform private.validate_text(v_body, 'post');
  perform private.apply_content_policy(v_body);
  perform private.validate_attachments(v_media, 'posts/' || p_account_id || '/');
  if v_scope is not null and v_scope not in ('global', 'stock') then
    perform private.api_error(400, 'invalid_pin', 'Sematkan di stream umum atau stream saham');
  end if;
  if v_scope = 'stock' and coalesce(v_stock, '') !~ '^[A-Z][A-Z0-9]{1,11}$' then
    perform private.api_error(400, 'invalid_stock', 'Kode saham tidak valid');
  end if;
  if v_scope is distinct from 'stock' then
    v_stock := null;
  end if;
  if v_scope is null and p_pin_until is not null then
    perform private.api_error(400, 'invalid_pin', 'Batas sematan hanya untuk postingan yang disematkan');
  end if;
  if p_pin_until is not null and p_pin_until <= coalesce(v_at, now()) then
    perform private.api_error(400, 'invalid_pin_until', 'Batas sematan harus setelah waktu terbit');
  end if;

  if p_id is null then
    insert into cs.community_posts (account_id, kind, title, body, attachments, pin_scope, pin_stock, pin_until,
                                    notify, publish_at, created_by)
    values (p_account_id, v_kind, v_title, v_body, v_media, v_scope, v_stock, p_pin_until,
            coalesce(p_notify, false), v_at, v_me)
    returning * into c;
  else
    select * into c from cs.community_posts where id = p_id for update;
    if not found then
      perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
    end if;
    if c.created_by <> v_me then
      perform private.api_error(403, 'not_post_owner', 'Hanya pembuat yang bisa mengubah draf ini');
    end if;
    if c.status not in ('draft', 'rejected', 'failed') then
      perform private.api_error(409, 'invalid_status', 'Postingan ini tidak bisa diubah lagi');
    end if;
    perform cs.check_version(c.version, p_version);
    update cs.community_posts
       set account_id = p_account_id, kind = v_kind, title = v_title, body = v_body, attachments = v_media,
           pin_scope = v_scope, pin_stock = v_stock, pin_until = p_pin_until, notify = coalesce(p_notify, false),
           publish_at = v_at, status = 'draft', error = null, updated_at = now(), version = version + 1
     where id = c.id
    returning * into c;
  end if;
  perform cs.audit('community.post_save', null, null, jsonb_build_object('post', c.id, 'kind', c.kind));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs_api.community_submit_post(p_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post}');
  c    cs.community_posts;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if not found then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;
  if c.created_by <> v_me then
    perform private.api_error(403, 'not_post_owner', 'Hanya pembuat yang bisa mengajukan draf ini');
  end if;
  if c.status <> 'draft' then
    perform private.api_error(409, 'invalid_status', 'Hanya draf yang bisa diajukan');
  end if;
  perform cs.check_version(c.version, p_version);
  if c.publish_at is not null and c.publish_at <= now() then
    update cs.community_posts set publish_at = null where id = c.id;
  end if;
  update cs.community_posts
     set status = 'pending', submitted_at = now(), review_note = null, reviewed_by = null, reviewed_at = null,
         updated_at = now(), version = version + 1
   where id = c.id;
  perform cs.audit('community.post_submit', null, null, jsonb_build_object('post', c.id));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs.as_system(p_sql text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_role   text := current_setting('request.jwt.claim.role', true);
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  execute p_sql;
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
end;
$$;

create or replace function cs.community_publish(p_id uuid)
returns cs.community_posts
language plpgsql
security definer
set search_path = ''
as $$
declare
  c        cs.community_posts;
  v_post   uuid;
  v_name   text;
  v_snip   text;
  v_camp   uuid;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if c.status not in ('pending', 'scheduled', 'draft') then
    return c;
  end if;
  perform cs.as_system(format(
    'insert into public.posts (author_id, body, attachments, client_id) values (%L, %L, %L::jsonb, %L)
     on conflict (author_id, client_id) where client_id is not null do nothing',
    c.account_id, c.body, c.attachments::text, c.id));
  select id into v_post from public.posts where author_id = c.account_id and client_id = c.id;

  if c.notify then
    select display_name into v_name from public.profiles where id = c.account_id;
    v_snip := left(regexp_replace(c.body, '\s+', ' ', 'g'), 200);
    insert into cs.community_campaigns (account_id, title, body, link_post_id, audience, audience_stock, status,
                                        send_at, created_by, submitted_at, reviewed_by, reviewed_at, started_at)
    values (c.account_id, left(coalesce(c.title, v_name, 'Pengumuman'), 80), v_snip, c.id,
            case when c.pin_scope = 'stock' then 'stock' else 'all' end, c.pin_stock, 'sending',
            now(), c.created_by, c.submitted_at, c.reviewed_by, c.reviewed_at, now())
    returning id into v_camp;
  end if;

  update cs.community_posts
     set status = 'published', post_id = v_post, published_at = now(), campaign_id = v_camp, error = null,
         updated_at = now(), version = version + 1
   where id = c.id
  returning * into c;
  perform cs.audit('community.post_publish', null, null, jsonb_build_object('post', c.id, 'public_post', v_post));
  if v_camp is not null then
    perform cs.community_send_batch(v_camp, 5000);
  end if;
  return c;
end;
$$;

create or replace function cs_api.community_review_post(p_id uuid, p_approve boolean, p_note text default null,
                                                         p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.publish}');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  c      cs.community_posts;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if not found then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;
  perform cs.check_version(c.version, p_version);
  if not (c.status = 'pending' or (c.status = 'draft' and c.created_by = v_me and not cs.four_eyes())) then
    perform private.api_error(409, 'invalid_status', 'Postingan ini tidak sedang menunggu persetujuan');
  end if;
  if cs.four_eyes() and c.created_by = v_me then
    perform private.api_error(403, 'four_eyes', 'Postingan harus disetujui staf lain, bukan pembuatnya');
  end if;

  if not coalesce(p_approve, false) then
    if char_length(coalesce(v_note, '')) not between 5 and 500 then
      perform private.api_error(400, 'note_required', 'Alasan penolakan 5–500 karakter');
    end if;
    update cs.community_posts
       set status = 'rejected', reviewed_by = v_me, reviewed_at = now(), review_note = v_note,
           updated_at = now(), version = version + 1
     where id = c.id;
    perform cs.audit('community.post_reject', null, null, jsonb_build_object('post', c.id, 'note', v_note));
    return cs.community_post_view(c.id);
  end if;

  if not cs.official_active(c.account_id) then
    perform private.api_error(400, 'official_inactive', 'Akun resmi postingan ini sudah dinonaktifkan');
  end if;
  update cs.community_posts
     set reviewed_by = v_me, reviewed_at = now(), review_note = v_note,
         submitted_at = coalesce(submitted_at, now()),
         status = case when publish_at > now() then 'scheduled' else status end,
         updated_at = now(), version = version + 1
   where id = c.id
  returning * into c;
  perform cs.audit('community.post_approve', null, null,
                   jsonb_build_object('post', c.id, 'scheduled', c.status = 'scheduled', 'publish_at', c.publish_at));
  if c.status <> 'scheduled' then
    perform cs.community_publish(c.id);
  end if;
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs_api.community_cancel_post(p_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post,community.publish}');
  c    cs.community_posts;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if not found then
    perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
  end if;
  perform cs.check_version(c.version, p_version);
  if not ((c.created_by = v_me and c.status in ('draft', 'pending', 'scheduled', 'rejected', 'failed'))
          or (cs.has_community('{community.publish}') and c.status in ('pending', 'scheduled'))) then
    perform private.api_error(409, 'invalid_status', 'Postingan ini tidak bisa dibatalkan');
  end if;
  update cs.community_posts set status = 'cancelled', updated_at = now(), version = version + 1 where id = c.id;
  perform cs.audit('community.post_cancel', null, null, jsonb_build_object('post', c.id));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs_api.community_pin_post(p_id uuid, p_scope text, p_stock text default null,
                                                      p_until timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.publish}');
  v_scope text := nullif(btrim(coalesce(p_scope, '')), '');
  v_stock text := nullif(upper(btrim(coalesce(p_stock, ''))), '');
  c       cs.community_posts;
begin
  select * into c from cs.community_posts where id = p_id for update;
  if not found or c.status <> 'published'
     or exists (select 1 from public.posts p where p.id = c.post_id and p.deleted_at is not null) then
    perform private.api_error(409, 'invalid_status', 'Hanya postingan yang sudah terbit yang bisa disematkan');
  end if;
  if v_scope is null then
    update cs.community_posts set unpinned_at = now(), updated_at = now(), version = version + 1 where id = c.id;
    perform cs.audit('community.post_unpin', null, null, jsonb_build_object('post', c.id));
    return cs.community_post_view(c.id);
  end if;
  if v_scope not in ('global', 'stock') or (v_scope = 'stock' and coalesce(v_stock, '') !~ '^[A-Z][A-Z0-9]{1,11}$') then
    perform private.api_error(400, 'invalid_pin', 'Sematkan di stream umum atau stream saham dengan kode valid');
  end if;
  if p_until is not null and p_until <= now() then
    perform private.api_error(400, 'invalid_pin_until', 'Batas sematan harus di masa depan');
  end if;
  update cs.community_posts
     set pin_scope = v_scope, pin_stock = case when v_scope = 'stock' then v_stock end, pin_until = p_until,
         unpinned_at = null, updated_at = now(), version = version + 1
   where id = c.id;
  perform cs.audit('community.post_pin', null, null,
                   jsonb_build_object('post', c.id, 'scope', v_scope, 'stock', v_stock, 'until', p_until));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs_api.community_delete_post(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.publish}');
  v_reason text := btrim(coalesce(p_reason, ''));
  c        cs.community_posts;
begin
  if char_length(v_reason) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  select * into c from cs.community_posts where id = p_id for update;
  if not found or c.status <> 'published' then
    perform private.api_error(409, 'invalid_status', 'Hanya postingan yang sudah terbit yang bisa dihapus');
  end if;
  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'post', p.id, p.author_id, p.body, p.attachments, v_me, 'moderator_remove'
  from public.posts p where p.id = c.post_id and p.deleted_at is null;
  update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb, moderated_at = now()
   where id = c.post_id and deleted_at is null;
  update cs.community_posts set unpinned_at = coalesce(unpinned_at, now()), updated_at = now(), version = version + 1
   where id = c.id;
  perform cs.audit('community.post_delete', null, null, jsonb_build_object('post', c.id, 'reason', v_reason));
  return cs.community_post_view(c.id);
end;
$$;

create or replace function cs.community_send_batch(p_id uuid, p_size integer default 5000)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  m       cs.community_campaigns;
  v_post  uuid;
  v_count integer;
  v_last  text;
begin
  select * into m from cs.community_campaigns where id = p_id for update;
  if m.status is distinct from 'sending' then
    return 0;
  end if;
  select c.post_id into v_post from cs.community_posts c where c.id = m.link_post_id;

  with batch as (
    select p.id
    from public.profiles p
    where p.deleted_at is null
      and p.olt_user_id not like 'official:%' and p.olt_user_id not like 'cs-staff:%'
      and (m.last_user_id is null or p.id > m.last_user_id)
      and (m.audience = 'all'
           or exists (select 1 from public.stock_watchers w where w.user_id = p.id and w.stock_code = m.audience_stock))
    order by p.id
    limit greatest(p_size, 1)
  ), sent as (
    insert into public.notifications (user_id, actor_id, type, payload)
    select b.id, m.account_id, 'announcement',
           jsonb_strip_nulls(jsonb_build_object('campaign_id', m.id, 'title', m.title, 'body', m.body,
                                                'post_id', v_post, 'url', m.link_url))
    from batch b
    returning user_id
  )
  select count(*)::integer, max(user_id::text) into v_count, v_last from sent;

  update cs.community_campaigns
     set recipients = recipients + v_count,
         last_user_id = coalesce(v_last::uuid, last_user_id),
         status = case when v_count < greatest(p_size, 1) then 'sent' else status end,
         finished_at = case when v_count < greatest(p_size, 1) then now() end,
         updated_at = now()
   where id = m.id
  returning * into m;
  if m.status = 'sent' then
    perform cs.audit('community.campaign_sent', null, null,
                     jsonb_build_object('campaign', m.id, 'recipients', m.recipients));
  end if;
  return v_count;
end;
$$;

create or replace function cs_api.community_campaigns(p_status text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
begin
  return coalesce((
    select jsonb_agg(cs.community_campaign_view(x.id) order by x.sort_at desc, x.id)
    from (select m.id, coalesce(m.started_at, m.send_at, m.updated_at) as sort_at
          from cs.community_campaigns m
          where p_status is null or m.status = p_status
          order by coalesce(m.started_at, m.send_at, m.updated_at) desc
          limit 300) x), '[]');
end;
$$;

create or replace function cs_api.community_audience_size(p_audience text, p_stock text default null)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.post,community.publish}');
  v_stock text := nullif(upper(btrim(coalesce(p_stock, ''))), '');
begin
  if coalesce(p_audience, '') not in ('all', 'stock') or (p_audience = 'stock' and coalesce(v_stock, '') !~ '^[A-Z][A-Z0-9]{1,11}$') then
    perform private.api_error(400, 'invalid_audience', 'Penerima: semua pengguna atau pemantau saham dengan kode valid');
  end if;
  return cs.community_audience_count(p_audience, v_stock);
end;
$$;

create or replace function cs_api.community_save_campaign(
  p_id             uuid,
  p_account_id     uuid,
  p_title          text,
  p_body           text,
  p_link_post_id   uuid default null,
  p_link_url       text default null,
  p_audience       text default 'all',
  p_audience_stock text default null,
  p_send_at        timestamptz default null,
  p_version        integer default null
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
  v_aud   text := coalesce(p_audience, 'all');
  v_stock text := nullif(upper(btrim(coalesce(p_audience_stock, ''))), '');
  v_at    timestamptz := case when p_send_at > now() then p_send_at end;
  m       cs.community_campaigns;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if char_length(v_title) not between 3 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul notifikasi 3–80 karakter');
  end if;
  if char_length(v_body) not between 3 and 240 then
    perform private.api_error(400, 'invalid_body', 'Isi notifikasi 3–240 karakter');
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
  if v_aud not in ('all', 'stock') or (v_aud = 'stock' and coalesce(v_stock, '') !~ '^[A-Z][A-Z0-9]{1,11}$') then
    perform private.api_error(400, 'invalid_audience', 'Penerima: semua pengguna atau pemantau saham dengan kode valid');
  end if;
  if v_aud = 'all' then
    v_stock := null;
  end if;

  if p_id is null then
    insert into cs.community_campaigns (account_id, title, body, link_post_id, link_url, audience, audience_stock,
                                        send_at, created_by)
    values (p_account_id, v_title, v_body, p_link_post_id, v_url, v_aud, v_stock, v_at, v_me)
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
           audience = v_aud, audience_stock = v_stock, send_at = v_at, status = 'draft',
           updated_at = now(), version = version + 1
     where id = m.id
    returning * into m;
  end if;
  perform cs.audit('community.campaign_save', null, null, jsonb_build_object('campaign', m.id));
  return cs.community_campaign_view(m.id);
end;
$$;

create or replace function cs_api.community_submit_campaign(p_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post}');
  m    cs.community_campaigns;
begin
  select * into m from cs.community_campaigns where id = p_id for update;
  if not found then
    perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
  end if;
  if m.created_by <> v_me then
    perform private.api_error(403, 'not_campaign_owner', 'Hanya pembuat yang bisa mengajukan draf ini');
  end if;
  if m.status <> 'draft' then
    perform private.api_error(409, 'invalid_status', 'Hanya draf yang bisa diajukan');
  end if;
  perform cs.check_version(m.version, p_version);
  update cs.community_campaigns
     set status = 'pending', submitted_at = now(), review_note = null, reviewed_by = null, reviewed_at = null,
         send_at = case when send_at > now() then send_at end, updated_at = now(), version = version + 1
   where id = m.id;
  perform cs.audit('community.campaign_submit', null, null, jsonb_build_object('campaign', m.id));
  return cs.community_campaign_view(m.id);
end;
$$;

create or replace function cs_api.community_review_campaign(p_id uuid, p_approve boolean, p_note text default null,
                                                             p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.publish}');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  m      cs.community_campaigns;
begin
  select * into m from cs.community_campaigns where id = p_id for update;
  if not found then
    perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
  end if;
  perform cs.check_version(m.version, p_version);
  if not (m.status = 'pending' or (m.status = 'draft' and m.created_by = v_me and not cs.four_eyes())) then
    perform private.api_error(409, 'invalid_status', 'Notifikasi ini tidak sedang menunggu persetujuan');
  end if;
  if cs.four_eyes() and m.created_by = v_me then
    perform private.api_error(403, 'four_eyes', 'Notifikasi harus disetujui staf lain, bukan pembuatnya');
  end if;
  if not coalesce(p_approve, false) then
    if char_length(coalesce(v_note, '')) not between 5 and 500 then
      perform private.api_error(400, 'note_required', 'Alasan penolakan 5–500 karakter');
    end if;
    update cs.community_campaigns
       set status = 'rejected', reviewed_by = v_me, reviewed_at = now(), review_note = v_note,
           updated_at = now(), version = version + 1
     where id = m.id;
    perform cs.audit('community.campaign_reject', null, null, jsonb_build_object('campaign', m.id, 'note', v_note));
    return cs.community_campaign_view(m.id);
  end if;
  if not cs.official_active(m.account_id) then
    perform private.api_error(400, 'official_inactive', 'Akun resmi notifikasi ini sudah dinonaktifkan');
  end if;
  update cs.community_campaigns
     set reviewed_by = v_me, reviewed_at = now(), review_note = v_note, submitted_at = coalesce(submitted_at, now()),
         status = case when send_at > now() then 'scheduled' else 'sending' end,
         send_at = coalesce(send_at, now()),
         started_at = case when send_at > now() then null else now() end,
         updated_at = now(), version = version + 1
   where id = m.id
  returning * into m;
  perform cs.audit('community.campaign_approve', null, null,
                   jsonb_build_object('campaign', m.id, 'scheduled', m.status = 'scheduled', 'send_at', m.send_at));
  if m.status = 'sending' then
    perform cs.community_send_batch(m.id, 5000);
  end if;
  return cs.community_campaign_view(m.id);
end;
$$;

create or replace function cs_api.community_cancel_campaign(p_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.post,community.publish}');
  m    cs.community_campaigns;
begin
  select * into m from cs.community_campaigns where id = p_id for update;
  if not found then
    perform private.api_error(404, 'campaign_not_found', 'Notifikasi tidak ditemukan');
  end if;
  perform cs.check_version(m.version, p_version);
  if not ((m.created_by = v_me and m.status in ('draft', 'pending', 'scheduled', 'rejected'))
          or (cs.has_community('{community.publish}') and m.status in ('pending', 'scheduled'))) then
    perform private.api_error(409, 'invalid_status', 'Notifikasi ini tidak bisa dibatalkan');
  end if;
  update cs.community_campaigns set status = 'cancelled', updated_at = now(), version = version + 1 where id = m.id;
  perform cs.audit('community.campaign_cancel', null, null, jsonb_build_object('campaign', m.id));
  return cs.community_campaign_view(m.id);
end;
$$;

create or replace function cs.community_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r           record;
  v_published integer := 0;
  v_failed    integer := 0;
  v_sent      integer := 0;
begin
  for r in
    select c.id from cs.community_posts c
    where c.status = 'scheduled' and c.publish_at <= now()
    order by c.publish_at
    for update skip locked
  loop
    begin
      perform cs.community_publish(r.id);
      v_published := v_published + 1;
    exception when others then
      update cs.community_posts
         set status = 'failed', error = left(coalesce(nullif(sqlerrm, ''), 'Gagal terbit'), 500),
             updated_at = now(), version = version + 1
       where id = r.id;
      perform cs.audit('community.post_failed', null, null, jsonb_build_object('post', r.id, 'error', sqlerrm));
      v_failed := v_failed + 1;
    end;
  end loop;

  update cs.community_campaigns
     set status = 'sending', started_at = now(), updated_at = now()
   where status = 'scheduled' and send_at <= now();

  for r in
    select m.id from cs.community_campaigns m where m.status = 'sending' order by m.started_at
  loop
    v_sent := v_sent + cs.community_send_batch(r.id, 5000);
  end loop;

  return jsonb_build_object('published', v_published, 'failed', v_failed, 'notifications', v_sent);
end;
$$;

select cron.schedule('cs-community', '15 seconds', 'select cs.community_tick()');

create or replace function public.get_official_accounts()
returns table (id uuid, username text, display_name text, avatar_url text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username::text, p.display_name, p.avatar_url
  from cs.official_accounts o
  join public.profiles p on p.id = o.profile_id
  where auth.uid() is not null
  order by p.display_name;
$$;

create or replace function public.get_pinned_posts(p_scope text default 'global', p_stock_code text default null)
returns table (kind text, title text, pinned_until timestamptz, post jsonb)
language sql
stable
security definer
set search_path = ''
as $$
  select c.kind, c.title, c.pin_until, (select to_jsonb(f) from private.feed_posts(array[c.post_id]) f)
  from cs.community_posts c
  join public.posts p on p.id = c.post_id
  where auth.uid() is not null
    and c.status = 'published' and c.pin_scope is not null and c.unpinned_at is null
    and (c.pin_until is null or c.pin_until > now())
    and p.deleted_at is null and p.moderation_status = 'visible'
    and ((coalesce(p_scope, 'global') = 'global' and c.pin_scope = 'global')
         or (p_scope = 'stock' and c.pin_scope = 'stock' and c.pin_stock = upper(btrim(coalesce(p_stock_code, '')))))
  order by (c.kind = 'announcement') desc, c.published_at desc
  limit 3;
$$;

create or replace function private.report_queue_rows(p_status text, p_limit integer, p_room_scope uuid default null)
returns table (target_type text, target_id uuid, report_count integer, reasons text[], priority numeric,
               first_reported_at timestamptz, last_reported_at timestamptz, author_id uuid, author_username text,
               excerpt text, target_status text)
language sql
stable
security definer
set search_path = ''
as $$
  with r as (
    select rp.target_type, rp.target_id, rp.reason, rp.created_at, coalesce(pr.trust_level, 1) as trust
    from public.reports rp
    left join public.profiles pr on pr.id = rp.reporter_id
    where rp.status = any (case when p_status = 'open' then '{open,reviewing}'::text[] else array[p_status] end)
  ), agg as (
    select r.target_type, r.target_id,
           count(*)::integer as report_count,
           array_agg(distinct r.reason order by r.reason) as reasons,
           round(sum((1 + r.trust) * case when r.reason in ('scam', 'pump_and_dump') then 2.0
                                          when r.reason = 'abuse' then 1.5 else 1.0 end)
                 / (1 + extract(epoch from now() - max(r.created_at)) / 86400.0), 2) as priority,
           min(r.created_at) as first_at, max(r.created_at) as last_at
    from r group by r.target_type, r.target_id
  )
  select a.target_type, a.target_id, a.report_count, a.reasons, a.priority, a.first_at, a.last_at,
         coalesce(p.author_id, c.author_id, m.sender_id, u.id),
         coalesce(pa.username, ca.username, ma.username, u.username)::text,
         left(coalesce(nullif(p.body, ''), nullif(c.body, ''), nullif(m.body, ''), '@' || u.username::text), 280),
         case when coalesce(p.deleted_at, c.deleted_at, m.deleted_at) is not null then 'removed'
              else coalesce(p.moderation_status, c.moderation_status, m.moderation_status, 'visible') end
  from agg a
  left join public.posts p    on a.target_type = 'post'    and p.id = a.target_id
  left join public.comments c on a.target_type = 'comment' and c.id = a.target_id
  left join public.messages m on a.target_type = 'message' and m.id = a.target_id
  left join public.profiles u on a.target_type = 'user'    and u.id = a.target_id
  left join public.profiles pa on pa.id = p.author_id
  left join public.profiles ca on ca.id = c.author_id
  left join public.profiles ma on ma.id = m.sender_id
  where p_room_scope is null
     or (a.target_type = 'message' and m.room_id in (
           select s.room_id from private.admin_room_scopes s where s.user_id = p_room_scope))
  order by a.priority desc, a.last_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
$$;

create or replace function admin_api.report_queue(p_status text default 'open', p_limit integer default 50)
returns table (target_type text, target_id uuid, report_count integer, reasons text[], priority numeric,
               first_reported_at timestamptz, last_reported_at timestamptz, author_id uuid, author_username text,
               excerpt text, target_status text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin,moderator,room_moderator,viewer}');
begin
  return query
  select * from private.report_queue_rows(p_status, p_limit, case when v_role = 'room_moderator' then auth.uid() end);
end;
$$;

create or replace function private.resolve_report(p_target_type text, p_target_id uuid, p_action text, p_reason text,
                                                  p_actor uuid, p_room_scope uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   uuid;
  v_status text;
  v_author uuid;
begin
  if p_action not in ('remove', 'hide', 'approve', 'restore', 'dismiss') then
    perform private.api_error(400, 'invalid_action', 'Aksi: remove, hide, approve, restore, atau dismiss');
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    perform private.api_error(400, 'reason_required', 'Alasan wajib diisi');
  end if;
  if p_target_type not in ('post', 'comment', 'message', 'user') then
    perform private.api_error(400, 'invalid_target', 'Target: post, comment, message, atau user');
  end if;
  if p_target_type = 'user' and p_action <> 'dismiss' then
    perform private.api_error(400, 'use_sanctions', 'Tindak user lewat admin_api.sanction_user');
  end if;
  if p_room_scope is not null then
    select m.room_id into v_room from public.messages m where p_target_type = 'message' and m.id = p_target_id;
    if v_room is null or not exists (
      select 1 from private.admin_room_scopes s where s.user_id = p_room_scope and s.room_id = v_room) then
      perform private.api_error(403, 'admin_forbidden', 'Hanya untuk pesan di room yang Anda moderasi');
    end if;
  end if;

  v_author := case p_target_type
    when 'post' then (select author_id from public.posts where id = p_target_id)
    when 'comment' then (select author_id from public.comments where id = p_target_id)
    when 'message' then (select sender_id from public.messages where id = p_target_id)
    else p_target_id end;

  if p_action = 'remove' then
    if p_target_type = 'post' then
      insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
      select 'post', id, author_id, body, attachments, p_actor, 'moderator_remove'
      from public.posts where id = p_target_id and deleted_at is null;
      update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb, moderated_at = now()
       where id = p_target_id and deleted_at is null;
    elsif p_target_type = 'comment' then
      insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
      select 'comment', id, author_id, body, p_actor, 'moderator_remove'
      from public.comments where id = p_target_id and deleted_at is null;
      update public.comments set deleted_at = now(), body = '', moderated_at = now()
       where id = p_target_id and deleted_at is null;
    else
      insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
      select 'message', id, sender_id, body, attachments, p_actor, 'moderator_remove'
      from public.messages where id = p_target_id and deleted_at is null;
      update public.messages set deleted_at = now(), body = '', attachments = '[]'::jsonb, moderated_at = now()
       where id = p_target_id and deleted_at is null;
    end if;
  elsif p_action in ('hide', 'approve', 'restore') then
    v_status := case p_action when 'hide' then 'hidden' else 'visible' end;
    if p_target_type = 'post' then
      update public.posts set moderation_status = v_status, moderated_at = now() where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set moderation_status = v_status, moderated_at = now() where id = p_target_id;
    else
      update public.messages set moderation_status = v_status, moderated_at = now() where id = p_target_id;
    end if;
  end if;

  update public.reports
     set status = case when p_action = 'dismiss' then 'dismissed' else 'resolved' end,
         resolution_note = p_reason,
         resolved_at = now()
   where target_type = p_target_type and target_id = p_target_id and status in ('open', 'reviewing');
  return v_author;
end;
$$;

create or replace function admin_api.resolve_target(p_target_type text, p_target_id uuid, p_action text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin,moderator,room_moderator}');
begin
  perform private.resolve_report(p_target_type, p_target_id, p_action, p_reason, auth.uid(),
                                 case when v_role = 'room_moderator' then auth.uid() end);
  perform private.audit('resolve_' || p_action, p_target_type, p_target_id::text,
                        jsonb_build_object('reason', p_reason));
end;
$$;

create or replace function private.apply_sanction(p_user_id uuid, p_reason text, p_category text, p_kind text,
                                                  p_duration_hours numeric, p_actor uuid)
returns private.user_sanctions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ladder jsonb := private.setting_json('moderation.sanction_ladder',
    '[{"kind":"warning"},{"kind":"mute","hours":1},{"kind":"mute","hours":24},{"kind":"ban","days":7},{"kind":"ban"}]');
  v_prior  integer;
  v_step   jsonb;
  v_kind   text;
  v_hours  numeric;
  v_row    private.user_sanctions;
begin
  if not exists (select 1 from public.profiles where id = p_user_id) then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    perform private.api_error(400, 'reason_required', 'Alasan wajib diisi');
  end if;
  if p_kind is null then
    select count(*) into v_prior from private.user_sanctions where user_id = p_user_id and revoked_at is null;
    v_step := v_ladder -> least(v_prior, jsonb_array_length(v_ladder) - 1);
    v_kind := v_step ->> 'kind';
    v_hours := coalesce((v_step ->> 'hours')::numeric, (v_step ->> 'days')::numeric * 24);
  else
    if p_kind not in ('warning', 'mute', 'ban') then
      perform private.api_error(400, 'invalid_kind', 'Jenis sanksi: warning, mute, atau ban');
    end if;
    v_kind := p_kind;
    v_hours := p_duration_hours;
  end if;
  insert into private.user_sanctions (user_id, kind, category, reason, ends_at, created_by)
  values (p_user_id, v_kind, p_category, btrim(p_reason),
          case when v_kind = 'warning' or v_hours is null then null
               else now() + make_interval(secs => (v_hours * 3600)::double precision) end,
          p_actor)
  returning * into v_row;
  if v_kind = 'ban' then
    perform private.revoke_sessions(p_user_id, 'ban');
  end if;
  return v_row;
end;
$$;

create or replace function admin_api.sanction_user(p_user_id uuid, p_reason text, p_category text default null,
                                                   p_kind text default null, p_duration_hours numeric default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin,moderator}');
  v_row  private.user_sanctions;
begin
  v_row := private.apply_sanction(p_user_id, p_reason, p_category, p_kind, p_duration_hours, auth.uid());
  perform private.audit('sanction_' || v_row.kind, 'user', p_user_id::text,
    jsonb_build_object('sanction_id', v_row.id, 'category', p_category, 'reason', p_reason, 'ends_at', v_row.ends_at));
  return to_jsonb(v_row);
end;
$$;

create or replace function cs.check_moderation_target(p_user_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.profiles p
             where p.id = p_user_id
               and (p.olt_user_id like 'cs-staff:%' or p.olt_user_id like 'official:%')) then
    perform private.api_error(400, 'protected_account', 'Akun staf dan akun resmi tidak bisa diberi sanksi');
  end if;
end;
$$;

create or replace function cs_api.community_reports(p_status text default 'open', p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate,community.sanction}');
begin
  if coalesce(p_status, '') not in ('open', 'resolved', 'dismissed') then
    perform private.api_error(400, 'invalid_status', 'Status laporan: open, resolved, atau dismissed');
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(q) || jsonb_build_object(
             'author_display_name', pr.display_name,
             'author_is_official', exists (select 1 from cs.official_accounts o where o.profile_id = q.author_id))
           order by q.priority desc, q.last_reported_at desc)
    from private.report_queue_rows(p_status, p_limit, null) q
    left join public.profiles pr on pr.id = q.author_id), '[]');
end;
$$;

create or replace function cs_api.community_resolve_report(p_target_type text, p_target_id uuid, p_action text,
                                                            p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.moderate}');
  v_author uuid;
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  v_author := private.resolve_report(p_target_type, p_target_id, p_action, btrim(p_reason), v_me, null);
  perform cs.audit('community.report_resolve', null, v_author,
                   jsonb_build_object('target_type', p_target_type, 'target_id', p_target_id,
                                      'action', p_action, 'reason', btrim(p_reason)));
  return jsonb_build_object('target_type', p_target_type, 'target_id', p_target_id, 'action', p_action);
end;
$$;

create or replace function cs_api.community_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_community('{community.moderate,community.sanction,community.accounts}');
  v_profile public.profiles;
begin
  select * into v_profile from public.profiles where id = p_user_id;
  if not found or v_profile.olt_user_id like 'cs-staff:%' then
    perform private.api_error(404, 'user_not_found', 'Pengguna tidak ditemukan');
  end if;
  return jsonb_build_object(
    'profile', cs.community_user_row(v_profile) || jsonb_build_object('bio', v_profile.bio),
    'counts', jsonb_build_object(
      'posts', (select count(*) from public.posts where author_id = p_user_id and deleted_at is null),
      'comments', (select count(*) from public.comments where author_id = p_user_id and deleted_at is null),
      'reports_against', (select count(*) from public.reports r
                          where (r.target_type = 'user' and r.target_id = p_user_id)
                             or (r.target_type = 'post' and r.target_id in (select id from public.posts where author_id = p_user_id))
                             or (r.target_type = 'comment' and r.target_id in (select id from public.comments where author_id = p_user_id))
                             or (r.target_type = 'message' and r.target_id in (select id from public.messages where sender_id = p_user_id))),
      'reports_made', (select count(*) from public.reports where reporter_id = p_user_id)),
    'recent_posts', coalesce((select jsonb_agg(x) from (
        select id, left(body, 280) as body, moderation_status, created_at from public.posts
        where author_id = p_user_id and deleted_at is null order by created_at desc limit 10) x), '[]'),
    'recent_comments', coalesce((select jsonb_agg(x) from (
        select id, post_id, left(body, 280) as body, moderation_status, created_at from public.comments
        where author_id = p_user_id and deleted_at is null order by created_at desc limit 10) x), '[]'),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'id', s.id, 'kind', s.kind, 'category', s.category, 'reason', s.reason, 'starts_at', s.starts_at,
        'ends_at', s.ends_at, 'created_at', s.created_at, 'created_by', cs.agent_name(s.created_by),
        'revoked_at', s.revoked_at, 'revoke_reason', s.revoke_reason,
        'active', s.revoked_at is null and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()))
        order by s.created_at desc)
      from private.user_sanctions s where s.user_id = p_user_id), '[]'));
end;
$$;

create or replace function cs_api.community_sanction_user(p_user_id uuid, p_reason text, p_kind text default null,
                                                           p_duration_hours numeric default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_community('{community.sanction}');
  v_row private.user_sanctions;
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  if p_duration_hours is not null and (p_duration_hours <= 0 or p_duration_hours > 8760) then
    perform private.api_error(400, 'invalid_duration', 'Durasi 1 jam sampai 365 hari');
  end if;
  perform cs.check_moderation_target(p_user_id);
  v_row := private.apply_sanction(p_user_id, btrim(p_reason), 'community', p_kind, p_duration_hours, v_me);
  perform cs.audit('community.sanction', null, p_user_id,
                   jsonb_build_object('sanction_id', v_row.id, 'kind', v_row.kind, 'ends_at', v_row.ends_at,
                                      'reason', v_row.reason));
  return cs_api.community_user(p_user_id);
end;
$$;

create or replace function cs_api.community_revoke_sanction(p_sanction_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.sanction}');
  v_user uuid;
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  update private.user_sanctions
     set revoked_at = now(), revoked_by = v_me, revoke_reason = btrim(p_reason)
   where id = p_sanction_id and revoked_at is null
  returning user_id into v_user;
  if v_user is null then
    perform private.api_error(404, 'not_found', 'Sanksi aktif tidak ditemukan');
  end if;
  perform cs.audit('community.sanction_revoke', null, v_user,
                   jsonb_build_object('sanction_id', p_sanction_id, 'reason', btrim(p_reason)));
  return cs_api.community_user(v_user);
end;
$$;

create or replace function cs_api.community_revoke_sessions(p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.sanction}');
begin
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–500 karakter');
  end if;
  perform cs.check_moderation_target(p_user_id);
  perform private.revoke_sessions(p_user_id, 'community');
  perform cs.audit('community.sessions_revoke', null, p_user_id, jsonb_build_object('reason', btrim(p_reason)));
  return cs_api.community_user(p_user_id);
end;
$$;

revoke execute on function cs.community_permission_codes() from public;
revoke execute on function cs.has_community(text[]) from public;
revoke execute on function cs.require_community(text[]) from public;
revoke execute on function cs.four_eyes() from public;
revoke execute on function cs.official_active(uuid) from public;
revoke execute on function cs.official_account_view(uuid) from public;
revoke execute on function cs.community_user_row(public.profiles) from public;
revoke execute on function cs.staff_ref(uuid) from public;
revoke execute on function cs.community_account_ref(uuid) from public;
revoke execute on function cs.community_post_view(uuid) from public;
revoke execute on function cs.community_campaign_view(uuid) from public;
revoke execute on function cs.community_audience_count(text, text) from public;
revoke execute on function cs.check_version(integer, integer) from public;
revoke execute on function cs.as_system(text) from public;
revoke execute on function cs.community_publish(uuid) from public;
revoke execute on function cs.community_send_batch(uuid, integer) from public;
revoke execute on function cs.community_tick() from public;
revoke execute on function cs.check_moderation_target(uuid) from public;
revoke execute on function private.report_queue_rows(text, integer, uuid) from public;
revoke execute on function private.resolve_report(text, uuid, text, text, uuid, uuid) from public;
revoke execute on function private.apply_sanction(uuid, text, text, text, numeric, uuid) from public;

grant execute on function cs.can_upload_official(text, text) to authenticated;

revoke execute on function cs_api.admin_set_community_permissions(uuid, text[]) from public;
revoke execute on function cs_api.community_accounts() from public;
revoke execute on function cs_api.community_save_account(uuid, text, text, text, text) from public;
revoke execute on function cs_api.community_set_account_disabled(uuid, boolean) from public;
revoke execute on function cs_api.community_find_users(text) from public;
revoke execute on function cs_api.community_set_verified(uuid, boolean, text) from public;
revoke execute on function cs_api.community_overview() from public;
revoke execute on function cs_api.community_posts(text) from public;
revoke execute on function cs_api.community_save_post(uuid, uuid, text, text, text, jsonb, text, text, timestamptz, boolean, timestamptz, integer) from public;
revoke execute on function cs_api.community_submit_post(uuid, integer) from public;
revoke execute on function cs_api.community_review_post(uuid, boolean, text, integer) from public;
revoke execute on function cs_api.community_cancel_post(uuid, integer) from public;
revoke execute on function cs_api.community_pin_post(uuid, text, text, timestamptz) from public;
revoke execute on function cs_api.community_delete_post(uuid, text) from public;
revoke execute on function cs_api.community_campaigns(text) from public;
revoke execute on function cs_api.community_audience_size(text, text) from public;
revoke execute on function cs_api.community_save_campaign(uuid, uuid, text, text, uuid, text, text, text, timestamptz, integer) from public;
revoke execute on function cs_api.community_submit_campaign(uuid, integer) from public;
revoke execute on function cs_api.community_review_campaign(uuid, boolean, text, integer) from public;
revoke execute on function cs_api.community_cancel_campaign(uuid, integer) from public;
revoke execute on function cs_api.community_reports(text, integer) from public;
revoke execute on function cs_api.community_resolve_report(text, uuid, text, text) from public;
revoke execute on function cs_api.community_user(uuid) from public;
revoke execute on function cs_api.community_sanction_user(uuid, text, text, numeric) from public;
revoke execute on function cs_api.community_revoke_sanction(uuid, text) from public;
revoke execute on function cs_api.community_revoke_sessions(uuid, text) from public;
revoke execute on function public.get_official_accounts() from public;
revoke execute on function public.get_pinned_posts(text, text) from public;

grant execute on function cs_api.admin_set_community_permissions(uuid, text[]) to authenticated;
grant execute on function cs_api.community_accounts() to authenticated;
grant execute on function cs_api.community_save_account(uuid, text, text, text, text) to authenticated;
grant execute on function cs_api.community_set_account_disabled(uuid, boolean) to authenticated;
grant execute on function cs_api.community_find_users(text) to authenticated;
grant execute on function cs_api.community_set_verified(uuid, boolean, text) to authenticated;
grant execute on function cs_api.community_overview() to authenticated;
grant execute on function cs_api.community_posts(text) to authenticated;
grant execute on function cs_api.community_save_post(uuid, uuid, text, text, text, jsonb, text, text, timestamptz, boolean, timestamptz, integer) to authenticated;
grant execute on function cs_api.community_submit_post(uuid, integer) to authenticated;
grant execute on function cs_api.community_review_post(uuid, boolean, text, integer) to authenticated;
grant execute on function cs_api.community_cancel_post(uuid, integer) to authenticated;
grant execute on function cs_api.community_pin_post(uuid, text, text, timestamptz) to authenticated;
grant execute on function cs_api.community_delete_post(uuid, text) to authenticated;
grant execute on function cs_api.community_campaigns(text) to authenticated;
grant execute on function cs_api.community_audience_size(text, text) to authenticated;
grant execute on function cs_api.community_save_campaign(uuid, uuid, text, text, uuid, text, text, text, timestamptz, integer) to authenticated;
grant execute on function cs_api.community_submit_campaign(uuid, integer) to authenticated;
grant execute on function cs_api.community_review_campaign(uuid, boolean, text, integer) to authenticated;
grant execute on function cs_api.community_cancel_campaign(uuid, integer) to authenticated;
grant execute on function cs_api.community_reports(text, integer) to authenticated;
grant execute on function cs_api.community_resolve_report(text, uuid, text, text) to authenticated;
grant execute on function cs_api.community_user(uuid) to authenticated;
grant execute on function cs_api.community_sanction_user(uuid, text, text, numeric) to authenticated;
grant execute on function cs_api.community_revoke_sanction(uuid, text) to authenticated;
grant execute on function cs_api.community_revoke_sessions(uuid, text) to authenticated;
grant execute on function public.get_official_accounts() to authenticated;
grant execute on function public.get_pinned_posts(text, text) to authenticated;
