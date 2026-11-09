create table cs.faq_categories (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  name_id    text not null check (char_length(btrim(name_id)) between 2 and 60),
  name_en    text not null check (char_length(btrim(name_en)) between 2 and 60),
  icon       text check (icon is null or icon in ('account', 'wallet', 'receipt', 'chart', 'tools', 'shield', 'help',
                                                  'document', 'phone', 'card', 'chat', 'star', 'bell', 'lock',
                                                  'globe', 'gift')),
  sort_order smallint not null default 0,
  active     boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table cs.faq_articles (
  id           uuid primary key default gen_random_uuid(),
  category_id  uuid not null references cs.faq_categories (id),
  question_id  text not null check (char_length(btrim(question_id)) between 5 and 200),
  question_en  text not null check (char_length(btrim(question_en)) between 5 and 200),
  answer_id    text not null check (char_length(btrim(answer_id)) between 1 and 8000),
  answer_en    text not null check (char_length(btrim(answer_en)) between 1 and 8000),
  keywords     text[] not null default '{}' check (cardinality(keywords) <= 20),
  topic_code   text references cs.support_topics (code) on update cascade on delete set null,
  sort_order   smallint not null default 0,
  status       text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  version      integer not null default 1,
  views        integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  published_at timestamptz
);

create index faq_articles_category_idx on cs.faq_articles (category_id, sort_order);
create index faq_articles_topic_idx on cs.faq_articles (topic_code) where status = 'published';

create table cs.faq_article_versions (
  article_id uuid not null references cs.faq_articles (id) on delete cascade,
  version    integer not null,
  content    jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  primary key (article_id, version)
);

create table cs.faq_feedback (
  article_id  uuid not null references cs.faq_articles (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  helpful     boolean not null,
  comment     text check (comment is null or char_length(comment) between 1 and 500),
  updated_at  timestamptz not null default now(),
  primary key (article_id, customer_id)
);

create table cs.faq_reads (
  article_id  uuid not null references cs.faq_articles (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  read_at     timestamptz not null default now(),
  primary key (article_id, customer_id)
);

create index faq_reads_customer_idx on cs.faq_reads (customer_id, read_at);

create table cs.faq_search_misses (
  id         bigint generated always as identity primary key,
  query      text not null check (char_length(query) between 1 and 100),
  language   text not null check (language in ('id', 'en')),
  created_at timestamptz not null default now()
);

create index faq_search_misses_created_idx on cs.faq_search_misses (created_at);

alter table cs.faq_categories enable row level security;
alter table cs.faq_articles enable row level security;
alter table cs.faq_article_versions enable row level security;
alter table cs.faq_feedback enable row level security;
alter table cs.faq_reads enable row level security;
alter table cs.faq_search_misses enable row level security;
revoke all on cs.faq_categories, cs.faq_articles, cs.faq_article_versions, cs.faq_feedback, cs.faq_reads,
              cs.faq_search_misses from public, anon, authenticated;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('faq_search', 30, 60),
  ('faq_feedback', 20, 3600)
on conflict (action, window_seconds) do nothing;

insert into cs.faq_categories (code, name_id, name_en, icon, sort_order) values
  ('account', 'Akun dan login', 'Account and login', 'account', 10),
  ('transaction', 'Transaksi', 'Transactions', 'receipt', 20),
  ('security', 'Keamanan', 'Security', 'shield', 30)
on conflict (code) do nothing;

create or replace function cs.faq_check_markdown(p_text text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_text ~ '<[A-Za-z/!?]' then
    perform private.api_error(400, 'invalid_answer', 'Jawaban tidak boleh memuat tag HTML');
  end if;
  if p_text ~* '\]\(\s*(?!https://)' then
    perform private.api_error(400, 'invalid_answer', 'Tautan di jawaban harus https://');
  end if;
end;
$$;

create or replace function cs.faq_clean_query(p_query text)
returns text
language sql
immutable
set search_path = ''
as $$
  select left(btrim(regexp_replace(regexp_replace(regexp_replace(lower(coalesce(p_query, '')),
           '[^[:space:]]+@[^[:space:]]+', '@', 'g'), '[0-9]{4,}', '#', 'g'), '[[:space:]]+', ' ', 'g')), 100);
$$;

create or replace function cs.faq_content(a cs.faq_articles)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('category_id', a.category_id, 'question_id', a.question_id, 'question_en', a.question_en,
                            'answer_id', a.answer_id, 'answer_en', a.answer_en, 'keywords', to_jsonb(a.keywords),
                            'topic_code', a.topic_code, 'sort_order', a.sort_order);
$$;

create or replace function cs.faq_customer_row(a cs.faq_articles, p_language text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.id,
    'category', (select c.code from cs.faq_categories c where c.id = a.category_id),
    'question', case when p_language = 'en' then a.question_en else a.question_id end,
    'answer', case when p_language = 'en' then a.answer_en else a.answer_id end,
    'topic', a.topic_code,
    'updated_at', a.updated_at);
$$;

create or replace function cs.faq_score(p_article uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(case when f.helpful then 1 else -1 end), 0)::numeric
  from cs.faq_feedback f where f.article_id = p_article;
$$;

create or replace function cs.faq_admin_row(a cs.faq_articles)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.faq_content(a) || jsonb_build_object(
    'id', a.id,
    'status', a.status,
    'version', a.version,
    'views', a.views,
    'readers', (select count(*) from cs.faq_reads r where r.article_id = a.id),
    'helpful', (select count(*) from cs.faq_feedback f where f.article_id = a.id and f.helpful),
    'not_helpful', (select count(*) from cs.faq_feedback f where f.article_id = a.id and not f.helpful),
    'tickets_after', (select count(*) from cs.faq_reads r
                      where r.article_id = a.id
                        and exists (select 1 from cs.tickets t
                                    where t.customer_id = r.customer_id
                                      and t.created_at between r.read_at and r.read_at + interval '24 hours')),
    'created_at', a.created_at,
    'updated_at', a.updated_at,
    'updated_by_name', (select g.display_name from cs.agents g where g.user_id = a.updated_by),
    'published_at', a.published_at);
$$;

create or replace function cs.faq_category_row(c cs.faq_categories)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id, 'code', c.code, 'name_id', c.name_id, 'name_en', c.name_en, 'icon', c.icon,
    'sort_order', c.sort_order, 'active', c.active, 'updated_at', c.updated_at,
    'article_count', (select count(*) from cs.faq_articles a where a.category_id = c.id and a.status <> 'archived'));
$$;

create or replace function cs_api.faq(p_language text default 'id')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
begin
  return jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
               'code', c.code,
               'name', case when p_language = 'en' then c.name_en else c.name_id end,
               'icon', c.icon,
               'articles', (select jsonb_agg(cs.faq_customer_row(a, p_language) order by a.sort_order, a.created_at)
                            from cs.faq_articles a where a.category_id = c.id and a.status = 'published'))
             order by c.sort_order, c.code)
      from cs.faq_categories c
      where c.active and exists (select 1 from cs.faq_articles a where a.category_id = c.id and a.status = 'published')),
      '[]'),
    'updated_at', (select max(a.updated_at) from cs.faq_articles a where a.status = 'published'));
end;
$$;

create or replace function cs_api.faq_search(p_query text, p_language text default 'id')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_customer();
  v_lang  text := case when p_language = 'en' then 'en' else 'id' end;
  v_clean text := cs.faq_clean_query(p_query);
  v_words text[];
  v_found jsonb;
begin
  if char_length(btrim(coalesce(p_query, ''))) not between 2 and 100 then
    perform private.api_error(400, 'invalid_query', 'Kata pencarian 2–100 karakter');
  end if;
  perform private.consume_rate_limit(v_me, 'faq_search');
  select array_agg(replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_'))
    into v_words
    from (select w from unnest(regexp_split_to_array(lower(btrim(p_query)), '[[:space:]]+')) w
          where char_length(w) >= 2 limit 6) x;
  if v_words is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(cs.faq_customer_row(m.a, v_lang) order by m.rank desc, m.score desc, (m.a).views desc), '[]')
    into v_found
    from (select a,
                 (select count(*) from unnest(v_words) w
                   where lower(case when v_lang = 'en' then a.question_en else a.question_id end) like '%' || w || '%') as rank,
                 cs.faq_score(a.id) as score
          from cs.faq_articles a
          join cs.faq_categories c on c.id = a.category_id and c.active
          where a.status = 'published'
            and not exists (
              select 1 from unnest(v_words) w
              where lower(case when v_lang = 'en' then a.question_en || ' ' || a.answer_en
                               else a.question_id || ' ' || a.answer_id end
                          || ' ' || array_to_string(a.keywords, ' ')) not like '%' || w || '%')
          order by rank desc, score desc, a.views desc
          limit 20) m;

  if v_found = '[]'::jsonb and v_clean <> '' then
    delete from cs.faq_search_misses where created_at < now() - interval '90 days';
    insert into cs.faq_search_misses (query, language) values (v_clean, v_lang);
  end if;
  return v_found;
end;
$$;

create or replace function cs_api.faq_article(p_id uuid, p_language text default 'id')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
  a    cs.faq_articles;
  f    cs.faq_feedback;
begin
  select * into a from cs.faq_articles x
  where x.id = p_id and x.status = 'published'
    and exists (select 1 from cs.faq_categories c where c.id = x.category_id and c.active);
  if a.id is null then
    perform private.api_error(404, 'article_not_found', 'Artikel tidak ditemukan');
  end if;
  if not exists (select 1 from cs.faq_reads r
                 where r.article_id = a.id and r.customer_id = v_me and r.read_at > now() - interval '1 hour') then
    update cs.faq_articles set views = views + 1 where id = a.id;
  end if;
  insert into cs.faq_reads (article_id, customer_id) values (a.id, v_me)
  on conflict (article_id, customer_id) do update set read_at = now();
  select * into f from cs.faq_feedback x where x.article_id = a.id and x.customer_id = v_me;
  return cs.faq_customer_row(a, p_language) || jsonb_build_object(
    'feedback', case when f.article_id is not null then jsonb_build_object('helpful', f.helpful, 'comment', f.comment) end);
end;
$$;

create or replace function cs_api.faq_feedback(p_article_id uuid, p_helpful boolean, p_comment text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_customer();
  v_comment text := nullif(btrim(coalesce(p_comment, '')), '');
begin
  if p_helpful is null then
    perform private.api_error(400, 'invalid_feedback', 'Pilih membantu atau tidak');
  end if;
  if char_length(v_comment) > 500 then
    perform private.api_error(400, 'invalid_feedback', 'Komentar maksimal 500 karakter');
  end if;
  if not exists (select 1 from cs.faq_articles a where a.id = p_article_id and a.status = 'published') then
    perform private.api_error(404, 'article_not_found', 'Artikel tidak ditemukan');
  end if;
  perform private.consume_rate_limit(v_me, 'faq_feedback');
  insert into cs.faq_feedback (article_id, customer_id, helpful, comment)
  values (p_article_id, v_me, p_helpful, v_comment)
  on conflict (article_id, customer_id) do update
    set helpful = excluded.helpful, comment = excluded.comment, updated_at = now();
  return jsonb_build_object('helpful', p_helpful, 'comment', v_comment);
end;
$$;

create or replace function cs_api.faq_for_topic(p_topic text, p_language text default 'id', p_limit integer default 3)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_customer();
begin
  return coalesce((
    select jsonb_agg(cs.faq_customer_row(m.a, p_language) order by m.score desc, (m.a).views desc, (m.a).sort_order)
    from (select a, cs.faq_score(a.id) as score
          from cs.faq_articles a
          join cs.faq_categories c on c.id = a.category_id and c.active
          where a.status = 'published' and a.topic_code = p_topic
          order by cs.faq_score(a.id) desc, a.views desc, a.sort_order
          limit least(greatest(coalesce(p_limit, 3), 1), 5)) m), '[]');
end;
$$;

create or replace function cs_api.admin_faq()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return jsonb_build_object(
    'categories', coalesce((select jsonb_agg(cs.faq_category_row(c) order by c.sort_order, c.code)
                            from cs.faq_categories c), '[]'),
    'articles', coalesce((select jsonb_agg(cs.faq_admin_row(a) order by a.sort_order, a.created_at)
                          from cs.faq_articles a), '[]'));
end;
$$;

create or replace function cs_api.admin_faq_save_category(
  p_id uuid, p_code text, p_name_id text, p_name_en text, p_icon text default null,
  p_sort_order integer default 0, p_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_old cs.faq_categories;
  c     cs.faq_categories;
begin
  if p_code is null or p_code !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_code', 'Kode 2–32 huruf kecil, angka, atau garis bawah, diawali huruf');
  end if;
  if char_length(btrim(coalesce(p_name_id, ''))) not between 2 and 60
     or char_length(btrim(coalesce(p_name_en, ''))) not between 2 and 60 then
    perform private.api_error(400, 'invalid_name', 'Nama kategori 2–60 karakter');
  end if;
  if p_icon is not null and p_icon not in ('account', 'wallet', 'receipt', 'chart', 'tools', 'shield', 'help', 'document',
                                           'phone', 'card', 'chat', 'star', 'bell', 'lock', 'globe', 'gift') then
    perform private.api_error(400, 'invalid_icon', 'Ikon tidak dikenal');
  end if;
  if exists (select 1 from cs.faq_categories x where x.code = p_code and x.id is distinct from p_id) then
    perform private.api_error(409, 'code_taken', 'Kode kategori sudah dipakai');
  end if;

  if p_id is null then
    insert into cs.faq_categories (code, name_id, name_en, icon, sort_order, active, updated_by)
    values (p_code, btrim(p_name_id), btrim(p_name_en), p_icon, coalesce(p_sort_order, 0), coalesce(p_active, true), v_me)
    returning * into c;
  else
    select * into v_old from cs.faq_categories x where x.id = p_id for update;
    if v_old.id is null then
      perform private.api_error(404, 'category_not_found', 'Kategori tidak ditemukan');
    end if;
    update cs.faq_categories
       set code = p_code, name_id = btrim(p_name_id), name_en = btrim(p_name_en), icon = p_icon,
           sort_order = coalesce(p_sort_order, 0), active = coalesce(p_active, true), updated_at = now(), updated_by = v_me
     where id = p_id
    returning * into c;
  end if;
  perform cs.audit('faq.category_save', null, null,
    jsonb_build_object('id', c.id, 'code', c.code, 'before', case when v_old.id is not null then to_jsonb(v_old) end,
                       'after', to_jsonb(c)));
  return cs.faq_category_row(c);
end;
$$;

create or replace function cs_api.admin_faq_save_article(
  p_id uuid, p_category_id uuid, p_question_id text, p_question_en text, p_answer_id text, p_answer_en text,
  p_keywords text[] default '{}', p_topic_code text default null, p_sort_order integer default 0,
  p_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_keywords text[];
  v_old      cs.faq_articles;
  a          cs.faq_articles;
begin
  if not exists (select 1 from cs.faq_categories c where c.id = p_category_id) then
    perform private.api_error(400, 'invalid_category', 'Kategori tidak ditemukan');
  end if;
  if char_length(btrim(coalesce(p_question_id, ''))) not between 5 and 200
     or char_length(btrim(coalesce(p_question_en, ''))) not between 5 and 200 then
    perform private.api_error(400, 'invalid_question', 'Pertanyaan 5–200 karakter dalam dua bahasa');
  end if;
  if char_length(btrim(coalesce(p_answer_id, ''))) not between 1 and 8000
     or char_length(btrim(coalesce(p_answer_en, ''))) not between 1 and 8000 then
    perform private.api_error(400, 'invalid_answer', 'Jawaban 1–8.000 karakter dalam dua bahasa');
  end if;
  perform cs.faq_check_markdown(p_answer_id);
  perform cs.faq_check_markdown(p_answer_en);
  select coalesce(array_agg(distinct k order by k), '{}') into v_keywords
    from (select lower(btrim(x)) as k from unnest(coalesce(p_keywords, '{}')) x) y
   where k <> '';
  if cardinality(v_keywords) > 20 or exists (select 1 from unnest(v_keywords) k where char_length(k) > 40) then
    perform private.api_error(400, 'invalid_keywords', 'Maksimal 20 kata kunci, masing-masing 40 karakter');
  end if;
  if p_topic_code is not null and not exists (select 1 from cs.support_topics t where t.code = p_topic_code) then
    perform private.api_error(400, 'invalid_topic', 'Topik chat tidak ditemukan');
  end if;

  if p_id is null then
    insert into cs.faq_articles (category_id, question_id, question_en, answer_id, answer_en, keywords, topic_code,
                                 sort_order, updated_by)
    values (p_category_id, btrim(p_question_id), btrim(p_question_en), btrim(p_answer_id), btrim(p_answer_en),
            v_keywords, p_topic_code, coalesce(p_sort_order, 0), v_me)
    returning * into a;
  else
    select * into v_old from cs.faq_articles x where x.id = p_id for update;
    if v_old.id is null then
      perform private.api_error(404, 'article_not_found', 'Artikel tidak ditemukan');
    end if;
    if p_version is not null and p_version <> v_old.version then
      perform private.api_error(409, 'version_conflict', 'Artikel sudah diubah orang lain, muat ulang dulu');
    end if;
    update cs.faq_articles
       set category_id = p_category_id, question_id = btrim(p_question_id), question_en = btrim(p_question_en),
           answer_id = btrim(p_answer_id), answer_en = btrim(p_answer_en), keywords = v_keywords,
           topic_code = p_topic_code, sort_order = coalesce(p_sort_order, 0), version = version + 1,
           updated_at = now(), updated_by = v_me
     where id = p_id
    returning * into a;
  end if;
  insert into cs.faq_article_versions (article_id, version, content, created_by)
  values (a.id, a.version, cs.faq_content(a), v_me);
  perform cs.audit('faq.article_save', null, null, jsonb_build_object('id', a.id, 'version', a.version));
  return cs.faq_admin_row(a);
end;
$$;

create or replace function cs_api.admin_faq_set_status(p_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_old cs.faq_articles;
  a     cs.faq_articles;
begin
  if p_status is null or p_status not in ('draft', 'published', 'archived') then
    perform private.api_error(400, 'invalid_status', 'Status harus draft, published, atau archived');
  end if;
  select * into v_old from cs.faq_articles x where x.id = p_id for update;
  if v_old.id is null then
    perform private.api_error(404, 'article_not_found', 'Artikel tidak ditemukan');
  end if;
  update cs.faq_articles
     set status = p_status, updated_at = now(), updated_by = v_me,
         published_at = case when p_status = 'published' then now() else published_at end
   where id = p_id
  returning * into a;
  perform cs.audit('faq.article_status', null, null,
    jsonb_build_object('id', a.id, 'before', v_old.status, 'after', a.status));
  return cs.faq_admin_row(a);
end;
$$;

create or replace function cs_api.admin_faq_versions(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'version', v.version, 'content', v.content, 'created_at', v.created_at,
             'created_by_name', (select g.display_name from cs.agents g where g.user_id = v.created_by))
           order by v.version desc)
    from cs.faq_article_versions v where v.article_id = p_id), '[]');
end;
$$;

create or replace function cs_api.admin_faq_restore(p_id uuid, p_version integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_content jsonb;
  a         cs.faq_articles;
begin
  select v.content into v_content from cs.faq_article_versions v where v.article_id = p_id and v.version = p_version;
  if v_content is null then
    perform private.api_error(404, 'version_not_found', 'Versi tidak ditemukan');
  end if;
  update cs.faq_articles
     set category_id = case when exists (select 1 from cs.faq_categories c where c.id = (v_content ->> 'category_id')::uuid)
                            then (v_content ->> 'category_id')::uuid else category_id end,
         question_id = v_content ->> 'question_id', question_en = v_content ->> 'question_en',
         answer_id = v_content ->> 'answer_id', answer_en = v_content ->> 'answer_en',
         keywords = array(select jsonb_array_elements_text(v_content -> 'keywords')),
         topic_code = case when exists (select 1 from cs.support_topics t where t.code = v_content ->> 'topic_code')
                           then v_content ->> 'topic_code' end,
         sort_order = coalesce((v_content ->> 'sort_order')::smallint, 0),
         version = version + 1, updated_at = now(), updated_by = v_me
   where id = p_id
  returning * into a;
  insert into cs.faq_article_versions (article_id, version, content, created_by)
  values (a.id, a.version, cs.faq_content(a), v_me);
  perform cs.audit('faq.article_restore', null, null,
    jsonb_build_object('id', a.id, 'from_version', p_version, 'version', a.version));
  return cs.faq_admin_row(a);
end;
$$;

create or replace function cs_api.admin_faq_feedback(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('helpful', f.helpful, 'comment', f.comment, 'updated_at', f.updated_at)
                     order by f.updated_at desc)
    from (select * from cs.faq_feedback x where x.article_id = p_id and x.comment is not null
          order by x.updated_at desc limit 200) f), '[]');
end;
$$;

create or replace function cs_api.admin_faq_misses(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin,cs_content}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('query', m.query, 'language', m.language, 'count', m.n, 'last_at', m.last_at)
                     order by m.n desc, m.last_at desc)
    from (select s.query, s.language, count(*) as n, max(s.created_at) as last_at
          from cs.faq_search_misses s
          where s.created_at > now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 90))
          group by s.query, s.language
          order by count(*) desc, max(s.created_at) desc
          limit 100) m), '[]');
end;
$$;

create or replace function private.faq_forget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from cs.faq_feedback where customer_id = new.id;
  delete from cs.faq_reads where customer_id = new.id;
  return null;
end;
$$;

create trigger profiles_71_faq_forget
  after update of deleted_at on public.profiles
  for each row when (new.deleted_at is not null and old.deleted_at is null)
  execute function private.faq_forget();

revoke execute on function cs.faq_check_markdown(text) from public;
revoke execute on function cs.faq_clean_query(text) from public;
revoke execute on function cs.faq_content(cs.faq_articles) from public;
revoke execute on function cs.faq_customer_row(cs.faq_articles, text) from public;
revoke execute on function cs.faq_score(uuid) from public;
revoke execute on function cs.faq_admin_row(cs.faq_articles) from public;
revoke execute on function cs.faq_category_row(cs.faq_categories) from public;
revoke execute on function private.faq_forget() from public;
revoke execute on function cs_api.faq(text) from public;
revoke execute on function cs_api.faq_search(text, text) from public;
revoke execute on function cs_api.faq_article(uuid, text) from public;
revoke execute on function cs_api.faq_feedback(uuid, boolean, text) from public;
revoke execute on function cs_api.faq_for_topic(text, text, integer) from public;
revoke execute on function cs_api.admin_faq() from public;
revoke execute on function cs_api.admin_faq_save_category(uuid, text, text, text, text, integer, boolean) from public;
revoke execute on function cs_api.admin_faq_save_article(uuid, uuid, text, text, text, text, text[], text, integer, integer) from public;
revoke execute on function cs_api.admin_faq_set_status(uuid, text) from public;
revoke execute on function cs_api.admin_faq_versions(uuid) from public;
revoke execute on function cs_api.admin_faq_restore(uuid, integer) from public;
revoke execute on function cs_api.admin_faq_feedback(uuid) from public;
revoke execute on function cs_api.admin_faq_misses(integer) from public;
grant execute on function cs_api.faq(text) to authenticated;
grant execute on function cs_api.faq_search(text, text) to authenticated;
grant execute on function cs_api.faq_article(uuid, text) to authenticated;
grant execute on function cs_api.faq_feedback(uuid, boolean, text) to authenticated;
grant execute on function cs_api.faq_for_topic(text, text, integer) to authenticated;
grant execute on function cs_api.admin_faq() to authenticated;
grant execute on function cs_api.admin_faq_save_category(uuid, text, text, text, text, integer, boolean) to authenticated;
grant execute on function cs_api.admin_faq_save_article(uuid, uuid, text, text, text, text, text[], text, integer, integer) to authenticated;
grant execute on function cs_api.admin_faq_set_status(uuid, text) to authenticated;
grant execute on function cs_api.admin_faq_versions(uuid) to authenticated;
grant execute on function cs_api.admin_faq_restore(uuid, integer) to authenticated;
grant execute on function cs_api.admin_faq_feedback(uuid) to authenticated;
grant execute on function cs_api.admin_faq_misses(integer) to authenticated;
