create or replace function cs_api.admin_set_banner_link_schemes(p_schemes text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin}');
  v_schemes text[] := coalesce((select array_agg(distinct lower(btrim(x)) order by lower(btrim(x)))
                                from unnest(coalesce(p_schemes, '{}')) x where btrim(x) <> ''), '{}');
  v_old     jsonb := cs.setting('banners.deep_link_schemes');
begin
  if cardinality(v_schemes) > 5 then
    perform private.api_error(400, 'invalid_link_schemes', 'Maksimal 5 skema deep link');
  end if;
  if exists (select 1 from unnest(v_schemes) x where x !~ '^[a-z][a-z0-9+.-]{0,31}$') then
    perform private.api_error(400, 'invalid_link_schemes',
      'Skema diawali huruf, hanya huruf kecil, angka, +, titik, atau -, maksimal 32 karakter');
  end if;
  if v_schemes && private.banner_forbidden_schemes() then
    perform private.api_error(400, 'invalid_link_schemes',
      'Skema ' || array_to_string(array(select x from unnest(v_schemes) x
                                        where x = any (private.banner_forbidden_schemes())), ', ')
      || ' tidak boleh dipakai sebagai deep link');
  end if;
  perform cs.set_setting('banners.deep_link_schemes', to_jsonb(v_schemes), v_me);
  perform cs.audit('banner.link_schemes', null, null, jsonb_build_object('before', v_old, 'after', to_jsonb(v_schemes)));
  return cs_api.admin_banner_settings();
end;
$$;
