-- 0003_notifications.sql
-- Notifikasi in-app: reply, mention, like, follow, message.
-- Dibuat oleh trigger (security definer); client hanya membaca & menandai dibaca.

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  actor_id    uuid references public.profiles(id) on delete cascade,
  type        text not null,
  payload     jsonb not null default '{}'::jsonb,
  -- Notifikasi sejenis yang belum dibaca digabung (mis. banyak like di satu post).
  group_key   text,
  event_count integer not null default 1 check (event_count >= 1),
  read_at     timestamptz,
  created_at  timestamptz not null default now(),
  constraint notifications_type check (type in ('reply', 'mention', 'like', 'follow', 'message'))
);
create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc, id desc);
create index if not exists notifications_user_unread_idx
  on public.notifications (user_id) where read_at is null;
create unique index if not exists notifications_group_unread_idx
  on public.notifications (user_id, group_key) where read_at is null and group_key is not null;

-- Buat notifikasi untuk p_user_id. Diabaikan jika penerima = pelaku atau
-- keduanya saling blokir. Jika p_group_key diisi dan ada notifikasi grup yang
-- belum dibaca, notifikasi itu diperbarui (event_count + 1) alih-alih menambah baris.
create or replace function private.notify(
  p_user_id   uuid,
  p_actor_id  uuid,
  p_type      text,
  p_payload   jsonb,
  p_group_key text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_user_id = p_actor_id then
    return;
  end if;
  if p_actor_id is not null and private.is_blocked_pair(p_user_id, p_actor_id) then
    return;
  end if;

  if p_group_key is null then
    insert into public.notifications (user_id, actor_id, type, payload)
    values (p_user_id, p_actor_id, p_type, coalesce(p_payload, '{}'::jsonb));
  else
    insert into public.notifications (user_id, actor_id, type, payload, group_key)
    values (p_user_id, p_actor_id, p_type, coalesce(p_payload, '{}'::jsonb), p_group_key)
    on conflict (user_id, group_key) where read_at is null and group_key is not null
    do update set
      actor_id    = excluded.actor_id,
      payload     = excluded.payload,
      event_count = public.notifications.event_count + 1,
      created_at  = now();
  end if;
end;
$$;

-- Potongan teks untuk payload notifikasi / preview.
create or replace function private.snippet(p_text text, p_len integer default 120)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_text is null then null
    when char_length(p_text) <= p_len then p_text
    else left(p_text, p_len - 1) || '…'
  end;
$$;

-- Notifikasi follow (satu notifikasi belum-dibaca per follower).
create or replace function private.notify_follow()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    new.following_id, new.follower_id, 'follow',
    jsonb_build_object('follower_id', new.follower_id),
    'follow:' || new.follower_id
  );
  return null;
end;
$$;

create or replace trigger follows_notify
  after insert on public.follows
  for each row execute function private.notify_follow();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own on public.notifications
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Daftar notifikasi terbaru (keyset: cursor = "<created_at>|<id>").
create or replace function public.get_notifications(p_cursor text default null, p_limit integer default 30)
returns table (
  id                 uuid,
  type               text,
  actor_id           uuid,
  actor_username     text,
  actor_display_name text,
  actor_avatar_url   text,
  payload            jsonb,
  event_count        integer,
  read_at            timestamptz,
  created_at         timestamptz,
  cursor             text
)
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_ts timestamptz;
  v_id uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_cursor is not null then
    begin
      v_ts := split_part(p_cursor, '|', 1)::timestamptz;
      v_id := split_part(p_cursor, '|', 2)::uuid;
    exception when others then
      perform private.api_error(400, 'invalid_cursor');
    end;
  end if;

  return query
  select n.id, n.type, n.actor_id, a.username::text, a.display_name, a.avatar_url,
         n.payload, n.event_count, n.read_at, n.created_at,
         to_char(n.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || n.id
  from public.notifications n
  left join public.profiles a on a.id = n.actor_id
  where n.user_id = auth.uid()
    and (v_ts is null or (n.created_at, n.id) < (v_ts, v_id))
  order by n.created_at desc, n.id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

-- Tandai dibaca. p_ids null = semua. Mengembalikan jumlah baris yang diubah.
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql
set search_path = public, extensions, pg_temp
as $$
declare
  v_count integer;
begin
  update public.notifications
     set read_at = now()
   where user_id = auth.uid()
     and read_at is null
     and (p_ids is null or id = any(p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.get_notification_unread_count()
returns integer
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select count(*)::integer from public.notifications
  where user_id = auth.uid() and read_at is null;
$$;

-- Fungsi baru otomatis executable oleh PUBLIC; cabut, lalu beri yang perlu saja.
revoke all on all functions in schema private from public;
grant execute on function private.snippet(text, integer) to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_notifications(text, integer) to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.get_notification_unread_count() to authenticated;
