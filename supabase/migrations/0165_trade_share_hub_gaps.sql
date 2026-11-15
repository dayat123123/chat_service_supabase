create or replace function cs.trade_share_agent_name(p_agent uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.display_name from cs.agents a where a.user_id = p_agent;
$$;

create or replace function cs_api.agent_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent();
  v_ready boolean := cs.nasabah_ready();
begin
  return (
    select jsonb_build_object(
      'id', a.user_id,
      'agent_code', a.agent_code,
      'display_name', a.display_name,
      'roles', to_jsonb(a.roles),
      'team', tm.code,
      'languages', to_jsonb(a.languages),
      'max_active_tickets', a.max_active_tickets,
      'status', st.status,
      'reason', st.reason,
      'active_tickets', cs.active_ticket_count(a.user_id),
      'skills', coalesce((select jsonb_object_agg(k.skill, k.level) from cs.agent_skills k where k.agent_id = a.user_id), '{}'),
      'nasabah_permissions', case when v_ready then to_jsonb(a.nasabah_permissions) else '[]'::jsonb end,
      'community_permissions', to_jsonb(a.community_permissions),
      'trade_permissions', to_jsonb(a.trade_permissions),
      'settings', jsonb_build_object(
        'wait_warn_minutes', cs.setting_int('ui.wait_warn_minutes'),
        'wait_late_minutes', cs.setting_int('ui.wait_late_minutes'),
        'idle_logout_minutes', cs.setting_int('ui.idle_logout_minutes'),
        'assignment_mode', cs.setting('assignment.mode') #>> '{}',
        'outcomes', cs.setting('resolve.outcomes'),
        'nasabah_ready', v_ready,
        'community_four_eyes', coalesce((cs.setting('community.four_eyes') #>> '{}')::boolean, true),
        'community_push_ready', cs.push_state() = 'active'))
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.teams tm on tm.id = a.team_id
    where a.user_id = v_me);
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
      'trade_permissions', to_jsonb(a.trade_permissions),
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


create or replace function cs_api.legal_set_required(p_kinds text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_old   text[] := cs.legal_required_kinds();
  v_kinds text[] := coalesce((select array_agg(distinct k order by k) from unnest(coalesce(p_kinds, '{}')) k), '{}');
begin
  if not (v_kinds <@ cs.legal_kinds()) then
    perform private.api_error(400, 'invalid_legal_kind', 'Jenis dokumen tidak dikenal');
  end if;
  if v_kinds && array['trade_share_terms', 'trade_share_risk'] then
    perform private.api_error(400, 'legal_kind_not_global', 'Dokumen Berbagi Trade hanya disetujui di alur Berbagi Trade');
  end if;
  insert into private.settings (key, value, description)
  values ('legal.required_kinds', to_jsonb(v_kinds), 'Jenis dokumen hukum yang wajib disetujui sebelum membuat konten')
  on conflict (key) do update set value = excluded.value, updated_at = now();
  perform cs.audit('legal.required_changed', null, null,
                   jsonb_build_object('old', to_jsonb(v_old), 'new', to_jsonb(v_kinds)));
  return to_jsonb(v_kinds);
end;
$$;


create or replace function cs.trade_share_item(s private.trade_sharers)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', cs.trade_share_profile_ref(s.profile_id),
    'status', s.status,
    'pause_source', s.pause_source,
    'show_price', s.show_price,
    'show_lot', s.show_lot,
    'delay_minutes', s.delay_minutes,
    'subscribe_mode', s.subscribe_mode,
    'applied_at', s.applied_at,
    'proposed_by', s.proposed_by,
    'proposed_by_name', cs.trade_share_agent_name(s.proposed_by),
    'proposed_at', s.proposed_at,
    'decided_by', s.decided_by,
    'decided_by_name', cs.trade_share_agent_name(s.decided_by),
    'decided_at', s.decided_at,
    'decision_reason', s.decision_reason,
    'suspended_until', s.suspended_until,
    'cooldown_until', s.cooldown_until,
    'accounts', (select count(*) from private.trade_sharer_accounts a where a.profile_id = s.profile_id),
    'warnings', (select count(*) from private.trade_sharer_accounts a
                  where a.profile_id = s.profile_id and a.state <> 'active'),
    'subscribers', private.trade_share_subscriber_counts(s.profile_id));
$$;


create or replace function cs.trade_share_detail_view(p_profile uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s private.trade_sharers;
begin
  select * into s from private.trade_sharers where profile_id = p_profile;
  if not found then
    perform private.api_error(404, 'trader_not_found', 'Trader tidak ditemukan');
  end if;
  return cs.trade_share_item(s) || jsonb_build_object(
    'account_review', cs.trade_share_account_review(p_profile),
    'eligibility', private.trade_share_eligibility(p_profile),
    'sanctions', jsonb_build_object(
      'active', private.has_active_sanction(p_profile, '{warning,mute,ban}'),
      'last_365_days', (select count(*) from private.user_sanctions us
                         where us.user_id = p_profile and us.created_at > now() - interval '365 days')),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', e.id, 'action', e.action, 'actor_kind', e.actor_kind, 'actor_id', e.actor_id,
                          'actor_name', case when e.actor_kind = 'staff' then cs.trade_share_agent_name(e.actor_id) end,
                          'from_status', e.from_status, 'to_status', e.to_status, 'reason', e.reason,
                          'details', e.details, 'created_at', e.created_at) order by e.id desc)
                        from (select * from private.trade_share_events ev where ev.profile_id = p_profile
                               order by ev.id desc limit 100) e), '[]'));
end;
$$;


create or replace function cs.trade_relay_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'iproxy_addr', c.iproxy_addr,
    'identity', c.identity,
    'heartbeat_seconds', c.heartbeat_seconds,
    'aes', jsonb_build_object('configured', c.aes_key_secret_id is not null, 'mode', c.aes_mode,
                              'fingerprint', c.aes_key_fingerprint, 'key_length', c.aes_key_length,
                              'has_iv', c.aes_iv_secret_id is not null, 'updated_at', c.aes_updated_at),
    'reconnect_generation', c.reconnect_generation,
    'restart_generation', c.restart_generation,
    'last_command_at', c.last_command_at,
    'version', c.version,
    'updated_at', c.updated_at,
    'updated_by', c.updated_by,
    'updated_by_name', cs.trade_share_agent_name(c.updated_by),
    'trade_notify_enabled', private.trade_share_bool('trade_notify.enabled'),
    'trade_share_enabled', private.trade_share_enabled(),
    'instances', coalesce((select jsonb_agg(jsonb_build_object(
        'instance', s.instance, 'version', s.version, 'connected', s.connected, 'state', s.state,
        'last_packet_at', s.last_packet_at, 'last_realtime_at', s.last_realtime_at, 'counters', s.counters,
        'last_error', s.last_error, 'applied_reconnect', s.applied_reconnect, 'applied_restart', s.applied_restart,
        'started_at', s.started_at, 'reported_at', s.reported_at) order by s.reported_at desc)
      from private.trade_relay_status s where s.reported_at > now() - interval '1 day'), '[]'),
    'today', coalesce((select jsonb_object_agg(d.metric, d.count) from private.trade_relay_daily d
                        where d.day = (now() at time zone 'Asia/Jakarta')::date), '{}'))
  from private.trade_relay_config c where c.singleton;
$$;


create or replace function cs_api.trade_share_flags(p_status text default 'open', p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
begin
  if coalesce(p_status, '') not in ('open', 'reviewed') then
    perform private.api_error(400, 'invalid_status', 'Status harus open atau reviewed');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', f.id, 'profile', cs.trade_share_profile_ref(f.profile_id),
                                        'kind', f.kind, 'details', f.details, 'created_at', f.created_at,
                                        'reviewed_by', f.reviewed_by, 'reviewed_by_name', cs.trade_share_agent_name(f.reviewed_by), 'reviewed_at', f.reviewed_at, 'note', f.note)
                     order by f.created_at desc)
    from (select * from private.trade_share_flags x
           where (p_status = 'open') = (x.reviewed_at is null)
           order by x.created_at desc
           limit v_limit) f), '[]');
end;
$$;


create or replace function cs_api.trade_share_find_profiles(p_query text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_trade('{trade_share.review,trade_share.manage}');
  v_text text := ltrim(btrim(coalesce(p_query, '')), '@');
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(v_text, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'profile', cs.trade_share_profile_ref(x.id),
             'trader_status', (select s.status from private.trade_sharers s where s.profile_id = x.id),
             'pilot_invited', exists (select 1 from private.trade_share_pilot_invites i where i.profile_id = x.id),
             'linked_accounts', (select count(*) from private.account_links l where l.profile_id = x.id))
           order by x.username)
    from (select p.id, p.username from public.profiles p
          where p.deleted_at is null and not p.is_guest and p.olt_user_id not like 'cs-staff:%'
            and (p.username::text ilike v_like or p.display_name ilike v_like)
          order by (p.username::text ilike v_text) desc, p.username
          limit 20) x), '[]');
end;
$$;


revoke execute on function cs.trade_share_agent_name(uuid) from public;
revoke execute on function cs_api.trade_share_find_profiles(text) from public;
grant execute on function cs_api.trade_share_find_profiles(text) to authenticated;
