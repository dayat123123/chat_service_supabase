create or replace function cs.topic_admin_row(t cs.support_topics)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'code', t.code, 'name_id', t.name_id, 'name_en', t.name_en, 'skill', t.skill,
    'default_priority', t.default_priority, 'help_url', t.help_url, 'sort_order', t.sort_order,
    'active', t.active, 'description_id', t.description_id, 'description_en', t.description_en,
    'icon', t.icon, 'style', t.style, 'flags', to_jsonb(t.flags),
    'intake', t.intake, 'customer_replies', t.customer_replies, 'sop', t.sop,
    'ticket_count', (select count(*) from cs.tickets x where x.topic = t.code));
$$;

create or replace function cs_api.admin_delete_topic(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_tickets bigint;
  t         cs.support_topics;
begin
  select * into t from cs.support_topics x where x.code = p_code for update;
  if t.code is null then
    perform private.api_error(404, 'topic_not_found', 'Topik tidak ditemukan');
  end if;
  if cardinality(t.flags) > 0 and not cs.has_role('{cs_super_admin}') then
    perform private.api_error(403, 'flags_forbidden', 'Topik bertanda pengaduan/penipuan hanya bisa dihapus Super Admin');
  end if;
  select count(*) into v_tickets from cs.tickets x where x.topic = p_code;
  if v_tickets > 0 then
    perform private.api_error(409, 'topic_in_use',
      format('Topik sudah dipakai %s tiket sehingga tidak bisa dihapus. Nonaktifkan saja agar tidak tampil di aplikasi.', v_tickets));
  end if;
  if t.active and not exists (select 1 from cs.support_topics x where x.active and x.code <> p_code) then
    perform private.api_error(409, 'last_active_topic', 'Minimal harus ada satu topik aktif');
  end if;
  delete from cs.support_topics where code = p_code;
  perform cs.audit('topic.delete', null, null, jsonb_build_object('code', p_code, 'before', to_jsonb(t)));
  return cs_api.admin_topics();
end;
$$;

revoke execute on function cs_api.admin_delete_topic(text) from public;
grant execute on function cs_api.admin_delete_topic(text) to authenticated;
