create index tickets_first_response_idx on care.tickets (first_response_due_at)
  where first_response_at is null and status not in ('resolved', 'closed', 'cancelled');

create or replace function care.alert_once(p_ticket_id uuid, p_kind text, p_stage text, p_due_at timestamptz)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  insert into care.sla_alerts (ticket_id, kind, stage, due_at) values (p_ticket_id, p_kind, p_stage, p_due_at)
  on conflict do nothing;
  return found;
end;
$$;

create or replace function care.run_sweep(p_now timestamptz default now())
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_today      date := care.local_date(p_now);
  v_stages     integer[] := array(
    select x::integer from jsonb_array_elements_text(coalesce(care.setting('complaint.warning_stages'), '[3, 1, 0]')) x
    order by 1);
  v_horizon    timestamptz;
  v_reminder   integer := care.setting_int('ticket.pending_reminder_business_days');
  v_autoclose  integer := care.setting_int('ticket.pending_autoresolve_business_days');
  v_reopen     integer := care.setting_int('ticket.reopen_days');
  v_objection  integer := care.setting_int('complaint.objection_days');
  r            record;
  v_stage      text;
  v_days       integer;
  v_warnings   integer := 0;
  v_documents  integer := 0;
  v_breaches   integer := 0;
  v_reminders  integer := 0;
  v_resolved   integer := 0;
  v_closed     integer := 0;
begin
  v_horizon := care.end_of_business_day(care.add_business_days(v_today, coalesce(v_stages[cardinality(v_stages)], 0)));
  for r in
    select t.id, t.team_id, t.assignee_id, c.number, c.due_at
    from care.complaints c
    join care.tickets t on t.id = c.ticket_id
    where c.reclassified_at is null and c.due_at is not null and c.clock_paused_at is null
      and c.due_at <= v_horizon
      and t.status not in ('resolved', 'closed', 'cancelled')
    order by c.due_at
    limit 500
  loop
    if p_now > r.due_at then
      v_stage := 'overdue';
    else
      v_days := care.business_days_between(v_today, care.local_date(r.due_at));
      v_stage := (select 'h' || s from unnest(v_stages) s where v_days <= s order by s limit 1);
    end if;
    continue when v_stage is null or not care.alert_once(r.id, 'regulatory', v_stage, r.due_at);
    perform care.add_event(r.id, 'sla_warning', 'internal',
      jsonb_build_object('kind', 'regulatory', 'stage', v_stage, 'due_at', r.due_at));
    perform care.notify_staff(
      array[r.assignee_id] || care.team_staff(r.team_id, '{supervisor}')
        || case when v_stage in ('h0', 'overdue') then care.role_staff('{compliance}') else '{}'::uuid[] end,
      case when v_stage = 'overdue' then 'complaint_overdue' else 'complaint_deadline' end, r.id,
      jsonb_build_object('number', r.number, 'stage', v_stage, 'due_at', r.due_at));
    v_warnings := v_warnings + 1;
  end loop;

  for r in
    select t.id, t.team_id, t.assignee_id, c.number, c.documents_due_at
    from care.complaints c
    join care.tickets t on t.id = c.ticket_id
    where c.reclassified_at is null and c.documents_complete_at is null
      and c.documents_due_at < p_now
      and t.status not in ('resolved', 'closed', 'cancelled')
    order by c.documents_due_at
    limit 500
  loop
    continue when not care.alert_once(r.id, 'documents', 'expired', r.documents_due_at);
    perform care.add_event(r.id, 'sla_warning', 'internal',
      jsonb_build_object('kind', 'documents', 'stage', 'expired', 'due_at', r.documents_due_at));
    perform care.notify_staff(array[r.assignee_id] || care.team_staff(r.team_id, '{supervisor}'),
      'documents_overdue', r.id, jsonb_build_object('number', r.number, 'due_at', r.documents_due_at));
    v_documents := v_documents + 1;
  end loop;

  for r in
    select t.id, t.team_id, t.assignee_id, 'first_response' as kind, t.first_response_due_at as due_at
    from care.tickets t
    where t.first_response_at is null and t.first_response_due_at < p_now and t.sla_paused_at is null
      and t.status not in ('resolved', 'closed', 'cancelled')
    union all
    select t.id, t.team_id, t.assignee_id, 'resolution', t.resolution_due_at
    from care.tickets t
    where t.resolution_due_at < p_now and t.sla_paused_at is null
      and t.status not in ('resolved', 'closed', 'cancelled')
    limit 1000
  loop
    continue when not care.alert_once(r.id, r.kind, 'breached', r.due_at);
    perform care.add_event(r.id, 'sla_warning', 'internal',
      jsonb_build_object('kind', r.kind, 'stage', 'breached', 'due_at', r.due_at));
    perform care.notify_staff(array[r.assignee_id] || care.team_staff(r.team_id, '{supervisor}'),
      'sla_breached', r.id, jsonb_build_object('kind', r.kind, 'due_at', r.due_at));
    v_breaches := v_breaches + 1;
  end loop;

  for r in
    select t.id, t.status_changed_at,
           exists (select 1 from care.complaints c where c.ticket_id = t.id and c.reclassified_at is null) as is_complaint
    from care.tickets t
    where t.status = 'pending_customer' and t.status_changed_at < p_now - interval '1 day'
    order by t.status_changed_at
    limit 500
  loop
    v_days := care.business_days_between(care.local_date(r.status_changed_at), v_today);
    if not r.is_complaint and v_days >= v_autoclose then
      update care.tickets set
        root_cause = 'no_customer_response',
        resolution_summary = 'Diselesaikan otomatis karena tidak ada tanggapan dari nasabah'
      where id = r.id;
      perform care.set_status(r.id, 'resolved', jsonb_build_object('reason', 'no_customer_response'));
      v_resolved := v_resolved + 1;
    elsif v_days >= v_reminder and care.alert_once(r.id, 'pending_customer', 'reminder', r.status_changed_at) then
      perform care.add_event(r.id, 'reminder_sent', 'public', jsonb_build_object('waiting_since', r.status_changed_at));
      v_reminders := v_reminders + 1;
    end if;
  end loop;

  for r in
    select t.id, t.resolved_at,
           exists (select 1 from care.complaints c where c.ticket_id = t.id and c.reclassified_at is null) as is_complaint
    from care.tickets t
    where t.status = 'resolved'
      and t.resolved_at < p_now - make_interval(days => least(v_reopen, v_objection))
    order by t.resolved_at
    limit 500
  loop
    continue when case when r.is_complaint
                       then p_now <= care.regulatory_deadline(r.resolved_at, v_objection)
                       else p_now <= r.resolved_at + make_interval(days => v_reopen) end;
    perform care.set_status(r.id, 'closed', jsonb_build_object('reason', 'window_elapsed'));
    v_closed := v_closed + 1;
  end loop;

  return jsonb_build_object(
    'warnings', v_warnings, 'documents', v_documents, 'breaches', v_breaches,
    'reminders', v_reminders, 'auto_resolved', v_resolved, 'closed', v_closed);
end;
$$;

create or replace function care.run_retention(p_now timestamptz default now())
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_doomed        uuid[];
  v_tickets       integer;
  v_audit         integer;
  v_outbox        integer;
  v_notifications integer;
begin
  perform set_config('care.retention', 'on', true);

  select coalesce(array_agg(t.id), '{}') into v_doomed
  from (
    select t.id from care.tickets t
    where t.retain_until < p_now and not t.legal_hold
    order by t.retain_until
    limit 1000
  ) t;
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select 'care-documents', 'letters/' || x::text || '/', 'care_retention'
  from unnest(v_doomed) x
  where exists (select 1 from care.official_letters l where l.ticket_id = x);
  delete from care.tickets where id = any (v_doomed);
  get diagnostics v_tickets = row_count;

  delete from care.audit_log
   where created_at < p_now - make_interval(years => care.setting_int('retention.audit_years'));
  get diagnostics v_audit = row_count;

  delete from care.outbox where status <> 'pending' and finished_at < p_now - interval '30 days';
  get diagnostics v_outbox = row_count;

  delete from care.staff_notifications where created_at < p_now - interval '180 days';
  get diagnostics v_notifications = row_count;

  perform set_config('care.retention', 'off', true);
  return jsonb_build_object('tickets', v_tickets, 'audit_log', v_audit, 'outbox', v_outbox,
                            'staff_notifications', v_notifications);
end;
$$;

revoke all on function care.alert_once(uuid, text, text, timestamptz) from public;
revoke all on function care.run_sweep(timestamptz) from public;
revoke all on function care.run_retention(timestamptz) from public;

select cron.schedule('care-sweep', '* * * * *', 'select care.run_sweep()');
select cron.schedule('care-partitions', '10 2 * * *', 'select care.ensure_partitions(3)');
select cron.schedule('care-retention', '40 3 * * *', 'select care.run_retention()');
