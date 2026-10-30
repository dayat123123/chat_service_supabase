create or replace function care.is_extended(p_complaint care.complaints)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    p_complaint.extension_count > 0
    and (p_complaint.last_objection_at is null or p_complaint.extended_at > p_complaint.last_objection_at),
    false);
$$;

create or replace function care.set_status(p_ticket_id uuid, p_to text, p_data jsonb default '{}')
returns void
language plpgsql
set search_path = ''
as $$
declare
  t          care.tickets;
  v_extended boolean;
  v_from     text;
  v_to       text;
begin
  select * into t from care.tickets where id = p_ticket_id for update;
  if t.id is null then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not care.transition_allowed(t.status, p_to) then
    perform private.api_error(409, 'invalid_transition',
      format('Status tiket tidak bisa diubah dari %s ke %s', t.status, p_to));
  end if;
  if p_to = 'extended' and t.kind <> 'complaint' then
    perform private.api_error(409, 'invalid_transition', 'Hanya pengaduan yang bisa diperpanjang');
  end if;

  if p_to = 'pending_customer' then
    insert into care.ticket_sla_pauses (ticket_id, paused_at) values (p_ticket_id, now())
    on conflict do nothing;
  elsif t.status = 'pending_customer' then
    update care.ticket_sla_pauses set resumed_at = now()
     where ticket_id = p_ticket_id and resumed_at is null;
  end if;

  update care.tickets set
    status = p_to,
    status_changed_at = now(),
    sla_paused_at = case when p_to = 'pending_customer' then now() end,
    resolved_at = case when p_to = 'resolved' then now() when p_to = 'closed' then resolved_at end,
    closed_at = case when p_to = 'closed' then now() end,
    cancelled_at = case when p_to = 'cancelled' then now() end,
    retain_until = case when p_to in ('closed', 'cancelled') then care.retention_until(p_ticket_id, now()) end
  where id = p_ticket_id;

  if t.status = 'pending_customer' then
    perform care.refresh_sla(p_ticket_id);
  end if;

  select care.is_extended(c) into v_extended
  from care.complaints c where c.ticket_id = p_ticket_id and c.reclassified_at is null;
  v_from := care.status_label(t.status, v_extended, 'id');
  v_to := care.status_label(p_to, v_extended, 'id');
  perform care.add_event(p_ticket_id, 'status_changed',
    case when v_from <> v_to then 'public' else 'internal' end,
    jsonb_build_object('from', t.status, 'to', p_to) || coalesce(p_data, '{}'));
end;
$$;

create or replace function care.public_summary(p_ticket_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'number', t.number,
    'complaint_number', c.number,
    'kind', t.kind,
    'kind_label', care.label('kind', t.kind, t.language),
    'channel', t.channel,
    'category_id', t.category_id,
    'category', case when t.language = 'en' then e.path_en else e.path_id end,
    'subject', t.subject,
    'status', t.status,
    'status_label', care.status_label(t.status, care.is_extended(c), t.language),
    'due_at', c.due_at,
    'created_at', t.created_at,
    'updated_at', t.updated_at)
  from care.tickets t
  left join care.complaints c on c.ticket_id = t.id and c.reclassified_at is null
  cross join lateral care.category_effective(t.category_id) e
  where t.id = p_ticket_id;
$$;

revoke all on function care.is_extended(care.complaints) from public;
