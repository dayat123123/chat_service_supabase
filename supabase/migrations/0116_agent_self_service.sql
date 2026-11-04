create or replace function cs.session_alive()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_session text := auth.jwt() ->> 'session_id';
begin
  if coalesce(v_session, '') = '' then
    return true;
  end if;
  if v_session !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return exists (select 1 from auth.sessions s where s.id = v_session::uuid);
end;
$$;

create or replace function cs.current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.user_id
  from cs.agents a
  where a.user_id = auth.uid()
    and a.disabled_at is null
    and coalesce(auth.role(), '') = 'authenticated'
    and cs.session_alive();
$$;

create or replace function cs.session_revoked()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.role(), '') = 'authenticated'
     and not cs.session_alive()
     and exists (select 1 from cs.agents a where a.user_id = auth.uid() and a.disabled_at is null);
$$;

create or replace function cs.require_agent(p_roles text[] default null)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := cs.current_agent_id();
begin
  if v_id is null then
    if cs.session_revoked() then
      perform private.api_error(401, 'session_revoked', 'Sesi ini sudah dikeluarkan, silakan masuk lagi');
    end if;
    perform private.api_error(403, 'agent_required', 'Butuh akun CS aktif');
  end if;
  if p_roles is not null and not cs.has_role(p_roles) then
    perform private.api_error(403, 'role_forbidden', 'Peran Anda tidak cukup untuk aksi ini');
  end if;
  return v_id;
end;
$$;

create or replace function cs.audit_self(p_action text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent();
  v_last timestamptz;
begin
  select max(l.created_at) into v_last
  from cs.cs_audit_log l
  where l.actor_id = v_me and l.action = p_action and l.created_at > now() - interval '30 seconds';
  if v_last is not null then
    return v_last;
  end if;
  perform cs.audit(p_action, null, null, jsonb_build_object('agent', v_me));
  return now();
end;
$$;

create or replace function cs_api.agent_password_changed()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return jsonb_build_object('password_changed_at', cs.audit_self('agent.password_changed'));
end;
$$;

create or replace function cs_api.agent_signed_out_everywhere()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return jsonb_build_object('signed_out_at', cs.audit_self('agent.signed_out_everywhere'));
end;
$$;

create or replace function cs_api.agent_my_profile()
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
      'email', u.email,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'team_name', jsonb_build_object('id', tm.name_id, 'en', tm.name_en),
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'nasabah_permissions', to_jsonb(a.nasabah_permissions),
      'community_permissions', to_jsonb(a.community_permissions),
      'created_at', a.created_at,
      'password_changed_at', (
        select max(l.created_at) from cs.cs_audit_log l
        where l.actor_id = a.user_id and l.action = 'agent.password_changed'))
    from cs.agents a
    left join auth.users u on u.id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
end;
$$;

create or replace function cs_api.agent_my_stats(p_period text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_agent}');
  v_days  integer := case p_period when 'today' then 1 when '7d' then 7 when '30d' then 30 end;
  v_to    date := cs.local_date(now());
  v_from  date;
  v_range tstzrange;
begin
  if v_days is null then
    perform private.api_error(400, 'invalid_period', 'Periode harus today, 7d, atau 30d');
  end if;
  v_from := v_to - (v_days - 1);
  v_range := cs.report_range(v_from, v_to);
  return (
    select jsonb_build_object(
      'period', p_period,
      'from', v_from,
      'to', v_to,
      'handled', count(*),
      'resolved', count(*) filter (where t.resolved_by = v_me),
      'active_tickets', cs.active_ticket_count(v_me),
      'avg_first_response_minutes',
        round((avg(extract(epoch from t.first_response_at - t.first_claimed_at)) / 60)::numeric, 1),
      'avg_resolution_minutes',
        round((avg(extract(epoch from t.resolved_at - t.created_at)) filter (where t.resolved_by = v_me) / 60)::numeric, 1),
      'avg_rating', round(avg(t.rating)::numeric, 2),
      'ratings', count(t.rating),
      'rating_counts', jsonb_build_object(
        '1', count(*) filter (where t.rating = 1),
        '2', count(*) filter (where t.rating = 2),
        '3', count(*) filter (where t.rating = 3),
        '4', count(*) filter (where t.rating = 4),
        '5', count(*) filter (where t.rating = 5)),
      'complaints', count(*) filter (where t.complaint_received_at is not null))
    from cs.tickets t
    where t.last_owner_id = v_me
      and t.created_at >= lower(v_range)
      and t.created_at < upper(v_range));
end;
$$;

revoke execute on function cs.session_alive() from public;
revoke execute on function cs.session_revoked() from public;
revoke execute on function cs.audit_self(text) from public;
revoke execute on function cs_api.agent_password_changed() from public;
revoke execute on function cs_api.agent_signed_out_everywhere() from public;
revoke execute on function cs_api.agent_my_profile() from public;
revoke execute on function cs_api.agent_my_stats(text) from public;
grant execute on function cs.session_revoked() to authenticated;
grant execute on function cs_api.agent_password_changed() to authenticated;
grant execute on function cs_api.agent_signed_out_everywhere() to authenticated;
grant execute on function cs_api.agent_my_profile() to authenticated;
grant execute on function cs_api.agent_my_stats(text) to authenticated;
