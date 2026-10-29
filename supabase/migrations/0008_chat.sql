-- 0008_chat.sql
-- Chat realtime: DM 1-on-1 (direct), grup, dan room per saham (stock).
-- Pesan hanya bisa dibaca anggota room. DM antar dua user selalu memakai room
-- yang sama (chat_rooms.direct_key unik).

create table if not exists public.chat_rooms (
  id                     uuid primary key default gen_random_uuid(),
  type                   text not null,
  name                   text,
  stock_code             text references public.stocks(code) on update cascade on delete cascade,
  -- "<uuid kecil>:<uuid besar>" untuk room direct
  direct_key             text,
  created_by             uuid references public.profiles(id) on delete set null,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint chat_rooms_type check (type in ('direct', 'group', 'stock')),
  constraint chat_rooms_stock check ((type = 'stock') = (stock_code is not null)),
  constraint chat_rooms_direct check ((type = 'direct') = (direct_key is not null)),
  constraint chat_rooms_name_length check (char_length(name) <= 80),
  constraint chat_rooms_group_name check (type <> 'group' or coalesce(btrim(name), '') <> '')
);
create unique index if not exists chat_rooms_direct_key_idx
  on public.chat_rooms (direct_key) where direct_key is not null;
create unique index if not exists chat_rooms_stock_idx
  on public.chat_rooms (stock_code) where type = 'stock';

create or replace trigger chat_rooms_set_updated_at
  before update on public.chat_rooms
  for each row execute function private.set_updated_at();

create table if not exists public.chat_members (
  room_id      uuid not null references public.chat_rooms(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  role         text not null default 'member',
  last_read_at timestamptz not null default now(),
  muted        boolean not null default false,
  joined_at    timestamptz not null default now(),
  primary key (room_id, user_id),
  constraint chat_members_role check (role in ('owner', 'admin', 'member'))
);
create index if not exists chat_members_user_idx on public.chat_members (user_id);

create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id   uuid references public.profiles(id) on delete set null,
  body        text not null default '',
  reply_to_id uuid references public.messages(id) on delete set null,
  -- [{"path":"rooms/<room_id>/<sender_id>/<file>","mime":"image/png",...}]
  attachments jsonb not null default '[]'::jsonb,
  -- Id dari client untuk optimistic send & dedup (unik per pengirim).
  client_id   uuid,
  edited_at   timestamptz,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  constraint messages_content check (
    deleted_at is not null
    or (char_length(body) <= 4000 and (body <> '' or jsonb_array_length(attachments) > 0))
  ),
  constraint messages_attachments check (
    jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 4
  ),
  constraint messages_client_id_key unique (sender_id, client_id)
);
create index if not exists messages_room_created_idx on public.messages (room_id, created_at desc, id desc);
create index if not exists messages_sender_created_idx on public.messages (sender_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Helper (security definer: dipakai di policy tanpa rekursi RLS)
-- ---------------------------------------------------------------------------
create or replace function private.my_room_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select room_id from public.chat_members where user_id = auth.uid();
$$;

create or replace function private.is_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members where room_id = p_room_id and user_id = auth.uid()
  );
$$;

create or replace function private.room_role(p_room_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.chat_members where room_id = p_room_id and user_id = auth.uid();
$$;

-- Anggota room, dan untuk DM: kedua pihak tidak saling blokir.
create or replace function private.can_send_message(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_room_member(p_room_id)
     and not exists (
       select 1
       from public.chat_rooms r
       join public.chat_members o on o.room_id = r.id and o.user_id <> auth.uid()
       where r.id = p_room_id
         and r.type = 'direct'
         and private.is_blocked_pair(auth.uid(), o.user_id)
     );
$$;

-- ---------------------------------------------------------------------------
-- Trigger messages
-- ---------------------------------------------------------------------------
create or replace function private.messages_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    perform private.validate_attachments(
      new.attachments, 'rooms/' || new.room_id || '/' || new.sender_id || '/');
    if new.reply_to_id is not null
       and not exists (select 1 from public.messages
                       where id = new.reply_to_id and room_id = new.room_id) then
      perform private.api_error(400, 'invalid_reply', 'Pesan yang dibalas tidak ada di room ini');
    end if;
  elsif new.deleted_at is null and new.body is distinct from old.body then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   public.chat_rooms;
  v_member record;
  v_preview text;
begin
  v_preview := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;

  update public.chat_rooms
     set last_message_at = new.created_at,
         last_message_preview = v_preview,
         last_message_sender_id = new.sender_id
   where id = new.room_id
   returning * into v_room;

  -- Pesan sendiri otomatis terbaca oleh pengirim.
  update public.chat_members
     set last_read_at = greatest(last_read_at, new.created_at)
   where room_id = new.room_id and user_id = new.sender_id;

  -- Room saham terlalu ramai untuk notifikasi; unread badge sudah cukup.
  if v_room.type in ('direct', 'group') then
    for v_member in
      select user_id from public.chat_members
      where room_id = new.room_id and user_id is distinct from new.sender_id and not muted
    loop
      perform private.notify(
        v_member.user_id, new.sender_id, 'message',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', v_room.type,
          'room_name', v_room.name,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'message:room:' || new.room_id
      );
    end loop;
  end if;
  return null;
end;
$$;

create or replace trigger messages_10_rate_limit
  before insert on public.messages
  for each row execute function private.enforce_rate_limit('message', 'sender_id');
create or replace trigger messages_20_before_write
  before insert or update on public.messages
  for each row execute function private.messages_before_write();
create or replace trigger messages_30_content_policy
  before insert or update of body on public.messages
  for each row execute function private.enforce_content_policy();
create or replace trigger messages_after_insert
  after insert on public.messages
  for each row execute function private.messages_after_insert();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.chat_rooms enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

revoke all on public.chat_rooms, public.chat_members, public.messages from anon, authenticated;
grant select on public.chat_rooms to authenticated;
grant update (name) on public.chat_rooms to authenticated;
grant select on public.chat_members to authenticated;
grant update (last_read_at, muted) on public.chat_members to authenticated;
grant select on public.messages to authenticated;
grant insert (id, room_id, sender_id, body, reply_to_id, attachments, client_id) on public.messages to authenticated;
grant update (body) on public.messages to authenticated;

-- Room saham bisa ditemukan semua user; room lain hanya oleh anggotanya.
drop policy if exists chat_rooms_select on public.chat_rooms;
create policy chat_rooms_select on public.chat_rooms
  for select to authenticated
  using (type = 'stock' or id in (select private.my_room_ids()));
drop policy if exists chat_rooms_update_admin on public.chat_rooms;
create policy chat_rooms_update_admin on public.chat_rooms
  for update to authenticated
  using (type = 'group' and private.room_role(id) in ('owner', 'admin'))
  with check (type = 'group');

drop policy if exists chat_members_select on public.chat_members;
create policy chat_members_select on public.chat_members
  for select to authenticated
  using (room_id in (select private.my_room_ids()));
drop policy if exists chat_members_update_own on public.chat_members;
create policy chat_members_update_own on public.chat_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated
  using (
    room_id in (select private.my_room_ids())
    and (sender_id is null or sender_id not in (select private.blocked_user_ids()))
  );
drop policy if exists messages_insert_member on public.messages;
create policy messages_insert_member on public.messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()) and private.can_send_message(room_id));
drop policy if exists messages_update_own on public.messages;
create policy messages_update_own on public.messages
  for update to authenticated
  using (sender_id = (select auth.uid()) and deleted_at is null)
  with check (sender_id = (select auth.uid()) and deleted_at is null);

-- ---------------------------------------------------------------------------
-- Bentuk data pesan untuk client
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'chat_message' and typnamespace = 'public'::regnamespace) then
    create type public.chat_message as (
      id                       uuid,
      room_id                  uuid,
      sender_id                uuid,
      sender_username          text,
      sender_display_name      text,
      sender_avatar_url        text,
      body                     text,     -- null jika dihapus
      is_deleted               boolean,
      reply_to_id              uuid,
      reply_to_body            text,     -- null jika pesan yang dibalas dihapus
      reply_to_sender_username text,
      attachments              jsonb,
      client_id                uuid,
      edited_at                timestamptz,
      created_at               timestamptz,
      cursor                   text
    );
  end if;
end;
$$;

create or replace function private.chat_messages(p_ids uuid[])
returns setof public.chat_message
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.id, m.room_id, m.sender_id,
         s.username::text, s.display_name, s.avatar_url,
         case when m.deleted_at is null then m.body end,
         m.deleted_at is not null,
         m.reply_to_id,
         case when rt.deleted_at is null then private.snippet(rt.body, 200) end,
         rs.username::text,
         case when m.deleted_at is null then m.attachments else '[]'::jsonb end,
         m.client_id, m.edited_at, m.created_at,
         private.make_cursor(m.created_at, m.id)
  from public.messages m
  left join public.profiles s on s.id = m.sender_id
  left join public.messages rt on rt.id = m.reply_to_id
  left join public.profiles rs on rs.id = rt.sender_id
  where m.id = any(p_ids)
  order by m.created_at desc, m.id desc;
$$;

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

-- Room DM dengan user lain; dibuat sekali, dipakai ulang selamanya.
create or replace function public.get_or_create_direct_room(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_me   uuid := auth.uid();
  v_key  text;
  v_room uuid;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_other_user_id is null or p_other_user_id = v_me then
    perform private.api_error(400, 'invalid_user', 'Tidak bisa membuat DM dengan diri sendiri');
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    perform private.api_error(404, 'user_not_found', 'User tidak ditemukan');
  end if;
  if private.is_blocked_pair(v_me, p_other_user_id) then
    perform private.api_error(403, 'blocked', 'Tidak bisa mengirim pesan ke user ini');
  end if;

  v_key := least(v_me::text, p_other_user_id::text) || ':' || greatest(v_me::text, p_other_user_id::text);

  insert into public.chat_rooms (type, direct_key, created_by)
  values ('direct', v_key, v_me)
  on conflict (direct_key) where direct_key is not null do nothing
  returning id into v_room;

  if v_room is null then
    select id into v_room from public.chat_rooms where direct_key = v_key;
  end if;

  insert into public.chat_members (room_id, user_id)
  values (v_room, v_me), (v_room, p_other_user_id)
  on conflict do nothing;

  return v_room;
end;
$$;

-- Buat grup; pembuat menjadi owner. Maks 100 anggota.
create or replace function public.create_group_room(p_name text, p_member_ids uuid[] default '{}')
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_me   uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_room uuid;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if char_length(v_name) not between 1 and 80 then
    perform private.api_error(400, 'invalid_name', 'Nama grup 1-80 karakter');
  end if;

  insert into public.chat_rooms (type, name, created_by)
  values ('group', v_name, v_me)
  returning id into v_room;

  insert into public.chat_members (room_id, user_id, role) values (v_room, v_me, 'owner');
  insert into public.chat_members (room_id, user_id)
  select v_room, p.id
  from public.profiles p
  where p.id = any(coalesce(p_member_ids, '{}'))
    and p.id <> v_me
    and not private.is_blocked_pair(v_me, p.id)
  limit 99
  on conflict do nothing;

  return v_room;
end;
$$;

-- Tambah anggota grup (owner/admin). Mengembalikan jumlah anggota baru.
create or replace function public.add_room_members(p_room_id uuid, p_user_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_me    uuid := auth.uid();
  v_count integer;
begin
  if not exists (select 1 from public.chat_rooms where id = p_room_id and type = 'group') then
    perform private.api_error(404, 'room_not_found', 'Grup tidak ditemukan');
  end if;
  if coalesce(private.room_role(p_room_id), '') not in ('owner', 'admin') then
    perform private.api_error(403, 'forbidden', 'Hanya owner/admin yang bisa menambah anggota');
  end if;

  insert into public.chat_members (room_id, user_id)
  select p_room_id, p.id
  from public.profiles p
  where p.id = any(coalesce(p_user_ids, '{}'))
    and not private.is_blocked_pair(v_me, p.id)
    and (select count(*) from public.chat_members where room_id = p_room_id) < 100
  on conflict do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Keluar dari grup/room saham. Owner grup yang keluar mewariskan kepemilikan.
create or replace function public.leave_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_room   public.chat_rooms;
  v_role   text;
  v_heir   uuid;
begin
  select * into v_room from public.chat_rooms where id = p_room_id;
  v_role := private.room_role(p_room_id);
  if not found or v_role is null then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_room.type = 'direct' then
    perform private.api_error(400, 'cannot_leave_direct', 'Room DM tidak bisa ditinggalkan');
  end if;

  delete from public.chat_members where room_id = p_room_id and user_id = auth.uid();

  if v_room.type = 'group' and v_role = 'owner' then
    select user_id into v_heir from public.chat_members
    where room_id = p_room_id
    order by (role = 'admin') desc, joined_at
    limit 1;
    if v_heir is null then
      delete from public.chat_rooms where id = p_room_id;
    else
      update public.chat_members set role = 'owner' where room_id = p_room_id and user_id = v_heir;
    end if;
  end if;
end;
$$;

-- Masuk room diskusi saham (dibuat otomatis jika belum ada).
create or replace function public.join_stock_room(p_stock_code text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_code  text := upper(btrim(coalesce(p_stock_code, '')));
  v_stock public.stocks;
  v_room  uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_stock from public.stocks where code = v_code and is_active;
  if not found then
    perform private.api_error(404, 'stock_not_found', 'Kode saham tidak dikenal');
  end if;

  insert into public.chat_rooms (type, name, stock_code, created_by)
  values ('stock', v_stock.name, v_code, auth.uid())
  on conflict (stock_code) where type = 'stock' do nothing
  returning id into v_room;

  if v_room is null then
    select id into v_room from public.chat_rooms where type = 'stock' and stock_code = v_code;
  end if;

  insert into public.chat_members (room_id, user_id) values (v_room, auth.uid())
  on conflict do nothing;
  return v_room;
end;
$$;

-- Kirim pesan (idempoten per client_id): mengembalikan pesan lengkap untuk UI.
create or replace function public.send_message(
  p_room_id     uuid,
  p_body        text,
  p_client_id   uuid default null,
  p_reply_to_id uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns setof public.chat_message
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not private.can_send_message(p_room_id) then
    perform private.api_error(403, 'cannot_send', 'Tidak bisa mengirim pesan ke room ini');
  end if;
  if char_length(coalesce(p_body, '')) > 4000 then
    perform private.api_error(400, 'body_too_long', 'Pesan maksimal 4000 karakter');
  end if;

  insert into public.messages (room_id, sender_id, body, reply_to_id, attachments, client_id)
  values (p_room_id, auth.uid(), coalesce(p_body, ''), p_reply_to_id,
          coalesce(p_attachments, '[]'::jsonb), p_client_id)
  on conflict (sender_id, client_id) do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.messages
    where sender_id = auth.uid() and client_id = p_client_id;
  end if;

  return query select * from private.chat_messages(array[v_id]);
end;
$$;

-- Riwayat pesan: p_cursor = lebih lama dari cursor (scroll ke atas),
-- p_after = lebih baru dari cursor (isi celah setelah reconnect).
-- Hasil selalu terbaru -> terlama.
create or replace function public.get_messages(
  p_room_id uuid,
  p_cursor  text default null,
  p_limit   integer default 30,
  p_after   text default null
)
returns setof public.chat_message
language plpgsql
stable
set search_path = public, extensions, pg_temp
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if not private.is_room_member(p_room_id) then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota room ini');
  end if;

  if p_after is not null and p_after <> '' then
    select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_after) c;
    select array_agg(x.id) into v_ids
    from (
      select m.id from public.messages m
      where m.room_id = p_room_id and (m.created_at, m.id) > (v_ts, v_id)
      order by m.created_at, m.id
      limit v_limit
    ) x;
  else
    select c.ts, c.id into v_ts, v_id from private.parse_cursor(p_cursor) c;
    select array_agg(x.id) into v_ids
    from (
      select m.id from public.messages m
      where m.room_id = p_room_id
        and (v_ts is null or (m.created_at, m.id) < (v_ts, v_id))
      order by m.created_at desc, m.id desc
      limit v_limit
    ) x;
  end if;

  return query select * from private.chat_messages(coalesce(v_ids, '{}'));
end;
$$;

-- Soft delete pesan milik sendiri; isi asli diarsipkan.
create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_msg public.messages;
begin
  select * into v_msg from public.messages where id = p_message_id and deleted_at is null for update;
  if not found then
    perform private.api_error(404, 'not_found', 'Pesan tidak ditemukan');
  end if;
  if v_msg.sender_id is distinct from auth.uid() and coalesce(auth.role(), '') <> 'service_role' then
    perform private.api_error(403, 'forbidden', 'Hanya pengirim yang bisa menghapus pesan ini');
  end if;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by)
  values ('message', v_msg.id, v_msg.sender_id, v_msg.body, v_msg.attachments, auth.uid());

  update public.messages
     set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where id = p_message_id;
end;
$$;

-- Tandai room sudah dibaca (juga notifikasi pesan untuk room ini).
create or replace function public.mark_room_read(p_room_id uuid)
returns void
language plpgsql
set search_path = public, extensions, pg_temp
as $$
begin
  update public.chat_members
     set last_read_at = now()
   where room_id = p_room_id and user_id = auth.uid();
  if not found then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;

  update public.notifications
     set read_at = now()
   where user_id = auth.uid()
     and read_at is null
     and type = 'message'
     and payload ->> 'room_id' = p_room_id::text;
end;
$$;

-- Jumlah pesan belum dibaca per room (dibatasi 100 per room; tampilkan "99+").
create or replace function public.get_unread_counts()
returns table (room_id uuid, unread_count integer)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.room_id,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = m.room_id
              and msg.created_at > m.last_read_at
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s)
  from public.chat_members m
  where m.user_id = auth.uid();
$$;

-- Daftar room milik user untuk halaman chat list.
create or replace function public.get_my_rooms()
returns table (
  id                     uuid,
  type                   text,
  name                   text,
  stock_code             text,
  created_by             uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  created_at             timestamptz,
  my_role                text,
  muted                  boolean,
  last_read_at           timestamptz,
  unread_count           integer,
  member_count           integer,
  other_user_id          uuid,
  other_username         text,
  other_display_name     text,
  other_avatar_url       text,
  other_is_verified      boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type, r.name, r.stock_code, r.created_by,
         r.last_message_at, r.last_message_preview, r.last_message_sender_id, r.created_at,
         m.role, m.muted, m.last_read_at,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = r.id
              and msg.created_at > m.last_read_at
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         (select count(*)::integer from public.chat_members mm where mm.room_id = r.id),
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified
    from public.chat_members om
    join public.profiles p on p.id = om.user_id
    where r.type = 'direct' and om.room_id = r.id and om.user_id <> m.user_id
    limit 1
  ) o on true
  where m.user_id = auth.uid()
  order by coalesce(r.last_message_at, r.created_at) desc;
$$;

-- Anggota room (untuk nama pengirim, read receipt, dan indikator online).
create or replace function public.get_room_members(p_room_id uuid)
returns table (
  user_id      uuid,
  username     text,
  display_name text,
  avatar_url   text,
  is_verified  boolean,
  role         text,
  last_read_at timestamptz,
  joined_at    timestamptz
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.user_id, p.username::text, p.display_name, p.avatar_url, p.is_verified,
         m.role, m.last_read_at, m.joined_at
  from public.chat_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = p_room_id
  order by m.joined_at
  limit 500;
$$;

revoke all on all functions in schema private from public;
grant execute on function private.my_room_ids() to authenticated;
grant execute on function private.is_room_member(uuid) to authenticated;
grant execute on function private.room_role(uuid) to authenticated;
grant execute on function private.can_send_message(uuid) to authenticated;
grant execute on function private.chat_messages(uuid[]) to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.get_or_create_direct_room(uuid) to authenticated;
grant execute on function public.create_group_room(text, uuid[]) to authenticated;
grant execute on function public.add_room_members(uuid, uuid[]) to authenticated;
grant execute on function public.leave_room(uuid) to authenticated;
grant execute on function public.join_stock_room(text) to authenticated;
grant execute on function public.send_message(uuid, text, uuid, uuid, jsonb) to authenticated;
grant execute on function public.get_messages(uuid, text, integer, text) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.mark_room_read(uuid) to authenticated;
grant execute on function public.get_unread_counts() to authenticated;
grant execute on function public.get_my_rooms() to authenticated;
grant execute on function public.get_room_members(uuid) to authenticated;
