create table cs.ticket_labels (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 30 and name = btrim(name)),
  color      text not null default 'neutral' check (color in ('neutral', 'info', 'success', 'warning', 'danger')),
  active     boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index ticket_labels_name_idx on cs.ticket_labels (lower(name));

create table cs.ticket_label_links (
  ticket_id uuid not null references cs.tickets (id) on delete cascade,
  label_id  uuid not null references cs.ticket_labels (id) on delete cascade,
  added_by  uuid,
  added_at  timestamptz not null default now(),
  primary key (ticket_id, label_id)
);
create index ticket_label_links_label_idx on cs.ticket_label_links (label_id, ticket_id);

alter table cs.ticket_labels enable row level security;
alter table cs.ticket_label_links enable row level security;
revoke all on cs.ticket_labels, cs.ticket_label_links from public, anon, authenticated;

create or replace function cs.ticket_label_list(p_ticket_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color)
                            order by l.sort_order, lower(l.name)), '[]')
  from cs.ticket_label_links k
  join cs.ticket_labels l on l.id = k.label_id
  where k.ticket_id = p_ticket_id;
$$;

do $$
declare
  v_def text := pg_get_functiondef('cs.ticket_agent_view(cs.tickets)'::regprocedure);
begin
  if position('''labels''' in v_def) = 0 then
    if position('''transfer'', (select' in v_def) = 0 then
      raise exception 'cs.ticket_agent_view tidak memiliki penanda transfer untuk menyisipkan label';
    end if;
    execute replace(v_def, '''transfer'', (select', '''labels'', cs.ticket_label_list(t.id),
    ''transfer'', (select');
  end if;
end;
$$;

create or replace function cs.ticket_label_view(l cs.ticket_labels)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color, 'active', l.active,
                            'sort_order', l.sort_order, 'updated_at', l.updated_at);
$$;

create or replace function cs.ticket_for_label_change(p_ticket_id uuid)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent,cs_super_admin}');
  t    cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found or not cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not (cs.has_role('{cs_super_admin}')
          or (t.owner_agent_id = v_me and t.status in ('claimed', 'waiting_customer'))) then
    perform private.api_error(403, 'not_ticket_owner', 'Label hanya bisa diubah CS pemegang tiket atau Super Admin');
  end if;
  return t;
end;
$$;

create or replace function cs_api.ticket_labels()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color)
                     order by l.sort_order, lower(l.name))
    from cs.ticket_labels l
    where l.active), '[]');
end;
$$;

create or replace function cs_api.admin_ticket_labels()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((
    select jsonb_agg(cs.ticket_label_view(l)
                     || jsonb_build_object('tickets', (select count(*) from cs.ticket_label_links k where k.label_id = l.id))
                     order by l.sort_order, lower(l.name))
    from cs.ticket_labels l), '[]');
end;
$$;

create or replace function cs_api.admin_save_ticket_label(
  p_id     uuid,
  p_name   text,
  p_color  text,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin}');
  v_name   text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  v_active boolean := coalesce(p_active, true);
  v_before cs.ticket_labels;
  l        cs.ticket_labels;
begin
  if char_length(v_name) not between 1 and 30 then
    perform private.api_error(400, 'invalid_label_name', 'Nama label 1–30 karakter');
  end if;
  if coalesce(p_color, '') not in ('neutral', 'info', 'success', 'warning', 'danger') then
    perform private.api_error(400, 'invalid_label_color', 'Warna label tidak dikenal');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('cs.ticket_labels', 0));
  if p_id is not null then
    select * into v_before from cs.ticket_labels where id = p_id for update;
    if not found then
      perform private.api_error(404, 'label_not_found', 'Label tidak ditemukan');
    end if;
  end if;
  if exists (select 1 from cs.ticket_labels x where lower(x.name) = lower(v_name) and x.id is distinct from p_id) then
    perform private.api_error(409, 'duplicate_label', 'Nama label sudah dipakai');
  end if;
  if v_active and not coalesce(v_before.active, false)
     and (select count(*) from cs.ticket_labels x where x.active) >= 50 then
    perform private.api_error(409, 'label_limit', 'Maksimal 50 label aktif');
  end if;
  if p_id is null then
    insert into cs.ticket_labels (name, color, active, sort_order, created_by)
    values (v_name, p_color, v_active, coalesce((select max(x.sort_order) + 1 from cs.ticket_labels x), 0), v_me)
    returning * into l;
    perform cs.audit('ticket_label.save', null, null,
      jsonb_build_object('label_id', l.id, 'after', jsonb_build_object('name', l.name, 'color', l.color, 'active', l.active)));
  else
    update cs.ticket_labels
       set name = v_name, color = p_color, active = v_active, updated_at = now()
     where id = p_id
    returning * into l;
    perform cs.audit('ticket_label.save', null, null,
      jsonb_build_object('label_id', l.id,
        'before', jsonb_build_object('name', v_before.name, 'color', v_before.color, 'active', v_before.active),
        'after', jsonb_build_object('name', l.name, 'color', l.color, 'active', l.active)));
  end if;
  return cs_api.admin_ticket_labels();
end;
$$;

create or replace function cs_api.admin_reorder_ticket_labels(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  perform pg_advisory_xact_lock(hashtextextended('cs.ticket_labels', 0));
  if p_ids is null
     or cardinality(p_ids) <> (select count(distinct x) from unnest(p_ids) x)
     or cardinality(p_ids) <> (select count(*) from cs.ticket_labels)
     or exists (select 1 from unnest(p_ids) x where not exists (select 1 from cs.ticket_labels l where l.id = x)) then
    perform private.api_error(400, 'invalid_label_order', 'Urutan harus memuat semua label tepat satu kali');
  end if;
  update cs.ticket_labels l
     set sort_order = o.n - 1, updated_at = now()
    from unnest(p_ids) with ordinality o(id, n)
   where l.id = o.id and l.sort_order is distinct from o.n - 1;
  perform cs.audit('ticket_label.reorder', null, null, jsonb_build_object('labels', to_jsonb(p_ids)));
  return cs_api.admin_ticket_labels();
end;
$$;

create or replace function cs_api.add_ticket_label(p_ticket_id uuid, p_label_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets := cs.ticket_for_label_change(p_ticket_id);
  l cs.ticket_labels;
begin
  select * into l from cs.ticket_labels where id = p_label_id;
  if not found then
    perform private.api_error(404, 'label_not_found', 'Label tidak ditemukan');
  end if;
  if exists (select 1 from cs.ticket_label_links k where k.ticket_id = t.id and k.label_id = l.id) then
    return cs.ticket_label_list(t.id);
  end if;
  if not l.active then
    perform private.api_error(409, 'label_inactive', 'Label sudah tidak aktif');
  end if;
  if (select count(*) from cs.ticket_label_links k where k.ticket_id = t.id) >= 5 then
    perform private.api_error(409, 'ticket_label_limit', 'Maksimal 5 label per tiket');
  end if;
  insert into cs.ticket_label_links (ticket_id, label_id, added_by) values (t.id, l.id, auth.uid());
  perform cs.log_event(t.id, 'label_added', jsonb_build_object('label', l.name));
  perform cs.audit('ticket.label_add', t.id, t.customer_id, jsonb_build_object('label_id', l.id, 'label', l.name));
  perform cs.broadcast_ticket(t, 'ticket_labels');
  return cs.ticket_label_list(t.id);
end;
$$;

create or replace function cs_api.remove_ticket_label(p_ticket_id uuid, p_label_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      cs.tickets := cs.ticket_for_label_change(p_ticket_id);
  v_name text;
begin
  delete from cs.ticket_label_links k
   using cs.ticket_labels l
   where k.ticket_id = t.id and k.label_id = p_label_id and l.id = k.label_id
  returning l.name into v_name;
  if v_name is not null then
    perform cs.log_event(t.id, 'label_removed', jsonb_build_object('label', v_name));
    perform cs.audit('ticket.label_remove', t.id, t.customer_id, jsonb_build_object('label_id', p_label_id, 'label', v_name));
    perform cs.broadcast_ticket(t, 'ticket_labels');
  end if;
  return cs.ticket_label_list(t.id);
end;
$$;

create or replace function cs_api.report_ticket_labels(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_from timestamptz;
  v_to   timestamptz;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    perform private.api_error(400, 'invalid_range', 'Rentang laporan 1–93 hari');
  end if;
  v_from := p_from::timestamp at time zone 'Asia/Jakarta';
  v_to := (p_to + 1)::timestamp at time zone 'Asia/Jakarta';
  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'total', (select count(*) from cs.tickets t where t.created_at >= v_from and t.created_at < v_to),
    'unlabeled', (select count(*) from cs.tickets t
                  where t.created_at >= v_from and t.created_at < v_to
                    and not exists (select 1 from cs.ticket_label_links k where k.ticket_id = t.id)),
    'labels', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color, 'active', l.active,
                                          'count', c.n)
                       order by c.n desc, l.sort_order, lower(l.name))
      from cs.ticket_labels l
      cross join lateral (
        select count(*)::integer as n
        from cs.ticket_label_links k
        join cs.tickets t on t.id = k.ticket_id
        where k.label_id = l.id and t.created_at >= v_from and t.created_at < v_to) c
      where l.active or c.n > 0), '[]'));
end;
$$;

revoke execute on function cs.ticket_label_list(uuid) from public;
revoke execute on function cs.ticket_label_view(cs.ticket_labels) from public;
revoke execute on function cs.ticket_for_label_change(uuid) from public;
revoke execute on function cs_api.ticket_labels() from public;
revoke execute on function cs_api.admin_ticket_labels() from public;
revoke execute on function cs_api.admin_save_ticket_label(uuid, text, text, boolean) from public;
revoke execute on function cs_api.admin_reorder_ticket_labels(uuid[]) from public;
revoke execute on function cs_api.add_ticket_label(uuid, uuid) from public;
revoke execute on function cs_api.remove_ticket_label(uuid, uuid) from public;
revoke execute on function cs_api.report_ticket_labels(date, date) from public;

grant execute on function cs_api.ticket_labels() to authenticated;
grant execute on function cs_api.admin_ticket_labels() to authenticated;
grant execute on function cs_api.admin_save_ticket_label(uuid, text, text, boolean) to authenticated;
grant execute on function cs_api.admin_reorder_ticket_labels(uuid[]) to authenticated;
grant execute on function cs_api.add_ticket_label(uuid, uuid) to authenticated;
grant execute on function cs_api.remove_ticket_label(uuid, uuid) to authenticated;
grant execute on function cs_api.report_ticket_labels(date, date) to authenticated;
