create or replace function private.app_integration_bridge(p_detail jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'app_env', left(p_detail ->> 'app_env', 40),
    'olt_mode', left(p_detail ->> 'olt_mode', 40),
    'issuer', left(p_detail ->> 'issuer', 200),
    'audience', left(p_detail ->> 'audience', 200),
    'max_ttl_seconds', case when jsonb_typeof(p_detail -> 'max_ttl_seconds') = 'number' then p_detail -> 'max_ttl_seconds' end,
    'key_count', case when jsonb_typeof(p_detail -> 'key_count') = 'number' then p_detail -> 'key_count' end,
    'keys', coalesce((
      select jsonb_agg(jsonb_build_object('kid', left(k ->> 'kid', 100), 'alg', left(k ->> 'alg', 20)) order by k ->> 'kid')
      from jsonb_array_elements(case when jsonb_typeof(p_detail -> 'keys') = 'array' then p_detail -> 'keys' else '[]' end) k
      where jsonb_typeof(k -> 'kid') = 'string'), '[]'));
$$;

create or replace function cs_api.app_integration_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{cs_super_admin}');
  v_instances jsonb;
  v_warnings  jsonb;
begin
  with live as (
    select s.instance, s.version, s.started_at, s.last_seen_at, s.status, s.error,
           private.app_integration_bridge(s.detail) as bridge
    from private.service_instances s
    where s.service = 'auth-bridge' and s.last_seen_at > now() - interval '3 minutes'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'instance', l.instance, 'version', l.version, 'started_at', l.started_at,
           'last_seen_at', l.last_seen_at, 'status', l.status, 'error', l.error) || l.bridge
           order by l.last_seen_at desc), '[]'),
         to_jsonb(array_remove(array[
           case when bool_or(exists (select 1 from jsonb_array_elements(l.bridge -> 'keys') k
                                     where k ->> 'kid' like 'dev-%')) then 'dev_key' end,
           case when bool_or(coalesce(l.bridge ->> 'olt_mode', '') <> 'jwt'
                             and coalesce(l.bridge ->> 'app_env', '') <> 'development') then 'not_jwt' end,
           case when count(distinct l.bridge - 'app_env' - 'key_count') > 1 then 'mismatch' end
         ], null))
    into v_instances, v_warnings
  from live l;

  return jsonb_build_object(
    'now', now(),
    'status', case
      when jsonb_array_length(v_instances) = 0 then 'no_heartbeat'
      when jsonb_array_length(v_warnings) > 0 then 'warning'
      else 'active' end,
    'warnings', v_warnings,
    'instances', v_instances,
    'last_seen_at', (select max(s.last_seen_at) from private.service_instances s where s.service = 'auth-bridge'),
    'logins', (select jsonb_build_object(
        'last_login_at', max(u.last_login_at),
        'users_24h', count(*) filter (where u.last_login_at > now() - interval '24 hours'))
      from private.user_private u));
end;
$$;

revoke execute on function private.app_integration_bridge(jsonb) from public;
revoke execute on function cs_api.app_integration_overview() from public;

grant execute on function cs_api.app_integration_overview() to authenticated;
