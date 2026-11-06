create or replace function cs.message_text_in(t cs.tickets, p_code text, p_vars jsonb, p_language text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select cs.render_text(coalesce(m.value ->> p_language, m.value ->> 'id', p_code),
                        jsonb_build_object('ticket', t.ticket_number) || coalesce(p_vars, '{}'))
  from (select cs.setting('messages.' || p_code) as value) m;
$$;

create or replace function cs.localized_vars(t cs.tickets, p_vars jsonb, p_language text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_vars, '{}'::jsonb)
    || case when p_vars ? 'received_at'
         then jsonb_build_object('received_at', cs.format_time(t.complaint_received_at, p_language))
         else '{}'::jsonb end
    || case when p_vars ? 'due_at'
         then jsonb_build_object('due_at', cs.format_time(t.complaint_due_at, p_language))
         else '{}'::jsonb end
    || case when p_vars ? 'next_open'
         then jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), p_language))
         else '{}'::jsonb end
    || case when p_vars ? 'topic'
         then coalesce((select jsonb_build_object('topic', case when p_language = 'en' then tp.name_en else tp.name_id end)
                          from cs.support_topics tp where tp.code = t.topic), '{}'::jsonb)
         else '{}'::jsonb end;
$$;

create or replace function cs.system_message(s cs.tickets, p_code text, p_vars jsonb default '{}',
                                             p_kind text default 'system', p_payload jsonb default '{}')
returns uuid
language sql
security definer
set search_path = ''
as $$
  select cs.post_system(s, p_code, cs.message_text(s, p_code, p_vars), p_kind,
    coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('texts', jsonb_build_object(
      'id', cs.message_text_in(s, p_code, cs.localized_vars(s, p_vars, 'id'), 'id'),
      'en', cs.message_text_in(s, p_code, cs.localized_vars(s, p_vars, 'en'), 'en'))));
$$;

create or replace function cs.ticket_opened_text(t cs.tickets, p_customer uuid, p_language text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_body text;
begin
  v_body := cs.message_text_in(t, 'ticket_opened',
    jsonb_build_object('name', coalesce((select p.display_name from public.profiles p where p.id = p_customer), '')),
    p_language);
  if not cs.is_open(now()) and not exists (select 1 from cs.agents a where cs.is_reachable(a.user_id, t.language)) then
    v_body := v_body || ' ' || cs.message_text_in(t, 'out_of_hours',
      jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), p_language)), p_language);
  end if;
  if 'complaint' = any (t.flags) then
    v_body := v_body || ' ' || cs.message_text_in(t, 'complaint',
      jsonb_build_object('received_at', cs.format_time(t.complaint_received_at, p_language),
                         'due_at', cs.format_time(t.complaint_due_at, p_language)), p_language);
  end if;
  return v_body;
end;
$$;

create or replace function cs.open_ticket(p_customer uuid, p_topic text, p_language text, p_flags text[],
                                          p_context jsonb, p_first_text text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  tp     cs.support_topics;
  v_room uuid;
  v_prio record;
  v_body text;
  v_old  uuid;
  t      cs.tickets;
begin
  select * into tp from cs.support_topics where code = p_topic and active;
  if not found then
    perform private.api_error(400, 'invalid_topic', 'Topik bantuan tidak dikenal');
  end if;
  v_room := cs.ensure_room(p_customer);
  select * into t from cs.tickets where room_id = v_room and status in ('open', 'claimed', 'waiting_customer') for update;
  if found then
    return t;
  end if;
  perform cs.check_rate('cs_ticket', p_customer);
  for v_old in select x.id from cs.tickets x where x.room_id = v_room and x.status = 'resolved' loop
    perform cs.finalize_ticket(v_old, 'superseded');
  end loop;

  select * into v_prio from cs.initial_priority(
    p_topic,
    coalesce(p_flags, '{}') || case when exists (select 1 from cs.vip_customers v where v.customer_id = p_customer)
                                    then array['vip'] else array[]::text[] end,
    p_first_text, now());

  insert into cs.tickets (room_id, customer_id, topic, language, priority, flags, required_skill, context,
                          ticket_number, complaint_received_at, complaint_due_at)
  values (v_room, p_customer, tp.code, coalesce(p_language, 'id'), v_prio.priority, v_prio.flags,
          case when 'fraud' = any (v_prio.flags) then 'fraud'
               when 'complaint' = any (v_prio.flags) then 'complaint'
               else tp.skill end,
          coalesce(p_context, '{}'), cs.next_ticket_number(),
          case when 'complaint' = any (v_prio.flags) then now() end,
          case when 'complaint' = any (v_prio.flags)
               then cs.regulatory_deadline(now(), cs.setting_int('complaint.days')) end)
  on conflict (room_id) where status in ('open', 'claimed', 'waiting_customer') do nothing
  returning * into t;
  if t.id is null then
    select * into t from cs.tickets where room_id = v_room and status in ('open', 'claimed', 'waiting_customer');
    return t;
  end if;

  perform cs.log_event(t.id, 'opened', jsonb_build_object('topic', t.topic, 'priority', t.priority, 'flags', t.flags));
  v_body := cs.ticket_opened_text(t, p_customer, t.language);
  perform cs.post_system(t, 'ticket_opened', v_body, 'system',
    case when tp.help_url is null then '{}'::jsonb else jsonb_build_object('url', tp.help_url) end
    || jsonb_build_object('texts', jsonb_build_object(
         'id', cs.ticket_opened_text(t, p_customer, 'id'),
         'en', cs.ticket_opened_text(t, p_customer, 'en'))));
  perform cs.broadcast_ticket(t, 'ticket_opened');
  return t;
end;
$$;

revoke execute on function cs.message_text_in(cs.tickets, text, jsonb, text) from public;
revoke execute on function cs.localized_vars(cs.tickets, jsonb, text) from public;
revoke execute on function cs.ticket_opened_text(cs.tickets, uuid, text) from public;
