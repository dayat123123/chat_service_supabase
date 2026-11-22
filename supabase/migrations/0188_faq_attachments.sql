insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('faq-files', 'faq-files', true, 26214400,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy olt_faq_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'faq-files'
              and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|png|webp|mp4|webm|mov)$'
              and (select private.can_manage_faq()));

create policy olt_faq_files_read on storage.objects for select to authenticated
  using (bucket_id = 'faq-files' and (select private.can_manage_faq()));

alter table cs.faq_articles
  add column attachments jsonb not null default '[]'
    check (jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 10);

create or replace function cs.faq_clean_attachments(p_items jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item   jsonb;
  v_path   text;
  v_name   text;
  v_ext    text;
  v_kind   text;
  v_mime   text;
  v_max    bigint;
  v_found  boolean;
  v_size   bigint;
  v_seen   text[] := '{}';
  v_result jsonb := '[]';
begin
  if p_items is null or p_items = 'null'::jsonb then
    return '[]'::jsonb;
  end if;
  if jsonb_typeof(p_items) <> 'array' then
    perform private.api_error(400, 'invalid_attachments', 'Lampiran tidak valid');
  end if;
  if jsonb_array_length(p_items) > 10 then
    perform private.api_error(400, 'too_many_attachments', 'Maksimal 10 lampiran per artikel');
  end if;
  for v_item in select e from jsonb_array_elements(p_items) with ordinality x(e, n) order by n loop
    if jsonb_typeof(v_item) <> 'object' then
      perform private.api_error(400, 'invalid_attachments', 'Lampiran tidak valid');
    end if;
    v_path := v_item ->> 'path';
    if v_path is null
       or v_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|png|webp|mp4|webm|mov)$' then
      perform private.api_error(400, 'invalid_attachments', 'Lampiran harus diunggah dari Hub');
    end if;
    if v_path = any(v_seen) then
      perform private.api_error(400, 'duplicate_attachment', 'Lampiran yang sama dipasang dua kali');
    end if;
    v_seen := v_seen || v_path;
    v_name := btrim(coalesce(v_item ->> 'name', ''));
    if char_length(v_name) not between 1 and 120 or v_name ~ '[[:cntrl:]]' then
      perform private.api_error(400, 'invalid_attachment_name', 'Nama lampiran 1–120 karakter');
    end if;
    v_ext := substring(v_path from '\.([a-z0-9]+)$');
    select k.kind, k.mime, k.max_bytes into v_kind, v_mime, v_max
      from (values ('pdf', 'document', 'application/pdf', 10485760::bigint),
                   ('jpg', 'image', 'image/jpeg', 5242880::bigint),
                   ('png', 'image', 'image/png', 5242880::bigint),
                   ('webp', 'image', 'image/webp', 5242880::bigint),
                   ('mp4', 'video', 'video/mp4', 26214400::bigint),
                   ('webm', 'video', 'video/webm', 26214400::bigint),
                   ('mov', 'video', 'video/quicktime', 26214400::bigint)) k(ext, kind, mime, max_bytes)
     where k.ext = v_ext;
    select true, coalesce((o.metadata ->> 'size')::bigint, 0) into v_found, v_size
      from storage.objects o where o.bucket_id = 'faq-files' and o.name = v_path;
    if v_found is not true then
      perform private.api_error(400, 'attachment_missing', 'File lampiran tidak ditemukan, unggah ulang');
    end if;
    if v_size > v_max then
      perform private.api_error(400, 'attachment_too_large',
        case v_kind when 'document' then 'PDF maksimal 10 MB'
                    when 'image' then 'Gambar maksimal 5 MB'
                    else 'Video maksimal 25 MB' end);
    end if;
    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'path', v_path, 'name', v_name, 'kind', v_kind, 'mime', v_mime, 'size', v_size));
    v_found := null;
  end loop;
  return v_result;
end;
$$;

create or replace function cs.faq_content(a cs.faq_articles)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('category_id', a.category_id, 'question_id', a.question_id, 'question_en', a.question_en,
                            'answer_id', a.answer_id, 'answer_en', a.answer_en, 'keywords', to_jsonb(a.keywords),
                            'topic_code', a.topic_code, 'sort_order', a.sort_order, 'attachments', a.attachments);
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
    'attachments', a.attachments,
    'updated_at', a.updated_at);
$$;

drop function cs_api.admin_faq_save_article(uuid, uuid, text, text, text, text, text[], text, integer, integer);

create function cs_api.admin_faq_save_article(
  p_id uuid, p_category_id uuid, p_question_id text, p_question_en text, p_answer_id text, p_answer_en text,
  p_keywords text[] default '{}', p_topic_code text default null, p_sort_order integer default 0,
  p_version integer default null, p_attachments jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me          uuid := cs.require_agent('{cs_super_admin,cs_content}');
  v_keywords    text[];
  v_attachments jsonb;
  v_old         cs.faq_articles;
  a             cs.faq_articles;
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
  if p_attachments is not null then
    v_attachments := cs.faq_clean_attachments(p_attachments);
  end if;

  if p_id is null then
    insert into cs.faq_articles (category_id, question_id, question_en, answer_id, answer_en, keywords, topic_code,
                                 sort_order, attachments, updated_by)
    values (p_category_id, btrim(p_question_id), btrim(p_question_en), btrim(p_answer_id), btrim(p_answer_en),
            v_keywords, p_topic_code, coalesce(p_sort_order, 0), coalesce(v_attachments, '[]'), v_me)
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
           topic_code = p_topic_code, sort_order = coalesce(p_sort_order, 0),
           attachments = coalesce(v_attachments, attachments), version = version + 1,
           updated_at = now(), updated_by = v_me
     where id = p_id
    returning * into a;
  end if;
  insert into cs.faq_article_versions (article_id, version, content, created_by)
  values (a.id, a.version, cs.faq_content(a), v_me);
  perform cs.audit('faq.article_save', null, null,
    jsonb_build_object('id', a.id, 'version', a.version, 'attachments', jsonb_array_length(a.attachments)));
  return cs.faq_admin_row(a);
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
         attachments = coalesce((
           select jsonb_agg(x.e order by x.n)
           from jsonb_array_elements(case when jsonb_typeof(v_content -> 'attachments') = 'array'
                                          then v_content -> 'attachments' else '[]'::jsonb end) with ordinality x(e, n)
           where exists (select 1 from storage.objects o where o.bucket_id = 'faq-files' and o.name = x.e ->> 'path')),
           '[]'),
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

revoke execute on function cs.faq_clean_attachments(jsonb) from public;
revoke execute on function cs.faq_content(cs.faq_articles) from public;
revoke execute on function cs.faq_customer_row(cs.faq_articles, text) from public;
revoke execute on function cs_api.admin_faq_save_article(uuid, uuid, text, text, text, text, text[], text, integer, integer, jsonb) from public;
revoke execute on function cs_api.admin_faq_restore(uuid, integer) from public;
grant execute on function cs_api.admin_faq_save_article(uuid, uuid, text, text, text, text, text[], text, integer, integer, jsonb) to authenticated;
grant execute on function cs_api.admin_faq_restore(uuid, integer) to authenticated;
