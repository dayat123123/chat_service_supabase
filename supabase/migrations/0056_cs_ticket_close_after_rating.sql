insert into cs.cs_settings (key, value, description) values
  ('ticket.auto_close_days', '3',
   'Tiket selesai yang belum dinilai nasabah ditutup otomatis setelah sekian hari (1–30). Tiket yang sudah dinilai langsung ditutup')
on conflict (key) do nothing;

alter table cs.tickets add column close_reason text;
alter table cs.tickets add constraint tickets_close_reason_check check (close_reason is null or status = 'closed');

update cs.tickets t
   set close_reason = e.reason
  from (select distinct on (x.session_id) x.session_id, x.data ->> 'reason' as reason
        from cs.session_events x
        where x.type = 'closed'
        order by x.session_id, x.created_at desc, x.id desc) e
 where e.session_id = t.id and t.status = 'closed';

create or replace function cs.reopen_until(t cs.tickets)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select case when t.status = 'resolved' and t.rating is null
              then t.resolved_at + make_interval(days => cs.setting_int('ticket.auto_close_days')) end;
$$;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes')
      or p_key like 'messages.%';
$$;

create or replace function cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_day   text;
  v_hours jsonb;
  v_lang  text;
  v_min   integer := 1;
  v_max   integer := 240;
  v_error text := 'Batas alert 1–240 menit';
begin
  case
    when p_key = 'assignment.mode' then
      if jsonb_typeof(p_value) <> 'string' or p_value #>> '{}' not in ('claim', 'auto_assign') then
        perform private.api_error(400, 'invalid_setting', 'Mode penugasan harus claim atau auto_assign');
      end if;
    when p_key in ('ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'alerts.unclaimed_minutes',
                   'alerts.p1_unclaimed_minutes') then
      if p_key = 'ticket.auto_release_offline_minutes' then
        v_min := 0;
        v_max := 1440;
        v_error := 'Lepas otomatis 0–1440 menit (0 = mati)';
      elsif p_key = 'ticket.auto_close_days' then
        v_max := 30;
        v_error := 'Tutup otomatis 1–30 hari';
      end if;
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_error);
      end if;
    when p_key = 'service.hours' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{1,2,3,4,5,6,7}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Jam layanan harus berisi hari 1–7');
      end if;
      for v_day, v_hours in select * from jsonb_each(p_value) loop
        if jsonb_typeof(v_hours) = 'null' then
          continue;
        end if;
        if jsonb_typeof(v_hours) <> 'array' or jsonb_array_length(v_hours) <> 2
           or (v_hours ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_hours ->> 1) !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$'
           or (v_hours ->> 0) >= (v_hours ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam layanan hari ' || v_day || ' harus HH:MM–HH:MM dan jam buka sebelum jam tutup');
        end if;
      end loop;
    when p_key like 'messages.%' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{en,id}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Pesan otomatis harus punya teks id dan en');
      end if;
      foreach v_lang in array array['id', 'en'] loop
        if jsonb_typeof(p_value -> v_lang) <> 'string' or char_length(btrim(p_value ->> v_lang)) not between 2 and 500 then
          perform private.api_error(400, 'invalid_setting', 'Teks pesan 2–500 karakter');
        end if;
        if not (cs.placeholders(p_value ->> v_lang) <@ cs.placeholders(p_old ->> v_lang)) then
          perform private.api_error(400, 'invalid_setting',
            'Variabel yang boleh dipakai: ' || coalesce(nullif(array_to_string(cs.placeholders(p_old ->> v_lang), ', '), ''), '-'));
        end if;
      end loop;
    else
      perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end case;
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
         closed_by = case when p_reason in ('customer', 'rated') then auth.uid() end,
         close_reason = p_reason
   where id = t.id
  returning * into t;
  perform cs.leave_staff(t.room_id);
  if v_prev is not null then
    perform cs.refresh_agent_load(v_prev);
  end if;
  perform cs.system_message(t, 'ticket_closed');
  perform cs.broadcast_ticket(t, 'ticket_closed', array[v_prev, t.last_owner_id]);
  return t;
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
    'close_reason', t.close_reason,
    'reopen_until', cs.reopen_until(t),
    'rating', t.rating,
    'can_rate', t.status in ('resolved', 'closed') and t.first_claimed_at is not null and t.rating is null
  );
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
  if t.status = 'resolved' then
    t := cs.finalize_ticket(t.id, 'rated');
  else
    perform cs.broadcast_ticket(t, 'ticket_updated', array[t.last_owner_id]);
  end if;
  return cs.ticket_customer_view(t);
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
    select * into t from cs.tickets x
    where x.room_id = new.room_id
    order by (x.status in ('open', 'claimed', 'waiting_customer')) desc, x.created_at desc
    limit 1
    for update;
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
    elsif t.id is not null and now() < cs.reopen_until(t) then
      t := cs.reopen_ticket(t);
    elsif t.id is not null then
      perform private.api_error(409, 'ticket_closed',
        'Tiket #' || t.ticket_number || ' sudah ditutup. Buat tiket baru untuk chat lagi');
    else
      t := cs.open_ticket(new.sender_id, cs.setting('ticket.default_topic') #>> '{}', 'id', '{}', '{}', new.body);
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
    select t.id, case when t.rating is not null then 'rated' else 'reopen_window_passed' end as reason
    from cs.tickets t
    where t.status = 'resolved' and (t.rating is not null or not (now() < cs.reopen_until(t)))
    for update skip locked
  loop
    perform cs.finalize_ticket(r.id, r.reason);
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

  if cs.setting('assignment.mode') #>> '{}' = 'auto_assign' then
    v_assigned := cs.auto_assign_open();
  end if;

  return jsonb_build_object('transfers_expired', v_expired, 'tickets_closed', v_closed,
                            'tickets_released', v_released, 'tickets_assigned', v_assigned);
end;
$$;

delete from cs.cs_settings where key = 'ticket.reopen_hours';

create or replace function cs.report_range(p_from date, p_to date)
returns tstzrange
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    perform private.api_error(400, 'invalid_range', 'Rentang laporan 1–93 hari');
  end if;
  return tstzrange(p_from::timestamp at time zone 'Asia/Jakarta', (p_to + 1)::timestamp at time zone 'Asia/Jakarta');
end;
$$;

create or replace function cs.minutes_between(p_from timestamptz, p_to timestamptz)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round((extract(epoch from p_to - p_from) / 60)::numeric, 1);
$$;

create or replace function cs.event_count(p_ticket_id uuid, p_type text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from cs.session_events e where e.session_id = p_ticket_id and e.type = p_type;
$$;

create or replace function cs_api.report_customers(p_from date, p_to date, p_search text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_range  tstzrange := cs.report_range(p_from, p_to);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_like   text;
begin
  if char_length(coalesce(v_search, '')) > 100 then
    perform private.api_error(400, 'invalid_search', 'Pencarian maksimal 100 karakter');
  end if;
  v_like := '%' || replace(replace(replace(coalesce(v_search, ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(r.item order by r.tickets desc, r.last_ticket_at desc, r.id)
    from (
      select p.id, count(*) as tickets, max(t.created_at) as last_ticket_at,
             jsonb_build_object(
               'id', p.id, 'display_name', p.display_name, 'username', p.username,
               'tickets', count(*),
               'resolved', count(*) filter (where t.resolved_at is not null),
               'reopened', count(*) filter (where cs.event_count(t.id, 'reopened') > 0),
               'complaints', count(*) filter (where t.complaint_received_at is not null),
               'avg_first_response_minutes', round(avg(cs.minutes_between(t.created_at, t.first_response_at)), 1),
               'avg_resolution_minutes', round(avg(cs.minutes_between(t.created_at, t.resolved_at)), 1),
               'avg_rating', round(avg(t.rating)::numeric, 2),
               'ratings', count(t.rating),
               'closed_unrated', count(*) filter (where t.close_reason = 'reopen_window_passed'),
               'last_ticket_at', max(t.created_at)) as item
      from cs.tickets t
      join public.profiles p on p.id = t.customer_id
      where t.created_at >= lower(v_range) and t.created_at < upper(v_range)
        and (v_search is null or p.display_name ilike v_like or p.username ilike v_like)
      group by p.id, p.display_name, p.username
      order by count(*) desc, max(t.created_at) desc, p.id
      limit 200) r), '[]');
end;
$$;

create or replace function cs_api.report_customer_trail(p_customer_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_range    tstzrange := cs.report_range(p_from, p_to);
  v_customer jsonb;
begin
  select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username) into v_customer
  from public.profiles p
  where p.id = p_customer_id and exists (select 1 from cs.tickets t where t.customer_id = p.id);
  if v_customer is null then
    perform private.api_error(404, 'customer_not_found', 'Nasabah tidak ditemukan');
  end if;
  perform cs.audit('report.customer_trail', null, p_customer_id, jsonb_build_object('from', p_from, 'to', p_to));
  return jsonb_build_object(
    'customer', v_customer,
    'from', p_from,
    'to', p_to,
    'tickets', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', t.id, 'ticket_number', t.ticket_number, 'topic', t.topic,
               'topic_name', coalesce(tp.name_id, t.topic), 'status', t.status, 'priority', t.priority,
               'flags', to_jsonb(t.flags), 'outcome', t.outcome, 'close_reason', t.close_reason,
               'agent', cs.agent_name(coalesce(t.owner_agent_id, t.last_owner_id)),
               'created_at', t.created_at, 'first_claimed_at', t.first_claimed_at,
               'first_response_at', t.first_response_at, 'resolved_at', t.resolved_at, 'closed_at', t.closed_at,
               'claim_minutes', cs.minutes_between(t.created_at, t.first_claimed_at),
               'first_response_minutes', cs.minutes_between(t.created_at, t.first_response_at),
               'resolution_minutes', cs.minutes_between(t.created_at, t.resolved_at),
               'rating', t.rating, 'rating_comment', t.rating_comment, 'rated_at', t.rated_at,
               'reopened', cs.event_count(t.id, 'reopened'),
               'transfers', cs.event_count(t.id, 'transferred') + cs.event_count(t.id, 'reassigned'),
               'events', coalesce((
                 select jsonb_agg(jsonb_build_object('type', e.type, 'actor_type', e.actor_type,
                                                     'actor_name', cs.agent_name(e.actor_id),
                                                     'data', e.data, 'created_at', e.created_at)
                                  order by e.created_at, e.id)
                 from cs.session_events e where e.session_id = t.id), '[]'))
             order by t.created_at desc)
      from (select x.* from cs.tickets x
            where x.customer_id = p_customer_id and x.created_at >= lower(v_range) and x.created_at < upper(v_range)
            order by x.created_at desc
            limit 100) t
      left join cs.support_topics tp on tp.code = t.topic), '[]'));
end;
$$;

revoke execute on function cs.reopen_until(cs.tickets) from public;
revoke execute on function cs.report_range(date, date) from public;
revoke execute on function cs.minutes_between(timestamptz, timestamptz) from public;
revoke execute on function cs.event_count(uuid, text) from public;
revoke execute on function cs_api.report_customers(date, date, text) from public;
revoke execute on function cs_api.report_customer_trail(uuid, date, date) from public;
grant execute on function cs_api.report_customers(date, date, text) to authenticated;
grant execute on function cs_api.report_customer_trail(uuid, date, date) to authenticated;
