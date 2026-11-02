create or replace function private.apply_content_policy(p_text text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r        record;
  v_result text := p_text;
  v_any    text;
begin
  if p_text is null or p_text = '' then
    return p_text;
  end if;
  select string_agg(w.word, '|' order by w.word) into v_any from public.banned_words w;
  if v_any is null or p_text !~* ('\m(' || v_any || ')\M') then
    return p_text;
  end if;
  for r in select w.word, w.action from public.banned_words w
           where p_text ~* ('\m' || w.word || '\M')
           order by w.word loop
    if r.action = 'block' then
      perform private.api_error(422, 'content_blocked',
        'Konten mengandung kata atau frasa yang tidak diizinkan.');
    end if;
    v_result := regexp_replace(v_result, '\m' || r.word || '\M', repeat('*', char_length(r.word)), 'gi');
  end loop;
  return v_result;
end;
$$;
