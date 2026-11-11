alter table public.chat_rooms
  add column description text,
  add column avatar_url text,
  add column only_admins_send boolean not null default false,
  add column only_admins_edit boolean not null default true,
  add constraint chat_rooms_description_length check (char_length(description) <= 500),
  add constraint chat_rooms_avatar_url check (char_length(avatar_url) <= 500 and avatar_url ~ '^https?://');

revoke update (name) on public.chat_rooms from authenticated;

alter table public.messages drop constraint messages_kind;
alter table public.messages add constraint messages_kind
  check (kind in ('text', 'system', 'quick_reply', 'help_link', 'identity_request', 'csat', 'group_event')) not valid;
alter table public.messages validate constraint messages_kind;

alter table public.messages drop constraint messages_support;
alter table public.messages add constraint messages_support
  check ((session_id is null) = (sender_role is null)
         and (session_id is not null or kind = 'text' or (kind = 'group_event' and sender_id is null))) not valid;
alter table public.messages validate constraint messages_support;

alter type public.chat_room_summary
  add attribute description text,
  add attribute avatar_url text,
  add attribute only_admins_send boolean,
  add attribute only_admins_edit boolean;

create or replace function private.chat_room_summaries(p_room_ids uuid[])
returns setof public.chat_room_summary
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type,
         case when r.type = 'support' then coalesce(cs.support_name(), 'CS') else r.name end,
         r.stock_code, r.created_by,
         r.last_message_at, r.last_message_preview, r.last_message_sender_id,
         case
           when r.last_message_at is null or r.last_message_sender_id is distinct from m.user_id then null
           when r.type = 'stock' or rc.others = 0 then 'sent'
           when rc.unread = 0 then 'read'
           when rc.undelivered = 0 then 'delivered'
           else 'sent'
         end,
         r.created_at,
         m.role, m.muted, m.last_read_at,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = r.id
              and msg.created_at > m.last_read_at
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         rc.members,
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified,
         case when r.type = 'support' then '1' else '0' end || '|'
           || private.make_cursor(coalesce(r.last_message_at, r.created_at), r.id),
         r.description, r.avatar_url,
         case when r.type = 'group' then r.only_admins_send end,
         case when r.type = 'group' then r.only_admins_edit end
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  cross join lateral (
    select count(*)::integer as members,
           count(*) filter (where om.user_id <> m.user_id)::integer as others,
           count(*) filter (where om.user_id <> m.user_id and om.last_read_at < r.last_message_at)::integer as unread,
           count(*) filter (where om.user_id <> m.user_id and om.last_delivered_at < r.last_message_at)::integer as undelivered
    from public.chat_members om
    where om.room_id = r.id
  ) rc
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified
    from public.chat_members om
    join public.profiles p on p.id = om.user_id
    where r.type = 'direct' and om.room_id = r.id and om.user_id <> m.user_id
    limit 1
  ) o on true
  where m.user_id = auth.uid() and m.room_id = any(p_room_ids)
  order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc, r.id desc;
$$;

create function private.member_name(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(p.display_name), ''), p.username::text)
  from public.profiles p
  where p.id = p_user;
$$;

create function private.post_group_event(p_room_id uuid, p_event text, p_body text, p_payload jsonb default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_role   text := current_setting('request.jwt.claim.role', true);
  v_actor  uuid := auth.uid();
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  insert into public.messages (room_id, sender_id, body, kind, payload, created_at)
  values (
    p_room_id, null, left(p_body, 4000), 'group_event',
    jsonb_build_object('event', p_event, 'actor_id', v_actor, 'actor_name', private.member_name(v_actor))
      || coalesce(p_payload, '{}'),
    clock_timestamp()
  );
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
end;
$$;

create function private.require_group_role(p_room_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.chat_rooms where id = p_room_id and type = 'group') then
    perform private.api_error(404, 'room_not_found', 'Grup tidak ditemukan');
  end if;
  v_role := private.room_role(p_room_id);
  if v_role is null then
    perform private.api_error(403, 'not_member', 'Anda bukan anggota grup ini');
  end if;
  return v_role;
end;
$$;

create function private.target_group_role(p_room_id uuid, p_user_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
begin
  select m.role into v_role from public.chat_members m where m.room_id = p_room_id and m.user_id = p_user_id;
  if v_role is null then
    perform private.api_error(404, 'member_not_found', 'Orang ini bukan anggota grup');
  end if;
  return v_role;
end;
$$;

create function public.remove_room_member(p_room_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_group_role(p_room_id);
  v_target text;
begin
  if p_user_id = auth.uid() then
    perform private.api_error(400, 'use_leave_room', 'Gunakan keluar grup untuk diri sendiri');
  end if;
  v_target := private.target_group_role(p_room_id, p_user_id);
  if v_role = 'member' or (v_role = 'admin' and v_target <> 'member') then
    perform private.api_error(403, 'forbidden', 'Anda tidak bisa mengeluarkan anggota ini');
  end if;
  perform private.post_group_event(
    p_room_id, 'removed',
    private.member_name(auth.uid()) || ' mengeluarkan ' || private.member_name(p_user_id),
    jsonb_build_object('target_id', p_user_id, 'target_name', private.member_name(p_user_id))
  );
  delete from public.chat_members where room_id = p_room_id and user_id = p_user_id;
end;
$$;

create function public.set_room_member_role(p_room_id uuid, p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_group_role(p_room_id);
  v_target text;
begin
  if p_role is null or p_role not in ('admin', 'member') then
    perform private.api_error(400, 'invalid_role', 'Peran harus admin atau member');
  end if;
  v_target := private.target_group_role(p_room_id, p_user_id);
  if v_target = 'owner' then
    perform private.api_error(403, 'forbidden', 'Peran pemilik grup hanya bisa dipindahkan');
  end if;
  if v_role = 'member' or (p_role = 'member' and v_role <> 'owner') then
    perform private.api_error(403, 'forbidden', 'Anda tidak bisa mengubah peran anggota ini');
  end if;
  if v_target = p_role then
    return;
  end if;
  update public.chat_members set role = p_role where room_id = p_room_id and user_id = p_user_id;
  perform private.post_group_event(
    p_room_id,
    case when p_role = 'admin' then 'promoted' else 'demoted' end,
    case when p_role = 'admin'
         then private.member_name(auth.uid()) || ' menjadikan ' || private.member_name(p_user_id) || ' admin'
         else private.member_name(auth.uid()) || ' mencabut status admin ' || private.member_name(p_user_id) end,
    jsonb_build_object('target_id', p_user_id, 'target_name', private.member_name(p_user_id))
  );
end;
$$;

create function public.transfer_room_ownership(p_room_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := private.require_group_role(p_room_id);
begin
  if v_role <> 'owner' then
    perform private.api_error(403, 'forbidden', 'Hanya pemilik grup yang bisa memindahkan kepemilikan');
  end if;
  if p_user_id = auth.uid() then
    perform private.api_error(400, 'invalid_target', 'Pilih anggota lain');
  end if;
  perform private.target_group_role(p_room_id, p_user_id);
  update public.chat_members set role = 'admin' where room_id = p_room_id and user_id = auth.uid();
  update public.chat_members set role = 'owner' where room_id = p_room_id and user_id = p_user_id;
  perform private.post_group_event(
    p_room_id, 'owner_changed',
    private.member_name(auth.uid()) || ' menjadikan ' || private.member_name(p_user_id) || ' pemilik grup',
    jsonb_build_object('target_id', p_user_id, 'target_name', private.member_name(p_user_id))
  );
end;
$$;

create function public.update_group_info(
  p_room_id     uuid,
  p_name        text default null,
  p_description text default null,
  p_avatar_url  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role   text := private.require_group_role(p_room_id);
  v_room   public.chat_rooms;
  v_actor  text := private.member_name(auth.uid());
  v_name   text := btrim(p_name);
  v_desc   text := nullif(btrim(p_description), '');
  v_avatar text := nullif(btrim(p_avatar_url), '');
begin
  select * into v_room from public.chat_rooms where id = p_room_id for update;
  if v_role = 'member' and v_room.only_admins_edit then
    perform private.api_error(403, 'group_admins_only_edit', 'Hanya admin yang bisa mengubah info grup');
  end if;
  if p_name is not null and char_length(v_name) not between 1 and 80 then
    perform private.api_error(400, 'invalid_name', 'Nama grup 1-80 karakter');
  end if;
  if p_description is not null and char_length(v_desc) > 500 then
    perform private.api_error(400, 'invalid_description', 'Deskripsi grup maksimal 500 karakter');
  end if;
  if v_avatar is not null and (char_length(v_avatar) > 500 or v_avatar !~ '^https?://') then
    perform private.api_error(400, 'invalid_avatar', 'Alamat foto grup tidak valid');
  end if;

  if p_name is not null and v_name is distinct from v_room.name then
    update public.chat_rooms set name = v_name where id = p_room_id;
    perform private.post_group_event(
      p_room_id, 'renamed', v_actor || ' mengubah nama grup menjadi "' || v_name || '"',
      jsonb_build_object('name', v_name)
    );
  end if;
  if p_description is not null and v_desc is distinct from v_room.description then
    update public.chat_rooms set description = v_desc where id = p_room_id;
    perform private.post_group_event(
      p_room_id, 'description_changed',
      v_actor || case when v_desc is null then ' menghapus deskripsi grup' else ' mengubah deskripsi grup' end,
      jsonb_build_object('removed', v_desc is null)
    );
  end if;
  if p_avatar_url is not null and v_avatar is distinct from v_room.avatar_url then
    update public.chat_rooms set avatar_url = v_avatar where id = p_room_id;
    perform private.post_group_event(
      p_room_id, 'photo_changed',
      v_actor || case when v_avatar is null then ' menghapus foto grup' else ' mengubah foto grup' end,
      jsonb_build_object('removed', v_avatar is null)
    );
  end if;
end;
$$;

create function public.update_group_settings(
  p_room_id          uuid,
  p_only_admins_send boolean default null,
  p_only_admins_edit boolean default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role  text := private.require_group_role(p_room_id);
  v_room  public.chat_rooms;
  v_actor text := private.member_name(auth.uid());
begin
  if v_role = 'member' then
    perform private.api_error(403, 'forbidden', 'Hanya admin yang bisa mengubah pengaturan grup');
  end if;
  select * into v_room from public.chat_rooms where id = p_room_id for update;
  if p_only_admins_send is not null and p_only_admins_send <> v_room.only_admins_send then
    update public.chat_rooms set only_admins_send = p_only_admins_send where id = p_room_id;
    perform private.post_group_event(
      p_room_id, 'settings_changed',
      v_actor || case when p_only_admins_send then ' mengizinkan hanya admin mengirim pesan'
                      else ' mengizinkan semua anggota mengirim pesan' end,
      jsonb_build_object('setting', 'only_admins_send', 'value', p_only_admins_send)
    );
  end if;
  if p_only_admins_edit is not null and p_only_admins_edit <> v_room.only_admins_edit then
    update public.chat_rooms set only_admins_edit = p_only_admins_edit where id = p_room_id;
    perform private.post_group_event(
      p_room_id, 'settings_changed',
      v_actor || case when p_only_admins_edit then ' mengizinkan hanya admin mengubah info grup'
                      else ' mengizinkan semua anggota mengubah info grup' end,
      jsonb_build_object('setting', 'only_admins_edit', 'value', p_only_admins_edit)
    );
  end if;
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
  v_added uuid[];
  v_names text[];
begin
  if not exists (select 1 from public.chat_rooms where id = p_room_id and type = 'group') then
    perform private.api_error(404, 'room_not_found', 'Grup tidak ditemukan');
  end if;
  if coalesce(private.room_role(p_room_id), '') not in ('owner', 'admin') then
    perform private.api_error(403, 'forbidden', 'Hanya owner/admin yang bisa menambah anggota');
  end if;
  perform private.reject_official_members(v_me, p_user_ids);

  with added as (
    insert into public.chat_members (room_id, user_id)
    select p_room_id, p.id
    from public.profiles p
    where p.id = any(coalesce(p_user_ids, '{}'))
      and not private.is_blocked_pair(v_me, p.id)
      and (select count(*) from public.chat_members where room_id = p_room_id) < 100
    on conflict do nothing
    returning user_id
  )
  select coalesce(array_agg(user_id), '{}') into v_added from added;

  if cardinality(v_added) > 0 then
    select array_agg(private.member_name(u) order by ord) into v_names
    from unnest(v_added) with ordinality as x(u, ord);
    perform private.post_group_event(
      p_room_id, 'added',
      private.member_name(v_me) || ' menambahkan ' || array_to_string(v_names[1:3], ', ')
        || case when cardinality(v_names) > 3 then ' dan ' || (cardinality(v_names) - 3) || ' lainnya' else '' end,
      jsonb_build_object(
        'targets', (select jsonb_agg(jsonb_build_object('id', v_added[i], 'name', v_names[i]) order by i)
                    from generate_subscripts(v_added, 1) i where i <= 20),
        'count', cardinality(v_added)
      )
    );
  end if;
  return cardinality(v_added);
end;
$$;

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
  if v_room.type = 'support' then
    perform private.api_error(400, 'cannot_leave_support', 'Chat CS tidak bisa ditinggalkan');
  end if;

  if v_room.type = 'group' then
    if v_role = 'owner' then
      select user_id into v_heir from public.chat_members
      where room_id = p_room_id and user_id <> auth.uid()
      order by (role = 'admin') desc, joined_at
      limit 1;
    end if;
    if v_role <> 'owner' or v_heir is not null then
      perform private.post_group_event(
        p_room_id, 'left',
        private.member_name(auth.uid()) || ' keluar'
          || case when v_heir is not null
                  then '. ' || private.member_name(v_heir) || ' sekarang pemilik grup' else '' end,
        case when v_heir is null then '{}'::jsonb
             else jsonb_build_object('new_owner_id', v_heir, 'new_owner_name', private.member_name(v_heir)) end
      );
    end if;
  end if;

  delete from public.chat_members where room_id = p_room_id and user_id = auth.uid();

  if v_room.type = 'group' and v_role = 'owner' then
    if v_heir is null then
      delete from public.chat_rooms where id = p_room_id;
    else
      update public.chat_members set role = 'owner' where room_id = p_room_id and user_id = v_heir;
    end if;
  end if;
end;
$$;

create function private.enforce_group_admins_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.sender_id is null or not private.is_end_user() then
    return new;
  end if;
  if not exists (select 1 from public.chat_rooms r
                 where r.id = new.room_id and r.type = 'group' and r.only_admins_send) then
    return new;
  end if;
  if exists (select 1 from public.chat_members m
             where m.room_id = new.room_id and m.user_id = new.sender_id and m.role in ('owner', 'admin'))
     or private.client_id_exists('public.messages'::regclass, 'sender_id', new.sender_id, new.client_id) then
    return new;
  end if;
  perform private.api_error(403, 'group_admins_only', 'Hanya admin yang bisa mengirim pesan di grup ini');
  return new;
end;
$$;

create trigger messages_26b_group_admins_only
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_group_admins_only();

create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room    public.chat_rooms;
  v_member  record;
  v_target  uuid;
  v_preview text;
  v_locked  boolean;
begin
  v_preview := case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end;

  select * into v_room from public.chat_rooms where id = new.room_id;

  if new.moderation_status = 'visible' then
    v_locked := v_room.type is distinct from 'stock';
    if not v_locked then
      perform 1 from public.chat_rooms r where r.id = new.room_id for no key update skip locked;
      v_locked := found;
    end if;
    if v_locked then
      update public.chat_rooms
         set last_message_at = new.created_at,
             last_message_preview = v_preview,
             last_message_sender_id = new.sender_id
       where id = new.room_id
         and (last_message_at is null or last_message_at <= new.created_at);
    else
      insert into private.room_preview_queue (room_id) values (new.room_id);
    end if;
  end if;

  update public.chat_members
     set last_read_at = greatest(last_read_at, new.created_at),
         last_delivered_at = greatest(last_delivered_at, new.created_at)
   where room_id = new.room_id and user_id = new.sender_id;

  if v_room.type in ('direct', 'group') and new.kind <> 'group_event' then
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
  elsif v_room.type = 'stock' and new.sender_id is not null and new.deleted_at is null
        and new.moderation_status = 'visible' and position('@' in new.body) > 0 then
    for v_target in
      select p.id
      from unnest((private.extract_mentions(new.body))[1:private.setting_num('notifications.mention_room_max', 5)::integer])
           with ordinality as u(username, ord)
      join public.profiles p on p.username = u.username::extensions.citext
      where p.id <> new.sender_id
        and p.deleted_at is null
        and not private.is_banned(p.id)
        and not exists (select 1 from public.mutes m where m.muter_id = p.id and m.muted_id = new.sender_id)
      order by u.ord
    loop
      perform private.notify(
        v_target, new.sender_id, 'mention',
        jsonb_build_object(
          'room_id', new.room_id,
          'room_type', 'stock',
          'room_name', v_room.name,
          'stock_code', v_room.stock_code,
          'message_id', new.id,
          'snippet', v_preview
        ),
        'mention:room:' || new.room_id
      );
    end loop;
  end if;
  return null;
end;
$$;

revoke execute on function private.member_name(uuid) from public;
revoke execute on function private.post_group_event(uuid, text, text, jsonb) from public;
revoke execute on function private.require_group_role(uuid) from public;
revoke execute on function private.target_group_role(uuid, uuid) from public;
revoke execute on function private.enforce_group_admins_only() from public;
revoke execute on function public.remove_room_member(uuid, uuid) from public, anon;
revoke execute on function public.set_room_member_role(uuid, uuid, text) from public, anon;
revoke execute on function public.transfer_room_ownership(uuid, uuid) from public, anon;
revoke execute on function public.update_group_info(uuid, text, text, text) from public, anon;
revoke execute on function public.update_group_settings(uuid, boolean, boolean) from public, anon;
grant execute on function public.remove_room_member(uuid, uuid) to authenticated;
grant execute on function public.set_room_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.transfer_room_ownership(uuid, uuid) to authenticated;
grant execute on function public.update_group_info(uuid, text, text, text) to authenticated;
grant execute on function public.update_group_settings(uuid, boolean, boolean) to authenticated;
