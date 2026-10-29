-- 0013_moderation_admin.sql
-- Fondasi moderasi & admin (docs/PROMPT-PRODUCTION.md 4.5, 4.6, 4.8 dan
-- docs/PROMPT-FEATURES.md 2.1, 2.6.c):
--   - status moderasi konten: visible | held (menunggu review) | hidden (disembunyikan
--     moderator). Konten non-visible hanya terlihat oleh penulisnya (RLS);
--   - admin: akun terpisah (GoTrue) + 2FA TOTP (klaim aal2), 5 peran;
--   - sanksi bertingkat (peringatan, mute, ban) dan pencabutan sesi;
--   - audit log admin yang tidak bisa diubah/dihapus;
--   - arsip konten untuk regulator (retensi + legal hold);
--   - API admin di schema `admin_api` (dipakai panel admin di F1).

-- ---------------------------------------------------------------------------
-- Status moderasi konten
-- ---------------------------------------------------------------------------
alter table public.posts
  add column if not exists moderation_status text not null default 'visible',
  add column if not exists moderated_at timestamptz;
alter table public.posts drop constraint if exists posts_moderation_status;
alter table public.posts add constraint posts_moderation_status
  check (moderation_status in ('visible', 'held', 'hidden'));

alter table public.comments
  add column if not exists moderation_status text not null default 'visible',
  add column if not exists moderated_at timestamptz;
alter table public.comments drop constraint if exists comments_moderation_status;
alter table public.comments add constraint comments_moderation_status
  check (moderation_status in ('visible', 'held', 'hidden'));

alter table public.messages
  add column if not exists moderation_status text not null default 'visible',
  add column if not exists moderated_at timestamptz;
alter table public.messages drop constraint if exists messages_moderation_status;
alter table public.messages add constraint messages_moderation_status
  check (moderation_status in ('visible', 'held', 'hidden'));

-- Konten held/hidden hanya terlihat penulis. Berlaku juga untuk Realtime
-- (postgres_changes diperiksa dengan RLS), sehingga isinya tidak bocor.
drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts
  for select to authenticated
  using (
    deleted_at is null
    and author_id not in (select private.blocked_user_ids())
    and (moderation_status = 'visible' or author_id = (select auth.uid()))
  );

drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments
  for select to authenticated
  using (
    author_id not in (select private.blocked_user_ids())
    and (moderation_status = 'visible' or author_id = (select auth.uid()))
  );

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (
    room_id in (select private.my_room_ids())
    and (sender_id is null or sender_id not in (select private.blocked_user_ids()))
    and (moderation_status = 'visible' or sender_id = (select auth.uid()))
  );

-- ---------------------------------------------------------------------------
-- Admin: akun GoTrue terpisah, wajib 2FA (aal2). JWT user OLT dari auth-bridge
-- tidak punya klaim aal, sehingga tidak pernah lolos pemeriksaan admin.
-- ---------------------------------------------------------------------------
create table if not exists private.admin_users (
  user_id      uuid primary key,
  role         text not null,
  display_name text,
  created_at   timestamptz not null default now(),
  created_by   uuid,
  disabled_at  timestamptz,
  constraint admin_users_role check (
    role in ('super_admin', 'compliance_admin', 'moderator', 'room_moderator', 'viewer')
  )
);
alter table private.admin_users enable row level security;

-- room_moderator hanya mengelola room tertentu.
create table if not exists private.admin_room_scopes (
  user_id uuid not null references private.admin_users(user_id) on delete cascade,
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  primary key (user_id, room_id)
);
alter table private.admin_room_scopes enable row level security;

create or replace function private.admin_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.role
  from private.admin_users a
  where a.user_id = auth.uid()
    and a.disabled_at is null
    and coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

-- Lempar 403 bila pemanggil bukan admin aktif (aal2) dengan salah satu peran.
create or replace function private.require_admin(p_roles text[])
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := private.admin_role();
begin
  if v_role is null then
    perform private.api_error(403, 'admin_required', 'Butuh akun admin aktif dengan 2FA');
  end if;
  if not (v_role = any (p_roles)) then
    perform private.api_error(403, 'admin_forbidden', 'Peran admin tidak cukup untuk aksi ini');
  end if;
  return v_role;
end;
$$;

-- ---------------------------------------------------------------------------
-- Audit log admin: hanya bisa ditambah. Update/delete/truncate ditolak, kecuali
-- penghapusan oleh job retensi (private.run_retention, 0015).
-- ---------------------------------------------------------------------------
create table if not exists private.admin_audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  actor_role  text,
  action      text not null,
  target_type text,
  target_id   text,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists admin_audit_log_created_idx on private.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_target_idx on private.admin_audit_log (target_type, target_id);
alter table private.admin_audit_log enable row level security;

create or replace function private.admin_audit_log_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('olt.audit_retention', true) = 'on' then
    return old;
  end if;
  raise exception 'admin_audit_log hanya bisa ditambah, tidak bisa diubah atau dihapus'
    using errcode = '42501';
end;
$$;

drop trigger if exists admin_audit_log_guard on private.admin_audit_log;
create trigger admin_audit_log_guard
  before update or delete on private.admin_audit_log
  for each row execute function private.admin_audit_log_guard();
drop trigger if exists admin_audit_log_no_truncate on private.admin_audit_log;
create trigger admin_audit_log_no_truncate
  before truncate on private.admin_audit_log
  for each statement execute function private.admin_audit_log_guard();

create or replace function private.audit(
  p_action text, p_target_type text, p_target_id text, p_details jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.admin_audit_log (actor_id, actor_role, action, target_type, target_id, details)
  values (auth.uid(), private.admin_role(), p_action, p_target_type, p_target_id,
          coalesce(p_details, '{}'::jsonb));
$$;

-- Log akses data pribadi (UU PDP): siapa membuka data pribadi siapa, untuk apa.
create table if not exists private.personal_data_access_log (
  id            bigint generated always as identity primary key,
  accessor_id   uuid,
  accessor_role text,
  subject_id    uuid,
  purpose       text not null,
  fields        text[] not null default '{}',
  created_at    timestamptz not null default now()
);
create index if not exists personal_data_access_log_subject_idx
  on private.personal_data_access_log (subject_id, created_at desc);
alter table private.personal_data_access_log enable row level security;

create or replace function private.log_personal_data_access(p_subject uuid, p_purpose text, p_fields text[])
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.personal_data_access_log (accessor_id, accessor_role, subject_id, purpose, fields)
  values (auth.uid(), coalesce(private.admin_role(), auth.role()), p_subject, p_purpose, p_fields);
$$;

-- ---------------------------------------------------------------------------
-- Arsip konten untuk regulator: retensi + legal hold. Hanya super_admin yang
-- bisa membaca (lewat admin_api.archive, setiap akses dicatat).
-- ---------------------------------------------------------------------------
alter table private.content_archive
  add column if not exists reason text not null default 'user_delete',
  add column if not exists category text,
  add column if not exists legal_hold boolean not null default false,
  add column if not exists retain_until timestamptz;
alter table private.content_archive drop constraint if exists content_archive_reason;
alter table private.content_archive add constraint content_archive_reason
  check (reason in ('user_delete', 'moderator_remove', 'account_delete', 'policy_block'));

insert into private.settings (key, value, description) values
  ('retention.archive_days', '1825',
   'Lama arsip konten untuk regulator (hari). DEFAULT SEMENTARA: tetapkan bersama tim legal.')
on conflict (key) do nothing;

create or replace function private.content_archive_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.retain_until is null then
    new.retain_until := new.deleted_at
      + make_interval(days => private.setting_num('retention.archive_days', 1825)::integer);
  end if;
  return new;
end;
$$;

drop trigger if exists content_archive_defaults on private.content_archive;
create trigger content_archive_defaults
  before insert on private.content_archive
  for each row execute function private.content_archive_defaults();

update private.content_archive
   set retain_until = deleted_at + interval '1825 days'
 where retain_until is null;

-- ---------------------------------------------------------------------------
-- Sanksi: peringatan, mute (tidak bisa mengirim konten), ban (tidak bisa memakai
-- fitur sosial sama sekali). ends_at kosong = permanen.
-- ---------------------------------------------------------------------------
create table if not exists private.user_sanctions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  kind          text not null,
  category      text,
  reason        text not null,
  starts_at     timestamptz not null default now(),
  ends_at       timestamptz,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  revoked_at    timestamptz,
  revoked_by    uuid,
  revoke_reason text,
  constraint user_sanctions_kind check (kind in ('warning', 'mute', 'ban')),
  constraint user_sanctions_period check (ends_at is null or ends_at > starts_at)
);
create index if not exists user_sanctions_user_idx on private.user_sanctions (user_id, created_at desc);
create index if not exists user_sanctions_active_idx
  on private.user_sanctions (user_id, kind) where revoked_at is null;
alter table private.user_sanctions enable row level security;

insert into private.settings (key, value, description) values
  ('moderation.sanction_ladder',
   '[{"kind":"warning"},{"kind":"mute","hours":1},{"kind":"mute","hours":24},{"kind":"ban","days":7},{"kind":"ban"}]',
   'Sanksi bertingkat: langkah ke-n dipakai untuk pelanggaran ke-n (langkah terakhir berulang)')
on conflict (key) do nothing;

create or replace function private.has_active_sanction(p_user uuid, p_kinds text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.user_sanctions s
    where s.user_id = p_user
      and s.kind = any (p_kinds)
      and s.revoked_at is null
      and s.starts_at <= now()
      and (s.ends_at is null or s.ends_at > now())
  );
$$;

create or replace function private.is_banned(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_sanction(p_user, '{ban}');
$$;

create or replace function private.is_muted(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_sanction(p_user, '{mute,ban}');
$$;

-- ---------------------------------------------------------------------------
-- Pencabutan sesi: JWT yang diterbitkan (iat) sebelum revoked_before ditolak
-- walaupun belum kedaluwarsa. Diperiksa PostgREST di setiap request
-- (PGRST_DB_PRE_REQUEST = private.check_request), plus policy Realtime & Storage.
-- ---------------------------------------------------------------------------
create table if not exists private.user_sessions (
  user_id        uuid primary key references public.profiles(id) on delete cascade,
  revoked_before timestamptz not null,
  reason         text,
  updated_at     timestamptz not null default now()
);
alter table private.user_sessions enable row level security;

create or replace function private.revoke_sessions(p_user uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  -- Dibulatkan ke detik: iat JWT berresolusi detik.
  insert into private.user_sessions (user_id, revoked_before, reason)
  values (p_user, date_trunc('second', now()), p_reason)
  on conflict (user_id) do update
    set revoked_before = date_trunc('second', now()), reason = excluded.reason, updated_at = now();
$$;

create or replace function private.check_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid;
  v_revoked timestamptz;
  v_iat     numeric;
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  if private.is_banned(v_uid) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
  end if;
  select s.revoked_before into v_revoked from private.user_sessions s where s.user_id = v_uid;
  if v_revoked is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::numeric;
    if v_iat is null or to_timestamp(v_iat) < v_revoked then
      perform private.api_error(401, 'session_revoked', 'Sesi sudah dicabut, silakan masuk ulang');
    end if;
  end if;
end;
$$;

-- PostgREST menjalankan pre-request untuk semua role, termasuk anon.
grant usage on schema private to anon;
grant execute on function private.check_request() to anon, authenticated;

-- Sanksi aktif milik sendiri (agar app bisa menjelaskan pembatasan ke user).
create or replace function public.get_my_sanctions()
returns table (id uuid, kind text, category text, reason text, starts_at timestamptz, ends_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.kind, s.category, s.reason, s.starts_at, s.ends_at
  from private.user_sanctions s
  where s.user_id = auth.uid()
    and s.revoked_at is null
    and (s.ends_at is null or s.ends_at > now())
  order by s.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- User yang di-ban tidak bisa bergabung ke channel private Realtime maupun upload.
-- ---------------------------------------------------------------------------
create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_topic is null or private.is_banned(auth.uid()) then
    return false;
  end if;
  if p_topic = 'online' then
    return true;
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return exists (
      select 1 from public.chat_members
      where room_id = substring(p_topic from 6)::uuid and user_id = auth.uid()
    );
  end if;
  return false;
end;
$$;

create or replace function private.not_banned()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not private.is_banned(auth.uid());
$$;
grant execute on function private.not_banned() to authenticated;

drop policy if exists olt_avatars_insert on storage.objects;
create policy olt_avatars_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select private.not_banned())
  );

drop policy if exists olt_attachments_insert on storage.objects;
create policy olt_attachments_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (select private.not_banned())
    and (
      (
        (storage.foldername(name))[1] = 'posts'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
      or (
        (storage.foldername(name))[1] = 'rooms'
        and (storage.foldername(name))[3] = (select auth.uid())::text
        and private.is_room_member_text((storage.foldername(name))[2])
      )
    )
  );

-- ---------------------------------------------------------------------------
-- API admin (panel admin F1). Semua fungsi memeriksa peran di server dan
-- mencatat aksinya ke audit log.
--
--   viewer            : lihat antrean & detail (tanpa data pribadi)
--   room_moderator    : tindak laporan pesan di room yang ditugaskan
--   moderator         : tindak semua laporan, beri sanksi, cabut sesi
--   compliance_admin  : + kebijakan konten (kata terlarang, trust, verifikasi),
--                       tunjuk moderator, baca audit log
--   super_admin       : + tunjuk admin lain, arsip regulator, pengaturan
-- ---------------------------------------------------------------------------
create schema if not exists admin_api;
revoke all on schema admin_api from public;
grant usage on schema admin_api to authenticated;

create or replace function admin_api.whoami()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin(
    '{super_admin,compliance_admin,moderator,room_moderator,viewer}');
begin
  return jsonb_build_object('user_id', auth.uid(), 'role', v_role);
end;
$$;

-- Antrean laporan per target, diurutkan prioritas: jumlah pelapor berbobot
-- (trust_level pelapor, jenis laporan) dan kebaruan.
create or replace function admin_api.report_queue(p_status text default 'open', p_limit integer default 50)
returns table (
  target_type       text,
  target_id         uuid,
  report_count      integer,
  reasons           text[],
  priority          numeric,
  first_reported_at timestamptz,
  last_reported_at  timestamptz,
  author_id         uuid,
  author_username   text,
  excerpt           text,
  target_status     text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin(
    '{super_admin,compliance_admin,moderator,room_moderator,viewer}');
begin
  return query
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
  where v_role <> 'room_moderator'
     or (a.target_type = 'message' and m.room_id in (
           select s.room_id from private.admin_room_scopes s where s.user_id = auth.uid()))
  order by a.priority desc, a.last_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- Tindak satu target laporan.
--   remove  : hapus (soft delete + arsip, alasan moderator_remove)
--   hide    : sembunyikan dari user lain (bisa dipulihkan)
--   approve : held -> visible (lolos review)
--   restore : hidden -> visible
--   dismiss : laporan diabaikan, konten tidak diubah
create or replace function admin_api.resolve_target(
  p_target_type text, p_target_id uuid, p_action text, p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_admin('{super_admin,compliance_admin,moderator,room_moderator}');
  v_room   uuid;
  v_status text;
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
  if v_role = 'room_moderator' then
    select m.room_id into v_room from public.messages m where p_target_type = 'message' and m.id = p_target_id;
    if v_room is null or not exists (
      select 1 from private.admin_room_scopes s where s.user_id = auth.uid() and s.room_id = v_room) then
      perform private.api_error(403, 'admin_forbidden', 'Hanya untuk pesan di room yang Anda moderasi');
    end if;
  end if;

  if p_action = 'remove' then
    if p_target_type = 'post' then
      insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
      select 'post', id, author_id, body, attachments, auth.uid(), 'moderator_remove'
      from public.posts where id = p_target_id and deleted_at is null;
      update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb,
                              moderated_at = now()
       where id = p_target_id and deleted_at is null;
    elsif p_target_type = 'comment' then
      insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
      select 'comment', id, author_id, body, auth.uid(), 'moderator_remove'
      from public.comments where id = p_target_id and deleted_at is null;
      update public.comments set deleted_at = now(), body = '',
                                 moderated_at = now()
       where id = p_target_id and deleted_at is null;
    else
      insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
      select 'message', id, sender_id, body, attachments, auth.uid(), 'moderator_remove'
      from public.messages where id = p_target_id and deleted_at is null;
      update public.messages set deleted_at = now(), body = '', attachments = '[]'::jsonb,
                                 moderated_at = now()
       where id = p_target_id and deleted_at is null;
    end if;
  elsif p_action in ('hide', 'approve', 'restore') then
    v_status := case p_action when 'hide' then 'hidden' else 'visible' end;
    if p_target_type = 'post' then
      update public.posts set moderation_status = v_status, moderated_at = now()
       where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set moderation_status = v_status, moderated_at = now()
       where id = p_target_id;
    else
      update public.messages set moderation_status = v_status, moderated_at = now()
       where id = p_target_id;
    end if;
  end if;

  update public.reports
     set status = case when p_action = 'dismiss' then 'dismissed' else 'resolved' end,
         resolution_note = p_reason,
         resolved_at = now()
   where target_type = p_target_type and target_id = p_target_id and status in ('open', 'reviewing');

  perform private.audit('resolve_' || p_action, p_target_type, p_target_id::text,
                        jsonb_build_object('reason', p_reason));
end;
$$;

-- Beri sanksi. Tanpa p_kind: ikuti tangga sanksi berdasarkan jumlah sanksi
-- sebelumnya. Ban otomatis mencabut semua sesi user.
create or replace function admin_api.sanction_user(
  p_user_id        uuid,
  p_reason         text,
  p_category       text default null,
  p_kind           text default null,
  p_duration_hours numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_admin('{super_admin,compliance_admin,moderator}');
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
    select count(*) into v_prior from private.user_sanctions
     where user_id = p_user_id and revoked_at is null;
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
          auth.uid())
  returning * into v_row;

  if v_kind = 'ban' then
    perform private.revoke_sessions(p_user_id, 'ban');
  end if;

  perform private.audit('sanction_' || v_kind, 'user', p_user_id::text,
    jsonb_build_object('sanction_id', v_row.id, 'category', p_category, 'reason', p_reason, 'ends_at', v_row.ends_at));
  return to_jsonb(v_row);
end;
$$;

create or replace function admin_api.revoke_sanction(p_sanction_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin,moderator}');
  v_user uuid;
begin
  update private.user_sanctions
     set revoked_at = now(), revoked_by = auth.uid(), revoke_reason = p_reason
   where id = p_sanction_id and revoked_at is null
  returning user_id into v_user;
  if v_user is null then
    perform private.api_error(404, 'not_found', 'Sanksi aktif tidak ditemukan');
  end if;
  perform private.audit('revoke_sanction', 'user', v_user::text,
                        jsonb_build_object('sanction_id', p_sanction_id, 'reason', p_reason));
end;
$$;

create or replace function admin_api.revoke_user_sessions(p_user_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin,moderator}');
begin
  perform private.revoke_sessions(p_user_id, coalesce(p_reason, 'admin'));
  perform private.audit('revoke_sessions', 'user', p_user_id::text, jsonb_build_object('reason', p_reason));
end;
$$;

-- Detail user untuk review. Email hanya untuk compliance_admin/super_admin dan
-- setiap aksesnya dicatat.
create or replace function admin_api.user_detail(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role    text := private.require_admin(
    '{super_admin,compliance_admin,moderator,room_moderator,viewer}');
  v_profile public.profiles;
  v_email   text;
begin
  select * into v_profile from public.profiles where id = p_user_id;
  if not found then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  if v_role in ('super_admin', 'compliance_admin') then
    select up.email into v_email from private.user_private up where up.user_id = p_user_id;
    perform private.log_personal_data_access(p_user_id, 'admin_user_detail', '{email}');
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.id, 'username', v_profile.username, 'display_name', v_profile.display_name,
      'bio', v_profile.bio, 'is_verified', v_profile.is_verified, 'trust_level', v_profile.trust_level,
      'created_at', v_profile.created_at, 'email', v_email),
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
        where author_id = p_user_id and deleted_at is null order by created_at desc limit 10) x), '[]'::jsonb),
    'recent_comments', coalesce((select jsonb_agg(x) from (
        select id, post_id, left(body, 280) as body, moderation_status, created_at from public.comments
        where author_id = p_user_id and deleted_at is null order by created_at desc limit 10) x), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(to_jsonb(s) order by s.created_at desc)
        from private.user_sanctions s where s.user_id = p_user_id), '[]'::jsonb)
  );
end;
$$;

-- Tunjuk / ubah admin. super_admin: semua peran. compliance_admin: hanya
-- moderator, room_moderator, viewer (tidak bisa menaikkan diri/orang lain).
create or replace function admin_api.set_admin(p_user_id uuid, p_role text, p_display_name text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role    text := private.require_admin('{super_admin,compliance_admin}');
  v_current text;
begin
  if p_role not in ('super_admin', 'compliance_admin', 'moderator', 'room_moderator', 'viewer') then
    perform private.api_error(400, 'invalid_role', 'Peran admin tidak dikenal');
  end if;
  select role into v_current from private.admin_users where user_id = p_user_id;
  if v_role = 'compliance_admin'
     and (p_role in ('super_admin', 'compliance_admin') or v_current in ('super_admin', 'compliance_admin')) then
    perform private.api_error(403, 'admin_forbidden', 'compliance_admin hanya bisa mengatur moderator dan viewer');
  end if;
  if p_user_id = auth.uid() then
    perform private.api_error(403, 'admin_forbidden', 'Tidak bisa mengubah peran diri sendiri');
  end if;

  insert into private.admin_users (user_id, role, display_name, created_by)
  values (p_user_id, p_role, p_display_name, auth.uid())
  on conflict (user_id) do update
    set role = excluded.role,
        display_name = coalesce(excluded.display_name, private.admin_users.display_name),
        disabled_at = null;
  perform private.audit('set_admin', 'admin', p_user_id::text,
                        jsonb_build_object('role', p_role, 'previous_role', v_current));
end;
$$;

create or replace function admin_api.disable_admin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_admin('{super_admin,compliance_admin}');
  v_target text;
begin
  select role into v_target from private.admin_users where user_id = p_user_id;
  if v_target is null then
    perform private.api_error(404, 'not_found', 'Admin tidak ditemukan');
  end if;
  if v_role = 'compliance_admin' and v_target in ('super_admin', 'compliance_admin') then
    perform private.api_error(403, 'admin_forbidden', 'compliance_admin hanya bisa mengatur moderator dan viewer');
  end if;
  update private.admin_users set disabled_at = now() where user_id = p_user_id;
  perform private.audit('disable_admin', 'admin', p_user_id::text, jsonb_build_object('role', v_target));
end;
$$;

create or replace function admin_api.set_room_scope(p_user_id uuid, p_room_id uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
begin
  if not exists (select 1 from private.admin_users where user_id = p_user_id and role = 'room_moderator') then
    perform private.api_error(400, 'not_room_moderator', 'User bukan room_moderator');
  end if;
  if p_enabled then
    insert into private.admin_room_scopes (user_id, room_id) values (p_user_id, p_room_id)
    on conflict do nothing;
  else
    delete from private.admin_room_scopes where user_id = p_user_id and room_id = p_room_id;
  end if;
  perform private.audit('set_room_scope', 'admin', p_user_id::text,
                        jsonb_build_object('room_id', p_room_id, 'enabled', p_enabled));
end;
$$;

create or replace function admin_api.set_trust_level(p_user_id uuid, p_level integer, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
  v_old  integer;
begin
  select trust_level into v_old from public.profiles where id = p_user_id for update;
  if not found then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  update public.profiles set trust_level = p_level where id = p_user_id;
  perform private.audit('set_trust_level', 'user', p_user_id::text,
                        jsonb_build_object('from', v_old, 'to', p_level, 'reason', p_reason));
end;
$$;

create or replace function admin_api.set_verified(p_user_id uuid, p_verified boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
begin
  update public.profiles set is_verified = p_verified where id = p_user_id;
  if not found then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  perform private.audit('set_verified', 'user', p_user_id::text,
                        jsonb_build_object('verified', p_verified, 'reason', p_reason));
end;
$$;

create or replace function admin_api.upsert_banned_word(p_word text, p_action text default 'mask')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
begin
  insert into public.banned_words (word, action) values (lower(btrim(p_word)), p_action)
  on conflict (word) do update set action = excluded.action;
  perform private.audit('upsert_banned_word', 'banned_word', lower(btrim(p_word)),
                        jsonb_build_object('action', p_action));
end;
$$;

create or replace function admin_api.delete_banned_word(p_word text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
begin
  delete from public.banned_words where word = lower(btrim(p_word));
  perform private.audit('delete_banned_word', 'banned_word', lower(btrim(p_word)), '{}'::jsonb);
end;
$$;

create or replace function admin_api.update_setting(p_key text, p_value jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
  v_old  jsonb;
begin
  select value into v_old from private.settings where key = p_key for update;
  if not found then
    perform private.api_error(404, 'setting_not_found', 'Pengaturan tidak dikenal');
  end if;
  update private.settings set value = p_value, updated_at = now() where key = p_key;
  perform private.audit('update_setting', 'setting', p_key, jsonb_build_object('from', v_old, 'to', p_value));
end;
$$;

create or replace function admin_api.audit_log(p_limit integer default 100, p_before_id bigint default null)
returns setof private.admin_audit_log
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin,compliance_admin}');
begin
  return query
  select * from private.admin_audit_log l
  where p_before_id is null or l.id < p_before_id
  order by l.id desc
  limit least(greatest(coalesce(p_limit, 100), 1), 500);
end;
$$;

-- Arsip regulator (super_admin saja). Setiap akses dicatat sebagai akses data pribadi.
create or replace function admin_api.archive(
  p_author_id uuid default null, p_from timestamptz default null, p_to timestamptz default null,
  p_limit integer default 100
)
returns setof private.content_archive
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin}');
begin
  perform private.log_personal_data_access(p_author_id, 'regulator_archive', '{body,attachments}');
  perform private.audit('read_archive', 'user', p_author_id::text,
                        jsonb_build_object('from', p_from, 'to', p_to));
  return query
  select * from private.content_archive a
  where (p_author_id is null or a.author_id = p_author_id)
    and (p_from is null or a.deleted_at >= p_from)
    and (p_to is null or a.deleted_at < p_to)
  order by a.deleted_at desc
  limit least(greatest(coalesce(p_limit, 100), 1), 1000);
end;
$$;

create or replace function admin_api.set_legal_hold(p_archive_id bigint, p_hold boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_admin('{super_admin}');
begin
  update private.content_archive set legal_hold = p_hold where id = p_archive_id;
  if not found then
    perform private.api_error(404, 'not_found', 'Arsip tidak ditemukan');
  end if;
  perform private.audit('set_legal_hold', 'archive', p_archive_id::text,
                        jsonb_build_object('hold', p_hold, 'reason', p_reason));
end;
$$;

-- ---------------------------------------------------------------------------
-- Hak akses
-- ---------------------------------------------------------------------------
-- Fungsi baru di private/admin_api tidak otomatis bisa dieksekusi PUBLIC.
alter default privileges for role postgres in schema private revoke execute on functions from public;
alter default privileges for role postgres in schema admin_api revoke execute on functions from public;

revoke all on all functions in schema private from public;
revoke all on all functions in schema admin_api from public;
grant execute on all functions in schema admin_api to authenticated;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_my_sanctions() to authenticated;
-- Dipakai policy RLS/Realtime/Storage oleh role authenticated.
grant execute on function private.check_request() to anon, authenticated;
grant execute on function private.not_banned() to authenticated;
