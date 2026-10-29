-- 0015_privacy.sql
-- Privasi & UU PDP (docs/PROMPT-PRODUCTION.md 4.8, docs/PROMPT-FEATURES.md 2.4):
--   - mute user / kata / saham: disaring di server lewat get_feed;
--   - hapus akun & data (delete_my_account), ekspor data (export_my_data);
--   - retensi otomatis (pg_cron, sekali per cluster) dan promosi akun baru;
--   - upsert_olt_profile: akun baru mulai trust_level 0, akun yang dihapus
--     dibuat ulang bersih saat login lagi, status ban ikut dikembalikan.

insert into private.settings (key, value, description) values
  ('retention.notifications_days', '90', 'Notifikasi lebih tua dari ini dihapus'),
  ('retention.deleted_messages_days', '30', 'Pesan yang sudah dihapus dibersihkan permanen setelah sekian hari'),
  ('retention.audit_log_days', '365', 'Audit log admin disimpan selama sekian hari'),
  ('retention.access_log_days', '730', 'Log akses data pribadi disimpan selama sekian hari'),
  ('retention.rate_limit_events_days', '2', 'Event rate limit disimpan selama sekian hari'),
  ('mute.max_keywords', '50', 'Maks kata yang bisa di-mute per user')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Profil terhapus
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists deleted_at timestamptz;

-- ---------------------------------------------------------------------------
-- Mute: user, kata, saham (milik sendiri; tidak terlihat oleh yang di-mute)
-- ---------------------------------------------------------------------------
create table if not exists public.mutes (
  muter_id   uuid not null references public.profiles(id) on delete cascade,
  muted_id   uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint mutes_no_self check (muter_id <> muted_id)
);

create table if not exists public.muted_keywords (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  keyword    extensions.citext not null,
  created_at timestamptz not null default now(),
  primary key (user_id, keyword),
  constraint muted_keywords_length check (char_length(keyword) between 2 and 50)
);

create table if not exists public.muted_stocks (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  stock_code text not null references public.stocks(code) on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, stock_code)
);

alter table public.mutes enable row level security;
alter table public.muted_keywords enable row level security;
alter table public.muted_stocks enable row level security;
revoke all on public.mutes, public.muted_keywords, public.muted_stocks from anon, authenticated;
grant select, insert, delete on public.mutes, public.muted_keywords, public.muted_stocks to authenticated;

drop policy if exists mutes_own on public.mutes;
create policy mutes_own on public.mutes
  for all to authenticated
  using (muter_id = (select auth.uid())) with check (muter_id = (select auth.uid()));
drop policy if exists muted_keywords_own on public.muted_keywords;
create policy muted_keywords_own on public.muted_keywords
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists muted_stocks_own on public.muted_stocks;
create policy muted_stocks_own on public.muted_stocks
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create or replace function private.muted_keywords_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.muted_keywords where user_id = new.user_id)
     >= private.setting_num('mute.max_keywords', 50) then
    perform private.api_error(422, 'too_many_muted_keywords', 'Batas kata yang di-mute sudah tercapai');
  end if;
  return new;
end;
$$;

create or replace trigger muted_keywords_limit
  before insert on public.muted_keywords
  for each row execute function private.muted_keywords_limit();

-- get_feed: sama dengan 0007, ditambah saringan mute.
--   global/following : tanpa user, saham, dan kata yang di-mute
--   stock            : tanpa user dan kata yang di-mute (halaman saham dibuka sengaja)
--   user             : tanpa saringan (profil dibuka sengaja)
create or replace function public.get_feed(
  p_scope      text default 'global',
  p_stock_code text default null,
  p_cursor     text default null,
  p_limit      integer default 20,
  p_author_id  uuid default null
)
returns setof public.feed_post
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_code  text := upper(btrim(coalesce(p_stock_code, '')));
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;

  case coalesce(p_scope, 'global')
    when 'global', 'following' then
      select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
      from (
        select p.id, p.created_at
        from public.posts p
        where p.deleted_at is null
          and (p_scope is distinct from 'following'
               or p.author_id = v_uid
               or p.author_id in (select f.following_id from public.follows f where f.follower_id = v_uid))
          and p.author_id not in (select m.muted_id from public.mutes m where m.muter_id = v_uid)
          and not exists (
            select 1 from public.post_stocks ps
            join public.muted_stocks ms on ms.stock_code = ps.stock_code and ms.user_id = v_uid
            where ps.post_id = p.id)
          and not exists (
            select 1 from public.muted_keywords mk
            where mk.user_id = v_uid and strpos(lower(p.body), lower(mk.keyword::text)) > 0)
          and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
        order by p.created_at desc, p.id desc
        limit v_limit
      ) x;

    when 'stock' then
      if v_code = '' then
        perform private.api_error(400, 'stock_code_required', 'stock_code wajib diisi untuk scope stock');
      end if;
      select array_agg(x.post_id order by x.post_created_at desc, x.post_id desc) into v_ids
      from (
        select ps.post_id, ps.post_created_at
        from public.post_stocks ps
        join public.posts p on p.id = ps.post_id
        where ps.stock_code = v_code
          and p.deleted_at is null
          and p.author_id not in (select m.muted_id from public.mutes m where m.muter_id = v_uid)
          and not exists (
            select 1 from public.muted_keywords mk
            where mk.user_id = v_uid and strpos(lower(p.body), lower(mk.keyword::text)) > 0)
          and (v_ts is null or (ps.post_created_at, ps.post_id) < (v_ts, v_id))
        order by ps.post_created_at desc, ps.post_id desc
        limit v_limit
      ) x;

    when 'user' then
      if p_author_id is null then
        perform private.api_error(400, 'author_required', 'author_id wajib diisi untuk scope user');
      end if;
      select array_agg(x.id order by x.created_at desc, x.id desc) into v_ids
      from (
        select p.id, p.created_at
        from public.posts p
        where p.author_id = p_author_id
          and p.deleted_at is null
          and (v_ts is null or (p.created_at, p.id) < (v_ts, v_id))
        order by p.created_at desc, p.id desc
        limit v_limit
      ) x;

    else
      perform private.api_error(400, 'invalid_scope', 'scope harus global, following, stock, atau user');
  end case;

  return query select * from private.feed_posts(coalesce(v_ids, '{}'));
end;
$$;

-- ---------------------------------------------------------------------------
-- Hapus akun (UU PDP). Konten dihapus dari tampilan dan diarsipkan untuk
-- regulator (retensi retention.archive_days, dikecualikan dari penghapusan sejauh
-- diwajibkan regulasi). Profil dianonimkan agar struktur thread tetap utuh.
-- File storage dimasukkan ke antrean pembersihan (diproses worker, lihat docs).
-- ---------------------------------------------------------------------------
create table if not exists private.storage_cleanup_queue (
  id         bigint generated always as identity primary key,
  bucket_id  text not null,
  prefix     text not null,
  reason     text not null,
  queued_at  timestamptz not null default now(),
  done_at    timestamptz
);
alter table private.storage_cleanup_queue enable row level security;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and deleted_at is null) then
    perform private.api_error(404, 'user_not_found', 'Akun tidak ditemukan');
  end if;

  -- Arsip untuk regulator, lalu hapus dari tampilan.
  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'post', id, author_id, body, attachments, v_uid, 'account_delete'
  from public.posts where author_id = v_uid and deleted_at is null;
  update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
  select 'comment', id, author_id, body, v_uid, 'account_delete'
  from public.comments where author_id = v_uid and deleted_at is null;
  update public.comments set deleted_at = now(), body = ''
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'message', id, sender_id, body, attachments, v_uid, 'account_delete'
  from public.messages where sender_id = v_uid and deleted_at is null;
  update public.messages set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where sender_id = v_uid and deleted_at is null;

  -- Relasi & data pribadi lain dihapus.
  delete from public.reactions where user_id = v_uid;
  delete from public.follows where follower_id = v_uid or following_id = v_uid;
  delete from public.blocks where blocker_id = v_uid or blocked_id = v_uid;
  delete from public.mutes where muter_id = v_uid or muted_id = v_uid;
  delete from public.muted_keywords where user_id = v_uid;
  delete from public.muted_stocks where user_id = v_uid;
  delete from public.stock_watchers where user_id = v_uid;
  delete from public.chat_members where user_id = v_uid;
  delete from public.notifications where user_id = v_uid or actor_id = v_uid;
  delete from public.user_consents where user_id = v_uid;
  delete from private.user_private where user_id = v_uid;

  update public.profiles
     set username = 'deleted_' || substr(md5(id::text), 1, 12),
         display_name = null, bio = null, avatar_url = null,
         is_verified = false, deleted_at = now()
   where id = v_uid;

  insert into private.storage_cleanup_queue (bucket_id, prefix, reason) values
    ('avatars', v_uid::text || '/', 'account_delete'),
    ('attachments', 'posts/' || v_uid::text || '/', 'account_delete');

  perform private.revoke_sessions(v_uid, 'account_delete');
  perform private.log_personal_data_access(v_uid, 'account_delete', '{all}');
end;
$$;

-- Ekspor data milik sendiri (JSON). Dibatasi 3x/hari (rate limit data_export).
create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.consume_rate_limit(v_uid, 'data_export');
  perform private.log_personal_data_access(v_uid, 'self_export', '{all}');

  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'olt_user_id' from public.profiles p where p.id = v_uid),
    'email', (select up.email from private.user_private up where up.user_id = v_uid),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'body', body, 'sentiment', sentiment, 'attachments', attachments,
        'created_at', created_at, 'edited_at', edited_at) order by created_at)
      from public.posts where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'post_id', post_id, 'parent_id', parent_id, 'body', body, 'created_at', created_at)
        order by created_at)
      from public.comments where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'room_id', room_id, 'body', body, 'attachments', attachments, 'created_at', created_at)
        order by created_at)
      from public.messages where sender_id = v_uid and deleted_at is null), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) - 'user_id') from public.reactions r
      where r.user_id = v_uid), '[]'::jsonb),
    'following', coalesce((select jsonb_agg(f.following_id) from public.follows f
      where f.follower_id = v_uid), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(b.blocked_id) from public.blocks b
      where b.blocker_id = v_uid), '[]'::jsonb),
    'muted_users', coalesce((select jsonb_agg(m.muted_id) from public.mutes m
      where m.muter_id = v_uid), '[]'::jsonb),
    'muted_keywords', coalesce((select jsonb_agg(k.keyword) from public.muted_keywords k
      where k.user_id = v_uid), '[]'::jsonb),
    'muted_stocks', coalesce((select jsonb_agg(s.stock_code) from public.muted_stocks s
      where s.user_id = v_uid), '[]'::jsonb),
    'watchlist', coalesce((select jsonb_agg(w.stock_code) from public.stock_watchers w
      where w.user_id = v_uid), '[]'::jsonb),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
        'target_type', target_type, 'target_id', target_id, 'reason', reason,
        'status', status, 'created_at', created_at))
      from public.reports where reporter_id = v_uid), '[]'::jsonb),
    'consents', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', d.kind, 'version', d.version, 'accepted_at', c.accepted_at))
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- upsert_olt_profile (auth-bridge): sama dengan 0002, ditambah:
--   - profil baru mulai trust_level 0 (batas lebih ketat 24 jam pertama);
--   - profil yang pernah dihapus dibuat ulang bersih;
--   - hasil memuat status ban (auth-bridge bisa menolak exchange).
-- ---------------------------------------------------------------------------
create or replace function public.upsert_olt_profile(
  p_id           uuid,
  p_olt_user_id  text,
  p_username     text,
  p_display_name text default null,
  p_email        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_base     text;
  v_username text;
  v_existing public.profiles;
  v_profile  public.profiles;
  v_attempt  integer := 0;
  v_ban_end  timestamptz;
  v_exists   boolean;
begin
  if p_id is null or coalesce(btrim(p_olt_user_id), '') = '' then
    perform private.api_error(400, 'invalid_profile', 'id dan olt_user_id wajib diisi');
  end if;

  v_base := regexp_replace(coalesce(p_username, ''), '[^A-Za-z0-9_]', '_', 'g');
  if char_length(v_base) < 3 then
    v_base := 'user_' || v_base;
  end if;
  v_base := left(v_base, 30);

  select * into v_existing from public.profiles where id = p_id;
  v_exists := found;

  if v_exists and v_existing.deleted_at is not null then
    -- Akun pernah dihapus: mulai lagi sebagai akun baru.
    update public.profiles
       set deleted_at = null, trust_level = 0, created_at = now(),
           display_name = nullif(left(btrim(p_display_name), 60), '')
     where id = p_id;
  end if;

  if v_exists then
    -- Ikuti username OLT terbaru bila berubah dan masih tersedia.
    if v_existing.username::text <> v_base
       and not exists (
         select 1 from public.profiles
         where username = v_base::extensions.citext and id <> p_id
       ) then
      begin
        update public.profiles set username = v_base where id = p_id;
      exception when unique_violation then
        null; -- diambil user lain secara bersamaan; pertahankan username lama
      end;
    end if;
    update public.profiles
       set display_name = coalesce(display_name, nullif(btrim(p_display_name), ''))
     where id = p_id
     returning * into v_profile;
  else
    loop
      v_username := case
        when v_attempt = 0 then v_base
        else left(v_base, 25) || '_' || substr(md5(p_olt_user_id || v_attempt::text), 1, 4)
      end;
      begin
        insert into public.profiles (id, olt_user_id, username, display_name, trust_level)
        values (p_id, p_olt_user_id, v_username, nullif(left(btrim(p_display_name), 60), ''), 0)
        returning * into v_profile;
        exit;
      exception when unique_violation then
        -- Bisa karena username terpakai atau insert paralel untuk id yang sama.
        select * into v_profile from public.profiles where id = p_id;
        exit when found;
        v_attempt := v_attempt + 1;
        if v_attempt > 5 then
          perform private.api_error(409, 'username_unavailable', 'Gagal menentukan username unik');
        end if;
      end;
    end loop;
  end if;

  insert into private.user_private (user_id, email, last_login_at, updated_at)
  values (p_id, nullif(btrim(p_email), ''), now(), now())
  on conflict (user_id) do update
    set email = coalesce(excluded.email, private.user_private.email),
        last_login_at = now(),
        updated_at = now();

  select s.ends_at into v_ban_end
  from private.user_sanctions s
  where s.user_id = p_id and s.kind = 'ban' and s.revoked_at is null
    and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
  order by s.ends_at desc nulls first
  limit 1;

  return jsonb_build_object(
    'id', v_profile.id,
    'olt_user_id', v_profile.olt_user_id,
    'username', v_profile.username,
    'display_name', v_profile.display_name,
    'avatar_url', v_profile.avatar_url,
    'is_verified', v_profile.is_verified,
    'banned', private.is_banned(p_id),
    'ban_ends_at', v_ban_end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Job terjadwal (pg_cron berjalan di database, otomatis sekali per cluster)
-- ---------------------------------------------------------------------------
create or replace function private.promote_new_accounts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.profiles p
     set trust_level = 1
   where p.trust_level = 0
     and p.deleted_at is null
     and p.created_at < now() - make_interval(hours => private.setting_num('trust.new_account_hours', 24)::integer)
     and not private.has_active_sanction(p.id, '{mute,ban}');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function private.run_retention()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb := '{}'::jsonb;
  v_count  integer;
begin
  delete from public.notifications
   where created_at < now() - make_interval(days => private.setting_num('retention.notifications_days', 90)::integer);
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('notifications', v_count);

  delete from public.messages
   where deleted_at is not null
     and deleted_at < now() - make_interval(days => private.setting_num('retention.deleted_messages_days', 30)::integer);
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('deleted_messages', v_count);

  delete from private.content_archive where retain_until < now() and not legal_hold;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('archive', v_count);

  perform set_config('olt.audit_retention', 'on', true);
  delete from private.admin_audit_log
   where created_at < now() - make_interval(days => private.setting_num('retention.audit_log_days', 365)::integer);
  get diagnostics v_count = row_count;
  perform set_config('olt.audit_retention', 'off', true);
  v_result := v_result || jsonb_build_object('audit_log', v_count);

  delete from private.personal_data_access_log
   where created_at < now() - make_interval(days => private.setting_num('retention.access_log_days', 730)::integer);
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('access_log', v_count);

  delete from private.rate_limit_events
   where created_at < now() - make_interval(days => private.setting_num('retention.rate_limit_events_days', 2)::integer);
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rate_limit_events', v_count);

  raise log 'olt.retention %', v_result;
  return v_result;
end;
$$;

create extension if not exists pg_cron;
select cron.schedule('olt-retention', '17 3 * * *', 'select private.run_retention()');
select cron.schedule('olt-promote-new-accounts', '*/15 * * * *', 'select private.promote_new_accounts()');

-- ---------------------------------------------------------------------------
-- Hak akses
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_feed(text, text, text, integer, uuid) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.export_my_data() to authenticated;
-- auth-bridge memanggil lewat service_role.
grant execute on function public.upsert_olt_profile(uuid, text, text, text, text) to service_role;
