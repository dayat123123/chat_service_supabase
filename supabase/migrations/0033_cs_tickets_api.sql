create or replace function cs.ticket_card(t cs.tickets, p_viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(t) || jsonb_build_object(
    'preview', (select private.snippet(m.body, 140) from public.messages m
                where m.session_id = t.id and m.sender_role in ('customer', 'agent', 'supervisor')
                order by m.created_at desc limit 1),
    'unread_count', case
      when t.status = 'open' then (select count(*)::integer from (
        select 1 from public.messages m where m.session_id = t.id and m.sender_role = 'customer' limit 99) x)
      else (select count(*)::integer from (
        select 1 from public.messages m
        join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = p_viewer
        where m.session_id = t.id and m.sender_role = 'customer' and m.created_at > cm.last_read_at limit 99) x)
    end,
    'waiting_since', case
      when t.status = 'open' then t.queued_at
      when t.last_customer_message_at > coalesce(t.last_agent_message_at, '-infinity') then t.last_customer_message_at
    end
  );
$$;

create or replace function cs_api.support_home()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_customer();
  v_room uuid;
  t      cs.tickets;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = v_me;
  select * into t from cs.tickets x
  where x.customer_id = v_me
  order by (x.status in ('open', 'claimed', 'waiting_customer')) desc, x.created_at desc
  limit 1;
  return jsonb_build_object(
    'room_id', v_room,
    'support_name', cs.support_name(),
    'ticket', case when t.id is not null then cs.ticket_customer_view(t) end,
    'active', t.id is not null and t.status in ('open', 'claimed', 'waiting_customer'),
    'unread_count', coalesce((
      select count(*)::integer from (
        select 1 from public.messages m
        join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = v_me
        where m.room_id = v_room and m.sender_id is distinct from v_me and m.created_at > cm.last_read_at
          and m.deleted_at is null
        limit 99) x), 0),
    'service_open', cs.is_open(now()),
    'next_open_at', case when not cs.is_open(now()) then cs.next_open_at(now()) end);
end;
$$;

create or replace function cs_api.open_ticket(p_topic text, p_language text default 'id', p_screen text default null,
                                              p_complaint boolean default false, p_card text default null,
                                              p_card_ref text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  if coalesce(p_language, '') not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if p_screen is not null and p_screen !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_screen', 'Asal layar tidak valid');
  end if;
  if p_card is not null and (p_card not in ('order', 'cash_transaction') or coalesce(p_card_ref, '') !~ '^[A-Za-z0-9._:-]{1,64}$') then
    perform private.api_error(400, 'invalid_card', 'Kartu harus berisi order atau transaksi dana yang valid');
  end if;
  t := cs.open_ticket(v_me, p_topic, p_language,
                      case when p_complaint then array['complaint'] else array[]::text[] end,
                      case when p_screen is null then '{}'::jsonb else jsonb_build_object('screen', p_screen) end,
                      null);
  if p_complaint and not ('complaint' = any (t.flags)) then
    t := cs.flag_ticket(t.id, 'complaint');
  end if;
  if p_card is not null then
    insert into public.messages (room_id, sender_id, body, kind, payload, session_id)
    values (t.room_id, v_me, case p_card when 'order' then 'Order ' else 'Transaksi dana ' end || p_card_ref,
            'card', jsonb_build_object('card', p_card, 'ref', p_card_ref), t.id);
    select * into t from cs.tickets where id = t.id;
  end if;
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs_api.my_tickets()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(cs.ticket_customer_view(t) || jsonb_build_object(
           'first_message_at', (select min(m.created_at) from public.messages m where m.session_id = t.id))
         order by t.created_at desc), '[]')
  from (select x.* from cs.tickets x where x.customer_id = cs.require_customer() order by x.created_at desc limit 50) t;
$$;

create or replace function cs_api.ticket_messages(p_ticket_id uuid)
returns setof public.chat_message
language plpgsql
stable
set search_path = ''
as $$
begin
  return query select * from private.chat_messages(array(
    select m.id from public.messages m where m.session_id = p_ticket_id order by m.created_at desc limit 500));
end;
$$;

create or replace function cs_api.close_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id and customer_id = v_me;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  t := cs.finalize_ticket(t.id, 'customer');
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs_api.rate_ticket(p_ticket_id uuid, p_rating integer, p_comment text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id and customer_id = v_me for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not (t.status in ('resolved', 'closed') and t.first_claimed_at is not null and t.rating is null) then
    perform private.api_error(409, 'cannot_rate', 'Tiket ini tidak bisa diberi nilai');
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    perform private.api_error(400, 'invalid_rating', 'Nilai harus 1 sampai 5');
  end if;
  if char_length(coalesce(p_comment, '')) > 500 then
    perform private.api_error(400, 'comment_too_long', 'Komentar maksimal 500 karakter');
  end if;
  update cs.tickets
     set rating = p_rating,
         rating_comment = nullif(btrim((cs.mask_sensitive(coalesce(p_comment, ''))).masked), ''),
         rated_at = now(), updated_at = now()
   where id = t.id
  returning * into t;
  perform cs.log_event(t.id, 'rated', jsonb_build_object('rating', p_rating));
  perform cs.broadcast_ticket(t, 'ticket_updated', array[t.last_owner_id]);
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs_api.request_complaint()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  t    cs.tickets;
begin
  select * into t from cs.tickets where customer_id = v_me and status in ('open', 'claimed', 'waiting_customer');
  if found then
    t := cs.flag_ticket(t.id, 'complaint');
  else
    t := cs.open_ticket(v_me, cs.setting('ticket.default_topic') #>> '{}', 'id', array['complaint'], '{}', null);
  end if;
  perform cs.audit('ticket.complaint_requested', t.id, v_me);
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs_api.report_fake_cs(p_description text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_customer();
  v_text text := btrim(coalesce(p_description, ''));
  t      cs.tickets;
begin
  if char_length(v_text) not between 5 and 2000 then
    perform private.api_error(400, 'invalid_description', 'Ceritakan kejadiannya (5–2000 karakter)');
  end if;
  select * into t from cs.tickets where customer_id = v_me and status in ('open', 'claimed', 'waiting_customer');
  if found then
    t := cs.flag_ticket(t.id, 'fraud');
  else
    t := cs.open_ticket(v_me, 'fraud', 'id', array['fraud'], jsonb_build_object('report', 'fake_cs'), null);
  end if;
  insert into public.messages (room_id, sender_id, body, session_id)
  values (t.room_id, v_me, 'Laporan CS palsu: ' || v_text, t.id);
  perform cs.log_event(t.id, 'fake_cs_reported');
  perform cs.audit('ticket.fake_cs_reported', t.id, v_me);
  perform realtime.send(jsonb_build_object('event', 'fake_cs_reported', 'ticket_id', t.id,
                                           'ticket_number', t.ticket_number, 'priority', t.priority),
                        'alert', 'cs:queue', true);
  select * into t from cs.tickets where id = t.id;
  return cs.ticket_customer_view(t);
end;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes'),
        'reveal_reasons', cs.setting('customer_data.reveal_reasons')))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.agent_set_status(p_status text, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent();
  v_old text;
begin
  if coalesce(p_status, '') not in ('online', 'busy', 'break', 'offline') then
    perform private.api_error(400, 'invalid_status', 'Status harus online, busy, break, atau offline');
  end if;
  if char_length(coalesce(p_reason, '')) > 120 then
    perform private.api_error(400, 'reason_too_long', 'Alasan maksimal 120 karakter');
  end if;
  select status into v_old from cs.agent_status where agent_id = v_me for update;
  update cs.agent_status
     set status = p_status,
         reason = nullif(btrim(p_reason), ''),
         last_heartbeat_at = now(),
         status_changed_at = case when status <> p_status then now() else status_changed_at end
   where agent_id = v_me;
  if p_status = 'offline' and v_old is distinct from 'offline' then
    perform cs.notify_owner_away(v_me);
  end if;
  perform cs.audit('agent.status', null, null, jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason));
  perform realtime.send(jsonb_build_object('event', 'agent_status', 'agent_id', v_me, 'status', p_status),
                        'agent', 'cs:queue', true);
  return cs_api.agent_me();
end;
$$;

create or replace function cs_api.agent_heartbeat()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
  st   cs.agent_status;
begin
  update cs.agent_status set last_heartbeat_at = now() where agent_id = v_me returning * into st;
  return jsonb_build_object('status', st.status, 'active_tickets', cs.active_ticket_count(v_me),
                            'max_active_tickets', (select a.max_active_tickets from cs.agents a where a.user_id = v_me));
end;
$$;

create or replace function cs_api.ticket_lists()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  v_sup   boolean := cs.has_role('{cs_supervisor}');
  v_today timestamptz := (cs.local_date(now())::timestamp at time zone 'Asia/Jakarta');
begin
  return jsonb_build_object(
    'open', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.queued_at)
      from (select * from cs.tickets x where x.status = 'open' order by x.priority, x.queued_at limit 200) t), '[]'),
    'mine', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, coalesce(t.last_customer_message_at, t.claimed_at))
      from cs.tickets t where t.owner_agent_id = v_me and t.status in ('claimed', 'waiting_customer')), '[]'),
    'resolved_today', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by coalesce(t.resolved_at, t.closed_at) desc)
      from cs.tickets t
      where t.last_owner_id = v_me and t.status in ('resolved', 'closed')
        and coalesce(t.resolved_at, t.closed_at) >= v_today), '[]'),
    'all_active', case when v_sup then coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.claimed_at)
      from cs.tickets t where t.status in ('claimed', 'waiting_customer')), '[]') else '[]'::jsonb end,
    'transfers_in', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'note', x.note, 'expires_at', x.expires_at,
                                          'from_name', cs.agent_name(x.from_agent_id), 'ticket', cs.ticket_card(t, v_me))
             order by x.created_at)
      from cs.ticket_transfers x join cs.tickets t on t.id = x.ticket_id
      where x.to_agent_id = v_me and x.result is null and x.expires_at > now()), '[]'),
    'transfers_out', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'ticket_id', x.ticket_id, 'expires_at', x.expires_at,
                                          'to_name', cs.agent_name(x.to_agent_id)) order by x.created_at)
      from cs.ticket_transfers x where x.from_agent_id = v_me and x.result is null), '[]'));
end;
$$;

create or replace function cs_api.search_tickets(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  v_term text := btrim(coalesce(p_query, ''));
  v_like text;
begin
  if char_length(v_term) < 2 then
    return '[]'::jsonb;
  end if;
  v_like := '%' || replace(replace(replace(left(v_term, 80), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(cs.ticket_card(t, v_me) order by t.created_at desc)
    from (
      select x.* from cs.tickets x
      join public.profiles p on p.id = x.customer_id
      where cs.can_read_ticket(x.room_id, x.id, x.status, x.flags)
        and (x.ticket_number ilike v_like or p.display_name ilike v_like or p.username::text ilike v_like
             or p.olt_user_id ilike v_like
             or exists (select 1 from public.messages m where m.session_id = x.id and m.body ilike v_like))
      order by x.created_at desc
      limit 30) t), '[]');
end;
$$;

create or replace function cs_api.claim_ticket(p_ticket_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(cs.claim_ticket(p_ticket_id));
$$;

create or replace function cs_api.release_ticket(p_ticket_id uuid, p_reason text, p_version integer default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(cs.release_ticket(p_ticket_id, p_reason, p_version));
$$;

create or replace function cs_api.request_transfer(p_ticket_id uuid, p_to_agent_id uuid, p_note text,
                                                   p_version integer default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select to_jsonb(r) - 'note' from cs.request_transfer(p_ticket_id, p_to_agent_id, p_note, p_version) r;
$$;

create or replace function cs_api.respond_transfer(p_transfer_id uuid, p_accept boolean, p_reason text default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(cs.respond_transfer(p_transfer_id, p_accept, p_reason));
$$;

create or replace function cs_api.cancel_transfer(p_transfer_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select cs.cancel_transfer(p_transfer_id);
$$;

create or replace function cs_api.reassign_ticket(p_ticket_id uuid, p_to_agent_id uuid, p_reason text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(cs.reassign_ticket(p_ticket_id, p_to_agent_id, p_reason));
$$;

create or replace function cs_api.join_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_supervisor}');
  t    cs.tickets := cs.lock_ticket(p_ticket_id, null);
begin
  if t.status not in ('claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Hanya tiket yang sedang ditangani yang bisa digabungi');
  end if;
  insert into public.chat_members (room_id, user_id, role) values (t.room_id, v_me, 'member') on conflict do nothing;
  perform cs.log_event(t.id, 'supervisor_joined', jsonb_build_object('agent_id', v_me));
  perform cs.audit('ticket.join', t.id, t.customer_id);
  perform cs.broadcast_ticket(t, 'ticket_updated', array[v_me]);
  return cs.ticket_agent_view(t);
end;
$$;

create or replace function cs_api.wait_customer(p_ticket_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t    cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version);
begin
  if t.status <> 'claimed' then
    perform private.api_error(409, 'invalid_transition', 'Tiket sudah menunggu balasan nasabah');
  end if;
  t := cs.set_status(t.id, 'waiting_customer', 'waiting_customer');
  perform cs.broadcast_ticket(t, 'ticket_updated');
  return cs.ticket_agent_view(t);
end;
$$;

create or replace function cs_api.resolve_ticket(p_ticket_id uuid, p_outcome text, p_summary text,
                                                 p_tags text[] default '{}', p_version integer default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select cs.ticket_agent_view(cs.resolve_ticket(p_ticket_id, p_outcome, p_summary, p_tags, p_version));
$$;

create or replace function cs_api.set_ticket_priority(p_ticket_id uuid, p_priority text, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t    cs.tickets := cs.lock_ticket(p_ticket_id, p_version);
begin
  if coalesce(p_priority, '') not in ('P1', 'P2', 'P3', 'P4') then
    perform private.api_error(400, 'invalid_priority', 'Prioritas harus P1–P4');
  end if;
  if t.status in ('resolved', 'closed') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket sudah selesai');
  end if;
  if not (t.owner_agent_id = v_me or cs.has_role('{cs_supervisor}')) then
    perform private.api_error(403, 'not_ticket_owner',
      format('Tiket ini ditangani oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
  end if;
  update cs.tickets set priority = p_priority, version = version + 1, updated_at = now()
   where id = t.id returning * into t;
  perform cs.log_event(t.id, 'priority_changed', jsonb_build_object('priority', p_priority));
  perform cs.audit('ticket.priority', t.id, t.customer_id, jsonb_build_object('priority', p_priority));
  perform cs.broadcast_ticket(t, 'ticket_updated');
  return cs.ticket_agent_view(t);
end;
$$;

create or replace function cs_api.flag_ticket(p_ticket_id uuid, p_flag text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t    cs.tickets := cs.owned_ticket(p_ticket_id, v_me, null, true);
begin
  t := cs.flag_ticket(t.id, p_flag);
  perform cs.audit('ticket.flag', t.id, t.customer_id, jsonb_build_object('flag', p_flag));
  return cs.ticket_agent_view(t);
end;
$$;

create or replace function cs_api.agent_send_message(
  p_ticket_id   uuid,
  p_body        text,
  p_client_id   uuid default null,
  p_kind        text default 'text',
  p_payload     jsonb default '{}',
  p_reply_to_id uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t         cs.tickets;
  v_role    text;
  v_body    text := btrim(coalesce(p_body, ''));
  v_payload jsonb := '{}';
  v_url     text;
  v_id      uuid;
begin
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or t.status not in ('claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket tidak sedang ditangani');
  end if;
  if t.owner_agent_id = v_me then
    v_role := 'agent';
  elsif cs.has_role('{cs_supervisor}')
        and exists (select 1 from public.chat_members m where m.room_id = t.room_id and m.user_id = v_me) then
    v_role := 'supervisor';
  else
    perform private.api_error(403, 'not_ticket_owner',
      format('Tiket ini ditangani oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
  end if;
  if char_length(v_body) > 4000 then
    perform private.api_error(400, 'body_too_long', 'Pesan maksimal 4000 karakter');
  end if;
  if p_kind = 'quick_reply' then
    if jsonb_typeof(p_payload -> 'options') <> 'array'
       or jsonb_array_length(p_payload -> 'options') not between 2 and 6
       or exists (select 1 from jsonb_array_elements(p_payload -> 'options') x
                  where jsonb_typeof(x) <> 'string' or char_length(btrim(x #>> '{}')) not between 1 and 40) then
      perform private.api_error(400, 'invalid_options', 'Tombol pilihan berisi 2–6 teks, masing-masing 1–40 karakter');
    end if;
    v_payload := jsonb_build_object('options', p_payload -> 'options');
  elsif p_kind = 'help_link' then
    v_url := p_payload ->> 'url';
    if v_url is null or v_url !~ '^https://[A-Za-z0-9.-]+(/[^\s]*)?$'
       or not (cs.setting('help.allowed_hosts') ? lower(substring(v_url from '^https://([A-Za-z0-9.-]+)'))) then
      perform private.api_error(400, 'invalid_help_link', 'Tautan bantuan harus https ke situs bantuan resmi');
    end if;
    v_payload := jsonb_build_object('url', v_url);
  elsif p_kind = 'card' then
    if coalesce(p_payload ->> 'card', '') not in ('order', 'cash_transaction')
       or coalesce(p_payload ->> 'ref', '') !~ '^[A-Za-z0-9._:-]{1,64}$' then
      perform private.api_error(400, 'invalid_card', 'Kartu harus berisi order atau transaksi dana yang valid');
    end if;
    v_payload := jsonb_build_object('card', p_payload ->> 'card', 'ref', p_payload ->> 'ref');
    v_body := coalesce(nullif(v_body, ''),
                       case p_payload ->> 'card' when 'order' then 'Order ' else 'Transaksi dana ' end || (p_payload ->> 'ref'));
  elsif coalesce(p_kind, '') <> 'text' then
    perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak didukung');
  end if;
  if v_body = '' and (p_kind <> 'text' or jsonb_array_length(coalesce(p_attachments, '[]'::jsonb)) = 0) then
    perform private.api_error(400, 'body_required', 'Isi teks pesan');
  end if;

  if cs.requests_secret(v_body)
     or (p_kind = 'quick_reply' and cs.requests_secret((select string_agg(x #>> '{}', '. ') from jsonb_array_elements(v_payload -> 'options') x))) then
    perform cs.log_event(t.id, 'secret_request_blocked');
    perform cs.audit('message.secret_request_blocked', t.id, t.customer_id,
      jsonb_build_object('excerpt', left((cs.mask_sensitive(v_body)).masked, 200)));
    perform realtime.send(
      jsonb_build_object('event', 'secret_request_blocked', 'ticket_id', t.id, 'ticket_number', t.ticket_number,
                         'agent_id', v_me, 'agent_code', (select a.agent_code from cs.agents a where a.user_id = v_me)),
      'alert', 'cs:queue', true);
    return jsonb_build_object('status', 'blocked', 'code', 'secret_request_blocked',
      'message', 'Pesan ditahan: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.');
  end if;

  insert into public.messages (room_id, sender_id, body, reply_to_id, attachments, client_id, kind, session_id, sender_role, payload)
  values (t.room_id, v_me, v_body, p_reply_to_id, coalesce(p_attachments, '[]'::jsonb), p_client_id,
          p_kind, t.id, v_role, v_payload)
  on conflict (sender_id, client_id) do nothing
  returning id into v_id;
  if v_id is null then
    select m.id into v_id from public.messages m where m.sender_id = v_me and m.client_id = p_client_id;
  end if;
  return jsonb_build_object('status', 'sent',
    'message', (select to_jsonb(m) from private.chat_messages(array[v_id]) m));
end;
$$;

create or replace function cs_api.add_note(p_body text, p_ticket_id uuid default null, p_customer_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  v_customer uuid := p_customer_id;
  v_note     cs.agent_notes;
begin
  if p_ticket_id is not null then
    select t.customer_id into v_customer from cs.tickets t where t.id = p_ticket_id;
  end if;
  if v_customer is null or not cs.can_read_notes(v_customer, p_ticket_id) then
    perform private.api_error(403, 'notes_forbidden', 'Anda tidak berwenang menulis catatan untuk nasabah ini');
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 4000 then
    perform private.api_error(400, 'invalid_note', 'Catatan 1–4000 karakter');
  end if;
  insert into cs.agent_notes (customer_id, session_id, author_id, body)
  values (v_customer, p_ticket_id, v_me, (cs.mask_sensitive(btrim(p_body))).masked)
  returning * into v_note;
  return jsonb_build_object('id', v_note.id, 'customer_id', v_note.customer_id, 'ticket_id', v_note.session_id,
                            'kind', v_note.kind, 'body', v_note.body, 'created_at', v_note.created_at);
end;
$$;

create or replace function cs_api.ticket_detail(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  perform cs.require_agent();
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return cs.ticket_agent_view(t) || jsonb_build_object(
    'tags', to_jsonb(t.tags),
    'events', coalesce((select jsonb_agg(jsonb_build_object('type', e.type, 'actor_type', e.actor_type,
                                                            'actor_name', cs.agent_name(e.actor_id),
                                                            'data', e.data, 'created_at', e.created_at)
                                         order by e.created_at, e.id)
                        from cs.session_events e where e.session_id = t.id), '[]'));
end;
$$;

create or replace function cs_api.customer_history(p_customer_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  perform cs.require_agent();
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', t.id, 'ticket_number', t.ticket_number, 'topic', t.topic, 'status', t.status,
             'flags', to_jsonb(t.flags), 'created_at', t.created_at, 'resolved_at', t.resolved_at,
             'closed_at', t.closed_at, 'outcome', t.outcome, 'rating', t.rating, 'agent', a.display_name)
           order by t.created_at desc), '[]')
    from cs.tickets t
    left join cs.agents a on a.user_id = coalesce(t.owner_agent_id, t.last_owner_id)
    where t.customer_id = p_customer_id);
end;
$$;

create or replace function cs_api.online_agents()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  v_sup boolean := cs.has_role('{cs_supervisor}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code, 'roles', to_jsonb(a.roles),
             'status', st.status, 'active_tickets', cs.active_ticket_count(a.user_id),
             'max_active_tickets', a.max_active_tickets, 'can_take', cs.can_take_tickets(a.user_id),
             'last_heartbeat_at', st.last_heartbeat_at)
           order by (st.status = 'online') desc, a.display_name)
    from cs.agents a join cs.agent_status st on st.agent_id = a.user_id
    where a.disabled_at is null and a.roles && '{cs_agent,cs_supervisor}' and a.user_id <> v_me
      and (v_sup or st.status = 'online')), '[]');
end;
$$;

create or replace function cs_api.room_members(p_room_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', m.user_id, 'display_name', p.display_name, 'username', p.username, 'role', m.role,
           'is_staff', cs.is_staff(m.user_id), 'last_read_at', m.last_read_at, 'last_delivered_at', m.last_delivered_at,
           'joined_at', m.joined_at) order by m.joined_at), '[]')
  from public.chat_members m
  join public.profiles p on p.id = m.user_id
  where m.room_id = p_room_id and cs.require_agent() is not null;
$$;

create or replace function cs_api.agent_customer_access(p_ticket_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets := cs.customer_data_ticket(p_ticket_id);
begin
  if coalesce(p_kind, '') not in ('profile', 'orders', 'order', 'cash_transactions', 'cash_transaction', 'sessions', 'security') then
    perform private.api_error(400, 'invalid_kind', 'Jenis data nasabah tidak dikenal');
  end if;
  if p_kind = 'profile' then
    perform cs.check_hourly('customer_data.profile', 'customer_data.profile_views_per_hour');
  end if;
  perform cs.audit('customer_data.' || p_kind, t.id, t.customer_id);
  return jsonb_build_object(
    'customer_id', t.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = t.customer_id),
    'correlation_id', t.ticket_number || '/' || coalesce((select a.agent_code from cs.agents a where a.user_id = auth.uid()), 'service'));
end;
$$;

create or replace function cs_api.agent_reveal_access(p_ticket_id uuid, p_field text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets := cs.customer_data_ticket(p_ticket_id);
begin
  if coalesce(p_field, '') not in ('nik', 'phone', 'email', 'client_code', 'sid', 'address', 'birth_date', 'rdn_number', 'bank_account') then
    perform private.api_error(400, 'invalid_field', 'Field tidak bisa dibuka');
  end if;
  if cs.setting('customer_data.reveal_reasons') -> p_reason is null then
    perform private.api_error(400, 'invalid_reason', 'Alasan membuka data tidak ada dalam daftar');
  end if;
  perform cs.check_hourly('customer_data.reveal', 'customer_data.reveals_per_hour');
  perform cs.audit('customer_data.reveal', t.id, t.customer_id, jsonb_build_object('field', p_field, 'reason', p_reason));
  return jsonb_build_object(
    'customer_id', t.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = t.customer_id),
    'correlation_id', t.ticket_number || '/' || coalesce((select a.agent_code from cs.agents a where a.user_id = auth.uid()), 'service'),
    'valid_seconds', 300);
end;
$$;

create or replace function cs_api.agent_secure_account(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t    cs.tickets := cs.owned_ticket(p_ticket_id, v_me, null, true);
begin
  perform cs.log_event(t.id, 'secure_account_requested');
  perform cs.audit('secure_account.requested', t.id, t.customer_id,
    jsonb_build_object('actions', cs.setting('secure_account.actions')));
  return jsonb_build_object(
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = t.customer_id),
    'actions', cs.setting('secure_account.actions'),
    'idempotency_key', 'cs-secure:' || t.id::text,
    'correlation_id', t.ticket_number || '/' || coalesce((select a.agent_code from cs.agents a where a.user_id = v_me), 'service'));
end;
$$;

create or replace function cs_api.agent_secure_account_result(p_ticket_id uuid, p_ok boolean, p_results jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t    cs.tickets := cs.owned_ticket(p_ticket_id, v_me, null, true);
begin
  if p_ok is null or jsonb_typeof(coalesce(p_results, '{}')) <> 'object' then
    perform private.api_error(400, 'invalid_result', 'Hasil amankan akun tidak valid');
  end if;
  perform cs.log_event(t.id, case when p_ok then 'secure_account_done' else 'secure_account_failed' end,
                       jsonb_build_object('results', p_results));
  perform cs.audit('secure_account.result', t.id, t.customer_id, jsonb_build_object('ok', p_ok, 'results', p_results));
  if p_ok then
    perform cs.system_message(t, 'secured');
  end if;
end;
$$;

revoke execute on all functions in schema cs from public;
revoke execute on all functions in schema cs_api from public;
grant execute on all functions in schema cs_api to authenticated;
