create or replace function cs_api.ticket_customer_login(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  perform cs.require_agent();
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if t.context ? 'guest' then
    return jsonb_build_object('login_id', null, 'source', 'guest');
  end if;
  return (
    select jsonb_build_object('login_id', coalesce(up.olt_username, p.username::text),
                              'source', case when up.olt_username is null then 'profile' else 'olt' end)
    from public.profiles p
    left join private.user_private up on up.user_id = p.id
    where p.id = t.customer_id);
end;
$$;
