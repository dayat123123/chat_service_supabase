drop function cs_api.join_ticket(uuid);

delete from public.chat_members m
 using public.chat_rooms r, cs.agents a
 where r.id = m.room_id and r.type = 'support' and a.user_id = m.user_id and not ('cs_agent' = any (a.roles));

create or replace function cs.can_take_tickets(p_agent uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from cs.agents a join cs.agent_status st on st.agent_id = a.user_id
    where a.user_id = p_agent and a.disabled_at is null and 'cs_agent' = any (a.roles)
      and st.status = 'online' and cs.active_ticket_count(p_agent) < a.max_active_tickets
  );
$$;

create or replace function cs.claim_ticket(p_ticket_id uuid)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_agent}');
  v_agent cs.agents;
  v_state cs.agent_status;
  v_count integer;
  t       cs.tickets;
begin
  select * into v_state from cs.agent_status where agent_id = v_me for update;
  select * into v_agent from cs.agents where user_id = v_me;
  if v_state.status <> 'online' then
    perform private.api_error(409, 'agent_not_online', 'Ubah status Anda ke Online untuk mengambil tiket');
  end if;
  v_count := cs.active_ticket_count(v_me);
  if v_count >= v_agent.max_active_tickets then
    perform private.api_error(409, 'ticket_limit',
      format('Batas tiket aktif Anda sudah penuh (%s/%s)', v_count, v_agent.max_active_tickets));
  end if;

  update cs.tickets
     set status = 'claimed', owner_agent_id = v_me, last_owner_id = v_me,
         claimed_at = now(), first_claimed_at = coalesce(first_claimed_at, now()),
         returned_reason = null, version = version + 1, updated_at = now()
   where id = p_ticket_id and status = 'open' and owner_agent_id is null
  returning * into t;

  if not found then
    select * into t from cs.tickets where id = p_ticket_id;
    if not found then
      perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
    end if;
    if t.owner_agent_id is not null then
      perform private.api_error(409, 'ticket_taken',
        format('Tiket sudah diambil oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
    end if;
    perform private.api_error(409, 'ticket_not_open', 'Tiket ini tidak lagi terbuka');
  end if;

  perform cs.log_event(t.id, 'claimed', jsonb_build_object('status', 'claimed', 'agent_id', v_me));
  perform cs.audit('ticket.claim', t.id, t.customer_id);
  perform cs.after_owner_change(t, null, 'ticket_claimed', 'ticket_claimed');
  return t;
end;
$$;

create or replace function cs.release_ticket(p_ticket_id uuid, p_reason text, p_version integer)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent}');
  t      cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version);
  v_text text := btrim(coalesce(p_reason, ''));
begin
  if char_length(v_text) not between 3 and 300 then
    perform private.api_error(400, 'reason_required', 'Tulis alasan melepas tiket (3–300 karakter)');
  end if;
  perform cs.cancel_transfers(t.id, 'Tiket dilepas ke antrean');
  t := cs.set_status(t.id, 'open', 'released', jsonb_build_object('reason', v_text, 'agent_id', v_me));
  update cs.tickets set returned_reason = v_text where id = t.id returning * into t;
  perform cs.audit('ticket.release', t.id, t.customer_id, jsonb_build_object('reason', v_text));
  perform cs.after_owner_change(t, v_me, 'ticket_released', 'ticket_released');
  return t;
end;
$$;

create or replace function cs.request_transfer(p_ticket_id uuid, p_to uuid, p_note text, p_version integer)
returns cs.ticket_transfers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent}');
  t      cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version);
  v_note text := btrim(coalesce(p_note, ''));
  r      cs.ticket_transfers;
begin
  if p_to is null or p_to = v_me then
    perform private.api_error(400, 'invalid_target', 'Pilih CS tujuan yang lain');
  end if;
  if char_length(v_note) not between 3 and 1000 then
    perform private.api_error(400, 'handover_note_required', 'Tulis catatan serah terima (3–1000 karakter)');
  end if;
  if not cs.can_take_tickets(p_to) then
    perform private.api_error(409, 'agent_unavailable', 'CS tujuan tidak Online atau batas tiketnya penuh');
  end if;
  if exists (select 1 from cs.ticket_transfers x where x.ticket_id = t.id and x.result is null) then
    perform private.api_error(409, 'transfer_pending', 'Masih ada permintaan transfer yang menunggu jawaban');
  end if;
  insert into cs.ticket_transfers (ticket_id, from_agent_id, to_agent_id, note, expires_at)
  values (t.id, v_me, p_to, (cs.mask_sensitive(v_note)).masked,
          now() + make_interval(mins => cs.setting_int('transfer.expire_minutes')))
  returning * into r;
  perform cs.log_event(t.id, 'transfer_requested', jsonb_build_object('from', v_me, 'to', p_to));
  perform cs.audit('ticket.transfer_request', t.id, t.customer_id, jsonb_build_object('to', p_to));
  perform realtime.send(jsonb_build_object('event', 'transfer_requested', 'transfer_id', r.id, 'ticket_id', t.id,
                                           'ticket_number', t.ticket_number, 'from_name', cs.agent_name(v_me)),
                        'transfer', 'cs:agent:' || p_to::text, true);
  return r;
end;
$$;

create or replace function cs.respond_transfer(p_transfer_id uuid, p_accept boolean, p_reason text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent}');
  r    cs.ticket_transfers;
  t    cs.tickets;
begin
  select * into r from cs.ticket_transfers where id = p_transfer_id for update;
  if not found or r.to_agent_id <> v_me then
    perform private.api_error(404, 'transfer_not_found', 'Permintaan transfer tidak ditemukan');
  end if;
  if r.result is not null then
    perform private.api_error(409, 'transfer_closed', 'Permintaan transfer sudah tidak berlaku');
  end if;
  select * into t from cs.tickets where id = r.ticket_id for update;
  if r.expires_at <= now() or t.status not in ('claimed', 'waiting_customer') or t.owner_agent_id <> r.from_agent_id then
    update cs.ticket_transfers set result = 'expired', responded_at = now() where id = r.id;
    perform private.api_error(409, 'transfer_closed', 'Permintaan transfer sudah tidak berlaku');
  end if;
  if not coalesce(p_accept, false) then
    update cs.ticket_transfers set result = 'rejected', responded_at = now(), reason = left(btrim(p_reason), 300)
     where id = r.id;
    perform cs.log_event(t.id, 'transfer_rejected', jsonb_build_object('to', v_me, 'reason', p_reason));
    perform realtime.send(jsonb_build_object('event', 'transfer_rejected', 'transfer_id', r.id, 'ticket_id', t.id,
                                             'by_name', cs.agent_name(v_me), 'reason', p_reason),
                          'transfer', 'cs:agent:' || r.from_agent_id::text, true);
    return t;
  end if;
  perform cs.require_capacity(v_me, 'Anda harus Online dan masih punya slot tiket untuk menerima transfer');
  update cs.ticket_transfers set result = 'accepted', responded_at = now() where id = r.id;
  insert into cs.agent_notes (customer_id, session_id, author_id, kind, body)
  values (t.customer_id, t.id, r.from_agent_id, 'handover', r.note);
  t := cs.change_owner(t.id, v_me, 'transferred', jsonb_build_object('from', r.from_agent_id, 'to', v_me));
  perform cs.audit('ticket.transfer_accept', t.id, t.customer_id, jsonb_build_object('from', r.from_agent_id));
  return t;
end;
$$;

create or replace function cs.cancel_transfer(p_transfer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent}');
begin
  update cs.ticket_transfers set result = 'cancelled', responded_at = now()
   where id = p_transfer_id and from_agent_id = v_me and result is null;
  if not found then
    perform private.api_error(404, 'transfer_not_found', 'Permintaan transfer tidak ditemukan');
  end if;
end;
$$;

create or replace function cs_api.wait_customer(p_ticket_id uuid, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent}');
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

create or replace function cs.resolve_ticket(p_ticket_id uuid, p_outcome text, p_summary text, p_tags text[],
                                             p_version integer)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_agent}');
  t         cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version);
  v_summary text := btrim(coalesce(p_summary, ''));
  v_owner   uuid := t.owner_agent_id;
begin
  if cs.setting('resolve.outcomes') -> p_outcome is null then
    perform private.api_error(400, 'invalid_outcome', 'Pilih hasil penyelesaian dari daftar');
  end if;
  if char_length(v_summary) not between 5 and 500 then
    perform private.api_error(400, 'summary_required', 'Tulis ringkasan singkat penyelesaian (5–500 karakter)');
  end if;
  if cardinality(coalesce(p_tags, '{}')) > 10
     or exists (select 1 from unnest(coalesce(p_tags, '{}')) x where x !~ '^[a-z0-9_-]{1,32}$') then
    perform private.api_error(400, 'invalid_tags', 'Maksimal 10 tag, huruf kecil/angka/-/_');
  end if;
  perform cs.cancel_transfers(t.id, 'Tiket diselesaikan');
  t := cs.set_status(t.id, 'resolved', 'resolved', jsonb_build_object('outcome', p_outcome));
  update cs.tickets
     set resolved_by = v_me, outcome = p_outcome, resolution_summary = (cs.mask_sensitive(v_summary)).masked,
         tags = coalesce(p_tags, '{}')
   where id = t.id
  returning * into t;
  perform cs.leave_staff(t.room_id);
  perform cs.refresh_agent_load(v_owner);
  perform cs.system_message(t, 'ticket_resolved', jsonb_build_object('agent', cs.agent_name(v_owner)), 'csat',
                            jsonb_build_object('ticket_id', t.id));
  perform cs.audit('ticket.resolve', t.id, t.customer_id, jsonb_build_object('outcome', p_outcome));
  perform cs.broadcast_ticket(t, 'ticket_resolved', array[v_owner]);
  return t;
end;
$$;

create or replace function cs.reassign_ticket(p_ticket_id uuid, p_to uuid, p_reason text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_supervisor}');
  v_text text := btrim(coalesce(p_reason, ''));
  t      cs.tickets := cs.lock_ticket(p_ticket_id, null);
  v_from uuid := t.owner_agent_id;
begin
  if char_length(v_text) not between 3 and 300 then
    perform private.api_error(400, 'reason_required', 'Tulis alasan memindahkan tiket (3–300 karakter)');
  end if;
  if t.status not in ('open', 'claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Hanya tiket aktif yang bisa dipindahkan');
  end if;
  if p_to is null or p_to is not distinct from v_from then
    perform private.api_error(400, 'invalid_target', 'Pilih CS tujuan yang lain');
  end if;
  if not exists (select 1 from cs.agents a where a.user_id = p_to and a.disabled_at is null
                 and 'cs_agent' = any (a.roles)) then
    perform private.api_error(404, 'agent_not_found', 'CS tujuan tidak ditemukan');
  end if;
  perform 1 from cs.agent_status where agent_id = p_to for update;
  if cs.active_ticket_count(p_to) >= (select a.max_active_tickets from cs.agents a where a.user_id = p_to) then
    perform private.api_error(409, 'agent_unavailable', 'Batas tiket aktif CS tujuan sudah penuh');
  end if;
  perform cs.cancel_transfers(t.id, 'Dipindahkan supervisor');
  t := cs.change_owner(t.id, p_to, 'reassigned', jsonb_build_object('from', v_from, 'to', p_to, 'reason', v_text, 'by', v_me));
  perform cs.audit('ticket.reassign', t.id, t.customer_id,
    jsonb_build_object('from', v_from, 'to', p_to, 'reason', v_text));
  return t;
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
  v_me      uuid := cs.require_agent('{cs_agent}');
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
  if t.owner_agent_id is distinct from v_me then
    perform private.api_error(403, 'not_ticket_owner',
      format('Tiket ini ditangani oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
  end if;
  v_role := 'agent';
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

create or replace function cs.message_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   public.chat_rooms;
  t        cs.tickets;
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
    if new.kind <> 'text' then
      perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak diizinkan');
    end if;
  elsif new.sender_role is distinct from 'agent' or not cs.is_staff(new.sender_id) then
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
    select * into t from cs.tickets x where x.room_id = new.room_id order by x.created_at desc limit 1 for update;
    if t.id is not null and t.status in ('open', 'claimed', 'waiting_customer') then
      if t.status = 'waiting_customer' then
        t := cs.set_status(t.id, 'claimed', 'customer_replied');
        perform cs.broadcast_ticket(t, 'ticket_updated');
      end if;
      if t.last_customer_message_at is null then
        select * into v_prio from cs.initial_priority(t.topic, t.flags, new.body, now());
        if v_prio.priority < t.priority or not (v_prio.flags <@ t.flags) then
          update cs.tickets
             set priority = least(priority, v_prio.priority),
                 flags = array(select distinct f from unnest(flags || v_prio.flags) f order by f),
                 required_skill = case when 'fraud' = any (v_prio.flags) then 'fraud' else required_skill end,
                 version = version + 1,
                 updated_at = now()
           where id = t.id
          returning * into t;
          perform cs.log_event(t.id, 'priority_changed', jsonb_build_object('priority', t.priority, 'flags', t.flags));
          perform cs.broadcast_ticket(t, 'ticket_updated');
        end if;
      end if;
    elsif t.id is not null and t.status = 'resolved'
          and t.resolved_at > now() - make_interval(hours => cs.setting_int('ticket.reopen_hours')) then
      t := cs.reopen_ticket(t);
    else
      t := cs.open_ticket(new.sender_id, cs.setting('ticket.default_topic') #>> '{}',
                          coalesce(t.language, 'id'), '{}', '{}', new.body);
    end if;
    new.session_id := t.id;
  end if;

  select * into t from cs.tickets where id = new.session_id;
  if t.room_id is distinct from new.room_id then
    perform private.api_error(400, 'invalid_ticket', 'Tiket tidak sesuai dengan room');
  end if;

  if new.sender_role = 'agent' then
    if t.status not in ('claimed', 'waiting_customer') or t.owner_agent_id is distinct from new.sender_id then
      perform private.api_error(403, 'not_ticket_owner', 'Hanya CS pemilik tiket aktif yang bisa membalas');
    end if;
  end if;

  if new.sender_role = 'customer' then
    update cs.tickets set last_customer_message_at = clock_timestamp() where id = t.id;
  elsif new.sender_role = 'agent' then
    update cs.tickets
       set last_agent_message_at = clock_timestamp(),
           first_response_at = coalesce(first_response_at, clock_timestamp())
     where id = t.id;
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
    where a.disabled_at is null and 'cs_agent' = any (a.roles) and a.user_id <> v_me
      and (v_sup or st.status = 'online')), '[]');
end;
$$;

create or replace function cs_api.supervisor_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_supervisor}');
  v_late  integer := cs.setting_int('alerts.unclaimed_minutes');
  v_p1    integer := cs.setting_int('alerts.p1_unclaimed_minutes');
  v_stale interval := make_interval(secs => cs.setting_int('agent.heartbeat_fresh_seconds') * 4);
  v_today timestamptz := cs.local_date(now())::timestamp at time zone 'Asia/Jakarta';
begin
  return jsonb_build_object(
    'generated_at', now(),
    'thresholds', jsonb_build_object('unclaimed_minutes', v_late, 'p1_unclaimed_minutes', v_p1),
    'open_count', (select count(*) from cs.tickets t where t.status = 'open'),
    'oldest_open_at', (select min(t.queued_at) from cs.tickets t where t.status = 'open'),
    'active_count', (select count(*) from cs.tickets t where t.status in ('claimed', 'waiting_customer')),
    'resolved_today', (select count(*) from cs.tickets t where t.resolved_at >= v_today),
    'overdue', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.queued_at)
      from cs.tickets t
      where t.status = 'open'
        and (t.queued_at < now() - make_interval(mins => v_late)
             or (t.priority = 'P1' and t.queued_at < now() - make_interval(mins => v_p1)))), '[]'),
    'flagged_open', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.queued_at)
      from cs.tickets t
      where t.status = 'open' and t.flags && '{fraud,complaint}'::text[]), '[]'),
    'offline_owned', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.claimed_at)
      from cs.tickets t
      join cs.agent_status st on st.agent_id = t.owner_agent_id
      where t.status in ('claimed', 'waiting_customer')
        and (st.status = 'offline' or st.last_heartbeat_at < now() - v_stale)), '[]'),
    'agents', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
               'roles', to_jsonb(a.roles), 'status', st.status,
               'connected', st.status <> 'offline' and st.last_heartbeat_at > now() - v_stale,
               'active_tickets', cs.active_ticket_count(a.user_id), 'max_active_tickets', a.max_active_tickets,
               'resolved_today', (select count(*) from cs.tickets t where t.resolved_by = a.user_id and t.resolved_at >= v_today),
               'status_changed_at', st.status_changed_at)
             order by (st.status = 'online') desc, (st.status = 'offline'), a.display_name)
      from cs.agents a
      join cs.agent_status st on st.agent_id = a.user_id
      where a.disabled_at is null and 'cs_agent' = any (a.roles)), '[]'));
end;
$$;

create or replace function cs_api.admin_update_agent(
  p_agent_id           uuid,
  p_display_name       text,
  p_roles              text[],
  p_team               text,
  p_max_active_tickets integer,
  p_disabled           boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_admin}');
  v_disable boolean := coalesce(p_disabled, false);
  a         cs.agents;
begin
  perform cs.check_agent_input(p_display_name, p_roles, p_team, p_max_active_tickets);
  if p_agent_id = v_me and (v_disable or not ('cs_admin' = any (p_roles))) then
    perform private.api_error(400, 'cannot_change_self', 'Tidak bisa menonaktifkan atau melepas peran admin akun sendiri');
  end if;
  select * into a from cs.agents where user_id = p_agent_id for update;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  perform 1 from cs.agent_status where agent_id = p_agent_id for update;

  update cs.agents
     set display_name = btrim(p_display_name),
         roles = p_roles,
         team_id = coalesce((select t.id from cs.teams t where t.code = p_team), team_id),
         max_active_tickets = p_max_active_tickets,
         disabled_at = case when v_disable then coalesce(disabled_at, now()) end
   where user_id = p_agent_id;
  update public.profiles set display_name = btrim(p_display_name)
   where id = p_agent_id and display_name is distinct from btrim(p_display_name);

  if v_disable and a.disabled_at is null then
    update cs.agent_status set status = 'offline', reason = null, status_changed_at = now()
     where agent_id = p_agent_id and status <> 'offline';
    perform cs.retire_agent_work(p_agent_id, 'Akun CS dinonaktifkan');
    perform realtime.send(jsonb_build_object('event', 'agent_status', 'agent_id', p_agent_id, 'status', 'offline'),
                          'agent', 'cs:queue', true);
  elsif not ('cs_agent' = any (p_roles)) and 'cs_agent' = any (a.roles) then
    perform cs.retire_agent_work(p_agent_id, 'Peran CS diubah');
  end if;

  perform cs.audit('agent.update', null, null, jsonb_build_object(
    'agent', p_agent_id, 'roles', p_roles, 'team', p_team, 'max_active_tickets', p_max_active_tickets,
    'disabled', v_disable));
  return cs.agent_admin_view(p_agent_id);
end;
$$;
