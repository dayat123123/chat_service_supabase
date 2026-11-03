insert into private.settings (key, value, description) values
  ('dm.request_max_messages', '3', 'Pesan maksimal dari pengirim sebelum permintaan pesan DM diterima penerima')
on conflict (key) do nothing;

create table private.dm_preferences (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  policy     text not null default 'everyone',
  updated_at timestamptz not null default now(),
  constraint dm_preferences_policy check (policy in ('everyone', 'following', 'none'))
);
alter table private.dm_preferences enable row level security;

create table private.dm_requests (
  room_id      uuid primary key references public.chat_rooms (id) on delete cascade,
  sender_id    uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending',
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  constraint dm_requests_status check (status in ('pending', 'accepted', 'declined')),
  constraint dm_requests_pair check (sender_id <> recipient_id)
);
create index dm_requests_recipient_idx on private.dm_requests (recipient_id, created_at desc) where status = 'pending';
alter table private.dm_requests enable row level security;

insert into private.dm_requests (room_id, sender_id, recipient_id, status, created_at, responded_at)
select r.id, s.user_id, o.user_id, 'accepted', r.created_at, now()
from public.chat_rooms r
cross join lateral (
  select m.user_id from public.chat_members m
  where m.room_id = r.id
  order by (m.user_id = r.created_by) desc, m.joined_at
  limit 1) s
cross join lateral (
  select m.user_id from public.chat_members m
  where m.room_id = r.id and m.user_id <> s.user_id
  limit 1) o
where r.type = 'direct'
on conflict (room_id) do nothing;

create or replace function private.dm_policy(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select d.policy from private.dm_preferences d where d.user_id = p_user), 'everyone');
$$;

create or replace function private.is_following(p_follower uuid, p_following uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.follows f where f.follower_id = p_follower and f.following_id = p_following);
$$;

create or replace function private.dm_evaluate(p_sender uuid, p_recipient uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_policy  text;
  v_follows boolean;
begin
  if private.safety_exempt(p_sender) or private.safety_exempt(p_recipient) then
    return 'accepted';
  end if;
  v_policy := private.dm_policy(p_recipient);
  v_follows := private.is_following(p_recipient, p_sender);
  if v_policy = 'none' or (v_policy = 'following' and not v_follows) then
    return 'denied';
  end if;
  if v_follows and (not private.is_new_account(p_sender) or private.is_following(p_sender, p_recipient)) then
    return 'accepted';
  end if;
  return 'pending';
end;
$$;

create or replace function private.dm_request_pending(p_room uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.dm_requests q
    where q.room_id = p_room and q.recipient_id = p_user and q.status in ('pending', 'declined'));
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

create or replace function private.enforce_dm_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request private.dm_requests;
  v_other   uuid;
  v_state   text;
begin
  if not private.is_end_user() or new.sender_id is distinct from auth.uid() then
    return new;
  end if;
  if private.client_id_exists('public.messages'::regclass, 'sender_id', new.sender_id, new.client_id) then
    return new;
  end if;
  if not exists (select 1 from public.chat_rooms r where r.id = new.room_id and r.type = 'direct') then
    return new;
  end if;

  select * into v_request from private.dm_requests q where q.room_id = new.room_id for update;
  if not found then
    select m.user_id into v_other from public.chat_members m
    where m.room_id = new.room_id and m.user_id <> new.sender_id limit 1;
    if v_other is null then
      return new;
    end if;
    v_state := private.dm_evaluate(new.sender_id, v_other);
    if v_state = 'denied' then
      perform private.api_error(403, 'dm_not_allowed', 'Pengguna ini tidak menerima pesan langsung dari Anda');
    end if;
    insert into private.dm_requests (room_id, sender_id, recipient_id, status, responded_at)
    values (new.room_id, new.sender_id, v_other, v_state, case when v_state = 'accepted' then now() end)
    on conflict (room_id) do nothing;
    return new;
  end if;

  if v_request.status = 'accepted' then
    return new;
  end if;
  if new.sender_id = v_request.recipient_id then
    update private.dm_requests set status = 'accepted', responded_at = now() where room_id = new.room_id;
    return new;
  end if;

  v_state := private.dm_evaluate(v_request.sender_id, v_request.recipient_id);
  if v_state = 'accepted' then
    update private.dm_requests set status = 'accepted', responded_at = now() where room_id = new.room_id;
    return new;
  end if;
  if v_state = 'denied' then
    perform private.api_error(403, 'dm_not_allowed', 'Pengguna ini tidak menerima pesan langsung dari Anda');
  end if;
  if (select count(*) from public.messages m where m.room_id = new.room_id and m.sender_id = new.sender_id)
     >= private.setting_num('dm.request_max_messages', 3) then
    perform private.api_error(403, 'dm_request_limit',
      'Tunggu sampai penerima menerima permintaan pesan Anda sebelum mengirim pesan lagi');
  end if;
  return new;
end;
$$;

create trigger messages_27_dm_request
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_dm_request();

create or replace function public.get_message_requests(p_limit integer default 50, p_before timestamptz default null)
returns table (
  room_id              uuid,
  sender_id            uuid,
  username             text,
  display_name         text,
  avatar_url           text,
  is_verified          boolean,
  message_count        integer,
  has_image            boolean,
  last_message_preview text,
  last_message_at      timestamptz,
  created_at           timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select q.room_id, p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified,
         s.message_count, s.has_image,
         case when s.last_body = '' then '[lampiran]' else private.snippet(s.last_body, 120) end,
         s.last_at, q.created_at
  from private.dm_requests q
  join public.profiles p on p.id = q.sender_id
  cross join lateral (
    select count(*)::integer as message_count,
           coalesce(bool_or(private.has_image_attachment(m.attachments)), false) as has_image,
           (array_agg(m.body order by m.created_at desc, m.id desc))[1] as last_body,
           max(m.created_at) as last_at
    from public.messages m
    where m.room_id = q.room_id and m.sender_id = q.sender_id
      and m.deleted_at is null and m.moderation_status = 'visible') s
  where q.recipient_id = auth.uid()
    and q.status = 'pending'
    and not private.is_blocked_pair(q.recipient_id, q.sender_id)
    and (p_before is null or q.created_at < p_before)
  order by q.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

create or replace function public.respond_message_request(p_room_id uuid, p_action text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := auth.uid();
  v_request private.dm_requests;
begin
  if v_me is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_action is null or p_action not in ('accept', 'decline', 'block') then
    perform private.api_error(400, 'invalid_action', 'Aksi: accept, decline, atau block');
  end if;
  select * into v_request from private.dm_requests q
  where q.room_id = p_room_id and q.recipient_id = v_me and q.status in ('pending', 'declined')
  for update;
  if not found then
    perform private.api_error(404, 'request_not_found', 'Permintaan pesan tidak ditemukan');
  end if;

  if p_action = 'accept' then
    update private.dm_requests set status = 'accepted', responded_at = now() where room_id = p_room_id;
  else
    update private.dm_requests set status = 'declined', responded_at = now() where room_id = p_room_id;
    if p_action = 'block' then
      insert into public.blocks (blocker_id, blocked_id) values (v_me, v_request.sender_id) on conflict do nothing;
      insert into public.reports (reporter_id, target_type, target_id, reason, details)
      values (v_me, 'user', v_request.sender_id, 'spam', 'Permintaan pesan yang tidak diinginkan')
      on conflict (reporter_id, target_type, target_id) do nothing;
    end if;
  end if;
  return jsonb_build_object('room_id', p_room_id,
                            'status', case p_action when 'accept' then 'accepted' else 'declined' end,
                            'blocked', p_action = 'block');
end;
$$;

create or replace function public.get_dm_policy()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  return jsonb_build_object('policy', private.dm_policy(auth.uid()),
                            'request_max_messages', private.setting_num('dm.request_max_messages', 3));
end;
$$;

create or replace function public.set_dm_policy(p_policy text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if p_policy is null or p_policy not in ('everyone', 'following', 'none') then
    perform private.api_error(400, 'invalid_policy', 'Pilihan: everyone, following, atau none');
  end if;
  insert into private.dm_preferences (user_id, policy) values (auth.uid(), p_policy)
  on conflict (user_id) do update set policy = excluded.policy, updated_at = now();
  return public.get_dm_policy();
end;
$$;


create or replace function public.get_unread_chat_count()
returns integer
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select count(*)::integer
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  where m.user_id = auth.uid()
    and not m.muted
    and r.type in ('direct', 'group')
    and r.last_message_at > m.last_read_at
    and not (r.type = 'direct' and private.dm_request_pending(r.id, m.user_id))
    and exists (
      select 1 from public.messages msg
      where msg.room_id = m.room_id
        and msg.created_at > m.last_read_at
        and msg.sender_id is distinct from m.user_id
        and msg.deleted_at is null
    );
$$;

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
  where m.user_id = auth.uid()
    and not private.dm_request_pending(m.room_id, m.user_id);
$$;

create or replace function public.get_message_request_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from private.dm_requests q
  where q.recipient_id = auth.uid()
    and q.status = 'pending'
    and not private.is_blocked_pair(q.recipient_id, q.sender_id);
$$;

revoke execute on function private.dm_policy(uuid) from public;
revoke execute on function private.is_following(uuid, uuid) from public;
revoke execute on function private.dm_evaluate(uuid, uuid) from public;
revoke execute on function private.dm_request_pending(uuid, uuid) from public;
revoke execute on function private.enforce_dm_request() from public;
revoke execute on function public.get_or_create_direct_room(uuid) from public, anon;
revoke execute on function public.get_message_requests(integer, timestamptz) from public, anon;
revoke execute on function public.respond_message_request(uuid, text) from public, anon;
revoke execute on function public.get_dm_policy() from public, anon;
revoke execute on function public.set_dm_policy(text) from public, anon;

grant execute on function public.get_or_create_direct_room(uuid) to authenticated;
grant execute on function public.get_message_requests(integer, timestamptz) to authenticated;
grant execute on function public.respond_message_request(uuid, text) to authenticated;
grant execute on function public.get_dm_policy() to authenticated;
grant execute on function public.set_dm_policy(text) to authenticated;
revoke execute on function public.get_message_request_count() from public, anon;
revoke execute on function public.get_unread_chat_count() from public, anon;
revoke execute on function public.get_unread_counts() from public, anon;

grant execute on function private.dm_request_pending(uuid, uuid) to authenticated;
grant execute on function public.get_message_request_count() to authenticated;
grant execute on function public.get_unread_chat_count() to authenticated, service_role;
grant execute on function public.get_unread_counts() to authenticated, service_role;
