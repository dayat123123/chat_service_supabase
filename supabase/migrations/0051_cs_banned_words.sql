create or replace function cs.banned_word_limit()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 2000;
$$;

create or replace function cs.normalize_banned_word(p_word text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(regexp_replace(btrim(coalesce(p_word, '')), '\s+', ' ', 'g'));
$$;

create or replace function cs.check_banned_word(p_word text, p_action text, p_row bigint default null)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_where text := case when p_row is null then '' else 'Baris ' || p_row || ': ' end;
begin
  if char_length(p_word) not between 2 and 50 or p_word !~ '^[a-z0-9]+( [a-z0-9]+)*$' then
    perform private.api_error(400, 'invalid_banned_word',
      v_where || 'kata 2–50 karakter, hanya huruf, angka, dan spasi');
  end if;
  if p_action is null or p_action not in ('mask', 'block') then
    perform private.api_error(400, 'invalid_banned_action', v_where || 'aksi harus sensor (mask) atau blokir (block)');
  end if;
end;
$$;

create or replace function cs.banned_word_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'limit', cs.banned_word_limit(),
    'words', coalesce((select jsonb_agg(jsonb_build_object('word', w.word, 'action', w.action, 'created_at', w.created_at)
                                        order by w.word)
                       from public.banned_words w), '[]'));
$$;

create or replace function cs.lock_banned_words()
returns void
language sql
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtext('cs.banned_words'));
$$;

create or replace function cs_api.compliance_banned_words()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  return cs.banned_word_list();
end;
$$;

create or replace function cs_api.compliance_add_banned_word(p_word text, p_action text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_word text := cs.normalize_banned_word(p_word);
begin
  perform cs.check_banned_word(v_word, p_action);
  perform cs.lock_banned_words();
  if exists (select 1 from public.banned_words w where w.word = v_word) then
    perform private.api_error(409, 'banned_word_exists', 'Kata ini sudah ada di daftar');
  end if;
  if (select count(*) from public.banned_words) >= cs.banned_word_limit() then
    perform private.api_error(400, 'banned_word_limit', 'Daftar kata terlarang sudah mencapai batas');
  end if;
  insert into public.banned_words (word, action) values (v_word, p_action);
  perform cs.audit('banned_word.add', null, null, jsonb_build_object('word', v_word, 'action', p_action));
  return cs.banned_word_list();
end;
$$;

create or replace function cs_api.compliance_set_banned_word_action(p_word text, p_action text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_word text := cs.normalize_banned_word(p_word);
  v_old  text;
begin
  perform cs.check_banned_word(v_word, p_action);
  select w.action into v_old from public.banned_words w where w.word = v_word for update;
  if not found then
    perform private.api_error(404, 'banned_word_not_found', 'Kata tidak ada di daftar');
  end if;
  if v_old <> p_action then
    update public.banned_words set action = p_action where word = v_word;
    perform cs.audit('banned_word.update', null, null,
                     jsonb_build_object('word', v_word, 'from', v_old, 'action', p_action));
  end if;
  return cs.banned_word_list();
end;
$$;

create or replace function cs_api.compliance_delete_banned_word(p_word text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_word   text := cs.normalize_banned_word(p_word);
  v_action text;
begin
  delete from public.banned_words w where w.word = v_word returning w.action into v_action;
  if not found then
    perform private.api_error(404, 'banned_word_not_found', 'Kata tidak ada di daftar');
  end if;
  perform cs.audit('banned_word.delete', null, null, jsonb_build_object('word', v_word, 'action', v_action));
  return cs.banned_word_list();
end;
$$;

create or replace function cs_api.compliance_import_banned_words(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{compliance}');
  v_row       record;
  v_conflict  text;
  v_added     integer;
  v_updated   integer;
  v_unchanged integer;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform private.api_error(400, 'invalid_import', 'File tidak berisi kata');
  end if;
  if jsonb_array_length(p_rows) > 1000 then
    perform private.api_error(400, 'import_too_large', 'Maksimal 1.000 baris per import');
  end if;

  create temporary table pg_temp.banned_import on commit drop as
  select x.ordinality as line,
         cs.normalize_banned_word(x.value ->> 'word') as word,
         coalesce(nullif(btrim(x.value ->> 'action'), ''), 'mask') as action
  from jsonb_array_elements(p_rows) with ordinality as x(value, ordinality);

  for v_row in select * from pg_temp.banned_import order by line loop
    perform cs.check_banned_word(v_row.word, v_row.action, v_row.line);
  end loop;

  select i.word into v_conflict
  from pg_temp.banned_import i
  group by i.word
  having count(distinct i.action) > 1
  order by i.word
  limit 1;
  if v_conflict is not null then
    perform private.api_error(400, 'import_conflict',
      'Kata "' || v_conflict || '" muncul lebih dari sekali dengan aksi berbeda');
  end if;

  perform cs.lock_banned_words();
  select count(*) filter (where w.word is null),
         count(*) filter (where w.action <> i.action),
         count(*) filter (where w.action = i.action)
    into v_added, v_updated, v_unchanged
  from (select distinct word, action from pg_temp.banned_import) i
  left join public.banned_words w on w.word = i.word;

  if (select count(*) from public.banned_words) + v_added > cs.banned_word_limit() then
    perform private.api_error(400, 'banned_word_limit',
      'Import melebihi batas ' || cs.banned_word_limit() || ' kata terlarang');
  end if;

  insert into public.banned_words (word, action)
  select distinct word, action from pg_temp.banned_import
  on conflict (word) do update set action = excluded.action
  where public.banned_words.action <> excluded.action;

  drop table pg_temp.banned_import;
  perform cs.audit('banned_word.import', null, null,
                   jsonb_build_object('added', v_added, 'updated', v_updated, 'unchanged', v_unchanged,
                                      'rows', jsonb_array_length(p_rows)));
  return cs.banned_word_list()
         || jsonb_build_object('added', v_added, 'updated', v_updated, 'unchanged', v_unchanged);
end;
$$;

revoke execute on function cs.banned_word_limit() from public;
revoke execute on function cs.normalize_banned_word(text) from public;
revoke execute on function cs.check_banned_word(text, text, bigint) from public;
revoke execute on function cs.banned_word_list() from public;
revoke execute on function cs.lock_banned_words() from public;
revoke execute on function cs_api.compliance_banned_words() from public;
revoke execute on function cs_api.compliance_add_banned_word(text, text) from public;
revoke execute on function cs_api.compliance_set_banned_word_action(text, text) from public;
revoke execute on function cs_api.compliance_delete_banned_word(text) from public;
revoke execute on function cs_api.compliance_import_banned_words(jsonb) from public;

grant execute on function cs_api.compliance_banned_words() to authenticated;
grant execute on function cs_api.compliance_add_banned_word(text, text) to authenticated;
grant execute on function cs_api.compliance_set_banned_word_action(text, text) to authenticated;
grant execute on function cs_api.compliance_delete_banned_word(text) to authenticated;
grant execute on function cs_api.compliance_import_banned_words(jsonb) to authenticated;
