create or replace function private.rebuild_policy_patterns(p_part text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('private.policy_patterns'));
  insert into private.policy_patterns (id) values (true) on conflict (id) do nothing;

  if p_part in ('words', 'promo') then
    delete from private.policy_forms f where f.source = case p_part when 'words' then 'word' else 'promo' end;
    insert into private.policy_forms (source, form, word, action)
    select distinct case p_part when 'words' then 'word' else 'promo' end, v.form, s.word, s.action
    from (
      select w.word, w.action from public.banned_words w where p_part = 'words'
      union all
      select p.phrase, 'block' from cs.promo_phrases p where p_part = 'promo'
    ) s
    cross join lateral (select private.policy_collapse(private.normalize_for_policy(s.word)) as n) n
    cross join lateral (values (n.n), (replace(n.n, ' ', ''))) v(form)
    where v.form ~ '^[a-z0-9]+( [a-z0-9]+)*$' and char_length(v.form) >= 2;
  end if;

  if p_part = 'words' then
    update private.policy_patterns set
      words_max = coalesce((select max(cardinality(string_to_array(w.word, ' '))) from public.banned_words w), 0),
      updated_at = now()
    where id;
  elsif p_part = 'promo' then
    update private.policy_patterns set
      promo_max = coalesce((select max(cardinality(string_to_array(p.phrase, ' '))) from cs.promo_phrases p), 0),
      updated_at = now()
    where id;
  elsif p_part = 'allow' then
    update private.policy_patterns set
      allow = private.policy_alternation(array(select a.term from cs.policy_allowlist a)),
      updated_at = now()
    where id;
  elsif p_part = 'domains' then
    update private.policy_patterns set
      domains = (
        select '(?<![a-z0-9.-])((?:[a-z0-9-]+\.)*(?:'
               || string_agg(replace(d.domain, '.', '\.'), '|' order by char_length(d.domain) desc, d.domain)
               || '))(?![a-z0-9-])'
        from (select b.domain from cs.blocked_domains b where b.match = 'domain'
              union select a.domain from cs.allowed_domains a) d),
      updated_at = now()
    where id;
  end if;
end;
$$;

create or replace function cs_api.compliance_test_content(p_text text, p_surface text default 'post')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_result jsonb;
  v_body   text;
  v_banned text := 'allow';
begin
  if p_surface is null or p_surface not in ('post', 'comment', 'stock', 'group', 'direct') then
    perform private.api_error(400, 'invalid_surface', 'Tempat: post, comment, stock, group, atau direct');
  end if;
  if char_length(coalesce(p_text, '')) not between 1 and 4000 then
    perform private.api_error(400, 'invalid_text', 'Teks 1–4000 karakter');
  end if;
  begin
    v_body := private.apply_content_policy(p_text);
    if v_body is distinct from p_text then
      v_banned := 'censor';
    end if;
  exception when sqlstate 'PT422' then
    v_banned := 'block';
    v_body := p_text;
  end;
  v_result := private.evaluate_content(v_body, p_surface);
  return v_result || jsonb_build_object(
    'banned_words', v_banned,
    'normalized', private.normalize_for_policy(p_text),
    'banned_word_total', (select count(*) from public.banned_words),
    'promo_phrase_total', (select count(*) from cs.promo_phrases));
end;
$$;
