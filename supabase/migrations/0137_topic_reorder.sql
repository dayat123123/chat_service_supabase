create or replace function cs_api.admin_reorder_topics(p_codes text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_before jsonb;
begin
  if p_codes is null or cardinality(p_codes) <> (select count(*) from cs.support_topics)
     or cardinality(p_codes) <> (select count(distinct c) from unnest(p_codes) c)
     or exists (select 1 from unnest(p_codes) c where not exists (select 1 from cs.support_topics t where t.code = c)) then
    perform private.api_error(400, 'invalid_topic_order', 'Urutan harus memuat setiap topik tepat satu kali');
  end if;
  select jsonb_agg(t.code order by t.sort_order, t.code) into v_before from cs.support_topics t;
  update cs.support_topics t
     set sort_order = (o.ord * 10)::smallint
    from unnest(p_codes) with ordinality as o(code, ord)
   where t.code = o.code and t.sort_order is distinct from (o.ord * 10)::smallint;
  perform cs.audit('topic.reorder', null, null, jsonb_build_object('before', v_before, 'after', to_jsonb(p_codes)));
  return cs_api.admin_topics();
end;
$$;

revoke execute on function cs_api.admin_reorder_topics(text[]) from public;
grant execute on function cs_api.admin_reorder_topics(text[]) to authenticated;
