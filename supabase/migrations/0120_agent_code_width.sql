create or replace function private.agent_code(p_number bigint)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'CS-' || lpad(p_number::text, greatest(4, length(p_number::text)), '0');
$$;

create or replace function cs.create_agent(p_user_id uuid, p_display_name text, p_roles text[] default '{cs_agent}'::text[], p_team text default 'general'::text, p_skills jsonb default '{"general": 1}'::jsonb, p_languages text[] default '{id}'::text[], p_max_concurrent integer default 5, p_created_by uuid default null::uuid)
returns cs.agents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code     text := private.agent_code(nextval('cs.agent_code_seq'));
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

revoke execute on function private.agent_code(bigint) from public;
