alter table cs.agents drop constraint agents_roles_check;
alter table cs.agents add constraint agents_roles_check
  check (cardinality(roles) > 0
         and roles <@ array['cs_agent', 'cs_super_admin', 'compliance', 'community', 'product', 'cs_content']);

create or replace function cs.check_agent_input(p_display_name text, p_roles text[], p_team text, p_max integer)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if char_length(btrim(coalesce(p_display_name, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama CS 2–40 karakter');
  end if;
  if coalesce(cardinality(p_roles), 0) = 0
     or not (p_roles <@ '{cs_agent,cs_super_admin,compliance,community,product,cs_content}'::text[]) then
    perform private.api_error(400, 'invalid_roles',
      'Peran harus cs_agent, cs_super_admin, compliance, community, product, atau cs_content');
  end if;
  if p_team is not null and not exists (select 1 from cs.teams t where t.code = p_team and t.active) then
    perform private.api_error(400, 'invalid_team', 'Tim tidak dikenal');
  end if;
  if coalesce(p_max, 0) not between 1 and 20 then
    perform private.api_error(400, 'invalid_limit', 'Batas tiket aktif 1–20');
  end if;
end;
$$;

create or replace function cs_api.admin_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return jsonb_build_object(
    'teams', coalesce((select jsonb_agg(jsonb_build_object('code', t.code, 'name', t.name_id) order by t.name_id)
                       from cs.teams t where t.active), '[]'),
    'skills', coalesce((select jsonb_agg(jsonb_build_object('code', s.code, 'name', s.name_id) order by s.name_id)
                        from cs.skills s), '[]'));
end;
$$;

create or replace function cs_api.admin_topics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'code', t.code, 'name_id', t.name_id, 'name_en', t.name_en, 'skill', t.skill,
             'default_priority', t.default_priority, 'help_url', t.help_url, 'sort_order', t.sort_order,
             'active', t.active)
           order by t.sort_order, t.code)
    from cs.support_topics t), '[]');
end;
$$;

create or replace function cs_api.admin_save_topic(p_code text, p_name_id text, p_name_en text, p_skill text,
                                                   p_default_priority text, p_help_url text, p_sort_order integer,
                                                   p_active boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_url text := nullif(btrim(coalesce(p_help_url, '')), '');
begin
  if coalesce(p_code, '') !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_code', 'Kode topik 2–32 huruf kecil, angka, atau garis bawah');
  end if;
  if char_length(btrim(coalesce(p_name_id, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_name_en, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama topik (ID dan EN) 2–40 karakter');
  end if;
  if not exists (select 1 from cs.skills s where s.code = p_skill) then
    perform private.api_error(400, 'invalid_skill', 'Skill tidak dikenal');
  end if;
  if coalesce(p_default_priority, '') not in ('P1', 'P2', 'P3', 'P4') then
    perform private.api_error(400, 'invalid_priority', 'Prioritas harus P1–P4');
  end if;
  if coalesce(p_sort_order, -1) not between 0 and 999 then
    perform private.api_error(400, 'invalid_sort', 'Urutan 0–999');
  end if;
  if v_url is not null and (v_url !~ '^https://[A-Za-z0-9.-]+(/\S*)?$'
     or not (cs.setting('help.allowed_hosts') ? lower(substring(v_url from '^https://([A-Za-z0-9.-]+)')))) then
    perform private.api_error(400, 'invalid_help_link', 'Tautan bantuan harus https ke situs bantuan resmi');
  end if;
  if not coalesce(p_active, true) and p_code = cs.setting('ticket.default_topic') #>> '{}' then
    perform private.api_error(400, 'default_topic', 'Topik bawaan tidak bisa dinonaktifkan');
  end if;
  insert into cs.support_topics (code, name_id, name_en, skill, default_priority, help_url, sort_order, active)
  values (p_code, btrim(p_name_id), btrim(p_name_en), p_skill, p_default_priority, v_url, p_sort_order,
          coalesce(p_active, true))
  on conflict (code) do update
    set name_id = excluded.name_id, name_en = excluded.name_en, skill = excluded.skill,
        default_priority = excluded.default_priority, help_url = excluded.help_url,
        sort_order = excluded.sort_order, active = excluded.active;
  perform cs.audit('topic.save', null, null, jsonb_build_object('code', p_code, 'active', coalesce(p_active, true)));
  return cs_api.admin_topics();
end;
$$;
