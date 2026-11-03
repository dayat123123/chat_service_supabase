insert into private.settings (key, value, description) values
  ('safety.new_account_days', '3',
   'Akun baru (hari sejak daftar) masih dibatasi: tanpa gambar, tanpa tautan, DM ke non-mutual lewat permintaan pesan')
on conflict (key) do nothing;

create table private.account_signups (
  user_id      uuid primary key references public.profiles (id) on delete cascade,
  signed_up_at timestamptz not null default now()
);
alter table private.account_signups enable row level security;

insert into private.account_signups (user_id, signed_up_at)
select p.id, p.created_at from public.profiles p where p.trust_level = 0 and p.deleted_at is null
on conflict (user_id) do nothing;

create or replace function private.track_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.trust_level = 0 then
    insert into private.account_signups (user_id, signed_up_at) values (new.id, new.created_at)
    on conflict (user_id) do update set signed_up_at = excluded.signed_up_at;
  end if;
  return null;
end;
$$;

create trigger profiles_26_signup
  after insert on public.profiles
  for each row execute function private.track_signup();
create trigger profiles_27_signup_reset
  after update of created_at on public.profiles
  for each row when (new.created_at is distinct from old.created_at)
  execute function private.track_signup();

create or replace function private.is_new_account(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.trust_level = 0
        or (p.trust_level = 1 and exists (
              select 1 from private.account_signups s
              where s.user_id = p.id
                and s.signed_up_at > now() - private.setting_num('safety.new_account_days', 3) * interval '1 day'))
    from public.profiles p
    where p.id = p_user), false);
$$;

create or replace function private.safety_exempt(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.official_accounts o where o.profile_id = p_user)
      or exists (select 1 from cs.agents a where a.user_id = p_user);
$$;

create or replace function private.has_image_attachment(p_attachments jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1 from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments else '[]' end) a
    where jsonb_typeof(a -> 'path') = 'string'
      and coalesce(a ->> 'bucket', 'attachments') = 'attachments');
$$;

create or replace function private.policy_homoglyphs(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(p_text, 'аеёорсухкмтвнгпіїјѕԁԛԝьαβγεηικνορτυχωςıłøđ',
                           'aeeopcyxkmtbhrniijsdqwbabyeniknoptuxwsilod');
$$;

create or replace function private.policy_char_map(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(private.policy_homoglyphs(p_text),
    'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ'
      || 'àáâãäåāăąçćčďèéêëēėęěìíîïīįñńňòóôõöōőùúûüūůűųýÿźżžśšşţťŕř' || '013457$@',
    'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz'
      || 'aaaaaaaaa' || 'ccc' || 'd' || 'eeeeeeee' || 'iiiiii' || 'nnn' || 'ooooooo' || 'uuuuuuuu'
      || 'yy' || 'zzz' || 'sss' || 'tt' || 'rr' || 'oieastsa');
$$;

create or replace function private.policy_join_singles(p_text text, p_separator text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text    text := p_text;
  v_pattern text := '(?<![a-z0-9])[a-z0-9](?:' || p_separator || '[a-z0-9](?=' || p_separator
                    || '[a-z0-9]|[^a-z0-9]*(?:\s|$)))+';
  v_pos     integer;
  v_run     text;
begin
  if v_text is null or v_text !~ v_pattern then
    return v_text;
  end if;
  for i in 1 .. 500 loop
    v_pos := regexp_instr(v_text, v_pattern);
    exit when v_pos = 0;
    v_run := regexp_substr(v_text, v_pattern);
    v_text := overlay(v_text placing regexp_replace(v_run, '[^a-z0-9]', '', 'g') from v_pos for char_length(v_run));
  end loop;
  return v_text;
end;
$$;

create or replace function private.normalize_for_policy(p_text text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text;
begin
  if p_text is null or p_text = '' then
    return p_text;
  end if;
  v := lower(normalize(p_text, NFKD));
  v := regexp_replace(v, '[̀-ͯ­​-‏⁠-⁤﻿]', '', 'g');
  v := private.policy_homoglyphs(v);
  v := regexp_replace(v, '(?<![a-z0-9_$@])[$@][a-z][a-z0-9_]{1,29}', ' ', 'g');
  v := private.policy_join_singles(v, '[^a-z0-9\s]{1,2}');
  v := private.policy_join_singles(v, '\s[^a-z0-9\s]\s');
  v := private.policy_join_singles(v, '\s{1,2}');
  v := regexp_replace(v, '(?<![a-z0-9])[0-9]+(?![a-z0-9])', ' ', 'g');
  v := translate(v, '013457$@', 'oieastsa');
  v := regexp_replace(v, '([a-z])\1{2,}', '\1', 'g');
  return btrim(regexp_replace(v, '\s+', ' ', 'g'));
end;
$$;

create or replace function private.policy_collapse(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(p_text, '([a-z])\1+', '\1', 'g');
$$;

create or replace function private.policy_fuzzy_pattern(p_form text)
returns text
language sql
immutable
set search_path = ''
as $$
  select '(?<![a-z0-9])'
      || string_agg(case when c = ' ' then '[^a-z0-9]+' else c || '+' end, '[^a-z0-9]{0,3}' order by o)
      || '(?![a-z0-9])'
  from regexp_split_to_table(private.policy_collapse(p_form), '') with ordinality as t(c, o);
$$;

create table cs.policy_allowlist (
  term       text primary key,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint policy_allowlist_format check (
    term = lower(term) and term ~ '^[a-z0-9]+( [a-z0-9]+)*$' and char_length(term) between 2 and 50)
);
alter table cs.policy_allowlist enable row level security;

create table cs.promo_phrases (
  phrase     text primary key,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint promo_phrases_format check (
    phrase = lower(phrase) and phrase ~ '^[a-z0-9]+( [a-z0-9]+)*$' and char_length(phrase) between 3 and 50)
);
alter table cs.promo_phrases enable row level security;

create table cs.content_rules (
  category   text primary key,
  action     text not null,
  scope      text not null default 'public',
  updated_at timestamptz not null default now(),
  updated_by uuid,
  constraint content_rules_category check (
    category in ('gambling', 'porn', 'phishing', 'blocked', 'shortener', 'messenger', 'phone', 'promotion', 'other_link')),
  constraint content_rules_action check (action in ('allow', 'censor', 'hold', 'block')),
  constraint content_rules_scope check (scope in ('public', 'all'))
);
alter table cs.content_rules enable row level security;

insert into cs.content_rules (category, action, scope) values
  ('gambling', 'block', 'all'),
  ('porn', 'block', 'all'),
  ('phishing', 'block', 'all'),
  ('blocked', 'block', 'all'),
  ('shortener', 'hold', 'public'),
  ('messenger', 'hold', 'public'),
  ('phone', 'hold', 'public'),
  ('promotion', 'block', 'all'),
  ('other_link', 'allow', 'public')
on conflict (category) do nothing;

create table cs.blocked_domains (
  domain     text primary key,
  match      text not null default 'domain',
  category   text not null references cs.content_rules (category),
  action     text,
  note       text,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint blocked_domains_match check (match in ('domain', 'keyword')),
  constraint blocked_domains_category check (
    category in ('gambling', 'porn', 'phishing', 'blocked', 'shortener', 'messenger')),
  constraint blocked_domains_action check (action in ('allow', 'censor', 'hold', 'block')),
  constraint blocked_domains_note check (char_length(note) <= 200),
  constraint blocked_domains_format check (
    (match = 'domain' and char_length(domain) <= 253
     and domain ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$')
    or (match = 'keyword' and domain ~ '^[a-z0-9][a-z0-9-]{2,29}$'))
);
alter table cs.blocked_domains enable row level security;

create table cs.allowed_domains (
  domain     text primary key,
  note       text,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint allowed_domains_note check (char_length(note) <= 200),
  constraint allowed_domains_format check (
    char_length(domain) <= 253 and domain ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$')
);
alter table cs.allowed_domains enable row level security;

create table private.policy_patterns (
  id                boolean primary key default true check (id),
  words_max         integer not null default 0,
  promo_max         integer not null default 0,
  allow             text,
  domains           text,
  updated_at        timestamptz not null default now()
);
alter table private.policy_patterns enable row level security;

create table private.policy_forms (
  source text not null check (source in ('word', 'promo')),
  form   text not null,
  word   text not null,
  action text not null,
  primary key (source, form, word)
);
alter table private.policy_forms enable row level security;

create table private.content_flags (
  target_type text not null check (target_type in ('post', 'comment', 'message')),
  target_id   uuid not null,
  categories  text[] not null default '{}',
  source      text not null default 'policy' check (source in ('policy', 'manipulation')),
  alert_id    uuid,
  created_at  timestamptz not null default now(),
  primary key (target_type, target_id)
);
create index content_flags_alert_idx on private.content_flags (alert_id) where alert_id is not null;
alter table private.content_flags enable row level security;

create index if not exists posts_held_idx on public.posts (created_at) where moderation_status = 'held';
create index if not exists comments_held_idx on public.comments (created_at) where moderation_status = 'held';
create index if not exists messages_held_idx on public.messages (created_at) where moderation_status = 'held';

create or replace function private.policy_tokens(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_remove(regexp_split_to_array(lower(coalesce(p_text, '')), '[^a-z0-9]+'), '');
$$;

create or replace function private.policy_ngrams(p_tokens text[], p_max integer)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case when coalesce(p_max, 1) <= 1 then coalesce(p_tokens, '{}')
    else coalesce(p_tokens, '{}') || array(
      select array_to_string(p_tokens[i:i + n - 1], ' ')
      from generate_series(2, p_max) n, generate_series(1, cardinality(p_tokens) - n + 1) i) end;
$$;

create or replace function private.policy_alternation(p_items text[])
returns text
language sql
immutable
set search_path = ''
as $$
  select case when cardinality(p_items) > 0 then
    '\m(' || (select string_agg(i, '|' order by char_length(i) desc, i) from unnest(p_items) i) || ')\M' end;
$$;

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
      updated_at = now();
  elsif p_part = 'promo' then
    update private.policy_patterns set
      promo_max = coalesce((select max(cardinality(string_to_array(p.phrase, ' '))) from cs.promo_phrases p), 0),
      updated_at = now();
  elsif p_part = 'allow' then
    update private.policy_patterns set
      allow = private.policy_alternation(array(select a.term from cs.policy_allowlist a)),
      updated_at = now();
  elsif p_part = 'domains' then
    update private.policy_patterns set
      domains = (
        select '(?<![a-z0-9.-])((?:[a-z0-9-]+\.)*(?:'
               || string_agg(replace(d.domain, '.', '\.'), '|' order by char_length(d.domain) desc, d.domain)
               || '))(?![a-z0-9-])'
        from (select b.domain from cs.blocked_domains b where b.match = 'domain'
              union select a.domain from cs.allowed_domains a) d),
      updated_at = now();
  end if;
end;
$$;

create or replace function private.policy_patterns_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.rebuild_policy_patterns(tg_argv[0]);
  return null;
end;
$$;

create trigger banned_words_31_patterns
  after insert or update or delete or truncate on public.banned_words
  for each statement execute function private.policy_patterns_changed('words');
create trigger policy_allowlist_31_patterns
  after insert or update or delete or truncate on cs.policy_allowlist
  for each statement execute function private.policy_patterns_changed('allow');
create trigger promo_phrases_31_patterns
  after insert or update or delete or truncate on cs.promo_phrases
  for each statement execute function private.policy_patterns_changed('promo');
create trigger blocked_domains_31_patterns
  after insert or update or delete or truncate on cs.blocked_domains
  for each statement execute function private.policy_patterns_changed('domains');
create trigger allowed_domains_31_patterns
  after insert or update or delete or truncate on cs.allowed_domains
  for each statement execute function private.policy_patterns_changed('domains');

insert into cs.blocked_domains (domain, match, category) values
  ('bit.ly', 'domain', 'shortener'), ('bitly.com', 'domain', 'shortener'), ('s.id', 'domain', 'shortener'),
  ('tinyurl.com', 'domain', 'shortener'), ('cutt.ly', 'domain', 'shortener'), ('shorturl.at', 'domain', 'shortener'),
  ('t.co', 'domain', 'shortener'), ('rb.gy', 'domain', 'shortener'), ('is.gd', 'domain', 'shortener'),
  ('v.gd', 'domain', 'shortener'), ('ow.ly', 'domain', 'shortener'), ('goo.gl', 'domain', 'shortener'),
  ('tiny.cc', 'domain', 'shortener'), ('rebrand.ly', 'domain', 'shortener'), ('buff.ly', 'domain', 'shortener'),
  ('t.ly', 'domain', 'shortener'),
  ('wa.me', 'domain', 'messenger'), ('wa.link', 'domain', 'messenger'), ('chat.whatsapp.com', 'domain', 'messenger'),
  ('api.whatsapp.com', 'domain', 'messenger'), ('t.me', 'domain', 'messenger'), ('telegram.me', 'domain', 'messenger'),
  ('telegram.dog', 'domain', 'messenger'), ('discord.gg', 'domain', 'messenger'), ('discord.com', 'domain', 'messenger'),
  ('line.me', 'domain', 'messenger'), ('lin.ee', 'domain', 'messenger'),
  ('sbobet.com', 'domain', 'gambling'), ('bet365.com', 'domain', 'gambling'), ('1xbet.com', 'domain', 'gambling'),
  ('stake.com', 'domain', 'gambling'), ('w88.com', 'domain', 'gambling'), ('fun88.com', 'domain', 'gambling'),
  ('dafabet.com', 'domain', 'gambling'), ('188bet.com', 'domain', 'gambling'),
  ('togel', 'keyword', 'gambling'), ('gacor', 'keyword', 'gambling'), ('judol', 'keyword', 'gambling'),
  ('maxwin', 'keyword', 'gambling'), ('slot88', 'keyword', 'gambling'), ('casino', 'keyword', 'gambling'),
  ('pornhub.com', 'domain', 'porn'), ('xvideos.com', 'domain', 'porn'), ('xnxx.com', 'domain', 'porn'),
  ('xhamster.com', 'domain', 'porn'), ('redtube.com', 'domain', 'porn'), ('youporn.com', 'domain', 'porn'),
  ('bokep', 'keyword', 'porn'),
  ('grabify.link', 'domain', 'phishing'), ('iplogger.org', 'domain', 'phishing'), ('iplogger.com', 'domain', 'phishing'),
  ('2no.co', 'domain', 'phishing')
on conflict (domain) do nothing;

insert into cs.allowed_domains (domain, note) values
  ('idx.co.id', 'Bursa Efek Indonesia'),
  ('ojk.go.id', 'Otoritas Jasa Keuangan'),
  ('ksei.co.id', 'Kustodian Sentral Efek Indonesia'),
  ('kpei.co.id', 'Kliring Penjaminan Efek Indonesia'),
  ('bi.go.id', 'Bank Indonesia')
on conflict (domain) do nothing;

insert into cs.promo_phrases (phrase) values
  ('grup vip'), ('grup premium'), ('sinyal berbayar'), ('sinyal vip'), ('join premium')
on conflict (phrase) do nothing;

select private.rebuild_policy_patterns('words');
select private.rebuild_policy_patterns('allow');

create or replace function private.policy_fuzzy_mask(p_text text, p_form text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_map     text := private.policy_char_map(lower(p_text));
  v_pattern text := private.policy_fuzzy_pattern(p_form);
  v_result  text := p_text;
  v_pos     integer := 1;
  v_len     integer := 0;
begin
  if char_length(v_map) <> char_length(p_text) then
    return null;
  end if;
  for i in 1 .. 200 loop
    v_pos := regexp_instr(v_map, v_pattern, v_pos + v_len);
    exit when v_pos = 0;
    v_len := char_length(regexp_substr(v_map, v_pattern, v_pos));
    v_result := overlay(v_result placing (
      select string_agg(case when substr(v_map, v_pos + k - 1, 1) ~ '[a-z0-9]' then '*'
                             else substr(v_result, v_pos + k - 1, 1) end, '' order by k)
      from generate_series(1, v_len) k) from v_pos for v_len);
  end loop;
  return v_result;
end;
$$;

create or replace function private.apply_content_policy(p_text text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pat    private.policy_patterns;
  v_scan   text;
  v_grams  text[];
  v_norm   text[];
  v_result text := p_text;
  v_raw    text[] := '{}';
  v_forms  text[] := '{}';
  v_block  boolean;
  v_masked text;
  r        record;
begin
  if p_text is null or p_text = '' then
    return p_text;
  end if;
  select * into v_pat from private.policy_patterns where id;
  if coalesce(v_pat.words_max, 0) = 0 then
    return p_text;
  end if;
  v_scan := case when v_pat.allow is null then p_text else regexp_replace(p_text, v_pat.allow, ' ', 'gi') end;
  v_grams := private.policy_ngrams(private.policy_tokens(v_scan), v_pat.words_max);
  v_norm := private.policy_ngrams(
    private.policy_tokens(private.policy_collapse(private.normalize_for_policy(v_scan))), v_pat.words_max);
  select coalesce(array_agg(distinct w.word), '{}'), coalesce(bool_or(w.action = 'block'), false)
    into v_raw, v_block
  from unnest(v_grams) g join public.banned_words w on w.word = g;
  select coalesce(array_agg(distinct f.form), '{}'), v_block or coalesce(bool_or(f.action = 'block'), false)
    into v_forms, v_block
  from unnest(v_norm) g join private.policy_forms f on f.source = 'word' and f.form = g;
  if v_block then
    perform private.api_error(422, 'content_blocked', 'Konten mengandung kata atau frasa yang tidak diizinkan.');
  end if;

  foreach v_masked in array v_raw loop
    v_result := regexp_replace(v_result, '\m' || v_masked || '\M', repeat('*', char_length(v_masked)), 'gi');
  end loop;

  if cardinality(v_forms) > 0 then
    for r in
      select f.form, bool_or(f.word = any (v_raw)) as raw_hit
      from private.policy_forms f
      where f.source = 'word' and f.form = any (v_forms)
      group by f.form
    loop
      v_masked := private.policy_fuzzy_mask(v_result, r.form);
      if v_masked is null or (v_masked = v_result and not r.raw_hit) then
        perform private.api_error(422, 'content_blocked', 'Konten mengandung kata atau frasa yang tidak diizinkan.');
      end if;
      v_result := v_masked;
    end loop;
  end if;
  return v_result;
end;
$$;

create or replace function private.extract_hosts(p_text text)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_text  text;
  v_known text;
  v_hosts text[];
begin
  if p_text is null or p_text !~* '[.。｡．]|dot' then
    return '{}';
  end if;
  v_text := lower(normalize(p_text, NFKC));
  v_text := regexp_replace(v_text, '[­​-‏⁠-⁤﻿]', '', 'g');
  v_text := translate(private.policy_homoglyphs(v_text), '。｡', '..');
  v_text := regexp_replace(v_text, '\s*[\[\(\{<]\s*(?:dot|titik|\.)\s*[\]\)\}>]\s*', '.', 'g');
  v_text := regexp_replace(v_text, '(?<=[a-z0-9])\s+dot\s+(?=[a-z0-9])', '.', 'g');
  select p.domains into v_known from private.policy_patterns p where p.id;

  select array_agg(distinct h) into v_hosts
  from (
    select regexp_replace(rtrim(x.h, '.-'), '^www\.', '') as h
    from (
      select m[1] as h
      from regexp_matches(v_text, '(?:[a-z][a-z0-9+.-]{1,15}://(?:[^\s/@]*@)?|(?<![a-z0-9.-])www\.)([a-z0-9][a-z0-9.-]*)', 'g') m
      union all
      select m[1]
      from regexp_matches(v_text,
        '(?<![a-z0-9@._-])((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:com|net|org|info|biz|xyz|top|vip|site|online'
        || '|club|live|bet|win|io|app|link|ly|gg|cc|ws|pw|tk|ml|ga|cf|gq|icu|cyou|shop|store|fun|pro|ru|cn|asia'
        || '|casino|poker|games|bio|lol|click|today|world|space|website|host|cloud|stream|xxx|porn|sex|adult|cam'
        || '|mobi|monster|best|money|cash|finance|trade|market|exchange|co'
        || '|(?:co|ac|or|my|web|biz|go|sch|net|ponpes|desa|mil)\.id))(?![a-z0-9-])', 'g') m
      union all
      select m[1] from regexp_matches(v_text, coalesce(v_known, '$^'), 'g') m
    ) x
  ) y
  where y.h ~ '^[a-z0-9-]+(\.[a-z0-9-]+)+$';
  return coalesce(v_hosts, '{}');
end;
$$;

create or replace function private.host_rule(p_host text)
returns table (category text, action text, allowed boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with suffixes as (
    select array_to_string((string_to_array(p_host, '.'))[i:], '.') as suffix
    from generate_series(1, cardinality(string_to_array(p_host, '.')) - 1) i
  ), allowed as (
    select exists (select 1 from cs.allowed_domains a where a.domain in (select suffix from suffixes)) as ok
  ), hit as (
    select b.category, b.action
    from cs.blocked_domains b
    where (b.match = 'domain' and b.domain in (select suffix from suffixes))
       or (b.match = 'keyword' and position(b.domain in p_host) > 0)
    order by (b.match = 'domain') desc, char_length(b.domain) desc
    limit 1
  )
  select coalesce(h.category, 'other_link'), coalesce(h.action, r.action), al.ok
  from allowed al
  left join hit h on true
  join cs.content_rules r on r.category = coalesce(h.category, 'other_link');
$$;

create or replace function private.policy_phone_pattern()
returns text
language sql
immutable
set search_path = ''
as $$
  select '(?<![0-9])(?:\+\s?62|62|0)[\s.()-]{0,2}8[\s.()-]{0,2}(?:[0-9][\s.()-]{0,2}){7,10}[0-9](?![0-9])';
$$;

create or replace function private.evaluate_content(p_text text, p_surface text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_private  boolean := p_surface in ('direct', 'group');
  v_pat      private.policy_patterns;
  v_rules    jsonb;
  v_hits     text[] := '{}';
  v_level    integer := 0;
  v_body     text := p_text;
  v_links    boolean := false;
  v_scan     text;
  v_host     text;
  v_rule     record;
  v_action   text;
  v_censored text;
  v_phrase   text;
  v_phrases  text[];
  v_raw      boolean;
begin
  if p_text is null or btrim(p_text) = '' then
    return jsonb_build_object('action', 'allow', 'categories', '[]'::jsonb, 'links', false, 'body', p_text);
  end if;
  select jsonb_object_agg(r.category, jsonb_build_object('action', r.action, 'scope', r.scope))
    into v_rules from cs.content_rules r;
  select * into v_pat from private.policy_patterns where id;

  foreach v_host in array private.extract_hosts(p_text) loop
    select * into v_rule from private.host_rule(v_host);
    continue when v_rule.allowed;
    v_links := true;
    v_action := v_rule.action;
    if v_private and v_rules -> v_rule.category ->> 'scope' = 'public' then
      v_action := 'allow';
    end if;
    if v_action = 'censor' then
      v_censored := regexp_replace(v_body,
        '(?:[a-z][a-z0-9+.-]{1,15}://)?(?:[a-z0-9-]+\.)*' || replace(v_host, '.', '\.') || '(?:[/?#:][^\s]*)?',
        '[tautan disensor]', 'gi');
      if v_censored = v_body then
        v_action := 'hold';
      end if;
      v_body := v_censored;
    end if;
    if v_action <> 'allow' then
      v_hits := v_hits || v_rule.category;
      v_level := greatest(v_level, case v_action when 'censor' then 1 when 'hold' then 2 when 'block' then 3 else 0 end);
    end if;
  end loop;

  if p_text ~ private.policy_phone_pattern() or normalize(p_text, NFKC) ~ private.policy_phone_pattern() then
    v_action := v_rules -> 'phone' ->> 'action';
    if v_private and v_rules -> 'phone' ->> 'scope' = 'public' then
      v_action := 'allow';
    end if;
    if v_action = 'censor' then
      v_censored := regexp_replace(v_body, private.policy_phone_pattern(), '[nomor disensor]', 'g');
      if v_censored = v_body then
        v_action := 'hold';
      end if;
      v_body := v_censored;
    end if;
    if v_action <> 'allow' then
      v_hits := v_hits || 'phone'::text;
      v_level := greatest(v_level, case v_action when 'censor' then 1 when 'hold' then 2 when 'block' then 3 else 0 end);
    end if;
  end if;

  if coalesce(v_pat.promo_max, 0) > 0 then
    v_scan := case when v_pat.allow is null then p_text else regexp_replace(p_text, v_pat.allow, ' ', 'gi') end;
    select coalesce(array_agg(distinct p.phrase), '{}') into v_phrases
    from unnest(private.policy_ngrams(private.policy_tokens(v_scan), v_pat.promo_max)) g
    join cs.promo_phrases p on p.phrase = g;
    v_raw := cardinality(v_phrases) > 0;
    if v_raw or exists (
         select 1
         from unnest(private.policy_ngrams(private.policy_tokens(
                private.policy_collapse(private.normalize_for_policy(v_scan))), v_pat.promo_max)) g
         join private.policy_forms f on f.source = 'promo' and f.form = g) then
      v_action := v_rules -> 'promotion' ->> 'action';
      if v_private and v_rules -> 'promotion' ->> 'scope' = 'public' then
        v_action := 'allow';
      end if;
      if v_action = 'censor' then
        if v_raw then
          foreach v_phrase in array v_phrases loop
            v_body := regexp_replace(v_body, '\m' || v_phrase || '\M', repeat('*', char_length(v_phrase)), 'gi');
          end loop;
        else
          v_action := 'hold';
        end if;
      end if;
      if v_action <> 'allow' then
        v_hits := v_hits || 'promotion'::text;
        v_level := greatest(v_level, case v_action when 'censor' then 1 when 'hold' then 2 when 'block' then 3 else 0 end);
      end if;
    end if;
  end if;

  if v_private and v_level = 2 then
    v_level := 3;
  end if;
  return jsonb_build_object(
    'action', (array['allow', 'censor', 'hold', 'block'])[v_level + 1],
    'categories', to_jsonb(array(select distinct c from unnest(v_hits) c order by c)),
    'links', v_links,
    'body', v_body);
end;
$$;

create or replace function private.flag_content(p_type text, p_id uuid, p_categories text[], p_source text,
                                                p_alert uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.content_flags (target_type, target_id, categories, source, alert_id)
  values (p_type, p_id, coalesce(p_categories, '{}'), p_source, p_alert)
  on conflict (target_type, target_id) do update
    set categories = array(select distinct c from unnest(private.content_flags.categories || excluded.categories) c order by c),
        source = excluded.source,
        alert_id = coalesce(excluded.alert_id, private.content_flags.alert_id),
        created_at = now();
$$;

create or replace function private.enforce_content_safety()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind    text := tg_argv[0];
  v_row     jsonb := to_jsonb(new);
  v_user    uuid := (v_row ->> tg_argv[1])::uuid;
  v_surface text := v_kind;
  v_result  jsonb;
  v_new     boolean;
  v_cats    text[];
begin
  if not private.is_end_user() or new.deleted_at is not null or v_user is distinct from auth.uid() then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.body is not distinct from old.body then
    return new;
  end if;
  if tg_op = 'INSERT' and private.client_id_exists(tg_relid::regclass, tg_argv[1], v_user, (v_row ->> 'client_id')::uuid) then
    return new;
  end if;
  if v_kind = 'message' then
    select r.type into v_surface from public.chat_rooms r where r.id = (v_row ->> 'room_id')::uuid;
    if v_surface is null or v_surface = 'support' then
      return new;
    end if;
  end if;
  if private.safety_exempt(v_user) then
    return new;
  end if;

  v_new := private.is_new_account(v_user);
  if v_new and tg_op = 'INSERT' and private.has_image_attachment(v_row -> 'attachments') then
    perform private.api_error(403, 'new_account_restricted', 'image');
  end if;
  v_result := private.evaluate_content(new.body, v_surface);
  if v_new and (v_result ->> 'links')::boolean then
    perform private.api_error(403, 'new_account_restricted', 'link');
  end if;

  v_cats := array(select jsonb_array_elements_text(v_result -> 'categories'));
  if v_result ->> 'action' = 'block' then
    if v_cats && '{phone,messenger}'::text[] then
      perform private.api_error(422, 'contact_blocked',
        'Nomor kontak atau tautan grup chat tidak boleh dibagikan di sini.');
    elsif v_cats && '{gambling,porn,phishing,blocked,shortener,other_link}'::text[] then
      perform private.api_error(422, 'link_blocked', 'Tautan ini tidak diizinkan.');
    end if;
    perform private.api_error(422, 'content_blocked', 'Konten mengandung kata atau frasa yang tidak diizinkan.');
  end if;
  if v_result ->> 'body' is distinct from new.body then
    new.body := v_result ->> 'body';
  end if;
  if v_result ->> 'action' = 'hold' and new.moderation_status = 'visible' then
    new.moderation_status := 'held';
    perform private.flag_content(v_kind, new.id, v_cats, 'policy');
  end if;
  return new;
end;
$$;

create trigger posts_31_safety
  before insert or update of body on public.posts
  for each row execute function private.enforce_content_safety('post', 'author_id');
create trigger comments_31_safety
  before insert or update of body on public.comments
  for each row execute function private.enforce_content_safety('comment', 'author_id');
create trigger messages_31_safety
  before insert or update of body on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_content_safety('message', 'sender_id');

create or replace function private.skip_hidden_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text;
begin
  if new.type in ('reply', 'mention') and new.payload ? 'comment_id' then
    v_id := new.payload ->> 'comment_id';
    if exists (select 1 from public.comments c where c.id = v_id::uuid and c.moderation_status <> 'visible') then
      return null;
    end if;
  elsif new.type = 'mention' and new.payload ? 'post_id' then
    v_id := new.payload ->> 'post_id';
    if exists (select 1 from public.posts p where p.id = v_id::uuid and p.moderation_status <> 'visible') then
      return null;
    end if;
  elsif new.type = 'message' and new.payload ? 'message_id' then
    v_id := new.payload ->> 'message_id';
    if exists (select 1 from public.messages m where m.id = v_id::uuid and m.moderation_status <> 'visible') then
      return null;
    end if;
  end if;
  return new;
end;
$$;

create trigger notifications_31_hidden_content
  before insert on public.notifications
  for each row execute function private.skip_hidden_notification();

create or replace function private.keep_visible_preview()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.messages m
             where m.room_id = new.id and m.created_at = new.last_message_at
               and m.sender_id is not distinct from new.last_message_sender_id
               and new.last_message_preview = case when m.body = '' then '[lampiran]' else private.snippet(m.body, 120) end
               and m.moderation_status <> 'visible') then
    new.last_message_at := old.last_message_at;
    new.last_message_preview := old.last_message_preview;
    new.last_message_sender_id := old.last_message_sender_id;
  end if;
  return new;
end;
$$;

create trigger chat_rooms_31_visible_preview
  before update of last_message_at, last_message_preview on public.chat_rooms
  for each row when (new.last_message_at is distinct from old.last_message_at
                     or new.last_message_preview is distinct from old.last_message_preview)
  execute function private.keep_visible_preview();

create or replace function cs.content_rules_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'category', r.category, 'action', r.action, 'scope', r.scope, 'updated_at', r.updated_at,
        'updated_by', cs.staff_ref(r.updated_by)) order by r.category) from cs.content_rules r), '[]'),
    'blocked_domains', coalesce((select jsonb_agg(jsonb_build_object(
        'domain', b.domain, 'match', b.match, 'category', b.category, 'action', b.action, 'note', b.note,
        'created_at', b.created_at) order by b.category, b.domain) from cs.blocked_domains b), '[]'),
    'allowed_domains', coalesce((select jsonb_agg(jsonb_build_object(
        'domain', a.domain, 'note', a.note, 'created_at', a.created_at) order by a.domain) from cs.allowed_domains a), '[]'),
    'allowlist', coalesce((select jsonb_agg(jsonb_build_object('term', t.term, 'created_at', t.created_at) order by t.term)
                           from cs.policy_allowlist t), '[]'),
    'promo_phrases', coalesce((select jsonb_agg(jsonb_build_object('phrase', p.phrase, 'created_at', p.created_at)
                                                order by p.phrase) from cs.promo_phrases p), '[]'),
    'new_account_days', private.setting_num('safety.new_account_days', 3));
$$;

create or replace function cs.clean_domain(p_domain text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(regexp_replace(regexp_replace(lower(btrim(coalesce(p_domain, ''))),
           '^[a-z][a-z0-9+.-]*://', ''), '[/?#:].*$', ''), '^www\.', '');
$$;

create or replace function cs.check_policy_term(p_term text, p_min integer)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if char_length(p_term) not between p_min and 50 or p_term !~ '^[a-z0-9]+( [a-z0-9]+)*$' then
    perform private.api_error(400, 'invalid_term', 'Istilah ' || p_min || '–50 karakter, hanya huruf, angka, dan spasi');
  end if;
end;
$$;

create or replace function cs_api.compliance_content_rules()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_set_content_rule(p_category text, p_action text, p_scope text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{compliance}');
  v_old cs.content_rules;
begin
  select * into v_old from cs.content_rules where category = p_category for update;
  if not found then
    perform private.api_error(404, 'category_not_found', 'Kategori tidak dikenal');
  end if;
  if p_action is null or p_action not in ('allow', 'censor', 'hold', 'block') then
    perform private.api_error(400, 'invalid_action', 'Aksi: allow, censor, hold, atau block');
  end if;
  if p_scope is not null and p_scope not in ('public', 'all') then
    perform private.api_error(400, 'invalid_scope', 'Cakupan: public atau all');
  end if;
  update cs.content_rules
     set action = p_action, scope = coalesce(p_scope, scope), updated_at = now(), updated_by = v_me
   where category = p_category;
  perform cs.audit('content_rule.update', null, null,
    jsonb_build_object('category', p_category, 'from', jsonb_build_object('action', v_old.action, 'scope', v_old.scope),
                       'action', p_action, 'scope', coalesce(p_scope, v_old.scope)));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_save_blocked_domain(p_domain text, p_category text,
                                                                 p_action text default null, p_note text default null,
                                                                 p_match text default 'domain')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_match  text := coalesce(p_match, 'domain');
  v_domain text := case when coalesce(p_match, 'domain') = 'keyword' then lower(btrim(coalesce(p_domain, '')))
                        else cs.clean_domain(p_domain) end;
  v_note   text := nullif(btrim(coalesce(p_note, '')), '');
  v_old    cs.blocked_domains;
begin
  if v_match not in ('domain', 'keyword') then
    perform private.api_error(400, 'invalid_match', 'Jenis: domain atau keyword');
  end if;
  if (v_match = 'domain' and (char_length(v_domain) > 253
        or v_domain !~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$'))
     or (v_match = 'keyword' and v_domain !~ '^[a-z0-9][a-z0-9-]{2,29}$') then
    perform private.api_error(400, 'invalid_domain', 'Domain tidak valid (contoh: contoh.com) atau kata kunci 3–30 karakter');
  end if;
  if p_category is null or p_category not in ('gambling', 'porn', 'phishing', 'blocked', 'shortener', 'messenger') then
    perform private.api_error(400, 'invalid_category', 'Kategori domain tidak dikenal');
  end if;
  if p_action is not null and p_action not in ('allow', 'censor', 'hold', 'block') then
    perform private.api_error(400, 'invalid_action', 'Aksi: allow, censor, hold, atau block');
  end if;
  if char_length(coalesce(v_note, '')) > 200 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 200 karakter');
  end if;
  select * into v_old from cs.blocked_domains where domain = v_domain;
  if not found and (select count(*) from cs.blocked_domains) >= 5000 then
    perform private.api_error(400, 'domain_limit', 'Daftar domain sudah mencapai batas 5.000');
  end if;
  insert into cs.blocked_domains (domain, match, category, action, note, created_by)
  values (v_domain, v_match, p_category, p_action, v_note, v_me)
  on conflict (domain) do update
    set match = excluded.match, category = excluded.category, action = excluded.action, note = excluded.note;
  perform cs.audit('blocked_domain.save', null, null,
    jsonb_build_object('domain', v_domain, 'match', v_match, 'category', p_category, 'action', p_action,
                       'previous', case when v_old.domain is not null then jsonb_build_object(
                         'category', v_old.category, 'action', v_old.action, 'match', v_old.match) end));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_delete_blocked_domain(p_domain text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{compliance}');
  v_old cs.blocked_domains;
begin
  delete from cs.blocked_domains b
   where b.domain = case when b.match = 'keyword' then lower(btrim(coalesce(p_domain, ''))) else cs.clean_domain(p_domain) end
  returning * into v_old;
  if v_old.domain is null then
    perform private.api_error(404, 'domain_not_found', 'Domain tidak ada di daftar');
  end if;
  perform cs.audit('blocked_domain.delete', null, null,
    jsonb_build_object('domain', v_old.domain, 'match', v_old.match, 'category', v_old.category));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_save_allowed_domain(p_domain text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_domain text := cs.clean_domain(p_domain);
  v_note   text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if char_length(v_domain) > 253 or v_domain !~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$' then
    perform private.api_error(400, 'invalid_domain', 'Domain tidak valid (contoh: contoh.com)');
  end if;
  if char_length(coalesce(v_note, '')) > 200 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 200 karakter');
  end if;
  if not exists (select 1 from cs.allowed_domains where domain = v_domain)
     and (select count(*) from cs.allowed_domains) >= 1000 then
    perform private.api_error(400, 'domain_limit', 'Daftar domain tepercaya sudah mencapai batas 1.000');
  end if;
  insert into cs.allowed_domains (domain, note, created_by) values (v_domain, v_note, v_me)
  on conflict (domain) do update set note = excluded.note;
  perform cs.audit('allowed_domain.save', null, null, jsonb_build_object('domain', v_domain, 'note', v_note));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_delete_allowed_domain(p_domain text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_domain text;
begin
  delete from cs.allowed_domains where domain = cs.clean_domain(p_domain) returning domain into v_domain;
  if v_domain is null then
    perform private.api_error(404, 'domain_not_found', 'Domain tidak ada di daftar');
  end if;
  perform cs.audit('allowed_domain.delete', null, null, jsonb_build_object('domain', v_domain));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_add_allowlist_term(p_term text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_term text := cs.normalize_banned_word(p_term);
begin
  perform cs.check_policy_term(v_term, 2);
  if exists (select 1 from cs.policy_allowlist where term = v_term) then
    perform private.api_error(409, 'term_exists', 'Istilah ini sudah ada di daftar');
  end if;
  if (select count(*) from cs.policy_allowlist) >= 500 then
    perform private.api_error(400, 'term_limit', 'Daftar pengecualian sudah mencapai batas 500');
  end if;
  insert into cs.policy_allowlist (term, created_by) values (v_term, v_me);
  perform cs.audit('policy_allowlist.add', null, null, jsonb_build_object('term', v_term));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_delete_allowlist_term(p_term text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_term text;
begin
  delete from cs.policy_allowlist where term = cs.normalize_banned_word(p_term) returning term into v_term;
  if v_term is null then
    perform private.api_error(404, 'term_not_found', 'Istilah tidak ada di daftar');
  end if;
  perform cs.audit('policy_allowlist.delete', null, null, jsonb_build_object('term', v_term));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_add_promo_phrase(p_phrase text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_phrase text := cs.normalize_banned_word(p_phrase);
begin
  perform cs.check_policy_term(v_phrase, 3);
  if exists (select 1 from cs.promo_phrases where phrase = v_phrase) then
    perform private.api_error(409, 'term_exists', 'Frasa ini sudah ada di daftar');
  end if;
  if (select count(*) from cs.promo_phrases) >= 500 then
    perform private.api_error(400, 'term_limit', 'Daftar frasa promosi sudah mencapai batas 500');
  end if;
  insert into cs.promo_phrases (phrase, created_by) values (v_phrase, v_me);
  perform cs.audit('promo_phrase.add', null, null, jsonb_build_object('phrase', v_phrase));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_delete_promo_phrase(p_phrase text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_phrase text;
begin
  delete from cs.promo_phrases where phrase = cs.normalize_banned_word(p_phrase) returning phrase into v_phrase;
  if v_phrase is null then
    perform private.api_error(404, 'term_not_found', 'Frasa tidak ada di daftar');
  end if;
  perform cs.audit('promo_phrase.delete', null, null, jsonb_build_object('phrase', v_phrase));
  return cs.content_rules_view();
end;
$$;

create or replace function cs_api.compliance_set_new_account_days(p_days integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{compliance}');
  v_old jsonb := private.setting_json('safety.new_account_days', '3');
begin
  if p_days is null or p_days not between 0 and 30 then
    perform private.api_error(400, 'invalid_setting', 'Masa akun baru 0–30 hari');
  end if;
  update private.settings set value = to_jsonb(p_days), updated_at = now() where key = 'safety.new_account_days';
  perform cs.audit('content_rule.new_account_days', null, null, jsonb_build_object('from', v_old, 'to', p_days));
  return cs.content_rules_view();
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
  return v_result || jsonb_build_object('banned_words', v_banned, 'normalized', private.normalize_for_policy(p_text));
end;
$$;

create or replace function cs_api.community_held_content(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community('{community.moderate}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'target_type', x.target_type, 'target_id', x.id, 'excerpt', left(x.body, 280),
             'attachments', jsonb_array_length(x.attachments), 'stock_code', x.stock_code,
             'created_at', x.created_at, 'categories', to_jsonb(coalesce(f.categories, '{}')),
             'source', coalesce(f.source, 'staff'), 'alert_id', f.alert_id,
             'author', jsonb_build_object('id', pr.id, 'username', pr.username, 'display_name', pr.display_name,
                                          'trust_level', pr.trust_level, 'new_account', private.is_new_account(pr.id)))
           order by x.created_at)
    from (
      select * from (
        select 'post' as target_type, p.id, p.author_id, p.body, p.attachments, null::text as stock_code, p.created_at
        from public.posts p where p.moderation_status = 'held' and p.deleted_at is null
        union all
        select 'comment', c.id, c.author_id, c.body, '[]'::jsonb, null, c.created_at
        from public.comments c where c.moderation_status = 'held' and c.deleted_at is null
        union all
        select 'message', m.id, m.sender_id, m.body, m.attachments, r.stock_code, m.created_at
        from public.messages m join public.chat_rooms r on r.id = m.room_id
        where m.moderation_status = 'held' and m.deleted_at is null and m.session_id is null
      ) h
      order by h.created_at
      limit least(greatest(coalesce(p_limit, 100), 1), 500)
    ) x
    left join private.content_flags f on f.target_type = x.target_type and f.target_id = x.id
    left join public.profiles pr on pr.id = x.author_id), '[]');
end;
$$;

create or replace function private.domain_blocked(p_host text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select not r.allowed and r.action in ('hold', 'block') and r.category <> 'other_link'
                   from private.host_rule(cs.clean_domain(p_host)) r), false);
$$;

revoke execute on function private.track_signup() from public;
revoke execute on function private.is_new_account(uuid) from public;
revoke execute on function private.safety_exempt(uuid) from public;
revoke execute on function private.has_image_attachment(jsonb) from public;
revoke execute on function private.policy_homoglyphs(text) from public;
revoke execute on function private.policy_char_map(text) from public;
revoke execute on function private.policy_join_singles(text, text) from public;
revoke execute on function private.normalize_for_policy(text) from public;
revoke execute on function private.policy_collapse(text) from public;
revoke execute on function private.policy_fuzzy_pattern(text) from public;
revoke execute on function private.policy_alternation(text[]) from public;
revoke execute on function private.policy_tokens(text) from public;
revoke execute on function private.policy_ngrams(text[], integer) from public;
revoke execute on function private.rebuild_policy_patterns(text) from public;
revoke execute on function private.policy_patterns_changed() from public;
revoke execute on function private.policy_fuzzy_mask(text, text) from public;
revoke execute on function private.apply_content_policy(text) from public;
revoke execute on function private.extract_hosts(text) from public;
revoke execute on function private.host_rule(text) from public;
revoke execute on function private.policy_phone_pattern() from public;
revoke execute on function private.evaluate_content(text, text) from public;
revoke execute on function private.flag_content(text, uuid, text[], text, uuid) from public;
revoke execute on function private.enforce_content_safety() from public;
revoke execute on function private.skip_hidden_notification() from public;
revoke execute on function private.keep_visible_preview() from public;
revoke execute on function private.domain_blocked(text) from public;
revoke execute on function cs.content_rules_view() from public;
revoke execute on function cs.clean_domain(text) from public;
revoke execute on function cs.check_policy_term(text, integer) from public;
revoke execute on function cs_api.compliance_content_rules() from public;
revoke execute on function cs_api.compliance_set_content_rule(text, text, text) from public;
revoke execute on function cs_api.compliance_save_blocked_domain(text, text, text, text, text) from public;
revoke execute on function cs_api.compliance_delete_blocked_domain(text) from public;
revoke execute on function cs_api.compliance_save_allowed_domain(text, text) from public;
revoke execute on function cs_api.compliance_delete_allowed_domain(text) from public;
revoke execute on function cs_api.compliance_add_allowlist_term(text) from public;
revoke execute on function cs_api.compliance_delete_allowlist_term(text) from public;
revoke execute on function cs_api.compliance_add_promo_phrase(text) from public;
revoke execute on function cs_api.compliance_delete_promo_phrase(text) from public;
revoke execute on function cs_api.compliance_set_new_account_days(integer) from public;
revoke execute on function cs_api.compliance_test_content(text, text) from public;
revoke execute on function cs_api.community_held_content(integer) from public;

grant execute on function cs_api.compliance_content_rules() to authenticated;
grant execute on function cs_api.compliance_set_content_rule(text, text, text) to authenticated;
grant execute on function cs_api.compliance_save_blocked_domain(text, text, text, text, text) to authenticated;
grant execute on function cs_api.compliance_delete_blocked_domain(text) to authenticated;
grant execute on function cs_api.compliance_save_allowed_domain(text, text) to authenticated;
grant execute on function cs_api.compliance_delete_allowed_domain(text) to authenticated;
grant execute on function cs_api.compliance_add_allowlist_term(text) to authenticated;
grant execute on function cs_api.compliance_delete_allowlist_term(text) to authenticated;
grant execute on function cs_api.compliance_add_promo_phrase(text) to authenticated;
grant execute on function cs_api.compliance_delete_promo_phrase(text) to authenticated;
grant execute on function cs_api.compliance_set_new_account_days(integer) to authenticated;
grant execute on function cs_api.compliance_test_content(text, text) to authenticated;
grant execute on function cs_api.community_held_content(integer) to authenticated;
