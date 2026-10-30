create or replace function cs.customer_view(s cs.support_sessions)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', s.id,
    'room_id', s.room_id,
    'topic', s.topic,
    'status', s.status,
    'waiting', s.status in ('queued', 'offered', 'transferring', 'reopened'),
    'queue_position', case when s.status in ('queued', 'offered', 'transferring', 'reopened') then (
      select count(*)::integer + 1 from cs.support_sessions w
      where w.status in ('queued', 'transferring', 'reopened') and w.id <> s.id
        and (w.priority, w.queued_at) < (s.priority, s.queued_at)) end,
    'agent', case when s.status = 'active' then (
      select jsonb_build_object('display_name', a.display_name, 'agent_code', a.agent_code)
      from cs.agents a where a.user_id = s.current_agent_id) end,
    'complaint', case when s.complaint_received_at is not null then
      jsonb_build_object('received_at', s.complaint_received_at, 'due_at', s.complaint_due_at) end,
    'queued_at', s.queued_at,
    'closed_at', s.closed_at,
    'rating', s.rating,
    'can_rate', s.status = 'closed' and s.accepted_at is not null and s.rating is null
  );
$$;

create or replace function cs.agent_view(s cs.support_sessions)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', s.id,
    'room_id', s.room_id,
    'status', s.status,
    'topic', s.topic,
    'priority', s.priority,
    'flags', s.flags,
    'language', s.language,
    'customer', (select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username)
                 from public.profiles p where p.id = s.customer_id),
    'context', s.context,
    'queued_at', s.queued_at,
    'accepted_at', s.accepted_at,
    'first_response_at', s.first_response_at,
    'last_customer_message_at', s.last_customer_message_at,
    'last_agent_message_at', s.last_agent_message_at,
    'transfer_count', s.transfer_count,
    'complaint_received_at', s.complaint_received_at,
    'complaint_due_at', s.complaint_due_at,
    'closed_at', s.closed_at,
    'close_outcome', s.close_outcome,
    'rating', s.rating
  );
$$;

create or replace function cs.handled_session(p_session_id uuid, p_agent uuid)
returns cs.support_sessions
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = p_session_id;
  if not found or not ((s.status = 'active' and s.current_agent_id = p_agent) or cs.has_role('{cs_supervisor}')) then
    perform private.api_error(403, 'not_handling', 'Anda tidak sedang menangani sesi ini');
  end if;
  return s;
end;
$$;

create or replace function cs.customer_data_session(p_session_id uuid)
returns cs.support_sessions
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor,compliance}');
  s    cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = p_session_id;
  if not found or not (
    (s.status = 'active' and s.current_agent_id = v_me)
    or cs.has_role('{cs_supervisor}')
    or (cs.has_role('{compliance}') and s.flags && '{complaint,fraud}')
  ) then
    perform private.api_error(403, 'customer_data_forbidden', 'Anda tidak berwenang membuka data nasabah untuk sesi ini');
  end if;
  return s;
end;
$$;

create or replace function cs.check_hourly(p_action text, p_setting text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := cs.setting_int(p_setting);
begin
  if (select count(*) from cs.cs_audit_log a
      where a.actor_id = auth.uid() and a.action = p_action and a.created_at > now() - interval '1 hour') >= v_limit then
    perform private.raise_rate_limited(p_action, v_limit, 3600, 300);
  end if;
end;
$$;

create or replace function cs.correlation_id(s cs.support_sessions)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select s.id::text || '/' || coalesce((select a.agent_code from cs.agents a where a.user_id = auth.uid()), 'service');
$$;

create or replace function cs_api.topics(p_language text default 'id')
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', t.code,
           'name', case when p_language = 'en' then t.name_en else t.name_id end,
           'help_url', t.help_url,
           'urgent', t.default_priority = 'P1')
         order by t.sort_order, t.code), '[]')
  from cs.support_topics t
  where t.active;
$$;

create or replace function cs_api.start_session(p_topic text, p_language text default 'id', p_screen text default null,
                                                p_complaint boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  s    cs.support_sessions;
begin
  if coalesce(p_language, '') not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if p_screen is not null and p_screen !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_screen', 'Asal layar tidak valid');
  end if;
  s := cs.open_session(v_me, p_topic, p_language,
                       case when p_complaint then array['complaint'] else array[]::text[] end,
                       case when p_screen is null then '{}'::jsonb else jsonb_build_object('screen', p_screen) end,
                       null);
  if p_complaint and not ('complaint' = any (s.flags)) then
    s := cs.flag_session(s.id, 'complaint');
  end if;
  return cs.customer_view(s);
end;
$$;

create or replace function cs_api.my_support()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_customer();
  v_room uuid;
  s      cs.support_sessions;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = v_me;
  select * into s from cs.support_sessions where customer_id = v_me order by created_at desc limit 1;
  return jsonb_build_object(
    'room_id', v_room,
    'session', case when s.id is not null then cs.customer_view(s) end,
    'service_open', cs.is_open(now()),
    'next_open_at', case when not cs.is_open(now()) then cs.next_open_at(now()) end);
end;
$$;

create or replace function cs_api.send_message(
  p_room_id     uuid,
  p_body        text,
  p_client_id   uuid default null,
  p_reply_to_id uuid default null,
  p_attachments jsonb default '[]'::jsonb
)
returns setof public.chat_message
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support' and r.customer_id = v_me) then
    perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
  end if;
  return query select * from public.send_message(p_room_id, p_body, p_client_id, p_reply_to_id, p_attachments);
end;
$$;

create or replace function cs_api.send_card(p_room_id uuid, p_card text, p_ref text, p_client_id uuid default null)
returns setof public.chat_message
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  v_id uuid;
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support' and r.customer_id = v_me) then
    perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
  end if;
  if coalesce(p_card, '') not in ('order', 'cash_transaction') or coalesce(p_ref, '') !~ '^[A-Za-z0-9._:-]{1,64}$' then
    perform private.api_error(400, 'invalid_card', 'Kartu harus berisi order atau transaksi dana yang valid');
  end if;
  insert into public.messages (room_id, sender_id, body, kind, payload, client_id)
  values (p_room_id, v_me,
          case p_card when 'order' then 'Order ' else 'Transaksi dana ' end || p_ref,
          'card', jsonb_build_object('card', p_card, 'ref', p_ref), p_client_id)
  on conflict (sender_id, client_id) do nothing
  returning id into v_id;
  if v_id is null then
    select m.id into v_id from public.messages m where m.sender_id = v_me and m.client_id = p_client_id;
  end if;
  return query select * from private.chat_messages(array[v_id]);
end;
$$;

create or replace function cs_api.get_messages(
  p_room_id uuid,
  p_cursor  text default null,
  p_limit   integer default 30,
  p_after   text default null
)
returns setof public.chat_message
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  v_ts    timestamptz;
  v_id    uuid;
  v_ids   uuid[];
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
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

create or replace function cs_api.mark_read(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support') then
    perform private.api_error(404, 'room_not_found', 'Chat CS tidak ditemukan');
  end if;
  perform public.mark_room_read(p_room_id);
end;
$$;

create or replace function cs_api.end_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  s    cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = p_session_id and customer_id = v_me;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  s := cs.close_session(s.id, 'customer_ended', '{}', v_me);
  return cs.customer_view(s);
end;
$$;

create or replace function cs_api.rate_session(p_session_id uuid, p_rating integer, p_comment text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  s    cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = p_session_id and customer_id = v_me for update;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  if not (s.status = 'closed' and s.accepted_at is not null and s.rating is null) then
    perform private.api_error(409, 'cannot_rate', 'Sesi ini tidak bisa diberi nilai');
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    perform private.api_error(400, 'invalid_rating', 'Nilai harus 1 sampai 5');
  end if;
  if char_length(coalesce(p_comment, '')) > 500 then
    perform private.api_error(400, 'comment_too_long', 'Komentar maksimal 500 karakter');
  end if;
  update cs.support_sessions
     set rating = p_rating,
         rating_comment = nullif(btrim((cs.mask_sensitive(coalesce(p_comment, ''))).masked), ''),
         rated_at = now(), updated_at = now()
   where id = s.id
  returning * into s;
  perform cs.log_event(s.id, 'rated', jsonb_build_object('rating', p_rating));
  return cs.customer_view(s);
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
  s    cs.support_sessions;
begin
  select * into s from cs.support_sessions where customer_id = v_me and status <> 'closed';
  if found then
    s := cs.flag_session(s.id, 'complaint');
  else
    s := cs.open_session(v_me, cs.setting('session.default_topic') #>> '{}', 'id', array['complaint'], '{}', null);
  end if;
  perform cs.audit('session.complaint_requested', s.id, v_me);
  return cs.customer_view(s);
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
  s      cs.support_sessions;
begin
  if char_length(v_text) not between 5 and 2000 then
    perform private.api_error(400, 'invalid_description', 'Ceritakan kejadiannya (5–2000 karakter)');
  end if;
  select * into s from cs.support_sessions where customer_id = v_me and status <> 'closed';
  if found then
    s := cs.flag_session(s.id, 'fraud');
  else
    s := cs.open_session(v_me, 'fraud', 'id', array['fraud'], jsonb_build_object('report', 'fake_cs'), null);
  end if;
  insert into public.messages (room_id, sender_id, body, session_id)
  values (s.room_id, v_me, 'Laporan CS palsu: ' || v_text, s.id);
  perform cs.log_event(s.id, 'fake_cs_reported');
  perform cs.audit('session.fake_cs_reported', s.id, v_me);
  perform realtime.send(jsonb_build_object('kind', 'fake_cs_reported', 'session_id', s.id, 'priority', s.priority),
                        'alert', 'cs:queue', true);
  select * into s from cs.support_sessions where id = s.id;
  return cs.customer_view(s);
end;
$$;

create or replace function cs_api.check_sensitive(p_text text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'masked', cardinality(m.kinds) > 0,
    'kinds', to_jsonb(m.kinds),
    'preview', m.masked,
    'requests_secret', cs.requests_secret(p_text))
  from cs.mask_sensitive(left(coalesce(p_text, ''), 4000)) m;
$$;

create or replace function cs_api.customer_data_access(p_kind text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
begin
  if coalesce(p_kind, '') not in ('orders', 'order', 'cash_transactions') then
    perform private.api_error(400, 'invalid_kind', 'Jenis data tidak dikenal');
  end if;
  return jsonb_build_object(
    'customer_id', v_me,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = v_me));
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
      'team', t.code,
      'languages', to_jsonb(a.languages),
      'max_concurrent', a.max_concurrent,
      'status', st.status,
      'reason', st.reason,
      'active_sessions', st.active_sessions,
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams t on t.id = a.team_id
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
  v_id  uuid;
begin
  if coalesce(p_status, '') not in ('online', 'busy', 'break', 'offline') then
    perform private.api_error(400, 'invalid_status', 'Status harus online, busy, break, atau offline');
  end if;
  if char_length(coalesce(p_reason, '')) > 120 then
    perform private.api_error(400, 'reason_too_long', 'Alasan maksimal 120 karakter');
  end if;
  select status into v_old from cs.agent_status where agent_id = v_me for update;
  if p_status = 'offline' then
    perform cs.release_agent(v_me, 'offline', coalesce(nullif(btrim(p_reason), ''), 'Keluar'));
  else
    if p_status <> 'online' then
      for v_id in select o.id from cs.match_offers o where o.agent_id = v_me and o.result is null loop
        perform cs.close_offer(v_id, 'cancelled', 'Agen ' || p_status);
      end loop;
    end if;
    update cs.agent_status
       set status = p_status,
           reason = nullif(btrim(p_reason), ''),
           consecutive_timeouts = case when p_status = 'online' then 0 else consecutive_timeouts end,
           last_heartbeat_at = now(),
           status_changed_at = case when status <> p_status then now() else status_changed_at end
     where agent_id = v_me;
  end if;
  perform cs.audit('agent.status', null, null, jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason));
  perform realtime.send(jsonb_build_object('agent_id', v_me, 'status', p_status), 'agent_status', 'cs:queue', true);
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
  return jsonb_build_object('status', st.status, 'active_sessions', st.active_sessions,
                            'max_concurrent', (select a.max_concurrent from cs.agents a where a.user_id = v_me));
end;
$$;

create or replace function cs_api.agent_inbox()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent();
  v_today timestamptz := (cs.local_date(now())::timestamp at time zone 'Asia/Jakarta');
begin
  return jsonb_build_object(
    'active', coalesce((
      select jsonb_agg(cs.agent_view(s) || jsonb_build_object(
               'unread_count', (select count(*)::integer from public.messages m
                                join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = v_me
                                where m.room_id = s.room_id and m.sender_role = 'customer'
                                  and m.created_at > cm.last_read_at),
               'waiting_since', case when s.last_customer_message_at > coalesce(s.last_agent_message_at, '-infinity')
                                     then s.last_customer_message_at end)
             order by s.accepted_at)
      from cs.support_sessions s
      where s.current_agent_id = v_me and s.status = 'active'), '[]'),
    'offers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'offer_id', o.id,
               'expires_at', o.expires_at,
               'session', cs.agent_view(s),
               'preview', (select private.snippet(m.body, 160) from public.messages m
                           where m.session_id = s.id and m.sender_role = 'customer'
                           order by m.created_at desc limit 1))
             order by o.expires_at)
      from cs.match_offers o
      join cs.support_sessions s on s.id = o.session_id
      where o.agent_id = v_me and o.result is null), '[]'),
    'closed_today', coalesce((
      select jsonb_agg(cs.agent_view(s) order by s.closed_at desc)
      from cs.support_sessions s
      where s.last_agent_id = v_me and s.status = 'closed' and s.closed_at >= v_today), '[]'));
end;
$$;

create or replace function cs_api.accept_offer(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  o    cs.match_offers;
  s    cs.support_sessions;
begin
  select * into o from cs.match_offers where id = p_offer_id for update;
  if not found or o.agent_id <> v_me then
    perform private.api_error(404, 'offer_not_found', 'Penawaran tidak ditemukan');
  end if;
  if o.result is not null then
    perform private.api_error(409, 'offer_closed', 'Penawaran sudah tidak berlaku');
  end if;
  if o.expires_at <= now() then
    perform private.api_error(409, 'offer_expired', 'Waktu menerima penawaran sudah habis');
  end if;
  update cs.match_offers set result = 'accepted', responded_at = now() where id = o.id;
  s := cs.assign(o.session_id, v_me, 'accepted');
  perform cs.audit('session.accept', s.id, s.customer_id, jsonb_build_object('offer_id', o.id));
  return cs.agent_view(s);
end;
$$;

create or replace function cs_api.reject_offer(p_offer_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
  o    cs.match_offers;
begin
  select * into o from cs.match_offers where id = p_offer_id and agent_id = v_me;
  if not found then
    perform private.api_error(404, 'offer_not_found', 'Penawaran tidak ditemukan');
  end if;
  perform cs.close_offer(o.id, 'rejected', p_reason);
  perform cs.audit('session.reject', o.session_id, null, jsonb_build_object('offer_id', o.id, 'reason', p_reason));
end;
$$;

create or replace function cs_api.agent_send_message(
  p_session_id  uuid,
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
  s         cs.support_sessions;
  v_body    text := btrim(coalesce(p_body, ''));
  v_payload jsonb := '{}';
  v_url     text;
  v_id      uuid;
begin
  select * into s from cs.support_sessions where id = p_session_id;
  if not found or s.status <> 'active' or s.current_agent_id <> v_me then
    perform private.api_error(403, 'not_handling', 'Anda tidak sedang menangani sesi ini');
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
    perform cs.log_event(s.id, 'secret_request_blocked');
    perform cs.audit('message.secret_request_blocked', s.id, s.customer_id,
      jsonb_build_object('excerpt', left((cs.mask_sensitive(v_body)).masked, 200)));
    perform realtime.send(
      jsonb_build_object('kind', 'secret_request_blocked', 'session_id', s.id, 'agent_id', v_me,
                         'agent_code', (select a.agent_code from cs.agents a where a.user_id = v_me)),
      'alert', 'cs:queue', true);
    return jsonb_build_object('status', 'blocked', 'code', 'secret_request_blocked',
      'message', 'Pesan diblokir: CS tidak boleh meminta OTP, PIN, atau password. Supervisor sudah diberi tahu.');
  end if;

  insert into public.messages (room_id, sender_id, body, reply_to_id, attachments, client_id, kind, session_id, sender_role, payload)
  values (s.room_id, v_me, v_body, p_reply_to_id, coalesce(p_attachments, '[]'::jsonb), p_client_id,
          p_kind, s.id, 'agent', v_payload)
  on conflict (sender_id, client_id) do nothing
  returning id into v_id;
  if v_id is null then
    select m.id into v_id from public.messages m where m.sender_id = v_me and m.client_id = p_client_id;
  end if;
  return jsonb_build_object('status', 'sent',
    'message', (select to_jsonb(m) from private.chat_messages(array[v_id]) m));
end;
$$;

create or replace function cs_api.close_session(p_session_id uuid, p_outcome text, p_tags text[] default '{}',
                                                p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  s    cs.support_sessions := cs.handled_session(p_session_id, v_me);
begin
  if cardinality(coalesce(p_tags, '{}')) > 10
     or exists (select 1 from unnest(coalesce(p_tags, '{}')) t where t !~ '^[a-z0-9_-]{1,32}$') then
    perform private.api_error(400, 'invalid_tags', 'Maksimal 10 tag, huruf kecil/angka/-/_');
  end if;
  if coalesce(btrim(p_note), '') <> '' then
    insert into cs.agent_notes (customer_id, session_id, author_id, body)
    values (s.customer_id, s.id, v_me, (cs.mask_sensitive(btrim(p_note))).masked);
  end if;
  s := cs.close_session(s.id, p_outcome, p_tags, v_me);
  perform cs.audit('session.close', s.id, s.customer_id, jsonb_build_object('outcome', p_outcome, 'tags', p_tags));
  return cs.agent_view(s);
end;
$$;

create or replace function cs_api.transfer_session(p_session_id uuid, p_note text, p_team text default null,
                                                   p_topic text default null, p_agent_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  s    cs.support_sessions := cs.handled_session(p_session_id, v_me);
begin
  s := cs.transfer_session(s.id, p_team, p_topic, p_agent_id, p_note, v_me);
  perform cs.audit('session.transfer', s.id, s.customer_id,
    jsonb_build_object('team', p_team, 'topic', p_topic, 'agent_id', p_agent_id));
  return cs.agent_view(s);
end;
$$;

create or replace function cs_api.flag_session(p_session_id uuid, p_flag text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  s    cs.support_sessions := cs.handled_session(p_session_id, v_me);
begin
  s := cs.flag_session(s.id, p_flag);
  perform cs.audit('session.flag', s.id, s.customer_id, jsonb_build_object('flag', p_flag));
  return cs.agent_view(s);
end;
$$;

create or replace function cs_api.add_note(p_body text, p_session_id uuid default null, p_customer_id uuid default null)
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
  if p_session_id is not null then
    select s.customer_id into v_customer from cs.support_sessions s where s.id = p_session_id;
  end if;
  if v_customer is null or not cs.can_read_notes(v_customer, p_session_id) then
    perform private.api_error(403, 'notes_forbidden', 'Anda tidak berwenang menulis catatan untuk nasabah ini');
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 4000 then
    perform private.api_error(400, 'invalid_note', 'Catatan 1–4000 karakter');
  end if;
  insert into cs.agent_notes (customer_id, session_id, author_id, body)
  values (v_customer, p_session_id, v_me, (cs.mask_sensitive(btrim(p_body))).masked)
  returning * into v_note;
  return jsonb_build_object('id', v_note.id, 'customer_id', v_note.customer_id, 'session_id', v_note.session_id,
                            'kind', v_note.kind, 'body', v_note.body, 'created_at', v_note.created_at);
end;
$$;

create or replace function cs_api.notes(p_customer_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  perform cs.require_agent();
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', n.id, 'session_id', n.session_id, 'kind', n.kind, 'body', n.body, 'created_at', n.created_at,
             'author', case when a.user_id is not null
                            then jsonb_build_object('display_name', a.display_name, 'agent_code', a.agent_code) end)
           order by n.created_at desc), '[]')
    from cs.agent_notes n
    left join cs.agents a on a.user_id = n.author_id
    where n.customer_id = p_customer_id);
end;
$$;

create or replace function cs_api.session_detail(p_session_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  perform cs.require_agent();
  select * into s from cs.support_sessions where id = p_session_id;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  return cs.agent_view(s) || jsonb_build_object(
    'tags', to_jsonb(s.tags),
    'rating_comment', s.rating_comment,
    'events', coalesce((select jsonb_agg(jsonb_build_object('type', e.type, 'actor_type', e.actor_type,
                                                            'data', e.data, 'created_at', e.created_at)
                                         order by e.created_at, e.id)
                        from cs.session_events e where e.session_id = s.id), '[]'));
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
             'id', s.id, 'topic', s.topic, 'status', s.status, 'flags', to_jsonb(s.flags),
             'created_at', s.created_at, 'closed_at', s.closed_at, 'close_outcome', s.close_outcome,
             'rating', s.rating, 'agent', a.display_name)
           order by s.created_at desc), '[]')
    from cs.support_sessions s
    left join cs.agents a on a.user_id = s.last_agent_id
    where s.customer_id = p_customer_id);
end;
$$;

create or replace function cs_api.quick_replies(p_language text default 'id')
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  perform cs.require_agent();
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', q.id, 'scope', q.scope, 'shortcut', q.shortcut, 'title', q.title, 'body', q.body)
           order by q.shortcut, q.scope), '[]')
    from cs.quick_replies q
    where q.active and q.language = coalesce(p_language, 'id'));
end;
$$;

create or replace function cs_api.agent_customer_access(p_session_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions := cs.customer_data_session(p_session_id);
begin
  if coalesce(p_kind, '') not in ('profile', 'orders', 'order', 'cash_transactions', 'cash_transaction', 'sessions', 'security') then
    perform private.api_error(400, 'invalid_kind', 'Jenis data nasabah tidak dikenal');
  end if;
  if p_kind = 'profile' then
    perform cs.check_hourly('customer_data.profile', 'customer_data.profile_views_per_hour');
  end if;
  perform cs.audit('customer_data.' || p_kind, s.id, s.customer_id);
  return jsonb_build_object(
    'customer_id', s.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = s.customer_id),
    'correlation_id', cs.correlation_id(s));
end;
$$;

create or replace function cs_api.agent_reveal_access(p_session_id uuid, p_field text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions := cs.customer_data_session(p_session_id);
begin
  if coalesce(p_field, '') not in ('nik', 'phone', 'email', 'client_code', 'sid', 'address', 'birth_date', 'rdn_number', 'bank_account') then
    perform private.api_error(400, 'invalid_field', 'Field tidak bisa dibuka');
  end if;
  if cs.setting('customer_data.reveal_reasons') -> p_reason is null then
    perform private.api_error(400, 'invalid_reason', 'Alasan membuka data tidak ada dalam daftar');
  end if;
  perform cs.check_hourly('customer_data.reveal', 'customer_data.reveals_per_hour');
  perform cs.audit('customer_data.reveal', s.id, s.customer_id, jsonb_build_object('field', p_field, 'reason', p_reason));
  return jsonb_build_object(
    'customer_id', s.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = s.customer_id),
    'correlation_id', cs.correlation_id(s),
    'valid_seconds', 300);
end;
$$;

create or replace function cs_api.agent_secure_account(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  s    cs.support_sessions := cs.handled_session(p_session_id, v_me);
begin
  perform cs.log_event(s.id, 'secure_account_requested');
  perform cs.audit('secure_account.requested', s.id, s.customer_id,
    jsonb_build_object('actions', cs.setting('secure_account.actions')));
  return jsonb_build_object(
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = s.customer_id),
    'actions', cs.setting('secure_account.actions'),
    'idempotency_key', 'cs-secure:' || s.id::text,
    'correlation_id', cs.correlation_id(s));
end;
$$;

create or replace function cs_api.agent_secure_account_result(p_session_id uuid, p_ok boolean, p_results jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  s    cs.support_sessions := cs.handled_session(p_session_id, v_me);
begin
  if p_ok is null or jsonb_typeof(coalesce(p_results, '{}')) <> 'object' then
    perform private.api_error(400, 'invalid_result', 'Hasil amankan akun tidak valid');
  end if;
  perform cs.log_event(s.id, case when p_ok then 'secure_account_done' else 'secure_account_failed' end,
                       jsonb_build_object('results', p_results));
  perform cs.audit('secure_account.result', s.id, s.customer_id, jsonb_build_object('ok', p_ok, 'results', p_results));
  if p_ok then
    perform cs.system_message(s, 'secured');
  end if;
end;
$$;

revoke execute on all functions in schema cs from public;
revoke execute on all functions in schema cs_api from public;
grant execute on all functions in schema cs_api to authenticated;
grant execute on function cs.require_agent(text[]), cs.require_customer(), cs.current_customer_id() to authenticated;
