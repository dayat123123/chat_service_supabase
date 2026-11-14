drop function cs_api.guest_end(text);

create function cs_api.guest_end(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  g cs.guest_sessions := cs.guest_session(p_token);
  t cs.tickets;
begin
  if g.ticket_id is not null then
    select * into t from cs.tickets x where x.id = g.ticket_id;
    if t.id is not null and t.status <> 'closed' then
      perform cs.guest_act_as(g.profile_id);
      t := cs.finalize_ticket(t.id, 'customer');
    end if;
  end if;
  update cs.guest_sessions set ended_at = now() where id = g.id;
  return jsonb_build_object('ticket', case when t.id is not null then cs.ticket_customer_view(t) end);
end;
$$;

revoke execute on function cs_api.guest_end(text) from public;
grant execute on function cs_api.guest_end(text) to anon, authenticated;
