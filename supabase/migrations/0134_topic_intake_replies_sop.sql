alter table cs.support_topics
  add column intake jsonb not null default '[]' check (jsonb_typeof(intake) = 'array' and jsonb_array_length(intake) <= 8),
  add column customer_replies jsonb not null default '[]'
    check (jsonb_typeof(customer_replies) = 'array' and jsonb_array_length(customer_replies) <= 6),
  add column sop text check (sop is null or char_length(sop) between 1 and 4000);

create or replace function cs.check_topic_intake(p_fields jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_field  jsonb;
  v_out    jsonb := '[]';
  v_keys   text[] := '{}';
  v_key    text;
  v_type   text;
  v_option jsonb;
  v_opts   jsonb;
  v_values text[];
begin
  if jsonb_typeof(coalesce(p_fields, '[]')) <> 'array' or jsonb_array_length(coalesce(p_fields, '[]')) > 8 then
    perform private.api_error(400, 'invalid_intake', 'Maksimal 8 pertanyaan awal');
  end if;
  for v_field in select value from jsonb_array_elements(coalesce(p_fields, '[]')) loop
    v_key := v_field ->> 'key';
    v_type := v_field ->> 'type';
    if v_key is null or v_key !~ '^[a-z][a-z0-9_]{1,31}$' or v_key = any (v_keys) then
      perform private.api_error(400, 'invalid_intake', 'Kunci pertanyaan harus unik, huruf kecil/angka/garis bawah');
    end if;
    if v_type is null or v_type not in ('text', 'number', 'date', 'choice') then
      perform private.api_error(400, 'invalid_intake', 'Jenis isian harus text, number, date, atau choice');
    end if;
    if char_length(btrim(coalesce(v_field ->> 'label_id', ''))) not between 2 and 80
       or char_length(btrim(coalesce(v_field ->> 'label_en', ''))) not between 2 and 80 then
      perform private.api_error(400, 'invalid_intake', 'Label pertanyaan 2–80 karakter dalam dua bahasa');
    end if;
    v_opts := '[]';
    if v_type = 'choice' then
      if jsonb_typeof(v_field -> 'options') <> 'array' or jsonb_array_length(v_field -> 'options') not between 2 and 10 then
        perform private.api_error(400, 'invalid_intake', 'Pilihan berisi 2–10 opsi');
      end if;
      v_values := '{}';
      for v_option in select value from jsonb_array_elements(v_field -> 'options') loop
        if coalesce(v_option ->> 'value', '') !~ '^[a-z0-9_]{1,32}$' or (v_option ->> 'value') = any (v_values)
           or char_length(btrim(coalesce(v_option ->> 'label_id', ''))) not between 1 and 60
           or char_length(btrim(coalesce(v_option ->> 'label_en', ''))) not between 1 and 60 then
          perform private.api_error(400, 'invalid_intake', 'Opsi butuh nilai unik dan label 1–60 karakter');
        end if;
        v_values := v_values || (v_option ->> 'value');
        v_opts := v_opts || jsonb_build_array(jsonb_build_object('value', v_option ->> 'value',
          'label_id', btrim(v_option ->> 'label_id'), 'label_en', btrim(v_option ->> 'label_en')));
      end loop;
    end if;
    v_keys := v_keys || v_key;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'key', v_key, 'type', v_type, 'label_id', btrim(v_field ->> 'label_id'), 'label_en', btrim(v_field ->> 'label_en'),
      'required', coalesce((v_field ->> 'required')::boolean, false), 'options', v_opts));
  end loop;
  return v_out;
end;
$$;

create or replace function cs.valid_iso_date(p_value text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p_value ~ '^\d{4}-\d{2}-\d{2}$'
     and to_char(make_date(substr(p_value, 1, 4)::integer, substr(p_value, 6, 2)::integer,
                           substr(p_value, 9, 2)::integer), 'YYYY-MM-DD') = p_value;
exception when others then
  return false;
end;
$$;

create or replace function cs.check_intake_answers(p_topic text, p_answers jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fields jsonb := coalesce((select t.intake from cs.support_topics t where t.code = p_topic), '[]');
  v_field  jsonb;
  v_value  text;
  v_out    jsonb := '[]';
begin
  if p_answers is not null and jsonb_typeof(p_answers) <> 'object' then
    perform private.api_error(400, 'invalid_intake_answers', 'Jawaban pertanyaan awal harus objek');
  end if;
  for v_field in select value from jsonb_array_elements(v_fields) loop
    v_value := nullif(btrim(coalesce(p_answers ->> (v_field ->> 'key'), '')), '');
    if v_value is null then
      if (v_field ->> 'required')::boolean then
        perform private.api_error(400, 'intake_required', format('Isi dulu: %s', v_field ->> 'label_id'));
      end if;
      continue;
    end if;
    if char_length(v_value) > 200
       or (v_field ->> 'type' = 'number' and v_value !~ '^-?[0-9]{1,15}([.,][0-9]{1,4})?$')
       or (v_field ->> 'type' = 'date' and not cs.valid_iso_date(v_value))
       or (v_field ->> 'type' = 'choice'
           and not exists (select 1 from jsonb_array_elements(v_field -> 'options') o where o ->> 'value' = v_value)) then
      perform private.api_error(400, 'invalid_intake_answers', format('Jawaban tidak valid: %s', v_field ->> 'label_id'));
    end if;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'key', v_field ->> 'key', 'type', v_field ->> 'type', 'label', v_field ->> 'label_id', 'value', v_value,
      'display', case when v_field ->> 'type' = 'choice'
                      then (select o ->> 'label_id' from jsonb_array_elements(v_field -> 'options') o
                            where o ->> 'value' = v_value) else v_value end));
  end loop;
  return v_out;
end;
$$;

create or replace function cs.queue_eta_minutes(p_ahead integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when w.minutes is null then null
              else least(greatest(ceil(w.minutes * (coalesce(p_ahead, 0) + 1)
                                       / greatest((select count(*) from cs.agent_status s where s.status = 'online'), 1)),
                                  1), 240)::integer end
  from (select percentile_cont(0.5) within group (order by extract(epoch from x.first_claimed_at - x.queued_at) / 60)
                 as minutes
        from cs.tickets x
        where x.first_claimed_at is not null and x.queued_at is not null
          and x.first_claimed_at > now() - interval '7 days') w;
$$;

create or replace function cs.topic_admin_row(t cs.support_topics)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'code', t.code, 'name_id', t.name_id, 'name_en', t.name_en, 'skill', t.skill,
    'default_priority', t.default_priority, 'help_url', t.help_url, 'sort_order', t.sort_order,
    'active', t.active, 'description_id', t.description_id, 'description_en', t.description_en,
    'icon', t.icon, 'style', t.style, 'flags', to_jsonb(t.flags),
    'intake', t.intake, 'customer_replies', t.customer_replies, 'sop', t.sop);
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
           'description', case when p_language = 'en' then t.description_en else t.description_id end,
           'icon', t.icon,
           'style', t.style,
           'help_url', t.help_url,
           'urgent', t.default_priority = 'P1',
           'intake', (select coalesce(jsonb_agg(jsonb_build_object(
                         'key', f ->> 'key', 'type', f ->> 'type',
                         'label', case when p_language = 'en' then f ->> 'label_en' else f ->> 'label_id' end,
                         'required', (f ->> 'required')::boolean,
                         'options', (select coalesce(jsonb_agg(jsonb_build_object(
                                        'value', o ->> 'value',
                                        'label', case when p_language = 'en' then o ->> 'label_en' else o ->> 'label_id' end)), '[]')
                                     from jsonb_array_elements(f -> 'options') o))), '[]')
                      from jsonb_array_elements(t.intake) f))
         order by t.sort_order, t.code), '[]')
  from cs.support_topics t
  where t.active;
$$;

create or replace function cs_api.admin_set_topic_extras(p_code text, p_intake jsonb, p_customer_replies jsonb,
                                                         p_sop text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_old     cs.support_topics;
  v_intake  jsonb := cs.check_topic_intake(p_intake);
  v_replies jsonb := '[]';
  v_reply   jsonb;
  v_sop     text := nullif(btrim(coalesce(p_sop, '')), '');
  t         cs.support_topics;
begin
  select * into v_old from cs.support_topics x where x.code = p_code for update;
  if v_old.code is null then
    perform private.api_error(404, 'topic_not_found', 'Topik tidak ditemukan');
  end if;
  if jsonb_typeof(coalesce(p_customer_replies, '[]')) <> 'array' or jsonb_array_length(coalesce(p_customer_replies, '[]')) > 6 then
    perform private.api_error(400, 'invalid_customer_replies', 'Maksimal 6 saran balasan');
  end if;
  for v_reply in select value from jsonb_array_elements(coalesce(p_customer_replies, '[]')) loop
    if char_length(btrim(coalesce(v_reply ->> 'id', ''))) not between 1 and 40
       or char_length(btrim(coalesce(v_reply ->> 'en', ''))) not between 1 and 40 then
      perform private.api_error(400, 'invalid_customer_replies', 'Saran balasan 1–40 karakter dalam dua bahasa');
    end if;
    v_replies := v_replies || jsonb_build_array(jsonb_build_object('id', btrim(v_reply ->> 'id'), 'en', btrim(v_reply ->> 'en')));
  end loop;
  if char_length(v_sop) > 4000 then
    perform private.api_error(400, 'invalid_sop', 'SOP maksimal 4.000 karakter');
  end if;
  update cs.support_topics set intake = v_intake, customer_replies = v_replies, sop = v_sop
   where code = p_code
  returning * into t;
  perform cs.audit('topic.extras', null, null, jsonb_build_object(
    'code', p_code,
    'before', jsonb_build_object('intake', v_old.intake, 'customer_replies', v_old.customer_replies, 'sop', v_old.sop),
    'after', jsonb_build_object('intake', t.intake, 'customer_replies', t.customer_replies, 'sop', t.sop)));
  return cs.topic_admin_row(t);
end;
$$;

drop function cs_api.open_ticket(text, text, text, boolean);

create function cs_api.open_ticket(p_topic text, p_language text default 'id', p_screen text default null,
                                   p_complaint boolean default false, p_intake jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_customer();
  v_answers jsonb;
  v_context jsonb := '{}';
  t         cs.tickets;
begin
  if coalesce(p_language, '') not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if p_screen is not null and p_screen !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_screen', 'Asal layar tidak valid');
  end if;
  if not exists (select 1 from cs.tickets x where x.customer_id = v_me and x.status in ('open', 'claimed', 'waiting_customer')) then
    v_answers := cs.check_intake_answers(p_topic, p_intake);
  end if;
  if p_screen is not null then
    v_context := v_context || jsonb_build_object('screen', p_screen);
  end if;
  if jsonb_array_length(coalesce(v_answers, '[]')) > 0 then
    v_context := v_context || jsonb_build_object('intake', v_answers);
  end if;
  t := cs.open_ticket(v_me, p_topic, p_language,
                      case when p_complaint then array['complaint'] else array[]::text[] end,
                      v_context, null);
  if p_complaint and not ('complaint' = any (t.flags)) then
    t := cs.flag_ticket(t.id, 'complaint');
  end if;
  return cs.ticket_customer_view(t);
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
    'queue_ahead', q.ahead,
    'eta_minutes', case when t.status = 'open' then cs.queue_eta_minutes(q.ahead) end,
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
    'can_rate', t.status in ('resolved', 'closed') and t.first_claimed_at is not null and t.rating is null,
    'quick_replies', case when t.status in ('open', 'claimed', 'waiting_customer') then (
      select coalesce(jsonb_agg(case when t.language = 'en' then r ->> 'en' else r ->> 'id' end), '[]')
      from cs.support_topics tp, jsonb_array_elements(tp.customer_replies) r where tp.code = t.topic) end
  )
  from (select case when t.status = 'open' then (
          select count(*)::integer from cs.tickets w
          where w.status = 'open' and w.id <> t.id and (w.priority, w.queued_at) < (t.priority, t.queued_at)) end as ahead) q;
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
    'intake', coalesce(t.context -> 'intake', '[]'),
    'topic_sop', (select tp.sop from cs.support_topics tp where tp.code = t.topic),
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
    'labels', cs.ticket_label_list(t.id),
    'transfer', (select jsonb_build_object('id', x.id, 'from_id', x.from_agent_id, 'from_name', cs.agent_name(x.from_agent_id),
                                           'to_id', x.to_agent_id, 'to_name', cs.agent_name(x.to_agent_id),
                                           'note', x.note, 'expires_at', x.expires_at)
                 from cs.ticket_transfers x where x.ticket_id = t.id and x.result is null)
  );
$$;

revoke execute on function cs.check_topic_intake(jsonb) from public;
revoke execute on function cs.valid_iso_date(text) from public;
revoke execute on function cs.check_intake_answers(text, jsonb) from public;
revoke execute on function cs.queue_eta_minutes(integer) from public;
revoke execute on function cs_api.admin_set_topic_extras(text, jsonb, jsonb, text) from public;
revoke execute on function cs_api.open_ticket(text, text, text, boolean, jsonb) from public;
grant execute on function cs_api.admin_set_topic_extras(text, jsonb, jsonb, text) to authenticated;
grant execute on function cs_api.open_ticket(text, text, text, boolean, jsonb) to authenticated;
