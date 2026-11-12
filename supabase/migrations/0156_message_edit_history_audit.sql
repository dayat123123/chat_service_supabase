create or replace function cs_api.community_edit_history(p_target_type text, p_target_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  if p_target_type not in ('post', 'comment', 'message') then
    perform private.api_error(400, 'invalid_target', 'Jenis konten harus post, comment, atau message');
  end if;
  if p_target_type = 'message' then
    if not exists (select 1 from public.messages m join public.chat_rooms r on r.id = m.room_id
                   where m.id = p_target_id and r.type <> 'support') then
      perform private.api_error(404, 'content_not_found', 'Konten tidak ditemukan');
    end if;
    if cs.community_private_message(p_target_id) then
      if not cs.community_message_reviewable(p_target_id) then
        perform private.api_error(403, 'private_message_forbidden',
          'Pesan pribadi hanya bisa dibuka bila dilaporkan atau ditandai sistem');
      end if;
      perform cs.audit('community.private_message_edits_view', null, null,
                       jsonb_build_object('message', p_target_id));
    end if;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('body', e.body, 'edited_at', e.edited_at, 'edited_by', e.edited_by)
                     order by e.edited_at)
    from private.content_edits e
    where e.target_type = p_target_type and e.target_id = p_target_id), '[]');
end;
$$;
