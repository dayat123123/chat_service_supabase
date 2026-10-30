drop policy if exists support_sessions_select on cs.support_sessions;
drop policy if exists session_events_select on cs.session_events;
drop policy if exists messages_select_cs on public.messages;

drop function if exists cs_api.start_session(text, text, text, boolean);
drop function if exists cs_api.my_support();
drop function if exists cs_api.end_session(uuid);
drop function if exists cs_api.rate_session(uuid, integer, text);
drop function if exists cs_api.request_complaint();
drop function if exists cs_api.report_fake_cs(text);
drop function if exists cs_api.agent_me();
drop function if exists cs_api.agent_set_status(text, text);
drop function if exists cs_api.agent_heartbeat();
drop function if exists cs_api.agent_inbox();
drop function if exists cs_api.accept_offer(uuid);
drop function if exists cs_api.reject_offer(uuid, text);
drop function if exists cs_api.agent_send_message(uuid, text, uuid, text, jsonb, uuid, jsonb);
drop function if exists cs_api.close_session(uuid, text, text[], text);
drop function if exists cs_api.transfer_session(uuid, text, text, text, uuid);
drop function if exists cs_api.flag_session(uuid, text);
drop function if exists cs_api.add_note(text, uuid, uuid);
drop function if exists cs_api.session_detail(uuid);
drop function if exists cs_api.customer_history(uuid);
drop function if exists cs_api.agent_customer_access(uuid, text);
drop function if exists cs_api.agent_reveal_access(uuid, text, text);
drop function if exists cs_api.agent_secure_account(uuid);
drop function if exists cs_api.agent_secure_account_result(uuid, boolean, jsonb);

drop function if exists cs.assign(uuid, uuid, text);
drop function if exists cs.offer(uuid, uuid);
drop function if exists cs.close_offer(uuid, text, text);
drop function if exists cs.expire_offers();
drop function if exists cs.close_session(uuid, text, text[], uuid);
drop function if exists cs.transfer_session(uuid, text, text, uuid, text, uuid);
drop function if exists cs.requeue_session(uuid, text);
drop function if exists cs.release_agent(uuid, text, text);
drop function if exists cs.reopen(uuid);
drop function if exists cs.flag_session(uuid, text);
drop function if exists cs.open_session(uuid, text, text, text[], jsonb, text);
drop function if exists cs.set_status(uuid, text, text, jsonb, uuid);
drop function if exists cs.broadcast_session(cs.support_sessions, text, uuid);
drop function if exists cs.handled_session(uuid, uuid);
drop function if exists cs.customer_data_session(uuid);
drop function if exists cs.customer_view(cs.support_sessions);
drop function if exists cs.agent_view(cs.support_sessions);
drop function if exists cs.can_read_session(uuid, text[]);
drop function if exists cs.can_read_session_id(uuid);
drop function if exists cs.agent_available(uuid);

drop table cs.match_offers;

alter table cs.support_sessions rename to tickets;
alter index cs.support_sessions_pkey rename to tickets_pkey;
alter index cs.support_sessions_customer_idx rename to tickets_customer_idx;
alter index cs.support_sessions_room_idx rename to tickets_room_idx;
drop index cs.support_sessions_open_room_idx;
drop index cs.support_sessions_waiting_idx;
drop index cs.support_sessions_agent_idx;
drop index cs.support_sessions_last_agent_idx;

alter table cs.tickets drop constraint support_sessions_status_check;
alter table cs.tickets drop constraint support_sessions_check;
alter table cs.tickets drop constraint support_sessions_check1;
alter table cs.tickets rename constraint support_sessions_check2 to tickets_complaint_check;
alter table cs.tickets rename constraint support_sessions_context_check to tickets_context_check;
alter table cs.tickets rename constraint support_sessions_flags_check to tickets_flags_check;
alter table cs.tickets rename constraint support_sessions_language_check to tickets_language_check;
alter table cs.tickets rename constraint support_sessions_priority_check to tickets_priority_check;
alter table cs.tickets rename constraint support_sessions_rating_check to tickets_rating_check;
alter table cs.tickets rename constraint support_sessions_rating_comment_check to tickets_rating_comment_check;

alter table cs.tickets rename column current_agent_id to owner_agent_id;
alter table cs.tickets rename column last_agent_id to last_owner_id;
alter table cs.tickets rename column accepted_at to first_claimed_at;
alter table cs.tickets rename column close_outcome to outcome;
alter table cs.tickets drop column offered_at;
alter table cs.tickets drop column target_team_id;
alter table cs.tickets drop column target_agent_id;
alter table cs.tickets
  add column ticket_number      text,
  add column version            integer not null default 1,
  add column claimed_at         timestamptz,
  add column resolved_at        timestamptz,
  add column resolved_by        uuid,
  add column resolution_summary text check (char_length(resolution_summary) <= 500),
  add column returned_reason    text check (char_length(returned_reason) <= 300);

update cs.tickets
   set owner_agent_id = case when status = 'active' then owner_agent_id end,
       claimed_at = case when status = 'active' then first_claimed_at end,
       status = case status when 'active' then 'claimed' when 'closed' then 'closed' else 'open' end;

with numbered as (
  select id, cs.local_date(created_at) as day,
         row_number() over (partition by cs.local_date(created_at) order by created_at, id) as n
  from cs.tickets
)
update cs.tickets t
   set ticket_number = 'CS-' || to_char(n.day, 'YYYYMMDD') || '-' || lpad(n.n::text, greatest(4, length(n.n::text)), '0')
  from numbered n
 where n.id = t.id;

create table cs.ticket_counters (
  day        date primary key,
  last_value integer not null check (last_value > 0)
);
alter table cs.ticket_counters enable row level security;

insert into cs.ticket_counters (day, last_value)
select cs.local_date(created_at), count(*) from cs.tickets group by 1;

alter table cs.tickets alter column ticket_number set not null;
alter table cs.tickets add constraint tickets_status_check
  check (status in ('open', 'claimed', 'waiting_customer', 'resolved', 'closed'));
alter table cs.tickets add constraint tickets_owner_check
  check (status not in ('claimed', 'waiting_customer') or owner_agent_id is not null);
alter table cs.tickets add constraint tickets_open_unowned_check check (status <> 'open' or owner_agent_id is null);
alter table cs.tickets add constraint tickets_closed_check check ((status = 'closed') = (closed_at is not null));
alter table cs.tickets add constraint tickets_resolved_check check (status <> 'resolved' or resolved_at is not null);
alter table cs.tickets alter column status set default 'open';

create unique index tickets_number_idx on cs.tickets (ticket_number);
create unique index tickets_active_room_idx on cs.tickets (room_id) where status in ('open', 'claimed', 'waiting_customer');
create index tickets_open_idx on cs.tickets (priority, queued_at) where status = 'open';
create index tickets_owner_idx on cs.tickets (owner_agent_id) where status in ('claimed', 'waiting_customer');
create index tickets_last_owner_idx on cs.tickets (last_owner_id, resolved_at desc);

create table cs.ticket_transfers (
  id            uuid primary key default gen_random_uuid(),
  ticket_id     uuid not null references cs.tickets (id) on delete restrict,
  from_agent_id uuid not null references cs.agents (user_id),
  to_agent_id   uuid not null references cs.agents (user_id),
  note          text not null check (char_length(btrim(note)) between 3 and 1000),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  result        text check (result in ('accepted', 'rejected', 'expired', 'cancelled')),
  responded_at  timestamptz,
  reason        text check (char_length(reason) <= 300),
  check ((result is null) = (responded_at is null)),
  check (from_agent_id <> to_agent_id)
);
create unique index ticket_transfers_pending_idx on cs.ticket_transfers (ticket_id) where result is null;
create index ticket_transfers_to_idx on cs.ticket_transfers (to_agent_id) where result is null;
create index ticket_transfers_ticket_idx on cs.ticket_transfers (ticket_id, created_at desc);
alter table cs.ticket_transfers enable row level security;

alter table cs.agents rename column max_concurrent to max_active_tickets;
alter table cs.agents drop constraint agents_max_concurrent_check;
alter table cs.agents add constraint agents_max_active_tickets_check check (max_active_tickets between 0 and 50);
alter table cs.agents alter column max_active_tickets set default 5;
update cs.agents set max_active_tickets = 5;

alter table cs.agent_status rename column active_sessions to active_tickets;
alter table cs.agent_status rename constraint agent_status_active_sessions_check to agent_status_active_tickets_check;
alter table cs.agent_status rename column last_assigned_at to last_claimed_at;
alter table cs.agent_status drop column consecutive_timeouts;
alter table cs.agent_status add column away_notified_at timestamptz;

update private.rate_limits set action = 'cs_ticket' where action = 'cs_session';

delete from cs.cs_settings where key in (
  'offer.timeout_seconds', 'offer.max_consecutive_timeouts', 'session.reopen_minutes', 'messages.greeting',
  'messages.security_reminder', 'messages.queued', 'messages.connected', 'messages.transferred',
  'messages.reconnecting', 'messages.reopened', 'messages.closed', 'messages.csat', 'messages.help'
);
update cs.cs_settings set key = 'ticket.default_topic', description = 'Topik tiket baru yang dibuat dari pesan nasabah tanpa memilih topik'
 where key = 'session.default_topic';
update cs.cs_settings
   set key = 'resolve.outcomes',
       value = '{"answered": {"id": "Terjawab", "en": "Answered"}, "follow_up": {"id": "Perlu tindak lanjut", "en": "Needs follow-up"}, "complaint": {"id": "Pengaduan", "en": "Complaint"}, "other": {"id": "Lainnya", "en": "Other"}}',
       description = 'Hasil yang wajib dipilih CS saat menyelesaikan tiket'
 where key = 'close.outcomes';
update cs.cs_settings
   set description = 'CS bisa membaca riwayat room nasabah selama memegang tiketnya, dan sekian jam setelah tiket yang ia tangani selesai'
 where key = 'agent.history_hours';
update cs.tickets set outcome = case outcome when 'resolved' then 'answered' when 'no_response' then 'other' else outcome end
 where outcome in ('resolved', 'no_response');

insert into cs.cs_settings (key, value, description) values
  ('assignment.mode', '"claim"', 'Mode penugasan: claim (CS mengambil tiket sendiri) atau auto_assign (sistem menugaskan otomatis)'),
  ('ticket.reopen_hours', '24', 'Nasabah bisa membuka kembali tiket yang sudah selesai dalam sekian jam'),
  ('ticket.owner_away_minutes', '10',
   'Saat tiket dibuka kembali, tiket kembali ke CS pemilik kecuali pemilik offline lebih dari sekian menit'),
  ('ticket.auto_release_offline_minutes', '0',
   'Lepas tiket ke antrean bila pemilik offline lebih dari sekian menit. 0 = mati (default)'),
  ('transfer.expire_minutes', '10', 'Batas waktu CS tujuan menerima transfer tiket'),
  ('alerts.unclaimed_minutes', '10', 'Peringatan supervisor bila tiket terbuka belum diambil sekian menit'),
  ('alerts.p1_unclaimed_minutes', '2', 'Peringatan supervisor bila tiket P1 belum diambil sekian menit'),
  ('ui.wait_warn_minutes', '5', 'Lama menunggu berwarna kuning mulai sekian menit'),
  ('ui.wait_late_minutes', '15', 'Lama menunggu berwarna merah mulai sekian menit'),
  ('ui.idle_logout_minutes', '30', 'Web CS keluar otomatis setelah idle sekian menit'),
  ('brand.support_name', '"CS OLT"', 'Nama room CS di aplikasi nasabah'),
  ('messages.ticket_opened',
   '{"id": "Tiket #{ticket} dibuka. Halo {name}, terima kasih sudah menghubungi CS OLT. CS kami tidak pernah meminta PIN, password, atau OTP.", "en": "Ticket #{ticket} opened. Hi {name}, thank you for contacting OLT customer service. We never ask for your PIN, password, or OTP."}',
   'Pesan saat tiket dibuat: salam dan pengingat keamanan dalam satu pesan'),
  ('messages.ticket_claimed',
   '{"id": "Tiket diambil oleh {agent} – CS Resmi.", "en": "Your ticket is now handled by {agent} – Official CS."}',
   'Pesan saat CS mengambil tiket'),
  ('messages.ticket_transferred',
   '{"id": "Tiket dialihkan ke {agent} – CS Resmi.", "en": "Your ticket has been transferred to {agent} – Official CS."}',
   'Pesan saat tiket dipindahkan ke CS lain'),
  ('messages.ticket_released',
   '{"id": "Tiket dikembalikan ke antrean. CS lain akan segera membantu.", "en": "Your ticket is back in the queue. Another agent will help you shortly."}',
   'Pesan saat CS melepas tiket ke antrean'),
  ('messages.agent_away',
   '{"id": "CS {agent} sedang tidak aktif. Pesan Anda tetap tersimpan dan akan dibalas.", "en": "{agent} is currently away. Your messages are saved and will be answered."}',
   'Pesan saat CS pemilik tiket berstatus offline'),
  ('messages.ticket_resolved',
   '{"id": "Tiket #{ticket} diselesaikan oleh {agent}. Bagaimana pelayanan kami? Beri nilai 1–5.", "en": "Ticket #{ticket} was resolved by {agent}. How did we do? Rate us from 1 to 5."}',
   'Pesan saat tiket diselesaikan, sekaligus permintaan rating'),
  ('messages.ticket_reopened',
   '{"id": "Tiket #{ticket} dibuka kembali.", "en": "Ticket #{ticket} has been reopened."}',
   'Pesan saat tiket dibuka kembali dan menunggu CS'),
  ('messages.ticket_reopened_owner',
   '{"id": "Tiket #{ticket} dibuka kembali dan ditangani {agent} – CS Resmi.", "en": "Ticket #{ticket} has been reopened and is handled by {agent} – Official CS."}',
   'Pesan saat tiket dibuka kembali ke CS pemilik'),
  ('messages.ticket_closed',
   '{"id": "Tiket #{ticket} ditutup.", "en": "Ticket #{ticket} is closed."}',
   'Pemisah di chat saat tiket ditutup');

create or replace function cs.next_ticket_number()
returns text
language sql
security definer
set search_path = ''
as $$
  insert into cs.ticket_counters as c (day, last_value) values (cs.local_date(now()), 1)
  on conflict (day) do update set last_value = c.last_value + 1
  returning 'CS-' || to_char(c.day, 'YYYYMMDD') || '-' || lpad(c.last_value::text, greatest(4, length(c.last_value::text)), '0');
$$;

create or replace function cs.active_ticket_count(p_agent uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from cs.tickets t
  where t.owner_agent_id = p_agent and t.status in ('claimed', 'waiting_customer');
$$;

create or replace function cs.refresh_agent_load(p_agent uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update cs.agent_status set active_tickets = cs.active_ticket_count(p_agent) where agent_id = p_agent;
$$;

update cs.agent_status set active_tickets = cs.active_ticket_count(agent_id);

create or replace function cs.agent_name(p_agent uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.display_name from cs.agents a where a.user_id = p_agent;
$$;

create or replace function cs.agent_is_away(p_agent uuid, p_minutes integer)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select a.disabled_at is not null
        or (st.status = 'offline' and st.status_changed_at < now() - make_interval(mins => p_minutes))
        or st.last_heartbeat_at is null
        or st.last_heartbeat_at < now() - make_interval(mins => greatest(p_minutes, 1))
    from cs.agents a join cs.agent_status st on st.agent_id = a.user_id
    where a.user_id = p_agent), true);
$$;

create or replace function cs.can_take_tickets(p_agent uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from cs.agents a join cs.agent_status st on st.agent_id = a.user_id
    where a.user_id = p_agent and a.disabled_at is null and a.roles && '{cs_agent,cs_supervisor}'
      and st.status = 'online' and cs.active_ticket_count(p_agent) < a.max_active_tickets
  );
$$;

create or replace function cs.check_rate(p_action text, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r        record;
  v_count  integer;
  v_oldest timestamptz;
begin
  for r in
    select l.max_count, l.window_seconds from private.rate_limits l
    where l.action = p_action order by l.window_seconds
  loop
    if p_action = 'cs_ticket' then
      select count(*), min(t.created_at) into v_count, v_oldest
      from cs.tickets t
      where t.customer_id = p_user and t.created_at > now() - make_interval(secs => r.window_seconds);
    else
      select count(*), min(m.created_at) into v_count, v_oldest
      from public.messages m
      where m.sender_id = p_user and m.session_id is not null
        and m.created_at > now() - make_interval(secs => r.window_seconds);
    end if;
    if v_count >= r.max_count then
      perform private.raise_rate_limited(p_action, r.max_count, r.window_seconds,
        ceil(r.window_seconds - extract(epoch from (now() - v_oldest)))::integer);
    end if;
  end loop;
end;
$$;

create or replace function cs.transition_allowed(p_from text, p_to text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_from, p_to) in (
    ('open', 'claimed'), ('open', 'closed'),
    ('claimed', 'waiting_customer'), ('claimed', 'resolved'), ('claimed', 'open'), ('claimed', 'closed'),
    ('waiting_customer', 'claimed'), ('waiting_customer', 'resolved'), ('waiting_customer', 'open'),
    ('waiting_customer', 'closed'),
    ('resolved', 'claimed'), ('resolved', 'open'), ('resolved', 'closed')
  );
$$;

create or replace function cs.set_status(p_ticket_id uuid, p_to text, p_event text, p_data jsonb default '{}',
                                         p_owner uuid default null)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not cs.transition_allowed(t.status, p_to) then
    perform private.api_error(409, 'invalid_transition', format('Tiket berstatus %s tidak bisa menjadi %s', t.status, p_to));
  end if;
  update cs.tickets
     set status = p_to,
         owner_agent_id = case when p_to = 'open' then null
                               when p_to in ('claimed', 'waiting_customer') then coalesce(p_owner, owner_agent_id)
                               else owner_agent_id end,
         last_owner_id = case when p_to = 'claimed' then coalesce(p_owner, owner_agent_id, last_owner_id) else last_owner_id end,
         claimed_at = case when p_to = 'claimed'
                                and (t.status in ('open', 'resolved') or (p_owner is not null and p_owner <> t.owner_agent_id))
                           then now() else claimed_at end,
         first_claimed_at = case when p_to = 'claimed' then coalesce(first_claimed_at, now()) else first_claimed_at end,
         queued_at = case when p_to = 'open' then now() else queued_at end,
         resolved_at = case when p_to = 'resolved' then now() when p_to in ('open', 'claimed') then null else resolved_at end,
         closed_at = case when p_to = 'closed' then now() end,
         returned_reason = null,
         version = version + 1,
         updated_at = now()
   where id = p_ticket_id
  returning * into t;
  perform cs.log_event(t.id, p_event, coalesce(p_data, '{}') || jsonb_build_object('status', p_to));
  return t;
end;
$$;

create or replace function cs.message_text(t cs.tickets, p_code text, p_vars jsonb default '{}')
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select cs.render_text(coalesce(m.value ->> t.language, m.value ->> 'id', p_code),
                        jsonb_build_object('ticket', t.ticket_number) || coalesce(p_vars, '{}'))
  from (select cs.setting('messages.' || p_code) as value) m;
$$;

create or replace function cs.post_system(t cs.tickets, p_code text, p_body text, p_kind text default 'system',
                                          p_payload jsonb default '{}')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.messages (room_id, sender_id, body, kind, session_id, sender_role, payload)
  values (t.room_id, null, p_body, p_kind, t.id, 'system',
          coalesce(p_payload, '{}') || jsonb_build_object('code', p_code, 'ticket_number', t.ticket_number))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function cs.system_message(s cs.tickets, p_code text, p_vars jsonb default '{}',
                                             p_kind text default 'system', p_payload jsonb default '{}')
returns uuid
language sql
security definer
set search_path = ''
as $$
  select cs.post_system(s, p_code, cs.message_text(s, p_code, p_vars), p_kind, p_payload);
$$;

create or replace function cs.broadcast_ticket(t cs.tickets, p_event text, p_agents uuid[] default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payload jsonb := jsonb_build_object(
    'event', p_event, 'ticket_id', t.id, 'ticket_number', t.ticket_number, 'room_id', t.room_id,
    'status', t.status, 'priority', t.priority, 'flags', t.flags, 'topic', t.topic,
    'owner_id', t.owner_agent_id, 'owner_name', cs.agent_name(t.owner_agent_id), 'version', t.version);
  v_agent uuid;
begin
  perform realtime.send(jsonb_build_object('event', p_event, 'ticket_id', t.id, 'status', t.status),
                        'ticket', 'cs:room:' || t.room_id::text, true);
  perform realtime.send(v_payload, 'ticket', 'cs:queue', true);
  for v_agent in
    select distinct x from unnest(array_append(coalesce(p_agents, '{}'), t.owner_agent_id)) x where x is not null
  loop
    perform realtime.send(v_payload, 'ticket', 'cs:agent:' || v_agent::text, true);
  end loop;
end;
$$;

create or replace function cs.leave_staff(p_room_id uuid, p_keep uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.chat_members m
  where m.room_id = p_room_id and m.user_id is distinct from p_keep and cs.is_staff(m.user_id);
$$;

create or replace function cs.after_owner_change(t cs.tickets, p_previous uuid, p_event text, p_message text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if t.status in ('claimed', 'waiting_customer') then
    perform cs.leave_staff(t.room_id, t.owner_agent_id);
    insert into public.chat_members (room_id, user_id, role) values (t.room_id, t.owner_agent_id, 'member')
    on conflict do nothing;
    update cs.agent_status set last_claimed_at = now() where agent_id = t.owner_agent_id;
    perform cs.refresh_agent_load(t.owner_agent_id);
  else
    perform cs.leave_staff(t.room_id);
  end if;
  if p_previous is not null and p_previous is distinct from t.owner_agent_id then
    perform cs.refresh_agent_load(p_previous);
  end if;
  if p_message is not null then
    perform cs.system_message(t, p_message, jsonb_build_object('agent', cs.agent_name(t.owner_agent_id)));
  end if;
  perform cs.broadcast_ticket(t, p_event, array[p_previous]);
end;
$$;

create or replace function cs.cancel_transfers(p_ticket_id uuid, p_reason text)
returns void
language sql
security definer
set search_path = ''
as $$
  update cs.ticket_transfers
     set result = 'cancelled', responded_at = now(), reason = left(p_reason, 300)
   where ticket_id = p_ticket_id and result is null;
$$;

create or replace function cs.lock_ticket(p_ticket_id uuid, p_version integer)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if p_version is not null and p_version <> t.version then
    perform private.api_error(409, 'stale_ticket', 'Tiket sudah berubah. Muat ulang lalu coba lagi');
  end if;
  return t;
end;
$$;

create or replace function cs.owned_ticket(p_ticket_id uuid, p_agent uuid, p_version integer default null,
                                           p_allow_supervisor boolean default false)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets := cs.lock_ticket(p_ticket_id, p_version);
begin
  if t.status not in ('claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket tidak sedang ditangani');
  end if;
  if t.owner_agent_id is distinct from p_agent and not (p_allow_supervisor and cs.has_role('{cs_supervisor}')) then
    perform private.api_error(403, 'not_ticket_owner',
      format('Tiket ini ditangani oleh %s', coalesce(cs.agent_name(t.owner_agent_id), 'CS lain')));
  end if;
  return t;
end;
$$;

create or replace function cs.claim_ticket(p_ticket_id uuid)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_agent,cs_supervisor}');
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

create or replace function cs.change_owner(p_ticket_id uuid, p_to uuid, p_event text, p_data jsonb)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      cs.tickets;
  v_from uuid;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  v_from := t.owner_agent_id;
  if t.status = 'open' then
    t := cs.set_status(t.id, 'claimed', p_event, p_data, p_to);
  else
    update cs.tickets
       set status = 'claimed', owner_agent_id = p_to, last_owner_id = p_to, claimed_at = now(),
           first_claimed_at = coalesce(first_claimed_at, now()), version = version + 1, updated_at = now()
     where id = t.id
    returning * into t;
    perform cs.log_event(t.id, p_event, coalesce(p_data, '{}') || jsonb_build_object('status', 'claimed'));
  end if;
  perform cs.after_owner_change(t, v_from, 'ticket_' || p_event,
    case when v_from is null then 'ticket_claimed' else 'ticket_transferred' end);
  return t;
end;
$$;

create or replace function cs.require_capacity(p_agent uuid, p_message text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from cs.agent_status where agent_id = p_agent for update;
  if not cs.can_take_tickets(p_agent) then
    perform private.api_error(409, 'agent_unavailable', p_message);
  end if;
end;
$$;

create or replace function cs.release_ticket(p_ticket_id uuid, p_reason text, p_version integer)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent,cs_supervisor}');
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
  v_me   uuid := cs.require_agent('{cs_agent,cs_supervisor}');
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
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
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
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor}');
begin
  update cs.ticket_transfers set result = 'cancelled', responded_at = now()
   where id = p_transfer_id and from_agent_id = v_me and result is null;
  if not found then
    perform private.api_error(404, 'transfer_not_found', 'Permintaan transfer tidak ditemukan');
  end if;
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
                 and a.roles && '{cs_agent,cs_supervisor}') then
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

create or replace function cs.reopen_ticket(t cs.tickets)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid := t.owner_agent_id;
begin
  if v_owner is not null then
    perform 1 from cs.agent_status where agent_id = v_owner for update;
  end if;
  if v_owner is not null
     and not cs.agent_is_away(v_owner, cs.setting_int('ticket.owner_away_minutes'))
     and cs.active_ticket_count(v_owner) < (select a.max_active_tickets from cs.agents a where a.user_id = v_owner) then
    t := cs.set_status(t.id, 'claimed', 'reopened', jsonb_build_object('agent_id', v_owner), v_owner);
    perform cs.after_owner_change(t, null, 'ticket_reopened', 'ticket_reopened_owner');
  else
    t := cs.set_status(t.id, 'open', 'reopened');
    perform cs.after_owner_change(t, v_owner, 'ticket_reopened', 'ticket_reopened');
  end if;
  return t;
end;
$$;

create or replace function cs.finalize_ticket(p_ticket_id uuid, p_reason text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      cs.tickets;
  v_prev uuid;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  if t.status = 'closed' then
    return t;
  end if;
  v_prev := case when t.status in ('claimed', 'waiting_customer') then t.owner_agent_id end;
  perform cs.cancel_transfers(t.id, 'Tiket ditutup');
  t := cs.set_status(t.id, 'closed', 'closed', jsonb_build_object('reason', p_reason));
  update cs.tickets
     set outcome = coalesce(outcome, case when p_reason = 'customer' then 'customer_ended' else p_reason end),
         closed_by = case when p_reason = 'customer' then auth.uid() end
   where id = t.id
  returning * into t;
  perform cs.leave_staff(t.room_id);
  if v_prev is not null then
    perform cs.refresh_agent_load(v_prev);
  end if;
  perform cs.system_message(t, 'ticket_closed');
  perform cs.broadcast_ticket(t, 'ticket_closed', array[v_prev]);
  return t;
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
  v_me      uuid := cs.require_agent('{cs_agent,cs_supervisor}');
  t         cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version, true);
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
  v_body := cs.message_text(t, 'ticket_opened',
    jsonb_build_object('name', coalesce((select p.display_name from public.profiles p where p.id = p_customer), '')));
  if not cs.is_open(now()) then
    v_body := v_body || ' ' || cs.message_text(t, 'out_of_hours',
      jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), t.language)));
  end if;
  if 'complaint' = any (t.flags) then
    v_body := v_body || ' ' || cs.message_text(t, 'complaint', cs.complaint_note(t));
  end if;
  perform cs.post_system(t, 'ticket_opened', v_body, 'system',
    case when tp.help_url is null then '{}'::jsonb else jsonb_build_object('url', tp.help_url) end);
  perform cs.broadcast_ticket(t, 'ticket_opened');
  return t;
end;
$$;

create or replace function cs.flag_ticket(p_ticket_id uuid, p_flag text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  if p_flag not in ('complaint', 'fraud') then
    perform private.api_error(400, 'invalid_flag', 'Tanda tiket tidak dikenal');
  end if;
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if t.status in ('resolved', 'closed') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket sudah selesai');
  end if;
  if p_flag = any (t.flags) then
    return t;
  end if;
  update cs.tickets
     set flags = array(select distinct f from unnest(flags || p_flag) f order by f),
         priority = case when p_flag = 'fraud' then 'P1' else least(priority, 'P2') end,
         required_skill = case when p_flag = 'fraud' or not ('fraud' = any (flags)) then p_flag else required_skill end,
         complaint_received_at = case when p_flag = 'complaint' then now() else complaint_received_at end,
         complaint_due_at = case when p_flag = 'complaint'
                                 then cs.regulatory_deadline(now(), cs.setting_int('complaint.days'))
                                 else complaint_due_at end,
         version = version + 1,
         updated_at = now()
   where id = p_ticket_id
  returning * into t;
  perform cs.log_event(t.id, 'flagged', jsonb_build_object('flag', p_flag, 'priority', t.priority));
  if p_flag = 'complaint' then
    perform cs.system_message(t, 'complaint', cs.complaint_note(t));
  end if;
  perform cs.broadcast_ticket(t, 'ticket_updated');
  return t;
end;
$$;

create or replace function cs.notify_owner_away(p_agent uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  t       cs.tickets;
  v_count integer := 0;
begin
  for t in select * from cs.tickets x where x.owner_agent_id = p_agent and x.status in ('claimed', 'waiting_customer') loop
    perform cs.system_message(t, 'agent_away', jsonb_build_object('agent', cs.agent_name(p_agent)));
    perform cs.log_event(t.id, 'owner_away', jsonb_build_object('agent_id', p_agent));
    v_count := v_count + 1;
  end loop;
  update cs.agent_status set away_notified_at = now() where agent_id = p_agent;
  return v_count;
end;
$$;

create or replace function cs.release_owner_tickets(p_agent uuid, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  t       cs.tickets;
  v_count integer := 0;
begin
  for t in
    select * from cs.tickets x
    where x.owner_agent_id = p_agent and x.status in ('claimed', 'waiting_customer')
    order by x.claimed_at
  loop
    perform cs.cancel_transfers(t.id, p_reason);
    t := cs.set_status(t.id, 'open', 'released', jsonb_build_object('reason', p_reason, 'agent_id', p_agent, 'auto', true));
    update cs.tickets set returned_reason = left(p_reason, 300) where id = t.id returning * into t;
    perform cs.after_owner_change(t, p_agent, 'ticket_released', 'ticket_released');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.auto_assign_open()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  w       record;
  v_agent uuid;
  v_count integer := 0;
begin
  for w in
    select t.id, t.required_skill, t.language from cs.tickets t
    where t.status = 'open'
    order by t.priority, t.queued_at
    for update skip locked
  loop
    select a.user_id into v_agent
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.agent_skills k on k.agent_id = a.user_id and k.skill = w.required_skill
    where cs.can_take_tickets(a.user_id)
      and st.last_heartbeat_at > now() - make_interval(secs => cs.setting_int('agent.heartbeat_fresh_seconds'))
      and w.language = any (a.languages)
    order by (k.level is null), k.level desc, st.active_tickets, st.last_claimed_at nulls first
    limit 1
    for update of st skip locked;
    continue when v_agent is null;
    perform cs.change_owner(w.id, v_agent, 'assigned', jsonb_build_object('agent_id', v_agent, 'auto', true));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.run_sweep()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r          record;
  v_expired  integer := 0;
  v_closed   integer := 0;
  v_released integer := 0;
  v_assigned integer := 0;
  v_minutes  integer := coalesce(cs.setting_int('ticket.auto_release_offline_minutes'), 0);
begin
  for r in
    update cs.ticket_transfers set result = 'expired', responded_at = now()
     where result is null and expires_at <= now()
    returning ticket_id, from_agent_id, id
  loop
    perform cs.log_event(r.ticket_id, 'transfer_expired');
    perform realtime.send(jsonb_build_object('event', 'transfer_expired', 'transfer_id', r.id, 'ticket_id', r.ticket_id),
                          'transfer', 'cs:agent:' || r.from_agent_id::text, true);
    v_expired := v_expired + 1;
  end loop;

  for r in
    select t.id from cs.tickets t
    where t.status = 'resolved' and t.resolved_at < now() - make_interval(hours => cs.setting_int('ticket.reopen_hours'))
    for update skip locked
  loop
    perform cs.finalize_ticket(r.id, 'reopen_window_passed');
    v_closed := v_closed + 1;
  end loop;

  if v_minutes > 0 then
    for r in
      select distinct t.owner_agent_id as agent_id from cs.tickets t
      where t.status in ('claimed', 'waiting_customer') and cs.agent_is_away(t.owner_agent_id, v_minutes)
    loop
      v_released := v_released + cs.release_owner_tickets(r.agent_id,
        format('Pemilik offline lebih dari %s menit', v_minutes));
    end loop;
  end if;

  if cs.setting('assignment.mode') #>> '{}' = 'auto_assign' and cs.is_open(now()) then
    v_assigned := cs.auto_assign_open();
  end if;

  return jsonb_build_object('transfers_expired', v_expired, 'tickets_closed', v_closed,
                            'tickets_released', v_released, 'tickets_assigned', v_assigned);
end;
$$;

select cron.schedule('cs-sweep', '10 seconds', 'select cs.run_sweep()');

create or replace function cs.agent_can_read_room(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from cs.tickets t
    where t.room_id = p_room_id
      and ((t.status in ('claimed', 'waiting_customer') and t.owner_agent_id = cs.current_agent_id())
           or (t.last_owner_id = cs.current_agent_id() and t.status in ('resolved', 'closed')
               and coalesce(t.resolved_at, t.closed_at) > now() - make_interval(hours => cs.setting_int('agent.history_hours')))
           or exists (select 1 from cs.ticket_transfers x
                      where x.ticket_id = t.id and x.result is null and x.to_agent_id = cs.current_agent_id()))
  );
$$;

create or replace function cs.can_read_room(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_supervisor}') then
      exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support')
    else (cs.has_role('{cs_agent}')
          and (cs.agent_can_read_room(p_room_id)
               or exists (select 1 from cs.tickets t where t.room_id = p_room_id and t.status = 'open')))
      or (cs.has_role('{compliance}')
          and exists (select 1 from cs.tickets t where t.room_id = p_room_id and t.flags && '{complaint,fraud}'))
  end;
$$;

create or replace function cs.can_read_ticket(p_room_id uuid, p_ticket_id uuid, p_status text, p_flags text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_supervisor}') then true
    else (cs.has_role('{cs_agent}') and (p_status = 'open' or cs.agent_can_read_room(p_room_id)))
      or (cs.has_role('{compliance}') and p_flags && '{complaint,fraud}')
  end;
$$;

create or replace function cs.can_read_ticket_id(p_ticket_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) from cs.tickets t where t.id = p_ticket_id), false);
$$;

create or replace function cs.can_read_notes(p_customer_id uuid, p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_supervisor}') then true
    else (cs.has_role('{cs_agent}')
          and cs.agent_can_read_room((select r.id from public.chat_rooms r
                                      where r.type = 'support' and r.customer_id = p_customer_id)))
      or (cs.has_role('{compliance}') and p_session_id is not null
          and exists (select 1 from cs.tickets t where t.id = p_session_id and t.flags && '{complaint,fraud}'))
  end;
$$;

create or replace function cs.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := regexp_match(coalesce(p_topic, ''),
    '^cs:(room|agent):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$');
begin
  if p_topic = 'cs:queue' then
    return cs.has_role('{cs_agent,cs_supervisor}');
  end if;
  if v_parts is null then
    return false;
  end if;
  if v_parts[1] = 'agent' then
    return coalesce(v_parts[2]::uuid = cs.current_agent_id(), false);
  end if;
  return exists (select 1 from public.chat_rooms r
                 where r.id = v_parts[2]::uuid and r.type = 'support' and r.customer_id = auth.uid())
      or cs.can_read_room(v_parts[2]::uuid);
end;
$$;

create policy tickets_select on cs.tickets for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_ticket(room_id, id, status, flags));
create policy session_events_select on cs.session_events for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_ticket_id(session_id));
create policy ticket_transfers_select on cs.ticket_transfers for select to authenticated
  using (from_agent_id = (select cs.current_agent_id()) or to_agent_id = (select cs.current_agent_id())
         or (select cs.has_role('{cs_supervisor}')));
create policy messages_select_cs on public.messages for select to authenticated
  using (
    session_id is not null
    and moderation_status = 'visible'
    and (select cs.current_agent_id()) is not null
    and cs.can_read_ticket_id(session_id)
  );
grant select on cs.ticket_transfers to authenticated;

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
  elsif new.sender_role = 'supervisor' then
    if t.status not in ('claimed', 'waiting_customer')
       or not exists (select 1 from cs.agents a where a.user_id = new.sender_id and a.disabled_at is null
                      and 'cs_supervisor' = any (a.roles))
       or not exists (select 1 from public.chat_members m where m.room_id = new.room_id and m.user_id = new.sender_id) then
      perform private.api_error(403, 'not_joined', 'Supervisor harus bergabung ke tiket aktif sebelum membalas');
    end if;
  end if;

  if new.sender_role = 'customer' then
    update cs.tickets set last_customer_message_at = clock_timestamp() where id = t.id;
  elsif new.sender_role in ('agent', 'supervisor') then
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

create or replace function cs.message_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  select * into t from cs.tickets where id = new.session_id;
  if new.sender_role = 'customer' then
    perform realtime.send(jsonb_build_object('event', 'ticket_message', 'ticket_id', t.id, 'room_id', t.room_id,
                                             'status', t.status, 'message_id', new.id),
                          'ticket', case when t.status = 'open' then 'cs:queue'
                                         else 'cs:agent:' || coalesce(t.owner_agent_id::text, 'none') end, true);
  elsif new.sender_role in ('agent', 'supervisor')
        or new.payload ->> 'code' in ('ticket_claimed', 'ticket_resolved', 'ticket_transferred', 'ticket_reopened_owner') then
    perform private.notify(
      t.customer_id, new.sender_id, 'message',
      jsonb_build_object(
        'room_id', new.room_id,
        'room_type', 'support',
        'room_name', cs.setting('brand.support_name') #>> '{}',
        'message_id', new.id,
        'ticket_id', t.id,
        'snippet', case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end
      ),
      'message:room:' || new.room_id
    );
  end if;
  return null;
end;
$$;

create or replace function cs.support_room_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.muted and exists (select 1 from public.chat_rooms r where r.id = new.room_id and r.type = 'support') then
    perform private.api_error(400, 'cannot_mute_support', 'Chat CS tidak bisa dibisukan');
  end if;
  return new;
end;
$$;

create trigger chat_members_support_mute
  before update of muted on public.chat_members
  for each row execute function cs.support_room_guard();

create or replace function cs.create_agent(
  p_user_id        uuid,
  p_display_name   text,
  p_roles          text[] default '{cs_agent}',
  p_team           text default 'general',
  p_skills         jsonb default '{"general": 1}',
  p_languages      text[] default '{id}',
  p_max_concurrent integer default 5,
  p_created_by     uuid default null
)
returns cs.agents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code     text := 'CS-' || lpad(nextval('cs.agent_code_seq')::text, 4, '0');
  v_username text := 'cs_' || lower(replace(v_code, '-', ''));
  v_agent    cs.agents;
begin
  if exists (select 1 from public.profiles p where p.id = p_user_id) then
    perform private.api_error(409, 'profile_exists', 'Akun ini sudah punya profil nasabah, pakai akun staf terpisah');
  end if;
  if exists (select 1 from public.profiles p where p.username = v_username) then
    v_username := left(v_username, 24) || '_' || substr(md5(p_user_id::text), 1, 5);
  end if;
  insert into public.profiles (id, olt_user_id, username, display_name)
  values (p_user_id, 'cs-staff:' || p_user_id, v_username, btrim(p_display_name));

  insert into cs.agents (user_id, agent_code, display_name, roles, team_id, languages, max_active_tickets, created_by)
  values (p_user_id, v_code, btrim(p_display_name), p_roles,
          (select t.id from cs.teams t where t.code = p_team), p_languages, p_max_concurrent, p_created_by)
  returning * into v_agent;

  insert into cs.agent_status (agent_id) values (p_user_id);
  insert into cs.agent_skills (agent_id, skill, level)
  select p_user_id, s.key, (s.value #>> '{}')::smallint
  from jsonb_each(coalesce(p_skills, '{}')) s;
  return v_agent;
end;
$$;

create or replace function cs.ticket_customer_view(t cs.tickets)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'ticket_number', t.ticket_number,
    'room_id', t.room_id,
    'topic', t.topic,
    'topic_name', (select case when t.language = 'en' then tp.name_en else tp.name_id end
                   from cs.support_topics tp where tp.code = t.topic),
    'status', t.status,
    'queue_ahead', case when t.status = 'open' then (
      select count(*)::integer from cs.tickets w
      where w.status = 'open' and w.id <> t.id and (w.priority, w.queued_at) < (t.priority, t.queued_at)) end,
    'agent', case when t.status in ('claimed', 'waiting_customer', 'resolved') and t.owner_agent_id is not null then (
      select jsonb_build_object('display_name', a.display_name, 'agent_code', a.agent_code)
      from cs.agents a where a.user_id = t.owner_agent_id) end,
    'complaint', case when t.complaint_received_at is not null then
      jsonb_build_object('received_at', t.complaint_received_at, 'due_at', t.complaint_due_at) end,
    'created_at', t.created_at,
    'resolved_at', t.resolved_at,
    'closed_at', t.closed_at,
    'reopen_until', case when t.status = 'resolved'
                         then t.resolved_at + make_interval(hours => cs.setting_int('ticket.reopen_hours')) end,
    'rating', t.rating,
    'can_rate', t.status in ('resolved', 'closed') and t.first_claimed_at is not null and t.rating is null
  );
$$;

create or replace function cs.ticket_agent_view(t cs.tickets)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'ticket_number', t.ticket_number,
    'room_id', t.room_id,
    'status', t.status,
    'version', t.version,
    'topic', t.topic,
    'priority', t.priority,
    'flags', to_jsonb(t.flags),
    'language', t.language,
    'customer', (select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username,
                                           'deleted', p.deleted_at is not null)
                 from public.profiles p where p.id = t.customer_id),
    'owner', case when t.owner_agent_id is not null then (
      select jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
                                'status', st.status)
      from cs.agents a join cs.agent_status st on st.agent_id = a.user_id where a.user_id = t.owner_agent_id) end,
    'is_mine', t.owner_agent_id = auth.uid(),
    'context', t.context,
    'queued_at', t.queued_at,
    'created_at', t.created_at,
    'claimed_at', t.claimed_at,
    'first_response_at', t.first_response_at,
    'last_customer_message_at', t.last_customer_message_at,
    'last_agent_message_at', t.last_agent_message_at,
    'resolved_at', t.resolved_at,
    'closed_at', t.closed_at,
    'outcome', t.outcome,
    'resolution_summary', t.resolution_summary,
    'returned_reason', t.returned_reason,
    'complaint_received_at', t.complaint_received_at,
    'complaint_due_at', t.complaint_due_at,
    'rating', t.rating,
    'rating_comment', t.rating_comment,
    'transfer', (select jsonb_build_object('id', x.id, 'from_id', x.from_agent_id, 'from_name', cs.agent_name(x.from_agent_id),
                                           'to_id', x.to_agent_id, 'to_name', cs.agent_name(x.to_agent_id),
                                           'note', x.note, 'expires_at', x.expires_at)
                 from cs.ticket_transfers x where x.ticket_id = t.id and x.result is null)
  );
$$;

create or replace function cs.customer_data_ticket(p_ticket_id uuid)
returns cs.tickets
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_supervisor,compliance}');
  t    cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not (
    (t.status in ('claimed', 'waiting_customer') and t.owner_agent_id = v_me)
    or cs.has_role('{cs_supervisor}')
    or (cs.has_role('{compliance}') and t.flags && '{complaint,fraud}')
  ) then
    perform private.api_error(403, 'customer_data_forbidden', 'Anda tidak berwenang membuka data nasabah untuk tiket ini');
  end if;
  return t;
end;
$$;

create or replace function cs.support_name()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select cs.setting('brand.support_name') #>> '{}';
$$;

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
  last_message_status    text,
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
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified
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
  where m.user_id = auth.uid()
  order by (r.type = 'support') desc, coalesce(r.last_message_at, r.created_at) desc;
$$;

revoke execute on all functions in schema cs from public;
grant execute on function
  cs.current_agent_id(), cs.current_roles(), cs.has_role(text[]), cs.is_staff(uuid),
  cs.can_read_room(uuid), cs.can_read_ticket(uuid, uuid, text, text[]), cs.can_read_ticket_id(uuid),
  cs.can_read_notes(uuid, uuid), cs.can_read_room_text(text), cs.is_support_owner_text(text),
  cs.agent_can_read_room(uuid), cs.require_agent(text[]), cs.require_customer(), cs.current_customer_id(),
  cs.support_name()
to authenticated;
