create or replace function private.official_dm_exempt(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not private.is_end_user()
      or private.is_official_account(p_user)
      or cs.is_staff(p_user);
$$;

create or replace function private.official_no_dm_error()
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform private.api_error(403, 'official_no_dm',
    'Akun resmi tidak menerima pesan langsung. Hubungi CS untuk bantuan.');
end;
$$;

create or replace function public.get_or_create_direct_room(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_me    uuid := auth.uid();
  v_key   text;
  v_room  uuid;
  v_state text;
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
  select id into v_room from public.chat_rooms where direct_key = v_key;
  if v_room is null and private.is_official_account(p_other_user_id) and not private.official_dm_exempt(v_me) then
    perform private.official_no_dm_error();
  end if;
  if v_room is null or not exists (select 1 from private.dm_requests q where q.room_id = v_room) then
    v_state := private.dm_evaluate(v_me, p_other_user_id);
    if v_state = 'denied' then
      perform private.api_error(403, 'dm_not_allowed', 'Pengguna ini tidak menerima pesan langsung dari Anda');
    end if;
  end if;

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

  if v_state is not null then
    insert into private.dm_requests (room_id, sender_id, recipient_id, status, responded_at)
    values (v_room, v_me, p_other_user_id, v_state, case when v_state = 'accepted' then now() end)
    on conflict (room_id) do nothing;
  end if;
  return v_room;
end;
$$;

create or replace function private.reject_official_members(p_me uuid, p_members uuid[])
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if private.official_dm_exempt(p_me) then
    return;
  end if;
  if exists (
    select 1 from unnest(coalesce(p_members, '{}')) as m(id)
    where m.id <> p_me and private.is_official_account(m.id)
  ) then
    perform private.official_no_dm_error();
  end if;
end;
$$;

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
  perform private.reject_official_members(v_me, p_member_ids);

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
  perform private.reject_official_members(v_me, p_user_ids);

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

create or replace function private.enforce_official_no_dm()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.sender_id is distinct from auth.uid() or private.official_dm_exempt(new.sender_id) then
    return new;
  end if;
  if private.client_id_exists('public.messages'::regclass, 'sender_id', new.sender_id, new.client_id) then
    return new;
  end if;
  if exists (
    select 1
    from public.chat_rooms r
    join public.chat_members m on m.room_id = r.id and m.user_id <> new.sender_id
    where r.id = new.room_id and r.type = 'direct' and private.is_official_account(m.user_id)
  ) then
    perform private.official_no_dm_error();
  end if;
  return new;
end;
$$;

create trigger messages_26a_official_no_dm
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_official_no_dm();

drop function public.get_profile(uuid, text);
create function public.get_profile(p_user_id uuid default null, p_username text default null)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  is_verified boolean,
  follower_count integer,
  following_count integer,
  post_count integer,
  created_at timestamptz,
  is_me boolean,
  is_following boolean,
  follows_me boolean,
  is_blocked boolean,
  is_official boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select p.id, p.username::text, p.display_name, p.avatar_url, p.bio, p.is_verified,
         p.follower_count, p.following_count, p.post_count, p.created_at,
         p.id = auth.uid(),
         exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = p.id),
         exists (select 1 from public.follows f where f.follower_id = p.id and f.following_id = auth.uid()),
         exists (select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = p.id),
         private.is_official_account(p.id)
  from public.profiles p
  where (p_user_id is not null and p.id = p_user_id)
     or (p_user_id is null and p.username = p_username::extensions.citext)
  limit 1;
$$;

drop function public.search_profiles(text, integer);
create function public.search_profiles(p_query text, p_limit integer default 10)
returns table (id uuid, username text, display_name text, avatar_url text, is_verified boolean, is_official boolean)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified, private.is_official_account(p.id)
  from public.profiles p, q
  where q.term <> ''
    and (p.username::text ilike q.term || '%' or p.display_name ilike '%' || q.term || '%')
    and p.id not in (select private.blocked_user_ids())
    and not cs.is_staff(p.id)
    and not p.is_guest
  order by (lower(p.username::text) = lower(btrim(p_query))) desc,
           p.follower_count desc,
           p.username
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$$;

revoke execute on function private.official_dm_exempt(uuid) from public, anon;
revoke execute on function private.official_no_dm_error() from public, anon;
revoke execute on function private.reject_official_members(uuid, uuid[]) from public, anon;
revoke execute on function private.enforce_official_no_dm() from public, anon;
revoke execute on function public.get_profile(uuid, text) from public, anon;
revoke execute on function public.search_profiles(text, integer) from public, anon;

grant execute on function private.official_dm_exempt(uuid) to authenticated;
grant execute on function private.official_no_dm_error() to authenticated;
grant execute on function private.reject_official_members(uuid, uuid[]) to authenticated;
grant execute on function public.get_profile(uuid, text) to authenticated;
grant execute on function public.search_profiles(text, integer) to authenticated;
