create or replace function cs.open_session(p_customer uuid, p_topic text, p_language text, p_flags text[],
                                           p_context jsonb, p_first_text text)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      cs.support_topics;
  v_room uuid;
  v_prio record;
  s      cs.support_sessions;
begin
  select * into t from cs.support_topics where code = p_topic and active;
  if not found then
    perform private.api_error(400, 'invalid_topic', 'Topik bantuan tidak dikenal');
  end if;
  v_room := cs.ensure_room(p_customer);
  select * into s from cs.support_sessions where room_id = v_room and status <> 'closed' for update;
  if found then
    return s;
  end if;
  perform cs.check_rate('cs_session', p_customer);

  select * into v_prio from cs.initial_priority(
    p_topic,
    coalesce(p_flags, '{}') || case when exists (select 1 from cs.vip_customers v where v.customer_id = p_customer)
                                    then array['vip'] else array[]::text[] end,
    p_first_text, now());

  insert into cs.support_sessions (room_id, customer_id, topic, language, priority, flags, required_skill,
                                   target_team_id, context, complaint_received_at, complaint_due_at)
  values (v_room, p_customer, t.code, coalesce(p_language, 'id'), v_prio.priority, v_prio.flags,
          case when 'fraud' = any (v_prio.flags) then 'fraud'
               when 'complaint' = any (v_prio.flags) then 'complaint'
               else t.skill end,
          t.team_id, coalesce(p_context, '{}'),
          case when 'complaint' = any (v_prio.flags) then now() end,
          case when 'complaint' = any (v_prio.flags)
               then cs.regulatory_deadline(now(), cs.setting_int('complaint.days')) end)
  on conflict (room_id) where status <> 'closed' do nothing
  returning * into s;
  if s.id is null then
    select * into s from cs.support_sessions where room_id = v_room and status <> 'closed';
    return s;
  end if;

  perform cs.log_event(s.id, 'queued', jsonb_build_object('topic', s.topic, 'priority', s.priority, 'flags', s.flags));
  perform cs.system_message(s, 'greeting',
    jsonb_build_object('name', coalesce((select p.display_name from public.profiles p where p.id = p_customer), '')));
  perform cs.system_message(s, 'security_reminder');
  if t.help_url is not null then
    perform cs.system_message(s, 'help',
      jsonb_build_object('topic', case when s.language = 'en' then t.name_en else t.name_id end),
      'help_link', jsonb_build_object('url', t.help_url));
  end if;
  if cs.is_open(now()) then
    perform cs.system_message(s, 'queued');
  else
    perform cs.system_message(s, 'out_of_hours',
      jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), s.language)));
  end if;
  if 'complaint' = any (s.flags) then
    perform cs.system_message(s, 'complaint', cs.complaint_note(s));
  end if;
  perform cs.broadcast_session(s, 'queued');
  return s;
end;
$$;

create or replace function cs.reopen(p_session_id uuid)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  perform cs.set_status(p_session_id, 'reopened', 'reopened');
  update cs.support_sessions
     set closed_by = null, close_outcome = null, reopen_count = reopen_count + 1,
         target_agent_id = last_agent_id, queued_at = now()
   where id = p_session_id
  returning * into s;
  perform cs.system_message(s, 'reopened');
  if s.last_agent_id is not null then
    perform 1 from cs.agent_status where agent_id = s.last_agent_id for update;
    if cs.agent_available(s.last_agent_id) then
      return cs.assign(s.id, s.last_agent_id, 'reassigned');
    end if;
  end if;
  perform cs.broadcast_session(s, 'reopened');
  return s;
end;
$$;

create or replace function cs.message_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   public.chat_rooms;
  s        cs.support_sessions;
  v_last   cs.support_sessions;
  v_prio   record;
  v_masked record;
begin
  if tg_op = 'UPDATE' then
    if old.session_id is null
       or (new.body, new.attachments, new.deleted_at, new.kind, new.payload, new.session_id, new.sender_role)
          is not distinct from
          (old.body, old.attachments, old.deleted_at, old.kind, old.payload, old.session_id, old.sender_role)
       or not private.is_end_user()
       or private.admin_role() is not null then
      return new;
    end if;
    if new.deleted_at is not null and old.deleted_at is null then
      return null;
    end if;
    perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa diubah');
  end if;

  select * into v_room from public.chat_rooms where id = new.room_id;
  if v_room.type is distinct from 'support' then
    if new.session_id is not null or new.sender_role is not null then
      perform private.api_error(400, 'invalid_message', 'Pesan ini hanya untuk chat CS');
    end if;
    return new;
  end if;

  if new.sender_id is null then
    new.sender_role := 'system';
  elsif new.sender_id = v_room.customer_id then
    new.sender_role := 'customer';
    if new.kind not in ('text', 'card') then
      perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak diizinkan');
    end if;
  elsif new.sender_role is null or new.sender_role not in ('agent', 'supervisor') or not cs.is_staff(new.sender_id) then
    perform private.api_error(403, 'use_cs_api', 'Pesan CS hanya bisa dikirim lewat panel CS');
  end if;

  if new.sender_role = 'customer' and new.session_id is null then
    if new.client_id is not null then
      select m.session_id into new.session_id
      from public.messages m where m.sender_id = new.sender_id and m.client_id = new.client_id;
      if new.session_id is not null then
        return new;
      end if;
    end if;
    perform cs.check_rate('cs_message', new.sender_id);
    select * into v_last from cs.support_sessions
    where room_id = new.room_id order by created_at desc limit 1 for update;
    if v_last.id is not null and v_last.status <> 'closed' then
      s := v_last;
      if s.last_customer_message_at is null then
        select * into v_prio from cs.initial_priority(s.topic, s.flags, new.body, now());
        if v_prio.priority < s.priority or not (v_prio.flags <@ s.flags) then
          update cs.support_sessions
             set priority = least(priority, v_prio.priority),
                 flags = array(select distinct f from unnest(flags || v_prio.flags) f order by f),
                 required_skill = case when 'fraud' = any (v_prio.flags) then 'fraud' else required_skill end,
                 updated_at = now()
           where id = s.id
          returning * into s;
          perform cs.log_event(s.id, 'priority_changed', jsonb_build_object('priority', s.priority, 'flags', s.flags));
          perform cs.broadcast_session(s, 'priority_changed');
        end if;
      end if;
    elsif v_last.id is not null
          and v_last.closed_at > now() - make_interval(mins => cs.setting_int('session.reopen_minutes')) then
      s := cs.reopen(v_last.id);
    else
      s := cs.open_session(new.sender_id, cs.setting('session.default_topic') #>> '{}',
                           coalesce(v_last.language, 'id'), '{}', '{}', new.body);
    end if;
    new.session_id := s.id;
  end if;

  select * into s from cs.support_sessions where id = new.session_id;
  if s.room_id is distinct from new.room_id then
    perform private.api_error(400, 'invalid_session', 'Sesi tidak sesuai dengan room');
  end if;

  if new.sender_role = 'customer' then
    update cs.support_sessions set last_customer_message_at = clock_timestamp() where id = s.id;
  elsif new.sender_role in ('agent', 'supervisor') then
    update cs.support_sessions
       set last_agent_message_at = clock_timestamp(),
           first_response_at = coalesce(first_response_at, clock_timestamp())
     where id = s.id;
  end if;

  if new.sender_role <> 'system' and new.body <> '' then
    select * into v_masked from cs.mask_sensitive(new.body);
    if cardinality(v_masked.kinds) > 0 then
      new.body := v_masked.masked;
      new.payload := new.payload || jsonb_build_object('masked', to_jsonb(v_masked.kinds));
    end if;
  end if;
  new.created_at := clock_timestamp();
  return new;
end;
$$;

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
  if v_msg.session_id is not null and coalesce(auth.role(), '') <> 'service_role' then
    perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa dihapus');
  end if;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by)
  values ('message', v_msg.id, v_msg.sender_id, v_msg.body, v_msg.attachments, auth.uid());

  update public.messages
     set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where id = p_message_id;
end;
$$;
