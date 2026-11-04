create index quick_replies_personal_owner_idx on cs.quick_replies (owner_id, shortcut) where scope = 'personal';

create or replace function cs.personal_quick_reply_view(q cs.quick_replies)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('id', q.id, 'scope', q.scope, 'shortcut', q.shortcut, 'title', q.title, 'body', q.body,
                            'updated_at', q.updated_at);
$$;

create or replace function cs.personal_quick_reply_shortcut(p_owner uuid, p_title text, p_except uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_base text := left(btrim(regexp_replace(lower(coalesce(p_title, '')), '[^a-z0-9]+', '-', 'g'), '-'), 28);
  v_try  text;
  v_n    integer := 1;
begin
  v_base := btrim(v_base, '-');
  if char_length(v_base) < 2 then
    v_base := 'balasan';
  end if;
  v_try := v_base;
  while exists (select 1 from cs.quick_replies q
                where q.scope = 'personal' and q.owner_id = p_owner and q.shortcut = v_try
                  and q.id is distinct from p_except) loop
    v_n := v_n + 1;
    v_try := v_base || '-' || v_n;
  end loop;
  return v_try;
end;
$$;

create or replace function cs_api.quick_replies(p_language text default 'id')
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent();
begin
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', q.id, 'scope', q.scope, 'shortcut', q.shortcut, 'title', q.title, 'body', q.body)
           order by q.scope = 'personal' desc, q.shortcut, q.scope), '[]')
    from cs.quick_replies q
    where q.active
      and ((q.scope = 'personal' and q.owner_id = v_me)
           or (q.scope <> 'personal' and q.language = coalesce(p_language, 'id'))));
end;
$$;

create or replace function cs_api.my_quick_replies()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent}');
begin
  return coalesce((
    select jsonb_agg(cs.personal_quick_reply_view(q) order by q.shortcut)
    from cs.quick_replies q
    where q.scope = 'personal' and q.owner_id = v_me), '[]');
end;
$$;

create or replace function cs_api.save_my_quick_reply(
  p_id       uuid,
  p_title    text,
  p_body     text,
  p_shortcut text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_agent}');
  v_title    text := btrim(coalesce(p_title, ''));
  v_body     text := btrim(coalesce(p_body, ''));
  v_shortcut text := nullif(btrim(coalesce(p_shortcut, '')), '');
  q          cs.quick_replies;
begin
  if char_length(v_title) not between 1 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul 1–80 karakter');
  end if;
  if char_length(v_body) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Isi balasan 1–2000 karakter');
  end if;
  if v_shortcut is not null and v_shortcut !~ '^[a-z0-9_-]{2,32}$' then
    perform private.api_error(400, 'invalid_shortcut', 'Pintasan 2–32 huruf kecil, angka, - atau _');
  end if;
  if cs.requests_secret(v_title) or cs.requests_secret(v_body) then
    perform private.api_error(400, 'secret_request_blocked', 'Balasan cepat tidak boleh meminta OTP, PIN, atau password');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('cs.quick_replies.personal:' || v_me::text, 0));
  if p_id is null and (select count(*) from cs.quick_replies x
                       where x.scope = 'personal' and x.owner_id = v_me) >= 50 then
    perform private.api_error(409, 'quick_reply_limit', 'Maksimal 50 balasan cepat pribadi');
  end if;
  if p_id is not null and not exists (select 1 from cs.quick_replies x
                                      where x.id = p_id and x.scope = 'personal' and x.owner_id = v_me) then
    perform private.api_error(404, 'quick_reply_not_found', 'Balasan cepat tidak ditemukan');
  end if;
  if v_shortcut is null then
    v_shortcut := cs.personal_quick_reply_shortcut(v_me, v_title, p_id);
  elsif exists (select 1 from cs.quick_replies x
                where x.scope = 'personal' and x.owner_id = v_me and x.shortcut = v_shortcut
                  and x.id is distinct from p_id) then
    perform private.api_error(409, 'duplicate_shortcut', 'Pintasan sudah dipakai balasan lain');
  end if;
  v_body := (cs.mask_sensitive(v_body)).masked;
  if p_id is null then
    insert into cs.quick_replies (scope, owner_id, shortcut, title, body, language, active, created_by)
    values ('personal', v_me, v_shortcut, v_title, v_body, 'id', true, v_me)
    returning * into q;
  else
    update cs.quick_replies
       set shortcut = v_shortcut, title = v_title, body = v_body, active = true, updated_at = now()
     where id = p_id and scope = 'personal' and owner_id = v_me
    returning * into q;
  end if;
  return cs.personal_quick_reply_view(q);
end;
$$;

create or replace function cs_api.delete_my_quick_reply(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_agent}');
begin
  delete from cs.quick_replies
   where id = p_id and scope = 'personal' and owner_id = v_me;
  if not found then
    perform private.api_error(404, 'quick_reply_not_found', 'Balasan cepat tidak ditemukan');
  end if;
  return jsonb_build_object('deleted', true);
end;
$$;

revoke execute on function cs.personal_quick_reply_view(cs.quick_replies) from public;
revoke execute on function cs.personal_quick_reply_shortcut(uuid, text, uuid) from public;
revoke execute on function cs_api.my_quick_replies() from public;
revoke execute on function cs_api.save_my_quick_reply(uuid, text, text, text) from public;
revoke execute on function cs_api.delete_my_quick_reply(uuid) from public;

grant execute on function cs_api.my_quick_replies() to authenticated;
grant execute on function cs_api.save_my_quick_reply(uuid, text, text, text) to authenticated;
grant execute on function cs_api.delete_my_quick_reply(uuid) to authenticated;
