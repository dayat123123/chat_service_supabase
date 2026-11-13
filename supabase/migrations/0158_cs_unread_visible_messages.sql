create or replace function cs_api.support_home()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_customer();
  v_room uuid;
  v_lang text;
  t      cs.tickets;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = v_me;
  select * into t from cs.tickets x
  where x.customer_id = v_me
  order by (x.status in ('open', 'claimed', 'waiting_customer')) desc, x.created_at desc
  limit 1;
  v_lang := coalesce(t.language, 'id');
  return jsonb_build_object(
    'room_id', v_room,
    'support_name', cs.support_name(),
    'ticket', case when t.id is not null then cs.ticket_customer_view(t) end,
    'active', t.id is not null and t.status in ('open', 'claimed', 'waiting_customer'),
    'unread_count', coalesce((
      select count(*)::integer from (
        select 1 from public.messages m
        join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = v_me
        where m.room_id = v_room and m.sender_id is distinct from v_me and m.created_at > cm.last_read_at
          and m.deleted_at is null
          and m.moderation_status = 'visible'
          and (m.sender_id is null or m.sender_id not in (select private.blocked_user_ids()))
          and (cm.cleared_at is null or m.created_at > cm.cleared_at)
        limit 99) x), 0),
    'service_open', cs.is_open(now()),
    'next_open_at', case when not cs.is_open(now()) then cs.next_open_at(now()) end,
    'topic_picker', coalesce(cs.setting('topics.picker'), '{}'::jsonb),
    'incidents', cs.active_incidents(v_lang),
    'survey', jsonb_build_object('id', cs.survey_view('id'), 'en', cs.survey_view('en')));
end;
$$;
