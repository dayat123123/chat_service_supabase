create or replace function care.require_text(p_value text, p_min integer, p_max integer, p_code text, p_label text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_value text := btrim(coalesce(p_value, ''));
begin
  if char_length(v_value) < p_min or char_length(v_value) > p_max then
    perform private.api_error(400, p_code, format('%s wajib diisi %s–%s karakter', p_label, p_min, p_max));
  end if;
  return v_value;
end;
$$;

create or replace function care.try_timestamptz(p_value text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  return nullif(btrim(p_value), '')::timestamptz;
exception when others then
  return null;
end;
$$;

create or replace function care.form_definition(p_form_id uuid, p_language text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'key', f.key,
           'kind', f.kind,
           'label', case when p_language = 'en' then f.label_en else f.label_id end,
           'required', f.required,
           'options', (select coalesce(jsonb_agg(jsonb_build_object(
                                 'value', o ->> 'value', 'label', coalesce(o ->> p_language, o ->> 'id'))), '[]')
                       from jsonb_array_elements(f.options) o))
         order by f.sort_order, f.key), '[]')
  from care.form_fields f
  where f.form_id = p_form_id;
$$;

create or replace function care.category_node(p_category_id uuid, p_language text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
begin
  return (
    select jsonb_build_object(
      'id', c.id,
      'code', c.code,
      'name', case when p_language = 'en' then c.name_en else c.name_id end,
      'kind', e.kind,
      'potential_complaint', e.potential_complaint,
      'required_documents', e.required_documents,
      'fields', case when e.is_leaf then care.form_definition(e.form_id, p_language) else '[]'::jsonb end,
      'children', coalesce((
        select jsonb_agg(care.category_node(k.id, p_language) order by k.sort_order, k.code)
        from care.categories k
        where k.parent_id = c.id and k.active), '[]'))
    from care.categories c
    cross join lateral care.category_effective(c.id) e
    where c.id = p_category_id);
end;
$$;

create or replace function care.validate_fields(p_form_id uuid, p_values jsonb)
returns setof care.ticket_field_values
language plpgsql
stable
set search_path = ''
as $$
declare
  f       care.form_fields;
  r       care.ticket_field_values;
  v_value jsonb;
  v_text  text;
  v_kind  text;
begin
  if p_values is not null and jsonb_typeof(p_values) <> 'object' then
    perform private.api_error(400, 'invalid_fields', 'Isian formulir harus berupa objek');
  end if;
  if exists (
    select 1 from jsonb_object_keys(coalesce(p_values, '{}')) k (key)
    where not exists (select 1 from care.form_fields x where x.form_id = p_form_id and x.key = k.key)
  ) then
    perform private.api_error(400, 'unknown_field', 'Ada isian yang tidak dikenal untuk kategori ini');
  end if;

  for f in select * from care.form_fields x where x.form_id = p_form_id order by x.sort_order, x.key loop
    v_value := p_values -> f.key;
    v_kind := jsonb_typeof(v_value);
    if v_value is null or v_kind = 'null' or (v_kind = 'string' and btrim(v_value #>> '{}') = '') then
      if f.required then
        perform private.api_error(400, 'field_required', format('Isian "%s" wajib diisi', f.label_id));
      end if;
      continue;
    end if;
    v_text := btrim(v_value #>> '{}');

    if f.kind in ('text', 'textarea') then
      if v_kind <> 'string' or char_length(v_text) > (case when f.kind = 'text' then 300 else 4000 end) then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" terlalu panjang', f.label_id));
      end if;
      v_value := to_jsonb((care.mask_sensitive(v_text)).masked);
    elsif f.kind = 'number' then
      if v_kind <> 'number' then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus angka', f.label_id));
      end if;
    elsif f.kind = 'money' then
      if v_kind <> 'number' or v_value::numeric < 0 or v_value::numeric <> trunc(v_value::numeric) then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus nominal rupiah bulat', f.label_id));
      end if;
    elsif f.kind = 'boolean' then
      if v_kind <> 'boolean' then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus ya/tidak', f.label_id));
      end if;
    elsif f.kind = 'date' then
      if v_text !~ '^\d{4}-\d{2}-\d{2}$' or care.try_timestamptz(v_text) is null then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus tanggal (YYYY-MM-DD)', f.label_id));
      end if;
      v_value := to_jsonb(v_text);
    elsif f.kind = 'datetime' then
      if care.try_timestamptz(v_text) is null then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus tanggal dan jam', f.label_id));
      end if;
      v_value := to_jsonb(care.try_timestamptz(v_text));
    elsif f.kind = 'select' then
      if not exists (select 1 from jsonb_array_elements(f.options) o where o ->> 'value' = v_text) then
        perform private.api_error(400, 'invalid_field', format('Pilihan "%s" tidak dikenal', f.label_id));
      end if;
      v_value := to_jsonb(v_text);
    elsif f.kind in ('order', 'cash_transaction') then
      if v_text !~ '^[A-Za-z0-9._:-]{1,64}$' then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" tidak valid', f.label_id));
      end if;
      v_value := to_jsonb(v_text);
    elsif f.kind = 'stock' then
      v_text := upper(v_text);
      if v_text !~ '^[A-Z0-9-]{1,12}$' then
        perform private.api_error(400, 'invalid_field', format('Isian "%s" harus kode saham', f.label_id));
      end if;
      v_value := to_jsonb(v_text);
    end if;

    r.field_key := f.key;
    r.kind := f.kind;
    r.label_id := f.label_id;
    r.label_en := f.label_en;
    r.value := v_value;
    return next r;
  end loop;
end;
$$;

create or replace function care.create_ticket(
  p_customer_id uuid,
  p_channel     text,
  p_category_id uuid,
  p_subject     text,
  p_description text,
  p_fields      jsonb,
  p_context     jsonb,
  p_as_complaint boolean,
  p_language    text,
  p_received_at timestamptz,
  p_client_id   uuid
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  e         record;
  v_subject record;
  v_details record;
  v_id      uuid;
  v_kind    text;
  v_period  text := to_char(care.local_date(now()), 'YYYY-MM');
  v_item    record;
  v_item_id uuid;
begin
  select * into e from care.category_effective(p_category_id);
  if e.id is null or not e.active then
    perform private.api_error(404, 'category_not_found', 'Kategori tidak ditemukan');
  end if;
  if not e.is_leaf then
    perform private.api_error(400, 'category_not_leaf', 'Pilih subkategori yang paling sesuai');
  end if;
  select * into v_subject from care.mask_sensitive(care.require_text(p_subject, 3, 200, 'invalid_subject', 'Judul'));
  select * into v_details from care.mask_sensitive(care.require_text(p_description, 0, 4000, 'invalid_description', 'Deskripsi'));
  v_kind := case when coalesce(p_as_complaint, false) then 'complaint' else e.kind end;

  insert into care.tickets
    (number, kind, channel, customer_id, language, category_id, subject, description, priority, team_id,
     created_by, client_id, received_at, masked_kinds)
  values (
    care.format_number(care.setting_text('numbering.ticket_prefix'), v_period, care.next_number('ticket', v_period), 6),
    v_kind, p_channel, p_customer_id, case when p_language = 'en' then 'en' else 'id' end, e.id,
    v_subject.masked, v_details.masked, e.priority, e.team_id, coalesce(auth.uid(), p_customer_id), p_client_id,
    p_received_at,
    array(select distinct k from unnest(v_subject.kinds || v_details.kinds) k order by k))
  returning id into v_id;

  insert into care.ticket_field_values (ticket_id, field_key, kind, label_id, label_en, value)
  select v_id, x.field_key, x.kind, x.label_id, x.label_en, x.value
  from care.validate_fields(e.form_id, p_fields) x;

  for v_item in
    select f.kind, f.value #>> '{}' as ref
    from care.ticket_field_values f
    where f.ticket_id = v_id and f.kind in ('order', 'cash_transaction')
  loop
    insert into care.ticket_related_items (ticket_id, kind, ref) values (v_id, v_item.kind, v_item.ref)
    on conflict do nothing
    returning id into v_item_id;
    if v_item_id is not null then
      perform care.enqueue_job('fetch_snapshot', v_id, jsonb_build_object('item_id', v_item_id), 6);
    end if;
  end loop;

  if p_context is not null and jsonb_typeof(p_context) = 'object' and p_context <> '{}'::jsonb then
    insert into care.ticket_context
      (ticket_id, app_version, platform, os, device_model, locale, connection, last_screen, error_code, occurred_at, logs)
    values (
      v_id, left(p_context ->> 'app_version', 40), left(p_context ->> 'platform', 20), left(p_context ->> 'os', 80),
      left(p_context ->> 'device_model', 80), left(p_context ->> 'locale', 20), left(p_context ->> 'connection', 40),
      left(p_context ->> 'last_screen', 80), left(p_context ->> 'error_code', 40),
      care.try_timestamptz(p_context ->> 'occurred_at'),
      (care.mask_sensitive(left(p_context ->> 'logs', 16000))).masked);
  end if;

  perform care.refresh_sla(v_id);
  perform care.add_event(v_id, 'created', 'public',
    jsonb_build_object('channel', p_channel, 'kind', v_kind, 'category_id', e.id));
  if v_kind = 'complaint' then
    perform care.register_complaint(v_id, p_received_at);
  end if;
  if e.priority = 'P1' then
    perform care.notify_staff(
      care.team_staff(e.team_id, '{agent_l1,agent_l2,specialist,supervisor}'), 'urgent_ticket', v_id,
      jsonb_build_object('priority', 'P1'));
  end if;
  return v_id;
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
    'status_label', care.status_label(t.status, coalesce(c.extension_count > 0, false), t.language),
    'due_at', c.due_at,
    'created_at', t.created_at,
    'updated_at', t.updated_at)
  from care.tickets t
  left join care.complaints c on c.ticket_id = t.id and c.reclassified_at is null
  cross join lateral care.category_effective(t.category_id) e
  where t.id = p_ticket_id;
$$;

create or replace function care.public_timeline(p_ticket_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.item order by x.at, x.seq), '[]')
  from (
    select e.created_at as at, e.id as seq,
           jsonb_build_object('kind', 'event', 'type', e.type, 'at', e.created_at, 'actor', e.actor_type,
                              'data', e.data) as item
    from care.ticket_events e
    where e.ticket_id = p_ticket_id and e.visibility = 'public'
    union all
    select m.created_at, m.id,
           jsonb_build_object('kind', 'message', 'id', m.id, 'at', m.created_at, 'actor', m.author_type,
                              'author_name', s.display_name, 'agent_code', s.agent_code, 'body', m.body,
                              'masked', cardinality(m.masked_kinds) > 0)
    from care.ticket_messages m
    left join care.staff s on m.author_type = 'staff' and s.user_id = m.author_id
    where m.ticket_id = p_ticket_id and m.visibility = 'public' and m.status = 'sent'
  ) x;
$$;

create or replace function care.customer_ticket(p_ticket_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select care.public_summary(t.id) || jsonb_build_object(
    'description', t.description,
    'language', t.language,
    'received_at', t.received_at,
    'resolution_summary', t.resolution_summary,
    'complaint', case when c.ticket_id is not null then jsonb_build_object(
      'number', c.number,
      'form', c.form,
      'received_at', c.received_at,
      'due_at', c.due_at,
      'documents_required', c.documents_required,
      'documents_due_at', c.documents_due_at,
      'documents_complete', c.documents_complete_at is not null,
      'extension_count', c.extension_count,
      'final_response_at', c.final_response_at,
      'objection_deadline', case when c.final_response_at is not null then w.objection_deadline end) end,
    'can', jsonb_build_object(
      'reply', t.status not in ('resolved', 'closed', 'cancelled'),
      'cancel', t.status in ('new', 'open')
                or (c.ticket_id is not null and t.status not in ('resolved', 'closed', 'cancelled')),
      'confirm_resolved', c.ticket_id is null and t.status not in ('resolved', 'closed', 'cancelled'),
      'reopen', coalesce(c.ticket_id is null and t.status = 'resolved' and now() <= w.reopen_deadline, false),
      'escalate', c.ticket_id is null and t.status not in ('closed', 'cancelled'),
      'object', coalesce(c.ticket_id is not null and t.status = 'resolved' and c.final_response_at is not null
                         and now() <= w.objection_deadline, false)),
    'fields', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'key', f.field_key, 'kind', f.kind,
               'label', case when t.language = 'en' then f.label_en else f.label_id end,
               'value', f.value) order by f.field_key), '[]')
      from care.ticket_field_values f where f.ticket_id = t.id),
    'related', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', r.id, 'kind', r.kind, 'ref', r.ref, 'status', r.status, 'snapshot', r.snapshot)
             order by r.created_at), '[]')
      from care.ticket_related_items r where r.ticket_id = t.id),
    'letters', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', l.id, 'kind', l.kind, 'number', l.number, 'issued_at', l.issued_at,
               'ready', l.status = 'ready',
               'storage_path', case when l.status = 'ready' then l.storage_path end)
             order by l.issued_at), '[]')
      from care.official_letters l where l.ticket_id = t.id),
    'timeline', care.public_timeline(t.id))
  from care.tickets t
  left join care.complaints c on c.ticket_id = t.id and c.reclassified_at is null
  cross join lateral (
    select
      t.resolved_at + make_interval(days => care.setting_int('ticket.reopen_days')) as reopen_deadline,
      care.regulatory_deadline(t.resolved_at, care.setting_int('complaint.objection_days')) as objection_deadline
  ) w
  where t.id = p_ticket_id;
$$;

create or replace function care.staff_summary(p_ticket_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'number', t.number,
    'kind', t.kind,
    'channel', t.channel,
    'status', t.status,
    'priority', t.priority,
    'subject', t.subject,
    'language', t.language,
    'category_id', t.category_id,
    'category', e.path_id,
    'team', jsonb_build_object('id', tm.id, 'code', tm.code, 'name', tm.name_id),
    'assignee', case when s.user_id is not null then
      jsonb_build_object('id', s.user_id, 'name', s.display_name, 'agent_code', s.agent_code) end,
    'customer', jsonb_build_object(
      'id', p.id,
      'name', coalesce(nullif(btrim(p.display_name), ''), p.username::text),
      'deleted', p.deleted_at is not null),
    'complaint', case when c.ticket_id is not null then jsonb_build_object(
      'number', c.number,
      'form', c.form,
      'due_at', c.due_at,
      'business_days_left', case when c.due_at is not null then
        care.business_days_between(care.local_date(now()), care.local_date(c.due_at)) end,
      'overdue', c.due_at is not null and now() > c.due_at,
      'clock_paused', c.clock_paused_at is not null,
      'documents_complete', c.documents_complete_at is not null,
      'extension_count', c.extension_count) end,
    'sla', jsonb_build_object(
      'first_response_due_at', t.first_response_due_at,
      'first_response_at', t.first_response_at,
      'resolution_due_at', t.resolution_due_at,
      'paused', t.sla_paused_at is not null),
    'received_at', t.received_at,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'status_changed_at', t.status_changed_at)
  from care.tickets t
  join care.teams tm on tm.id = t.team_id
  join public.profiles p on p.id = t.customer_id
  left join care.staff s on s.user_id = t.assignee_id
  left join care.complaints c on c.ticket_id = t.id and c.reclassified_at is null
  cross join lateral care.category_effective(t.category_id) e
  where t.id = p_ticket_id;
$$;

create or replace function care.staff_ticket(p_ticket_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select care.staff_summary(t.id) || jsonb_build_object(
    'description', t.description,
    'created_by', t.created_by,
    'masked_kinds', t.masked_kinds,
    'root_cause', t.root_cause,
    'resolution_summary', t.resolution_summary,
    'resolved_at', t.resolved_at,
    'closed_at', t.closed_at,
    'cancelled_at', t.cancelled_at,
    'complaint_detail', (select to_jsonb(c) - 'ticket_id' from care.complaints c where c.ticket_id = t.id),
    'pending_reclassification', (
      select to_jsonb(r) from care.reclassification_requests r where r.ticket_id = t.id and r.decision is null),
    'allowed_statuses', (
      select coalesce(jsonb_agg(s.status order by s.status), '[]')
      from unnest(array['open', 'pending_customer', 'pending_internal', 'pending_third_party', 'escalated']) s (status)
      where care.transition_allowed(t.status, s.status)),
    'fields', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'key', f.field_key, 'kind', f.kind, 'label', f.label_id, 'value', f.value) order by f.field_key), '[]')
      from care.ticket_field_values f where f.ticket_id = t.id),
    'context', (select to_jsonb(x) - 'ticket_id' from care.ticket_context x where x.ticket_id = t.id),
    'related', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', r.id, 'kind', r.kind, 'ref', r.ref, 'status', r.status, 'snapshot', r.snapshot,
               'fetched_at', r.fetched_at) order by r.created_at), '[]')
      from care.ticket_related_items r where r.ticket_id = t.id),
    'letters', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', l.id, 'kind', l.kind, 'number', l.number, 'issued_at', l.issued_at, 'status', l.status,
               'email_status', l.email_status, 'sha256', l.sha256, 'storage_path', l.storage_path)
             order by l.issued_at), '[]')
      from care.official_letters l where l.ticket_id = t.id),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', e.id, 'type', e.type, 'at', e.created_at, 'actor', e.actor_type, 'actor_id', e.actor_id,
               'visibility', e.visibility, 'data', e.data) order by e.created_at, e.id), '[]')
      from care.ticket_events e where e.ticket_id = t.id),
    'messages', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', m.id, 'at', m.created_at, 'author_type', m.author_type, 'author_id', m.author_id,
               'author_name', s.display_name, 'agent_code', s.agent_code, 'visibility', m.visibility,
               'status', m.status, 'body', m.body, 'masked_kinds', m.masked_kinds) order by m.created_at, m.id), '[]')
      from care.ticket_messages m
      left join care.staff s on m.author_type = 'staff' and s.user_id = m.author_id
      where m.ticket_id = t.id))
  from care.tickets t
  where t.id = p_ticket_id;
$$;

create or replace function care.next_cursor(p_items jsonb, p_limit integer)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_array_length(p_items) = p_limit then
    jsonb_build_object('updated_at', p_items -> -1 -> 'updated_at', 'id', p_items -> -1 -> 'id') end;
$$;

create or replace function care.own_ticket(p_ticket_id uuid)
returns care.tickets
language plpgsql
set search_path = ''
as $$
declare
  t care.tickets;
begin
  select * into t from care.tickets
  where id = p_ticket_id and customer_id = care.require_customer()
  for update;
  if t.id is null then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return t;
end;
$$;

create or replace function care.workable_ticket(p_ticket_id uuid)
returns care.tickets
language plpgsql
set search_path = ''
as $$
declare
  t care.tickets;
begin
  perform care.require_staff('{agent_l1,agent_l2,specialist,supervisor,compliance}');
  select * into t from care.tickets where id = p_ticket_id for update;
  if t.id is null or not care.staff_can_view(t.team_id, t.assignee_id, t.customer_id) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return t;
end;
$$;

create or replace function care.active_complaint(p_ticket_id uuid)
returns care.complaints
language plpgsql
set search_path = ''
as $$
declare
  c care.complaints;
begin
  select * into c from care.complaints
  where ticket_id = p_ticket_id and reclassified_at is null
  for update;
  if c.ticket_id is null then
    perform private.api_error(409, 'not_a_complaint', 'Tiket ini bukan pengaduan');
  end if;
  return c;
end;
$$;

create or replace function care.claim_if_unassigned(p_ticket_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_me uuid := care.current_staff_id();
begin
  update care.tickets t set assignee_id = v_me
  where t.id = p_ticket_id
    and t.assignee_id is null
    and exists (select 1 from care.team_members tm where tm.team_id = t.team_id and tm.user_id = v_me);
  if found then
    perform care.add_event(p_ticket_id, 'assigned', 'internal', jsonb_build_object('assignee_id', v_me, 'self', true));
  end if;
end;
$$;

create or replace function care.ensure_open(p_ticket_id uuid, p_reason text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from care.tickets t where t.id = p_ticket_id and t.status = 'new') then
    perform care.set_status(p_ticket_id, 'open', jsonb_build_object('reason', p_reason));
  end if;
end;
$$;

create or replace function care.insert_message(
  p_ticket_id   uuid,
  p_author_type text,
  p_visibility  text,
  p_status      text,
  p_body        text,
  p_client_id   uuid
)
returns care.ticket_messages
language plpgsql
set search_path = ''
as $$
declare
  m care.ticket_messages;
begin
  insert into care.ticket_messages (ticket_id, author_type, author_id, visibility, status, body, client_id)
  values (p_ticket_id, p_author_type, auth.uid(), p_visibility, p_status, p_body, p_client_id)
  returning * into m;
  return m;
end;
$$;

create or replace function care.message_json(m care.ticket_messages)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', m.id, 'ticket_id', m.ticket_id, 'at', m.created_at, 'author_type', m.author_type,
    'visibility', m.visibility, 'status', m.status, 'body', m.body, 'masked_kinds', m.masked_kinds);
$$;

create or replace function care.existing_message(p_ticket_id uuid, p_client_id uuid)
returns care.ticket_messages
language sql
stable
set search_path = ''
as $$
  select * from care.ticket_messages m
  where p_client_id is not null and m.ticket_id = p_ticket_id and m.author_id = auth.uid() and m.client_id = p_client_id
  limit 1;
$$;

create or replace function care.on_job_dead(p_job care.outbox)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_letter care.official_letters;
  v_item   uuid;
  v_team   uuid;
begin
  if p_job.kind = 'fetch_snapshot' then
    v_item := (p_job.payload ->> 'item_id')::uuid;
    update care.ticket_related_items set status = 'unavailable', fetched_at = now()
     where id = v_item and status = 'pending';
    if found then
      perform care.add_event(p_job.ticket_id, 'snapshot_unavailable', 'internal', jsonb_build_object('item_id', v_item));
    end if;
  elsif p_job.kind in ('render_letter', 'email_letter') then
    select * into v_letter from care.official_letters where id = (p_job.payload ->> 'letter_id')::uuid;
    if p_job.kind = 'render_letter' then
      update care.official_letters set status = 'failed' where id = v_letter.id and status = 'pending';
    else
      update care.official_letters set email_status = 'failed' where id = v_letter.id and email_status = 'pending';
    end if;
    perform care.notify_staff(care.role_staff('{compliance}'), 'letter_delivery_failed', p_job.ticket_id,
      jsonb_build_object('letter_id', v_letter.id, 'number', v_letter.number, 'step', p_job.kind));
  elsif p_job.kind = 'secure_account' then
    select t.team_id into v_team from care.tickets t where t.id = p_job.ticket_id;
    perform care.add_event(p_job.ticket_id, 'secure_account_failed', 'public', jsonb_build_object('reason', 'unavailable'));
    perform care.notify_staff(
      care.team_staff(v_team, '{agent_l1,agent_l2,specialist,supervisor}') || care.role_staff('{compliance}'),
      'secure_account_failed', p_job.ticket_id, jsonb_build_object('reason', 'unavailable'));
  end if;
end;
$$;

create or replace function care_api.categories(p_language text default 'id')
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(care.category_node(c.id, p_language) order by c.sort_order, c.code), '[]')
  from care.categories c
  where c.parent_id is null and c.active;
$$;

create or replace function care_api.create_ticket(
  p_category_id  uuid,
  p_subject      text,
  p_description  text default '',
  p_fields       jsonb default '{}',
  p_context      jsonb default '{}',
  p_as_complaint boolean default false,
  p_language     text default 'id',
  p_client_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer uuid := care.require_customer();
  v_id       uuid;
begin
  if p_client_id is not null then
    select t.id into v_id from care.tickets t where t.created_by = v_customer and t.client_id = p_client_id;
    if v_id is not null then
      return care.customer_ticket(v_id);
    end if;
  end if;
  perform care.check_rate_limit(v_customer, 'care_ticket', 'care.tickets'::regclass, 'created_by');
  v_id := care.create_ticket(v_customer, 'app', p_category_id, p_subject, p_description, p_fields, p_context,
                             p_as_complaint, p_language, now(), p_client_id);
  return care.customer_ticket(v_id);
end;
$$;

create or replace function care_api.my_tickets(p_filter text default 'all', p_cursor jsonb default null, p_limit integer default 20)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_customer uuid := care.require_customer();
  v_limit    integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items    jsonb;
begin
  if coalesce(p_filter, 'all') not in ('all', 'open', 'waiting', 'done') then
    perform private.api_error(400, 'invalid_filter', 'Filter: all, open, waiting, atau done');
  end if;
  with page as (
    select t.id, t.updated_at
    from care.tickets t
    where t.customer_id = v_customer
      and (coalesce(p_filter, 'all') = 'all'
           or (p_filter = 'open' and t.status not in ('pending_customer', 'resolved', 'closed', 'cancelled'))
           or (p_filter = 'waiting' and t.status = 'pending_customer')
           or (p_filter = 'done' and t.status in ('resolved', 'closed', 'cancelled')))
      and (p_cursor is null
           or (t.updated_at, t.id) < ((p_cursor ->> 'updated_at')::timestamptz, (p_cursor ->> 'id')::uuid))
    order by t.updated_at desc, t.id desc
    limit v_limit
  )
  select coalesce(jsonb_agg(care.public_summary(p.id) order by p.updated_at desc, p.id desc), '[]')
  into v_items from page p;
  return jsonb_build_object('items', v_items, 'next_cursor', care.next_cursor(v_items, v_limit));
end;
$$;

create or replace function care_api.ticket_detail(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from care.tickets t where t.id = p_ticket_id and t.customer_id = care.require_customer()) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return care.customer_ticket(p_ticket_id);
end;
$$;

create or replace function care_api.post_message(p_ticket_id uuid, p_body text, p_client_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      care.tickets := care.own_ticket(p_ticket_id);
  m      care.ticket_messages := care.existing_message(p_ticket_id, p_client_id);
  v_body text := care.require_text(p_body, 1, 4000, 'invalid_body', 'Pesan');
begin
  if m.id is not null then
    return jsonb_build_object('message', care.message_json(m), 'ticket', care.public_summary(t.id));
  end if;
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah selesai. Buka kembali atau buat tiket baru');
  end if;
  perform care.check_rate_limit(t.customer_id, 'care_message', 'care.ticket_messages'::regclass, 'author_id');
  m := care.insert_message(t.id, 'customer', 'public', 'sent', v_body, p_client_id);
  if t.status = 'pending_customer' then
    perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'customer_reply'));
  end if;
  return jsonb_build_object('message', care.message_json(m), 'ticket', care.public_summary(t.id));
end;
$$;

create or replace function care_api.escalate_to_complaint(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t care.tickets := care.own_ticket(p_ticket_id);
begin
  if t.status in ('closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah ditutup. Buat tiket baru sebagai pengaduan');
  end if;
  if exists (select 1 from care.complaints c where c.ticket_id = t.id and c.reclassified_at is null) then
    return care.customer_ticket(t.id);
  end if;
  if t.status = 'resolved' then
    perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'escalated_to_complaint'));
  end if;
  perform care.add_event(t.id, 'kind_changed', 'public',
    jsonb_build_object('from', t.kind, 'to', 'complaint', 'by', 'customer'));
  perform care.register_complaint(t.id, now());
  return care.customer_ticket(t.id);
end;
$$;

create or replace function care_api.cancel_ticket(p_ticket_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t           care.tickets := care.own_ticket(p_ticket_id);
  v_reason    text := care.require_text(p_reason, 3, 500, 'invalid_reason', 'Alasan');
  v_complaint boolean := exists (select 1 from care.complaints c where c.ticket_id = t.id and c.reclassified_at is null);
begin
  if not (t.status in ('new', 'open') or (v_complaint and t.status not in ('resolved', 'closed', 'cancelled'))) then
    perform private.api_error(409, 'invalid_transition', 'Tiket ini tidak bisa dibatalkan');
  end if;
  perform care.set_status(t.id, 'cancelled', jsonb_build_object(
    'by', 'customer', 'withdrawn_complaint', v_complaint, 'reason', (care.mask_sensitive(v_reason)).masked));
  return care.customer_ticket(t.id);
end;
$$;

create or replace function care_api.confirm_resolved(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t care.tickets := care.own_ticket(p_ticket_id);
begin
  if t.kind = 'complaint' then
    perform private.api_error(409, 'complaint_needs_response', 'Pengaduan diselesaikan dengan tanggapan resmi');
  end if;
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'invalid_transition', 'Tiket sudah selesai');
  end if;
  perform care.ensure_open(t.id, 'customer_confirmed');
  update care.tickets set resolution_summary = coalesce(resolution_summary, 'Dikonfirmasi selesai oleh nasabah')
  where id = t.id;
  perform care.set_status(t.id, 'resolved', jsonb_build_object('by', 'customer'));
  return care.customer_ticket(t.id);
end;
$$;

create or replace function care_api.reopen_ticket(p_ticket_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        care.tickets := care.own_ticket(p_ticket_id);
  v_reason text := care.require_text(p_reason, 3, 1000, 'invalid_reason', 'Alasan');
begin
  if t.kind = 'complaint' then
    perform private.api_error(409, 'use_objection', 'Untuk pengaduan, ajukan keberatan atas tanggapan');
  end if;
  if t.status <> 'resolved'
     or now() > t.resolved_at + make_interval(days => care.setting_int('ticket.reopen_days')) then
    perform private.api_error(409, 'reopen_window_passed', 'Tiket tidak bisa dibuka kembali. Buat tiket baru');
  end if;
  perform care.set_status(t.id, 'open', jsonb_build_object(
    'by', 'customer', 'reason', (care.mask_sensitive(v_reason)).masked));
  perform care.notify_staff(array[t.assignee_id], 'ticket_reopened', t.id, '{}');
  return care.customer_ticket(t.id);
end;
$$;

create or replace function care_api.object_to_response(p_ticket_id uuid, p_reason text, p_new_documents boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        care.tickets := care.own_ticket(p_ticket_id);
  c        care.complaints := care.active_complaint(p_ticket_id);
  v_reason text := care.require_text(p_reason, 10, 2000, 'invalid_reason', 'Alasan keberatan');
  v_due    timestamptz;
begin
  if t.status <> 'resolved' or c.final_response_at is null
     or now() > care.regulatory_deadline(t.resolved_at, care.setting_int('complaint.objection_days')) then
    perform private.api_error(409, 'objection_window_passed', 'Keberatan hanya bisa diajukan dalam batas waktu setelah tanggapan akhir');
  end if;
  v_due := care.regulatory_deadline(now(), case when coalesce(p_new_documents, false)
                                                then care.setting_int('complaint.written_days')
                                                else care.setting_int('complaint.objection_review_days') end);
  update care.complaints set
    objection_count = objection_count + 1,
    last_objection_at = now(),
    due_at = v_due,
    original_due_at = null,
    clock_paused_at = null,
    final_response_at = null
  where ticket_id = t.id;
  perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'objection'));
  perform care.add_event(t.id, 'objection_filed', 'public', jsonb_build_object(
    'reason', (care.mask_sensitive(v_reason)).masked, 'new_documents', coalesce(p_new_documents, false), 'due_at', v_due));
  perform care.notify_staff(care.team_staff(t.team_id, '{supervisor}') || array[t.assignee_id], 'objection_filed', t.id,
    jsonb_build_object('due_at', v_due));
  return care.customer_ticket(t.id);
end;
$$;

create or replace function care_api.request_secure_account(p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer uuid := care.require_customer();
  v_category uuid := (select c.id from care.categories c where c.code = 'suspicious_activity');
  v_language text := case when (auth.jwt() -> 'app_metadata' ->> 'locale') = 'en' then 'en' else 'id' end;
  v_id       uuid;
  v_team     uuid;
  v_actions  jsonb := coalesce(care.setting('secure_account.actions'), '["logout_all"]');
begin
  select t.id into v_id
  from care.tickets t
  join care.outbox o on o.ticket_id = t.id and o.kind = 'secure_account' and o.status <> 'dead'
  where t.customer_id = v_customer and t.created_at > now() - interval '30 minutes'
  order by t.created_at desc
  limit 1;
  if v_id is not null then
    return care.customer_ticket(v_id);
  end if;

  v_id := care.create_ticket(v_customer, 'app', v_category,
    case when v_language = 'en' then 'Secure my account request' else 'Permintaan amankan akun' end,
    coalesce(p_note, ''), '{}', '{}', false, v_language, now(), null);
  update care.tickets set priority = 'P1' where id = v_id returning team_id into v_team;
  perform care.refresh_sla(v_id);
  perform care.enqueue_job('secure_account', v_id, jsonb_build_object(
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = v_customer),
    'actions', v_actions,
    'idempotency_key', v_id), 10);
  perform care.add_event(v_id, 'secure_account_requested', 'public', jsonb_build_object('actions', v_actions));
  perform care.notify_staff(
    care.team_staff(v_team, '{agent_l1,agent_l2,specialist,supervisor}'), 'secure_account_requested', v_id,
    jsonb_build_object('actions', v_actions));
  perform care.audit('customer.secure_account', v_id, 'customer', v_customer::text, jsonb_build_object('actions', v_actions));
  return care.customer_ticket(v_id);
end;
$$;

create or replace function care_api.customer_data_access(p_kind text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_customer uuid := care.require_customer();
begin
  if p_kind not in ('orders', 'order', 'cash_transactions', 'cash_transaction') then
    perform private.api_error(400, 'invalid_kind', 'Jenis data tidak dikenal');
  end if;
  return jsonb_build_object(
    'customer_id', v_customer,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = v_customer));
end;
$$;

create or replace function care_api.verify_letter(p_number text, p_code text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object('valid', true, 'kind', l.kind, 'number', l.number, 'issued_at', l.issued_at,
                              'sha256', l.sha256)
    from care.official_letters l
    where l.number = btrim(p_number)
      and l.verification_code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
  ), jsonb_build_object('valid', false));
$$;

create or replace function care_api.staff_whoami()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := care.require_staff();
begin
  return (
    select jsonb_build_object(
      'user_id', s.user_id,
      'agent_code', s.agent_code,
      'display_name', s.display_name,
      'roles', care.current_roles(),
      'teams', coalesce((
        select jsonb_agg(jsonb_build_object('id', tm.id, 'code', tm.code, 'name', tm.name_id) order by tm.code)
        from care.team_members m join care.teams tm on tm.id = m.team_id
        where m.user_id = s.user_id), '[]'))
    from care.staff s
    where s.user_id = v_me);
end;
$$;

create or replace function care_api.staff_tickets(p_view text default 'mine', p_cursor jsonb default null, p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := care.require_staff('{agent_l1,agent_l2,specialist,supervisor,compliance}');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_today date := care.local_date(now());
  v_items jsonb;
begin
  if coalesce(p_view, '') not in ('mine', 'unassigned', 'team', 'complaints', 'near_deadline', 'pending_customer') then
    perform private.api_error(400, 'invalid_view',
      'Tampilan: mine, unassigned, team, complaints, near_deadline, atau pending_customer');
  end if;

  if p_view = 'near_deadline' then
    select coalesce(jsonb_agg(care.staff_summary(x.id) order by x.due_at, x.id), '[]') into v_items
    from (
      select t.id, c.due_at
      from care.tickets t
      join care.complaints c on c.ticket_id = t.id and c.reclassified_at is null
      where c.due_at is not null
        and t.status not in ('resolved', 'closed', 'cancelled')
        and care.business_days_between(v_today, care.local_date(c.due_at)) <= 3
        and care.staff_can_view(t.team_id, t.assignee_id, t.customer_id)
      order by c.due_at, t.id
      limit v_limit
    ) x;
    return jsonb_build_object('items', v_items, 'next_cursor', null);
  end if;

  with page as (
    select t.id, t.updated_at
    from care.tickets t
    where care.staff_can_view(t.team_id, t.assignee_id, t.customer_id)
      and case p_view
        when 'mine' then t.assignee_id = v_me and t.status not in ('closed', 'cancelled')
        when 'unassigned' then t.assignee_id is null and t.status not in ('resolved', 'closed', 'cancelled')
        when 'team' then t.status not in ('closed', 'cancelled')
        when 'complaints' then t.kind = 'complaint' and t.status not in ('closed', 'cancelled')
        else t.status = 'pending_customer'
      end
      and (p_cursor is null
           or (t.updated_at, t.id) < ((p_cursor ->> 'updated_at')::timestamptz, (p_cursor ->> 'id')::uuid))
    order by t.updated_at desc, t.id desc
    limit v_limit
  )
  select coalesce(jsonb_agg(care.staff_summary(p.id) order by p.updated_at desc, p.id desc), '[]')
  into v_items from page p;
  return jsonb_build_object('items', v_items, 'next_cursor', care.next_cursor(v_items, v_limit));
end;
$$;

create or replace function care_api.staff_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t care.tickets := care.workable_ticket(p_ticket_id);
begin
  perform care.audit('ticket.view', t.id, 'ticket', t.id::text, jsonb_build_object(
    'snapshots', (select count(*) from care.ticket_related_items r where r.ticket_id = t.id and r.snapshot is not null)));
  return care.staff_ticket(t.id);
end;
$$;

create or replace function care_api.staff_create_ticket(
  p_customer_id  uuid,
  p_channel      text,
  p_category_id  uuid,
  p_subject      text,
  p_description  text default '',
  p_fields       jsonb default '{}',
  p_as_complaint boolean default false,
  p_received_at  timestamptz default null,
  p_language     text default 'id',
  p_client_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := care.require_staff('{agent_l1,agent_l2,specialist,supervisor,compliance}');
  v_received timestamptz := coalesce(p_received_at, now());
  v_id       uuid;
begin
  if p_channel not in ('phone', 'email', 'letter', 'walk_in', 'social_media') then
    perform private.api_error(400, 'invalid_channel', 'Kanal manual: phone, email, letter, walk_in, atau social_media');
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_customer_id and p.deleted_at is null) then
    perform private.api_error(404, 'customer_not_found', 'Nasabah tidak ditemukan');
  end if;
  if v_received > now() + interval '5 minutes'
     or v_received < now() - make_interval(days => care.setting_int('ticket.max_backdate_days')) then
    perform private.api_error(400, 'invalid_received_at', 'Waktu terima tidak boleh di masa depan atau terlalu lama');
  end if;
  if p_client_id is not null then
    select t.id into v_id from care.tickets t where t.created_by = v_me and t.client_id = p_client_id;
    if v_id is not null then
      return care.staff_summary(v_id);
    end if;
  end if;

  v_id := care.create_ticket(p_customer_id, p_channel, p_category_id, p_subject, p_description, p_fields, '{}',
                             p_as_complaint, p_language, v_received, p_client_id);
  perform care.claim_if_unassigned(v_id);
  if exists (select 1 from care.tickets t where t.id = v_id and t.assignee_id = v_me and t.status = 'new') then
    perform care.set_status(v_id, 'open', jsonb_build_object('reason', 'manual_entry'));
  end if;
  perform care.audit('ticket.create_manual', v_id, 'customer', p_customer_id::text,
    jsonb_build_object('channel', p_channel, 'received_at', v_received));
  return care.staff_summary(v_id);
end;
$$;

create or replace function care_api.staff_assign(
  p_ticket_id   uuid,
  p_assignee_id uuid default null,
  p_team_code   text default null,
  p_note        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t          care.tickets := care.workable_ticket(p_ticket_id);
  v_me       uuid := care.current_staff_id();
  v_team     uuid := t.team_id;
  v_assignee uuid := coalesce(p_assignee_id, case when p_team_code is null then v_me end);
begin
  if t.status in ('closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah ditutup');
  end if;
  if p_team_code is not null then
    select tm.id into v_team from care.teams tm where tm.code = p_team_code and tm.active;
    if v_team is null then
      perform private.api_error(400, 'invalid_team', 'Tim tidak dikenal');
    end if;
  end if;
  if (v_assignee is distinct from v_me or v_team <> t.team_id) and not care.is_team_supervisor(t.team_id) then
    perform private.api_error(403, 'staff_forbidden', 'Hanya supervisor tim yang bisa menugaskan ulang atau memindahkan tiket');
  end if;
  if v_assignee is not null and not exists (
    select 1 from care.staff s
    join care.staff_roles r on r.user_id = s.user_id
      and r.role in ('agent_l1', 'agent_l2', 'specialist', 'supervisor', 'compliance')
    where s.user_id = v_assignee and s.disabled_at is null
      and (r.role = 'compliance'
           or exists (select 1 from care.team_members m where m.team_id = v_team and m.user_id = v_assignee))
  ) then
    perform private.api_error(400, 'invalid_assignee', 'Staf tujuan tidak aktif atau bukan anggota tim');
  end if;

  update care.tickets set team_id = v_team, assignee_id = v_assignee where id = t.id;
  if v_team <> t.team_id then
    perform care.add_event(t.id, 'team_changed', 'internal', jsonb_build_object(
      'from', t.team_id, 'to', v_team, 'note', nullif(btrim(coalesce(p_note, '')), '')));
  end if;
  perform care.add_event(t.id, 'assigned', 'internal', jsonb_build_object(
    'assignee_id', v_assignee, 'team_id', v_team, 'note', nullif(btrim(coalesce(p_note, '')), '')));
  if t.status = 'new' and v_assignee is not null then
    perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'assigned'));
  end if;
  if v_assignee is not null and v_assignee <> v_me then
    perform care.notify_staff(array[v_assignee], 'ticket_assigned', t.id, jsonb_build_object('by', v_me));
  end if;
  perform care.audit('ticket.assign', t.id, 'staff', v_assignee::text, jsonb_build_object(
    'from_team', t.team_id, 'to_team', v_team, 'from_assignee', t.assignee_id));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_set_status(p_ticket_id uuid, p_status text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      care.tickets := care.workable_ticket(p_ticket_id);
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if p_status not in ('open', 'pending_customer', 'pending_internal', 'pending_third_party', 'escalated') then
    perform private.api_error(400, 'invalid_status',
      'Gunakan aksi khusus untuk menyelesaikan, membatalkan, atau memperpanjang tiket');
  end if;
  if p_status in ('escalated', 'pending_third_party') then
    v_note := care.require_text(v_note, 3, 1000, 'note_required', 'Catatan');
  end if;
  perform care.claim_if_unassigned(t.id);
  if p_status <> 'open' then
    perform care.ensure_open(t.id, 'status_change');
  end if;
  perform care.set_status(t.id, p_status, jsonb_build_object('note', v_note));
  perform care.audit('ticket.status', t.id, 'ticket', t.id::text, jsonb_build_object('from', t.status, 'to', p_status));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_set_priority(p_ticket_id uuid, p_priority text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        care.tickets := care.workable_ticket(p_ticket_id);
  v_reason text := care.require_text(p_reason, 3, 500, 'invalid_reason', 'Alasan');
begin
  if p_priority not in ('P1', 'P2', 'P3', 'P4') then
    perform private.api_error(400, 'invalid_priority', 'Prioritas: P1, P2, P3, atau P4');
  end if;
  if t.kind = 'complaint' and p_priority in ('P3', 'P4') then
    perform private.api_error(409, 'complaint_priority', 'Pengaduan minimal berprioritas P2');
  end if;
  if p_priority = t.priority then
    return care.staff_summary(t.id);
  end if;
  update care.tickets set priority = p_priority where id = t.id;
  perform care.refresh_sla(t.id);
  perform care.add_event(t.id, 'priority_changed', 'internal',
    jsonb_build_object('from', t.priority, 'to', p_priority, 'reason', v_reason));
  perform care.audit('ticket.priority', t.id, 'ticket', t.id::text,
    jsonb_build_object('from', t.priority, 'to', p_priority, 'reason', v_reason));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_post_message(
  p_ticket_id uuid,
  p_body      text,
  p_internal  boolean default false,
  p_client_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      care.tickets := care.workable_ticket(p_ticket_id);
  m      care.ticket_messages := care.existing_message(p_ticket_id, p_client_id);
  v_body text := care.require_text(p_body, 1, 4000, 'invalid_body', 'Pesan');
begin
  if m.id is not null then
    return jsonb_build_object('held', m.status = 'held', 'message', care.message_json(m));
  end if;
  if coalesce(p_internal, false) then
    m := care.insert_message(t.id, 'staff', 'internal', 'sent', v_body, p_client_id);
    return jsonb_build_object('held', false, 'message', care.message_json(m));
  end if;
  if t.status in ('closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah ditutup');
  end if;
  if care.requests_secret(v_body) then
    m := care.insert_message(t.id, 'staff', 'internal', 'held', v_body, p_client_id);
    perform care.add_event(t.id, 'message_held', 'internal', jsonb_build_object('message_id', m.id));
    perform care.notify_staff(care.team_staff(t.team_id, '{supervisor}'), 'message_held', t.id,
      jsonb_build_object('message_id', m.id, 'agent_id', auth.uid()));
    perform care.audit('message.held', t.id, 'message', m.id::text, '{}');
    return jsonb_build_object('held', true, 'message', care.message_json(m));
  end if;

  m := care.insert_message(t.id, 'staff', 'public', 'sent', v_body, p_client_id);
  update care.tickets set first_response_at = coalesce(first_response_at, now()) where id = t.id;
  perform care.claim_if_unassigned(t.id);
  if t.status = 'new' then
    perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'first_reply'));
  end if;
  return jsonb_build_object('held', false, 'message', care.message_json(m));
end;
$$;

create or replace function care_api.staff_change_kind(p_ticket_id uuid, p_kind text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        care.tickets := care.workable_ticket(p_ticket_id);
  v_reason text := care.require_text(p_reason, 10, 1000, 'invalid_reason', 'Alasan');
  v_id     uuid;
begin
  if p_kind not in ('inquiry', 'request', 'complaint', 'incident_report', 'fraud_report', 'feedback') then
    perform private.api_error(400, 'invalid_kind', 'Jenis tiket tidak dikenal');
  end if;
  if t.status in ('closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah ditutup');
  end if;
  if p_kind = t.kind then
    perform private.api_error(409, 'no_change', 'Jenis tiket sudah sama');
  end if;

  if t.kind = 'complaint' then
    begin
      insert into care.reclassification_requests (ticket_id, from_kind, to_kind, reason, requested_by)
      values (t.id, t.kind, p_kind, v_reason, care.current_staff_id())
      returning id into v_id;
    exception when unique_violation then
      perform private.api_error(409, 'reclassification_pending', 'Masih ada permintaan ubah klasifikasi yang menunggu');
    end;
    perform care.add_event(t.id, 'reclassification_requested', 'internal',
      jsonb_build_object('request_id', v_id, 'to', p_kind, 'reason', v_reason));
    perform care.notify_staff(care.team_staff(t.team_id, '{supervisor}') || care.role_staff('{compliance}'),
      'reclassification_requested', t.id, jsonb_build_object('request_id', v_id, 'to', p_kind));
    perform care.audit('ticket.reclassification_requested', t.id, 'reclassification', v_id::text,
      jsonb_build_object('to', p_kind, 'reason', v_reason));
    return care.staff_summary(t.id) || jsonb_build_object('pending_approval', true, 'request_id', v_id);
  end if;

  if p_kind = 'complaint' then
    perform care.add_event(t.id, 'kind_changed', 'public', jsonb_build_object('from', t.kind, 'to', 'complaint', 'by', 'staff'));
    perform care.register_complaint(t.id, t.received_at);
  else
    update care.tickets set kind = p_kind where id = t.id;
    perform care.add_event(t.id, 'kind_changed', 'internal',
      jsonb_build_object('from', t.kind, 'to', p_kind, 'reason', v_reason));
  end if;
  perform care.audit('ticket.kind', t.id, 'ticket', t.id::text,
    jsonb_build_object('from', t.kind, 'to', p_kind, 'reason', v_reason));
  return care.staff_summary(t.id) || jsonb_build_object('pending_approval', false);
end;
$$;

create or replace function care_api.staff_decide_reclassification(p_request_id uuid, p_approve boolean, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := care.require_staff('{supervisor,compliance}');
  v_note text := care.require_text(p_note, 3, 1000, 'invalid_note', 'Catatan keputusan');
  r      care.reclassification_requests;
  t      care.tickets;
begin
  select * into r from care.reclassification_requests where id = p_request_id for update;
  if r.id is null then
    perform private.api_error(404, 'request_not_found', 'Permintaan tidak ditemukan');
  end if;
  if r.decision is not null then
    perform private.api_error(409, 'already_decided', 'Permintaan sudah diputuskan');
  end if;
  select * into t from care.tickets where id = r.ticket_id for update;
  if not care.is_team_supervisor(t.team_id) then
    perform private.api_error(403, 'staff_forbidden', 'Hanya supervisor tim atau kepatuhan yang bisa memutuskan');
  end if;
  if r.requested_by = v_me then
    perform private.api_error(403, 'four_eyes', 'Permintaan tidak bisa disetujui oleh pembuatnya sendiri');
  end if;

  update care.reclassification_requests
     set decision = case when p_approve then 'approved' else 'rejected' end,
         decided_by = v_me, decided_at = now(), decision_note = v_note
   where id = r.id;
  if p_approve then
    if t.status in ('closed', 'cancelled') then
      perform private.api_error(409, 'ticket_closed', 'Tiket sudah ditutup');
    end if;
    update care.tickets set kind = r.to_kind where id = t.id;
    update care.complaints set reclassified_at = now(), reclassified_to = r.to_kind where ticket_id = t.id;
    perform care.add_event(t.id, 'kind_changed', 'public',
      jsonb_build_object('from', 'complaint', 'to', r.to_kind, 'by', 'supervisor'));
    perform care.notify_staff(care.role_staff('{compliance}'), 'complaint_reclassified', t.id,
      jsonb_build_object('to', r.to_kind, 'request_id', r.id));
  else
    perform care.add_event(t.id, 'reclassification_rejected', 'internal',
      jsonb_build_object('request_id', r.id, 'note', v_note));
  end if;
  perform care.notify_staff(array[r.requested_by], 'reclassification_decided', t.id,
    jsonb_build_object('request_id', r.id, 'approved', p_approve));
  perform care.audit('ticket.reclassification_decided', t.id, 'reclassification', r.id::text,
    jsonb_build_object('approved', p_approve, 'note', v_note, 'to', r.to_kind));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_request_documents(p_ticket_id uuid, p_documents text[], p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t           care.tickets := care.workable_ticket(p_ticket_id);
  c           care.complaints;
  v_documents text[];
  v_due       timestamptz := care.regulatory_deadline(now(), care.setting_int('complaint.document_wait_days'));
begin
  select coalesce(array_agg(btrim(d) order by n), '{}') into v_documents
  from unnest(p_documents) with ordinality x (d, n)
  where btrim(coalesce(d, '')) <> '';
  if cardinality(v_documents) not between 1 and 10
     or exists (select 1 from unnest(v_documents) d where char_length(d) not between 2 and 100) then
    perform private.api_error(400, 'invalid_documents', 'Sebutkan 1–10 dokumen, masing-masing 2–100 karakter');
  end if;
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah selesai');
  end if;

  select * into c from care.complaints where ticket_id = t.id and reclassified_at is null for update;
  if c.ticket_id is not null then
    update care.complaints set
      documents_required = v_documents,
      documents_requested_at = now(),
      documents_due_at = v_due,
      conversion_requested_at = case when form = 'oral' then now() else conversion_requested_at end,
      clock_paused_at = case when form = 'written' and documents_complete_at is not null and due_at is not null
                             then now() else clock_paused_at end,
      documents_complete_at = case when form = 'written' then null else documents_complete_at end
    where ticket_id = t.id;
  end if;
  perform care.add_event(t.id, 'documents_requested', 'public', jsonb_build_object(
    'documents', v_documents, 'due_at', v_due, 'note', nullif(btrim(coalesce(p_note, '')), ''),
    'converts_to_written', c.ticket_id is not null and c.form = 'oral'));
  perform care.claim_if_unassigned(t.id);
  perform care.ensure_open(t.id, 'documents_requested');
  if t.status <> 'pending_customer' then
    perform care.set_status(t.id, 'pending_customer', jsonb_build_object('reason', 'documents_requested'));
  end if;
  perform care.audit('ticket.documents_requested', t.id, 'ticket', t.id::text,
    jsonb_build_object('documents', v_documents));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_mark_documents_complete(p_ticket_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t     care.tickets := care.workable_ticket(p_ticket_id);
  c     care.complaints := care.active_complaint(p_ticket_id);
  v_due timestamptz;
begin
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Tiket sudah selesai');
  end if;
  if c.form = 'oral' then
    if c.conversion_requested_at is null then
      perform private.api_error(409, 'documents_not_requested', 'Dokumen belum pernah diminta untuk pengaduan lisan ini');
    end if;
    v_due := care.regulatory_deadline(now(), care.setting_int('complaint.written_days'));
    update care.complaints set form = 'written', documents_complete_at = now(), due_at = v_due, clock_paused_at = null
    where ticket_id = t.id;
    perform care.add_event(t.id, 'converted_to_written', 'public',
      jsonb_build_object('previous_due_at', c.due_at, 'due_at', v_due));
  else
    if c.documents_complete_at is not null then
      perform private.api_error(409, 'documents_already_complete', 'Dokumen sudah dinyatakan lengkap');
    end if;
    v_due := case when c.clock_paused_at is not null
                  then care.sla_shift(c.due_at, 'business_days', c.clock_paused_at, now())
                  else care.regulatory_deadline(now(), care.setting_int('complaint.written_days')) end;
    update care.complaints set documents_complete_at = now(), due_at = v_due, clock_paused_at = null
    where ticket_id = t.id;
  end if;
  perform care.add_event(t.id, 'documents_completed', 'public',
    jsonb_build_object('due_at', v_due, 'note', nullif(btrim(coalesce(p_note, '')), '')));
  if t.status = 'pending_customer' then
    perform care.set_status(t.id, 'open', jsonb_build_object('reason', 'documents_completed'));
  end if;
  perform care.audit('complaint.documents_complete', t.id, 'complaint', c.number, jsonb_build_object('due_at', v_due));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_extend_deadline(p_ticket_id uuid, p_reason_code text, p_explanation text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t             care.tickets := care.workable_ticket(p_ticket_id);
  c             care.complaints := care.active_complaint(p_ticket_id);
  v_explanation text := (care.mask_sensitive(
                          care.require_text(p_explanation, 10, 2000, 'invalid_explanation', 'Penjelasan'))).masked;
  v_reason      jsonb := care.setting('complaint.extension_reasons') -> p_reason_code;
  v_new_due     timestamptz;
begin
  if not care.is_team_supervisor(t.team_id) then
    perform private.api_error(403, 'staff_forbidden', 'Perpanjangan hanya oleh supervisor tim atau kepatuhan');
  end if;
  if v_reason is null then
    perform private.api_error(400, 'invalid_reason', 'Alasan perpanjangan tidak ada dalam daftar yang diizinkan');
  end if;
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'ticket_closed', 'Pengaduan sudah selesai');
  end if;
  if c.due_at is null or c.clock_paused_at is not null then
    perform private.api_error(409, 'deadline_not_running', 'Tenggat belum berjalan atau sedang dijeda');
  end if;
  if now() > c.due_at then
    perform private.api_error(409, 'deadline_passed', 'Perpanjangan hanya bisa dilakukan sebelum tenggat lewat');
  end if;
  if c.extension_count >= care.setting_int('complaint.max_extensions') then
    perform private.api_error(409, 'extension_limit', 'Batas perpanjangan sudah tercapai');
  end if;

  v_new_due := care.end_of_business_day(
    care.add_business_days(care.local_date(c.due_at), care.setting_int('complaint.extension_days')));
  update care.complaints set
    original_due_at = coalesce(original_due_at, due_at),
    due_at = v_new_due,
    extension_count = extension_count + 1,
    extended_at = now(),
    extension_reason = p_reason_code
  where ticket_id = t.id;
  perform care.ensure_open(t.id, 'extension');
  perform care.set_status(t.id, 'extended', jsonb_build_object('reason', p_reason_code));
  perform care.add_event(t.id, 'deadline_extended', 'public', jsonb_build_object(
    'reason', p_reason_code, 'previous_due_at', c.due_at, 'due_at', v_new_due));
  perform care.issue_letter(t.id, 'extension_notice', jsonb_build_object(
    'extension_reason', coalesce(v_reason ->> t.language, v_reason ->> 'id'),
    'extension_explanation', v_explanation,
    'original_due_date', care.format_date(c.due_at, t.language, true),
    'new_due_date', care.format_date(v_new_due, t.language, true)));
  perform care.audit('complaint.extended', t.id, 'complaint', c.number, jsonb_build_object(
    'reason', p_reason_code, 'previous_due_at', c.due_at, 'due_at', v_new_due));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_resolve(p_ticket_id uuid, p_root_cause text, p_resolution text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t            care.tickets := care.workable_ticket(p_ticket_id);
  c            care.complaints;
  v_resolution text := (care.mask_sensitive(
                         care.require_text(p_resolution, 10, 4000, 'invalid_resolution', 'Ringkasan penyelesaian'))).masked;
begin
  if care.setting('ticket.root_causes') -> p_root_cause is null then
    perform private.api_error(400, 'invalid_root_cause', 'Kategori akar masalah tidak dikenal');
  end if;
  if t.status in ('resolved', 'closed', 'cancelled') then
    perform private.api_error(409, 'invalid_transition', 'Tiket sudah selesai');
  end if;
  perform care.ensure_open(t.id, 'resolving');
  update care.tickets set
    root_cause = p_root_cause,
    resolution_summary = v_resolution,
    first_response_at = coalesce(first_response_at, now()),
    assignee_id = coalesce(assignee_id, care.current_staff_id())
  where id = t.id;

  select * into c from care.complaints where ticket_id = t.id and reclassified_at is null for update;
  if c.ticket_id is not null then
    update care.complaints set final_response_at = now() where ticket_id = t.id;
  end if;
  perform care.set_status(t.id, 'resolved', jsonb_build_object('resolution', v_resolution));
  if c.ticket_id is not null then
    perform care.issue_letter(t.id, 'final_response', jsonb_build_object(
      'resolution', v_resolution,
      'resolved_at', care.format_date(now(), t.language, true),
      'objection_deadline', care.format_date(
        care.regulatory_deadline(now(), care.setting_int('complaint.objection_days')), t.language, true)));
  end if;
  perform care.audit('ticket.resolve', t.id, 'ticket', t.id::text, jsonb_build_object('root_cause', p_root_cause));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_cancel(p_ticket_id uuid, p_reason text, p_duplicate_of uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        care.tickets := care.workable_ticket(p_ticket_id);
  v_reason text := care.require_text(p_reason, 3, 500, 'invalid_reason', 'Alasan');
begin
  if exists (select 1 from care.complaints c where c.ticket_id = t.id and c.reclassified_at is null) then
    perform private.api_error(409, 'complaint_needs_response', 'Pengaduan tidak bisa dibatalkan staf');
  end if;
  if t.status not in ('new', 'open') then
    perform private.api_error(409, 'invalid_transition', 'Hanya tiket baru atau terbuka yang bisa dibatalkan');
  end if;
  if p_duplicate_of is not null and not exists (
    select 1 from care.tickets d where d.id = p_duplicate_of and d.customer_id = t.customer_id and d.id <> t.id) then
    perform private.api_error(400, 'invalid_duplicate', 'Tiket duplikat harus milik nasabah yang sama');
  end if;
  perform care.set_status(t.id, 'cancelled', jsonb_build_object(
    'by', 'staff', 'reason', v_reason, 'duplicate_of', p_duplicate_of));
  perform care.audit('ticket.cancel', t.id, 'ticket', t.id::text,
    jsonb_build_object('reason', v_reason, 'duplicate_of', p_duplicate_of));
  return care.staff_summary(t.id);
end;
$$;

create or replace function care_api.staff_notifications(p_unread_only boolean default false, p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := care.require_staff();
begin
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', n.id, 'kind', n.kind, 'ticket_id', n.ticket_id, 'data', n.data,
             'created_at', n.created_at, 'read_at', n.read_at) order by n.created_at desc, n.id desc), '[]')
    from (
      select * from care.staff_notifications n
      where n.staff_id = v_me and (not coalesce(p_unread_only, false) or n.read_at is null)
      order by n.created_at desc, n.id desc
      limit least(greatest(coalesce(p_limit, 50), 1), 200)
    ) n);
end;
$$;

create or replace function care_api.staff_mark_notifications_read(p_ids bigint[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := care.require_staff();
  v_count integer;
begin
  update care.staff_notifications set read_at = now()
  where staff_id = v_me and read_at is null and (p_ids is null or id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function care_api.staff_customer_access(p_ticket_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := care.require_staff('{agent_l1,agent_l2,specialist,supervisor,compliance}');
  v_limit integer := care.setting_int('customer_data.profile_views_per_hour');
  t       care.tickets;
begin
  if p_kind not in ('profile', 'orders', 'order', 'cash_transactions', 'cash_transaction', 'portfolio', 'sessions', 'security') then
    perform private.api_error(400, 'invalid_kind', 'Jenis data nasabah tidak dikenal');
  end if;
  if not care.staff_can_access_customer(p_ticket_id, p_kind) then
    perform private.api_error(403, 'customer_data_forbidden', 'Anda tidak berwenang membuka data nasabah untuk tiket ini');
  end if;
  if p_kind = 'profile' and (
    select count(*) from care.audit_log a
    where a.actor_id = v_me and a.action = 'customer_data.profile' and a.created_at > now() - interval '1 hour'
  ) >= v_limit then
    perform private.raise_rate_limited('customer_data.profile', v_limit, 3600, 300);
  end if;
  select * into t from care.tickets where id = p_ticket_id;
  perform care.audit('customer_data.' || p_kind, t.id, 'customer', t.customer_id::text, '{}');
  return jsonb_build_object(
    'customer_id', t.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = t.customer_id),
    'correlation_id', t.number || '/' || (select s.agent_code from care.staff s where s.user_id = v_me));
end;
$$;

create or replace function care_api.staff_reveal_access(p_ticket_id uuid, p_field text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := care.require_staff('{agent_l1,agent_l2,specialist,supervisor,compliance}');
  v_limit integer := care.setting_int('customer_data.reveals_per_hour');
  t       care.tickets;
begin
  if p_field not in ('nik', 'phone', 'email', 'client_code', 'sid', 'address', 'birth_date', 'rdn_number', 'bank_account') then
    perform private.api_error(400, 'invalid_field', 'Field tidak bisa dibuka');
  end if;
  if care.setting('customer_data.reveal_reasons') -> p_reason is null then
    perform private.api_error(400, 'invalid_reason', 'Alasan membuka data tidak ada dalam daftar');
  end if;
  if not care.staff_can_access_customer(p_ticket_id, 'profile') then
    perform private.api_error(403, 'customer_data_forbidden', 'Anda tidak berwenang membuka data nasabah untuk tiket ini');
  end if;
  if (
    select count(*) from care.audit_log a
    where a.actor_id = v_me and a.action = 'customer_data.reveal' and a.created_at > now() - interval '1 hour'
  ) >= v_limit then
    perform private.raise_rate_limited('customer_data.reveal', v_limit, 3600, 300);
  end if;
  select * into t from care.tickets where id = p_ticket_id;
  perform care.audit('customer_data.reveal', t.id, 'customer', t.customer_id::text,
    jsonb_build_object('field', p_field, 'reason', p_reason));
  return jsonb_build_object(
    'customer_id', t.customer_id,
    'olt_user_id', (select p.olt_user_id from public.profiles p where p.id = t.customer_id),
    'correlation_id', t.number || '/' || (select s.agent_code from care.staff s where s.user_id = v_me),
    'valid_seconds', 300);
end;
$$;

create or replace function care_api.calendar(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform care.require_staff();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 800 then
    perform private.api_error(400, 'invalid_range', 'Rentang tanggal maksimal 800 hari');
  end if;
  return jsonb_build_object(
    'holidays', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'day', h.day, 'name', h.name, 'kind', h.kind, 'verified', h.verified) order by h.day), '[]')
      from care.holidays h where h.day between p_from and p_to),
    'business_hours', (
      select coalesce(jsonb_agg(jsonb_build_object('isodow', b.isodow, 'opens', b.opens, 'closes', b.closes)
             order by b.isodow), '[]')
      from care.business_hours b),
    'overrides', (
      select coalesce(jsonb_agg(jsonb_build_object('day', o.day, 'opens', o.opens, 'closes', o.closes, 'note', o.note)
             order by o.day), '[]')
      from care.business_hours_overrides o where o.day between p_from and p_to));
end;
$$;

create or replace function care_api.compliance_upsert_holiday(p_day date, p_name text, p_kind text, p_verified boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := care.require_staff('{compliance}');
  v_old jsonb := (select to_jsonb(h) from care.holidays h where h.day = p_day);
  v_new care.holidays;
begin
  if p_kind not in ('national', 'collective_leave', 'exchange') then
    perform private.api_error(400, 'invalid_kind', 'Jenis libur: national, collective_leave, atau exchange');
  end if;
  insert into care.holidays (day, name, kind, verified, updated_at, updated_by)
  values (p_day, care.require_text(p_name, 2, 120, 'invalid_name', 'Nama libur'), p_kind,
          coalesce(p_verified, true), now(), v_me)
  on conflict (day) do update
    set name = excluded.name, kind = excluded.kind, verified = excluded.verified,
        updated_at = excluded.updated_at, updated_by = excluded.updated_by
  returning * into v_new;
  perform care.audit('calendar.holiday_upsert', null, 'holiday', p_day::text,
    jsonb_build_object('from', v_old, 'to', to_jsonb(v_new)));
  return to_jsonb(v_new);
end;
$$;

create or replace function care_api.compliance_delete_holiday(p_day date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
begin
  perform care.require_staff('{compliance}');
  delete from care.holidays h where h.day = p_day returning to_jsonb(h) into v_old;
  if v_old is null then
    perform private.api_error(404, 'holiday_not_found', 'Hari libur tidak ditemukan');
  end if;
  perform care.audit('calendar.holiday_delete', null, 'holiday', p_day::text, jsonb_build_object('from', v_old));
end;
$$;

create or replace function care_api.staff_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform care.require_staff('{cc_admin,compliance}');
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'key', s.key, 'value', s.value, 'scope', s.scope, 'description', s.description,
             'updated_at', s.updated_at) order by s.key), '[]')
    from care.settings s);
end;
$$;

create or replace function care_api.admin_update_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := care.require_staff('{cc_admin,compliance}');
  s    care.settings;
begin
  select * into s from care.settings where key = p_key for update;
  if s.key is null then
    perform private.api_error(404, 'setting_not_found', 'Pengaturan tidak dikenal');
  end if;
  if s.scope = 'regulatory' and not ('compliance' = any (care.current_roles())) then
    perform private.api_error(403, 'staff_forbidden', 'Pengaturan regulasi hanya bisa diubah tim kepatuhan');
  end if;
  if p_value is null or jsonb_typeof(p_value) <> jsonb_typeof(s.value) then
    perform private.api_error(400, 'invalid_value', format('Nilai harus bertipe %s', jsonb_typeof(s.value)));
  end if;
  if jsonb_typeof(p_value) = 'number' and (p_value::numeric < 0 or p_value::numeric <> trunc(p_value::numeric)) then
    perform private.api_error(400, 'invalid_value', 'Nilai harus bilangan bulat tidak negatif');
  end if;
  update care.settings set value = p_value, updated_at = now(), updated_by = v_me where key = p_key;
  insert into care.settings_history (key, old_value, new_value, changed_by) values (p_key, s.value, p_value, v_me);
  perform care.audit('settings.update', null, 'setting', p_key, jsonb_build_object('from', s.value, 'to', p_value));
  return jsonb_build_object('key', p_key, 'value', p_value);
end;
$$;

create or replace function care_api.admin_upsert_staff(
  p_user_id      uuid,
  p_display_name text,
  p_roles        text[],
  p_team_codes   text[] default '{}',
  p_email        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := care.require_staff('{cc_admin}');
  v_name  text := care.require_text(p_display_name, 2, 60, 'invalid_name', 'Nama panggilan');
  v_old   jsonb;
  v_teams uuid[];
begin
  if p_user_id is null or p_user_id = v_me then
    perform private.api_error(403, 'staff_forbidden', 'Tidak bisa mengubah akun staf sendiri');
  end if;
  if cardinality(coalesce(p_roles, '{}')) = 0 or exists (
    select 1 from unnest(p_roles) r
    where r not in ('agent_l1', 'agent_l2', 'specialist', 'supervisor', 'compliance', 'kb_editor', 'cc_admin')) then
    perform private.api_error(400, 'invalid_roles', 'Peran staf tidak dikenal');
  end if;
  select coalesce(array_agg(tm.id), '{}') into v_teams
  from care.teams tm where tm.code = any (coalesce(p_team_codes, '{}')) and tm.active;
  if cardinality(v_teams) <> cardinality(array(select distinct x from unnest(coalesce(p_team_codes, '{}')) x)) then
    perform private.api_error(400, 'invalid_team', 'Ada kode tim yang tidak dikenal');
  end if;

  select to_jsonb(s) || jsonb_build_object(
           'roles', (select coalesce(array_agg(r.role order by r.role), '{}') from care.staff_roles r where r.user_id = s.user_id))
  into v_old from care.staff s where s.user_id = p_user_id;
  insert into care.staff (user_id, agent_code, display_name, email, created_by)
  values (p_user_id,
          care.format_number('CS', '', care.next_number('agent_code', 'all'), 4),
          v_name, nullif(btrim(coalesce(p_email, '')), ''), v_me)
  on conflict (user_id) do update
    set display_name = excluded.display_name, email = coalesce(excluded.email, care.staff.email), disabled_at = null;
  delete from care.staff_roles where user_id = p_user_id and role <> all (p_roles);
  insert into care.staff_roles (user_id, role, granted_by)
  select p_user_id, r, v_me from unnest(p_roles) r
  on conflict (user_id, role) do nothing;
  delete from care.team_members where user_id = p_user_id and team_id <> all (v_teams);
  insert into care.team_members (team_id, user_id)
  select x, p_user_id from unnest(v_teams) x
  on conflict do nothing;
  perform care.audit('staff.upsert', null, 'staff', p_user_id::text, jsonb_build_object(
    'from', v_old, 'roles', p_roles, 'teams', p_team_codes));
  return (select jsonb_build_object('user_id', s.user_id, 'agent_code', s.agent_code, 'display_name', s.display_name)
          from care.staff s where s.user_id = p_user_id);
end;
$$;

create or replace function care_api.admin_disable_staff(p_user_id uuid, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := care.require_staff('{cc_admin}');
  v_reason text := care.require_text(p_reason, 3, 500, 'invalid_reason', 'Alasan');
  v_ticket uuid;
  v_count  integer := 0;
begin
  if p_user_id = v_me then
    perform private.api_error(403, 'staff_forbidden', 'Tidak bisa menonaktifkan akun sendiri');
  end if;
  update care.staff set disabled_at = now() where user_id = p_user_id and disabled_at is null;
  if not found then
    perform private.api_error(404, 'staff_not_found', 'Staf aktif tidak ditemukan');
  end if;
  for v_ticket in
    update care.tickets set assignee_id = null
    where assignee_id = p_user_id and status not in ('closed', 'cancelled')
    returning id
  loop
    perform care.add_event(v_ticket, 'unassigned', 'internal', jsonb_build_object('reason', 'staff_disabled'));
    v_count := v_count + 1;
  end loop;
  perform care.audit('staff.disable', null, 'staff', p_user_id::text,
    jsonb_build_object('reason', v_reason, 'tickets_returned', v_count));
  return v_count;
end;
$$;

create or replace function care_api.service_claim_jobs(
  p_kinds         text[],
  p_worker        text,
  p_limit         integer default 10,
  p_lease_seconds integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jobs jsonb;
begin
  if coalesce(btrim(p_worker), '') = '' then
    perform private.api_error(400, 'invalid_worker', 'Nama worker wajib diisi');
  end if;
  with ready as (
    select o.id
    from care.outbox o
    where o.status = 'pending'
      and o.kind = any (p_kinds)
      and o.run_after <= now()
      and (o.locked_until is null or o.locked_until < now())
    order by o.run_after, o.id
    limit least(greatest(coalesce(p_limit, 10), 1), 100)
    for update skip locked
  ), claimed as (
    update care.outbox o set
      attempts = o.attempts + 1,
      locked_by = p_worker,
      locked_until = now() + make_interval(secs => least(greatest(coalesce(p_lease_seconds, 60), 5), 900))
    from ready
    where o.id = ready.id
    returning o.id, o.kind, o.ticket_id, o.payload, o.attempts, o.max_attempts
  )
  select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]') into v_jobs from claimed c;
  return v_jobs;
end;
$$;

create or replace function care_api.service_complete_job(p_job_id bigint, p_worker text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update care.outbox
     set status = 'done', finished_at = now(), locked_until = null, last_error = null
   where id = p_job_id and status = 'pending' and locked_by = p_worker;
  return found;
end;
$$;

create or replace function care_api.service_fail_job(p_job_id bigint, p_worker text, p_error text, p_retryable boolean default true)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  j care.outbox;
begin
  select * into j from care.outbox where id = p_job_id and status = 'pending' and locked_by = p_worker for update;
  if j.id is null then
    return 'ignored';
  end if;
  if not coalesce(p_retryable, true) or j.attempts >= j.max_attempts then
    update care.outbox
       set status = 'dead', finished_at = now(), locked_until = null, last_error = left(p_error, 2000)
     where id = j.id;
    perform care.on_job_dead(j);
    return 'dead';
  end if;
  update care.outbox
     set locked_until = null,
         last_error = left(p_error, 2000),
         run_after = now() + least(interval '1 hour', interval '10 seconds' * power(2, j.attempts - 1))
   where id = j.id;
  return 'retry';
end;
$$;

create or replace function care_api.service_letter(p_letter_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', l.id, 'ticket_id', l.ticket_id, 'kind', l.kind, 'number', l.number, 'status', l.status,
    'storage_path', l.storage_path, 'content', l.content)
  from care.official_letters l
  where l.id = p_letter_id;
$$;

create or replace function care_api.service_letter_rendered(p_letter_id uuid, p_sha256 text, p_size_bytes integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  l care.official_letters;
begin
  select * into l from care.official_letters where id = p_letter_id for update;
  if l.id is null then
    perform private.api_error(404, 'letter_not_found', 'Surat tidak ditemukan');
  end if;
  if l.status = 'ready' then
    return;
  end if;
  update care.official_letters
     set status = 'ready', sha256 = lower(p_sha256), size_bytes = p_size_bytes, rendered_at = now()
   where id = l.id;
  perform care.enqueue_job('email_letter', l.ticket_id, jsonb_build_object('letter_id', l.id));
  perform care.audit('letter.rendered', l.ticket_id, 'letter', l.id::text,
    jsonb_build_object('number', l.number, 'sha256', lower(p_sha256)));
end;
$$;

create or replace function care_api.service_letter_email(p_letter_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'letter_id', l.id,
    'to', nullif(btrim(u.email), ''),
    'subject', l.content -> 'email' ->> 'subject',
    'body', l.content -> 'email' ->> 'body',
    'storage_path', l.storage_path,
    'filename', replace(l.number, '/', '-') || '.pdf',
    'status', l.status,
    'email_status', l.email_status)
  from care.official_letters l
  join care.tickets t on t.id = l.ticket_id
  left join private.user_private u on u.user_id = t.customer_id
  where l.id = p_letter_id;
$$;

create or replace function care_api.service_letter_emailed(p_letter_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_status not in ('sent', 'no_address', 'failed') then
    perform private.api_error(400, 'invalid_status', 'Status email: sent, no_address, atau failed');
  end if;
  update care.official_letters
     set email_status = p_status, emailed_at = case when p_status = 'sent' then now() end
   where id = p_letter_id and email_status = 'pending';
end;
$$;

create or replace function care_api.service_snapshot_target(p_item_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'item_id', r.id, 'ticket_id', r.ticket_id, 'kind', r.kind, 'ref', r.ref, 'status', r.status,
    'olt_user_id', p.olt_user_id, 'correlation_id', t.number || '/system')
  from care.ticket_related_items r
  join care.tickets t on t.id = r.ticket_id
  join public.profiles p on p.id = t.customer_id
  where r.id = p_item_id;
$$;

create or replace function care_api.service_store_snapshot(p_item_id uuid, p_status text, p_snapshot jsonb default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r care.ticket_related_items;
begin
  if p_status not in ('ok', 'not_found', 'unavailable') then
    perform private.api_error(400, 'invalid_status', 'Status snapshot: ok, not_found, atau unavailable');
  end if;
  if p_status = 'ok' and (p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object') then
    perform private.api_error(400, 'invalid_snapshot', 'Snapshot wajib berupa objek');
  end if;
  update care.ticket_related_items
     set status = p_status, snapshot = case when p_status = 'ok' then p_snapshot end, fetched_at = now()
   where id = p_item_id and status = 'pending'
  returning * into r;
  if r.id is not null then
    perform care.add_event(r.ticket_id,
      case when p_status = 'ok' then 'snapshot_attached' else 'snapshot_unavailable' end, 'internal',
      jsonb_build_object('item_id', r.id, 'kind', r.kind, 'ref', r.ref, 'status', p_status));
  end if;
end;
$$;

create or replace function care_api.service_secure_account_result(p_ticket_id uuid, p_ok boolean, p_results jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team uuid;
begin
  select t.team_id into v_team from care.tickets t where t.id = p_ticket_id;
  if v_team is null then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  perform care.add_event(p_ticket_id,
    case when p_ok then 'secure_account_completed' else 'secure_account_failed' end, 'public',
    jsonb_build_object('results', coalesce(p_results, '{}')));
  if not p_ok then
    perform care.notify_staff(
      care.team_staff(v_team, '{agent_l1,agent_l2,specialist,supervisor}') || care.role_staff('{compliance}'),
      'secure_account_failed', p_ticket_id, jsonb_build_object('results', coalesce(p_results, '{}')));
  end if;
  perform care.audit('olt.secure_account', p_ticket_id, 'ticket', p_ticket_id::text,
    jsonb_build_object('ok', p_ok, 'results', coalesce(p_results, '{}')));
end;
$$;

revoke all on all functions in schema care from public;
revoke all on all functions in schema care_api from public;

grant execute on function care_api.categories(text) to anon, authenticated;
grant execute on function care_api.verify_letter(text, text) to anon, authenticated;

grant execute on function
  care_api.create_ticket(uuid, text, text, jsonb, jsonb, boolean, text, uuid),
  care_api.my_tickets(text, jsonb, integer),
  care_api.ticket_detail(uuid),
  care_api.post_message(uuid, text, uuid),
  care_api.escalate_to_complaint(uuid),
  care_api.cancel_ticket(uuid, text),
  care_api.confirm_resolved(uuid),
  care_api.reopen_ticket(uuid, text),
  care_api.object_to_response(uuid, text, boolean),
  care_api.request_secure_account(text),
  care_api.customer_data_access(text),
  care_api.staff_whoami(),
  care_api.staff_tickets(text, jsonb, integer),
  care_api.staff_ticket(uuid),
  care_api.staff_create_ticket(uuid, text, uuid, text, text, jsonb, boolean, timestamptz, text, uuid),
  care_api.staff_assign(uuid, uuid, text, text),
  care_api.staff_set_status(uuid, text, text),
  care_api.staff_set_priority(uuid, text, text),
  care_api.staff_post_message(uuid, text, boolean, uuid),
  care_api.staff_change_kind(uuid, text, text),
  care_api.staff_decide_reclassification(uuid, boolean, text),
  care_api.staff_request_documents(uuid, text[], text),
  care_api.staff_mark_documents_complete(uuid, text),
  care_api.staff_extend_deadline(uuid, text, text),
  care_api.staff_resolve(uuid, text, text),
  care_api.staff_cancel(uuid, text, uuid),
  care_api.staff_notifications(boolean, integer),
  care_api.staff_mark_notifications_read(bigint[]),
  care_api.staff_customer_access(uuid, text),
  care_api.staff_reveal_access(uuid, text, text),
  care_api.calendar(date, date),
  care_api.compliance_upsert_holiday(date, text, text, boolean),
  care_api.compliance_delete_holiday(date),
  care_api.staff_settings(),
  care_api.admin_update_setting(text, jsonb),
  care_api.admin_upsert_staff(uuid, text, text[], text[], text),
  care_api.admin_disable_staff(uuid, text)
to authenticated;

grant execute on function
  care_api.service_claim_jobs(text[], text, integer, integer),
  care_api.service_complete_job(bigint, text),
  care_api.service_fail_job(bigint, text, text, boolean),
  care_api.service_letter(uuid),
  care_api.service_letter_rendered(uuid, text, integer),
  care_api.service_letter_email(uuid),
  care_api.service_letter_emailed(uuid, text),
  care_api.service_snapshot_target(uuid),
  care_api.service_store_snapshot(uuid, text, jsonb),
  care_api.service_secure_account_result(uuid, boolean, jsonb)
to service_role;
