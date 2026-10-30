create or replace function cs_api.session_detail(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  perform cs.require_agent();
  select * into s from cs.support_sessions where id = p_session_id;
  if not found or not cs.can_read_session(s.room_id, s.flags) then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  return cs.agent_view(s) || jsonb_build_object(
    'tags', to_jsonb(s.tags),
    'rating_comment', s.rating_comment,
    'events', coalesce((select jsonb_agg(jsonb_build_object('type', e.type, 'actor_type', e.actor_type,
                                                            'data', e.data, 'created_at', e.created_at)
                                         order by e.created_at, e.id)
                        from cs.session_events e where e.session_id = s.id), '[]'));
end;
$$;
