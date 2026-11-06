create table private.message_receipts (
  message_id         uuid not null references public.messages (id) on delete cascade,
  user_id            uuid not null references public.profiles (id) on delete cascade,
  message_created_at timestamptz not null,
  delivered_at       timestamptz,
  read_at            timestamptz,
  primary key (message_id, user_id)
);
create index message_receipts_created_idx on private.message_receipts (message_created_at);
create index message_receipts_user_idx on private.message_receipts (user_id);
alter table private.message_receipts enable row level security;
revoke all on private.message_receipts from public, anon, authenticated;

create or replace function private.record_message_receipts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_floor timestamptz := now() - interval '14 days';
begin
  if not exists (
    select 1 from public.chat_rooms r where r.id = new.room_id and r.type in ('direct', 'group', 'support')
  ) then
    return null;
  end if;

  if new.last_read_at > old.last_read_at then
    insert into private.message_receipts (message_id, user_id, message_created_at, delivered_at, read_at)
    select m.id, new.user_id, m.created_at, now(), now()
      from public.messages m
     where m.room_id = new.room_id
       and m.created_at > greatest(old.last_read_at, v_floor)
       and m.created_at <= new.last_read_at
       and m.sender_id is not null
       and m.sender_id <> new.user_id
     order by m.created_at desc
     limit 1000
    on conflict (message_id, user_id) do update
       set read_at = coalesce(private.message_receipts.read_at, excluded.read_at),
           delivered_at = coalesce(private.message_receipts.delivered_at, excluded.delivered_at);
  end if;

  if new.last_delivered_at > old.last_delivered_at then
    insert into private.message_receipts (message_id, user_id, message_created_at, delivered_at)
    select m.id, new.user_id, m.created_at, now()
      from public.messages m
     where m.room_id = new.room_id
       and m.created_at > greatest(old.last_delivered_at, v_floor)
       and m.created_at <= new.last_delivered_at
       and m.sender_id is not null
       and m.sender_id <> new.user_id
     order by m.created_at desc
     limit 1000
    on conflict (message_id, user_id) do nothing;
  end if;

  return null;
end;
$$;

create trigger chat_members_message_receipts
  after update of last_read_at, last_delivered_at on public.chat_members
  for each row
  when (new.last_read_at > old.last_read_at or new.last_delivered_at > old.last_delivered_at)
  execute function private.record_message_receipts();

create or replace function public.get_message_info(p_message_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_msg  public.messages;
  v_type text;
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  select * into v_msg from public.messages m where m.id = p_message_id;
  if not found or v_msg.sender_id is distinct from v_uid
     or not exists (select 1 from public.chat_members cm where cm.room_id = v_msg.room_id and cm.user_id = v_uid) then
    perform private.api_error(404, 'message_not_found', 'Pesan tidak ditemukan');
  end if;
  select r.type into v_type from public.chat_rooms r where r.id = v_msg.room_id;

  return jsonb_build_object(
    'message_id', v_msg.id,
    'sent_at', v_msg.created_at,
    'room_type', v_type,
    'recipients', case when v_type = 'stock' then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id', p.id,
               'username', p.username,
               'display_name', p.display_name,
               'avatar_url', p.avatar_url,
               'delivered', cm.last_delivered_at >= v_msg.created_at,
               'read', cm.last_read_at >= v_msg.created_at,
               'delivered_at', r.delivered_at,
               'read_at', r.read_at)
             order by r.read_at desc nulls last, r.delivered_at desc nulls last, p.username)
        from public.chat_members cm
        join public.profiles p on p.id = cm.user_id and p.deleted_at is null
        left join private.message_receipts r on r.message_id = v_msg.id and r.user_id = cm.user_id
       where cm.room_id = v_msg.room_id and cm.user_id <> v_uid
    ), '[]'::jsonb) end
  );
end;
$$;

create or replace function private.message_receipts_retention()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.message_receipts where message_created_at < now() - interval '30 days';
$$;

revoke execute on function private.record_message_receipts() from public;
revoke execute on function private.message_receipts_retention() from public;
revoke execute on function public.get_message_info(uuid) from public, anon;
grant execute on function public.get_message_info(uuid) to authenticated;

select cron.schedule('message-receipts-retention', '43 3 * * *', 'select private.message_receipts_retention()');
