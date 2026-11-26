create table private.research_documents (
  id           uuid primary key default gen_random_uuid(),
  file_id      uuid not null references private.research_files (id) on delete cascade,
  source       text not null check (source in ('api', 'hub')),
  key_id       uuid references private.integration_keys (id),
  uploaded_by  uuid references cs.agents (user_id),
  object_name  text not null unique
               check (object_name ~ '^research/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx)$'),
  name         text check (char_length(name) between 1 and 120),
  mime         text not null,
  size_bytes   integer not null check (size_bytes between 1 and 20971520),
  sha256       text check (sha256 ~ '^[0-9a-f]{64}$'),
  status       text not null default 'queued' check (status in ('queued', 'processing', 'ready', 'rejected')),
  attempts     integer not null default 0,
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by    text check (char_length(locked_by) <= 100),
  error_code   text check (error_code ~ '^[a-z_]{1,40}$'),
  error_detail text check (char_length(error_detail) <= 500),
  created_at   timestamptz not null default now(),
  finished_at  timestamptz,
  constraint research_documents_origin check ((source = 'api') = (key_id is not null)
                                              and (source = 'hub') = (uploaded_by is not null)),
  constraint research_documents_api_sha check (source <> 'api' or sha256 is not null)
);
create index research_documents_file_idx on private.research_documents (file_id, created_at);
create index research_documents_queue_idx on private.research_documents (available_at, created_at)
  where status in ('queued', 'processing');
alter table private.research_documents enable row level security;

create policy olt_research_documents_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'post-files'
              and name ~ '^research/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx)$'
              and (select private.can_upload_research()));

create or replace function private.research_document_label(p_report uuid, p_object text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.entity_code || ' Laporan Keuangan '
         || case r.period when 'FY' then 'Tahunan' when 'Q1' then 'Kuartal I' when 'Q2' then 'Kuartal II'
                          else 'Kuartal III' end
         || ' ' || extract(year from r.period_end)::integer || '.' || substring(p_object from '\.([a-z]+)$')
  from private.research_reports r
  where r.id = p_report;
$$;

create or replace function private.research_document_items(p_report uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.item order by x.created_at, x.id), '[]')
  from (
    select u.created_at, u.id, u.item
    from (
      select distinct on (d.sha256) d.created_at, d.id,
             jsonb_build_object('type', 'file', 'file', jsonb_build_object(
               'bucket', 'post-files', 'path', d.object_name,
               'name', coalesce(d.name, private.research_document_label(p_report, d.object_name)),
               'mime', d.mime, 'size', d.size_bytes)) as item
      from private.research_documents d
      join private.research_files f on f.id = d.file_id
      where f.report_id = p_report and d.status = 'ready'
      order by d.sha256, d.created_at, d.id) u
    order by u.created_at, u.id
    limit 3) x;
$$;

create or replace function private.research_attachments(p_report uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.research_document_items(r.id)
         || case when private.card_document_valid(r.document)
                 then jsonb_build_array(jsonb_build_object('type', 'card', 'source', 'research', 'research_id', r.id,
                                                           'kind', r.kind, 'stock_code', r.entity_code,
                                                           'document', r.document))
                 else '[]'::jsonb end
  from private.research_reports r
  where r.id = p_report;
$$;

create or replace function private.research_merge_files(p_attachments jsonb, p_files jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_other jsonb;
  v_own   jsonb;
  v_card  jsonb;
  v_room  integer;
  v_add   jsonb;
begin
  select coalesce(jsonb_agg(e.value order by e.ordinality)
                    filter (where coalesce(e.value ->> 'type', '') not in ('card', 'file')), '[]'),
         coalesce(jsonb_agg(e.value order by e.ordinality)
                    filter (where e.value ->> 'type' = 'file'
                              and coalesce(e.value #>> '{file,path}', '') !~ '^research/'), '[]'),
         coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'card'), '[]')
    into v_other, v_own, v_card
  from jsonb_array_elements(case when jsonb_typeof(p_attachments) = 'array' then p_attachments else '[]' end)
       with ordinality e;
  v_room := greatest(0, 5 - jsonb_array_length(v_own));
  select coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.ordinality <= v_room), '[]')
    into v_add
  from jsonb_array_elements(coalesce(p_files, '[]')) with ordinality e;
  return v_other || v_own || v_add || v_card;
end;
$$;

create or replace function private.research_sync_post(p_report uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cp    uuid;
  c       cs.community_posts;
  v_files jsonb;
  v_new   jsonb;
  v_pub   jsonb;
begin
  select r.community_post_id into v_cp from private.research_reports r where r.id = p_report;
  if v_cp is null then
    return;
  end if;
  select * into c from cs.community_posts where id = v_cp for update;
  if not found or c.status not in ('draft', 'pending', 'scheduled', 'published') then
    return;
  end if;
  v_files := private.research_document_items(p_report);
  v_new := private.research_merge_files(c.attachments, v_files);
  if v_new is distinct from c.attachments then
    update cs.community_posts
       set attachments = v_new, updated_at = now(), version = version + 1
     where id = c.id;
  end if;
  if c.status = 'published' and c.post_id is not null then
    select p.attachments into v_pub from public.posts p where p.id = c.post_id and p.deleted_at is null for update;
    if found then
      v_new := private.research_merge_files(v_pub, v_files);
      if v_new is distinct from v_pub then
        perform cs.as_system(format('update public.posts set attachments = %L::jsonb where id = %L',
                                    v_new::text, c.post_id));
      end if;
    end if;
  end if;
end;
$$;

create or replace function private.research_document_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', d.id, 'status', d.status, 'source', d.source,
    'name', coalesce(d.name, private.research_document_label(f.report_id, d.object_name)),
    'path', d.object_name, 'mime', d.mime, 'size_bytes', d.size_bytes,
    'key', case when d.key_id is not null then (select jsonb_build_object('id', k.id, 'name', k.name, 'prefix', k.prefix)
                                                from private.integration_keys k where k.id = d.key_id) end,
    'uploaded_by', cs.staff_ref(d.uploaded_by), 'error_code', d.error_code, 'error_detail', d.error_detail,
    'received_at', d.created_at, 'finished_at', d.finished_at)
  from private.research_documents d
  join private.research_files f on f.id = d.file_id
  where d.id = p_id;
$$;

create or replace function private.research_document_external(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', d.id, 'status', d.status,
    'name', coalesce(d.name, private.research_document_label(f.report_id, d.object_name)),
    'mime', d.mime, 'size_bytes', d.size_bytes, 'sha256', d.sha256,
    'received_at', d.created_at, 'finished_at', d.finished_at,
    'error', case when d.status = 'rejected' then jsonb_build_object('code', d.error_code, 'detail', d.error_detail) end)
  from private.research_documents d
  join private.research_files f on f.id = d.file_id
  where d.id = p_id;
$$;

create or replace function private.research_document_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if v_name is not null and (char_length(v_name) > 120 or v_name ~ '[[:cntrl:]/\\]') then
    perform private.api_error(400, 'invalid_document_name', 'Nama dokumen maksimal 120 karakter tanpa garis miring');
  end if;
  return v_name;
end;
$$;

create or replace function private.research_document_insert(p_file uuid, p_key uuid, p_staff uuid, p_object text,
                                                             p_name text, p_sha256 text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name   text := btrim(coalesce(p_object, ''));
  v_mime   text;
  v_max    bigint;
  v_size   bigint;
  v_stored text;
  v_owner  text;
  v_id     uuid;
begin
  if v_name !~ '^research/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx)$' then
    perform private.api_error(400, 'invalid_object', 'Lokasi dokumen tidak valid');
  end if;
  select (o.metadata ->> 'size')::bigint, o.metadata ->> 'mimetype', o.owner_id
    into v_size, v_stored, v_owner
  from storage.objects o
  where o.bucket_id = 'post-files' and o.name = v_name;
  if not found or (p_staff is not null and v_owner is distinct from p_staff::text) then
    perform private.api_error(404, 'object_not_found', 'Dokumen belum terunggah ke storage');
  end if;
  if exists (select 1 from private.research_documents d where d.object_name = v_name) then
    perform private.api_error(409, 'already_submitted', 'Dokumen ini sudah diajukan');
  end if;
  select t.mime, t.max_bytes into v_mime, v_max
  from private.post_file_type(substring(v_name from '\.([a-z]+)$')) t;
  if coalesce(v_size, 0) not between 1 and v_max then
    perform private.api_error(400, 'file_too_large', 'Ukuran dokumen melebihi 20 MB');
  end if;
  if v_stored is distinct from v_mime then
    perform private.api_error(400, 'invalid_file_type', 'Jenis dokumen tidak sesuai dengan ekstensinya');
  end if;
  insert into private.research_documents (file_id, source, key_id, uploaded_by, object_name, name, mime, size_bytes,
                                          sha256)
  values (p_file, case when p_key is not null then 'api' else 'hub' end, p_key, p_staff, v_name, p_name, v_mime,
          v_size, p_sha256)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.research_document_submit(p_key_id uuid, p_file uuid, p_object text, p_sha256 text,
                                                           p_name text default null, p_ip text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k      private.integration_keys := private.integration_key_for(p_key_id, 'research', p_ip);
  v_cap  integer := private.setting_num('research.documents_per_hour', 120)::integer;
  v_sha  text := lower(btrim(coalesce(p_sha256, '')));
  v_name text;
  f      private.research_files;
  v_id   uuid;
  v_used integer;
begin
  perform private.integration_touch(k.id, p_ip, '{}');
  select * into f from private.research_files where id = p_file and key_id = k.id for update;
  if not found then
    perform private.api_error(404, 'file_not_found', 'File laporan tidak ditemukan untuk API key ini');
  end if;
  if f.status = 'rejected' then
    perform private.api_error(409, 'file_rejected', 'File laporan ini ditolak, jadi dokumennya tidak bisa dilampirkan');
  end if;
  if v_sha !~ '^[0-9a-f]{64}$' then
    perform private.api_error(400, 'invalid_sha256', 'Sidik SHA-256 dokumen tidak valid');
  end if;
  v_name := private.research_document_name(p_name);

  select d.id into v_id
  from private.research_documents d
  where d.file_id = f.id and d.sha256 = v_sha and d.status <> 'rejected'
  order by d.created_at
  limit 1;
  if found then
    return private.research_document_external(v_id) || jsonb_build_object('resubmitted', true);
  end if;

  if (select count(*) from private.research_documents d where d.file_id = f.id and d.status <> 'rejected') >= 3 then
    perform private.api_error(409, 'too_many_documents', 'Maksimal 3 dokumen per laporan');
  end if;
  select count(*) into v_used from private.research_documents d
   where d.key_id = k.id and d.created_at > now() - interval '1 hour';
  if v_used >= v_cap then
    perform private.api_error(429, 'rate_limited', format('Maksimal %s dokumen per jam untuk API key ini', v_cap));
  end if;

  v_id := private.research_document_insert(f.id, k.id, null, p_object, v_name, v_sha);
  return private.research_document_external(v_id) || jsonb_build_object('resubmitted', false);
end;
$$;

create or replace function public.research_document_claim(p_instance text, p_lease_seconds integer default 120)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := private.setting_num('research.max_attempts', 5)::integer;
  d     private.research_documents;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Instance worker tidak valid');
  end if;
  loop
    select * into d from private.research_documents
     where status in ('queued', 'processing') and available_at <= now()
       and (status = 'queued' or locked_until < now())
     order by available_at, created_at
     limit 1
     for update skip locked;
    if not found then
      return null;
    end if;
    if d.attempts >= v_max then
      update private.research_documents
         set status = 'rejected', error_code = 'too_many_attempts',
             error_detail = left(coalesce(error_detail, 'Worker stopped while processing this document'), 500),
             locked_until = null, locked_by = null, finished_at = now()
       where id = d.id;
      continue;
    end if;
    update private.research_documents
       set status = 'processing', attempts = attempts + 1, locked_by = p_instance,
           locked_until = now() + make_interval(secs => greatest(30, least(coalesce(p_lease_seconds, 120), 900)))
     where id = d.id
    returning * into d;
    return jsonb_build_object('id', d.id, 'object_name', d.object_name, 'mime', d.mime, 'sha256', d.sha256,
                              'size_bytes', d.size_bytes, 'attempts', d.attempts);
  end loop;
end;
$$;

create or replace function private.research_document_claimed(p_id uuid, p_instance text)
returns private.research_documents
language plpgsql
security definer
set search_path = ''
as $$
declare
  d private.research_documents;
begin
  select * into d from private.research_documents where id = p_id for update;
  if not found or d.status <> 'processing' or d.locked_by is distinct from p_instance then
    perform private.api_error(409, 'not_claimed', 'Dokumen ini tidak sedang diproses oleh worker ini');
  end if;
  return d;
end;
$$;

create or replace function public.research_document_done(p_id uuid, p_instance text, p_sha256 text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d        private.research_documents := private.research_document_claimed(p_id, p_instance);
  v_sha    text := lower(btrim(coalesce(p_sha256, '')));
  v_report uuid;
begin
  if v_sha !~ '^[0-9a-f]{64}$' or (d.sha256 is not null and d.sha256 <> v_sha) then
    perform private.api_error(400, 'checksum_mismatch', 'Sidik dokumen tidak sama dengan yang diterima');
  end if;
  update private.research_documents
     set status = 'ready', sha256 = v_sha, finished_at = now(), locked_until = null, locked_by = null,
         error_code = null, error_detail = null
   where id = d.id;
  select f.report_id into v_report from private.research_files f where f.id = d.file_id;
  if v_report is not null then
    perform private.research_sync_post(v_report);
  end if;
  return jsonb_build_object('status', 'ready');
end;
$$;

create or replace function public.research_document_fail(p_id uuid, p_instance text, p_code text, p_detail text,
                                                         p_retry boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d      private.research_documents := private.research_document_claimed(p_id, p_instance);
  v_max  integer := private.setting_num('research.max_attempts', 5)::integer;
  v_code text := case when coalesce(p_code, '') ~ '^[a-z_]{1,40}$' then p_code else 'internal' end;
  v_note text := left(nullif(btrim(coalesce(p_detail, '')), ''), 500);
begin
  if coalesce(p_retry, false) and d.attempts < v_max then
    update private.research_documents
       set status = 'queued', available_at = now() + make_interval(mins => d.attempts * d.attempts),
           locked_until = null, locked_by = null, error_code = v_code, error_detail = v_note
     where id = d.id;
    return jsonb_build_object('status', 'queued', 'retry_at', now() + make_interval(mins => d.attempts * d.attempts));
  end if;
  update private.research_documents
     set status = 'rejected', error_code = case when coalesce(p_retry, false) then 'too_many_attempts' else v_code end,
         error_detail = v_note, locked_until = null, locked_by = null, finished_at = now()
   where id = d.id;
  if v_code = 'infected' then
    insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
    values ('post-files', regexp_replace(d.object_name, '[^/]+$', ''), 'research_infected');
  end if;
  return jsonb_build_object('status', 'rejected');
end;
$$;

create or replace function cs_api.research_add_document(p_report uuid, p_object text, p_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.post}');
  r      private.research_reports;
  v_file uuid;
  v_name text := private.research_document_name(p_name);
  v_id   uuid;
begin
  select * into r from private.research_reports where id = p_report for update;
  if not found then
    perform private.api_error(404, 'report_not_found', 'Laporan tidak ditemukan');
  end if;
  if r.superseded_at is not null then
    perform private.api_error(409, 'superseded', 'Laporan ini sudah digantikan revisi yang lebih baru');
  end if;
  if (select count(*) from private.research_documents d join private.research_files f on f.id = d.file_id
      where f.report_id = r.id and d.status <> 'rejected') >= 3 then
    perform private.api_error(409, 'too_many_documents', 'Maksimal 3 dokumen per laporan');
  end if;
  select f.id into v_file
  from private.research_files f
  where f.report_id = r.id
  order by f.status = 'done' desc, f.created_at desc
  limit 1;
  v_id := private.research_document_insert(v_file, null, v_me, p_object, v_name, null);
  perform cs.audit('research.document_add', null, null,
                   jsonb_build_object('report', r.id, 'document', v_id, 'name', v_name));
  return cs_api.research_report(r.id);
end;
$$;

create or replace function cs_api.research_remove_document(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.post}');
  d        private.research_documents;
  v_report uuid;
begin
  select * into d from private.research_documents where id = p_id for update;
  if not found then
    perform private.api_error(404, 'document_not_found', 'Dokumen tidak ditemukan');
  end if;
  select f.report_id into v_report from private.research_files f where f.id = d.file_id;
  delete from private.research_documents where id = d.id;
  if v_report is not null then
    perform private.research_sync_post(v_report);
  end if;
  perform cs.audit('research.document_remove', null, null,
                   jsonb_build_object('report', v_report, 'document', d.id, 'status', d.status));
  return case when v_report is not null then cs_api.research_report(v_report) end;
end;
$$;

create or replace function private.post_files_clean(p_account uuid, p_items jsonb)
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
  v_mime   text;
  v_max    bigint;
  v_size   bigint;
  v_stored text;
  v_seen   text[] := '{}';
  v_result jsonb := '[]';
begin
  if jsonb_array_length(p_items) > 5 then
    perform private.api_error(400, 'too_many_files', 'Maksimal 5 dokumen per postingan');
  end if;
  for v_item in select e.value from jsonb_array_elements(p_items) with ordinality e order by e.ordinality loop
    v_path := v_item #>> '{file,path}';
    if v_path is null
       or not (v_path ~ ('^' || p_account::text
                         || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx|csv|docx|pptx)$')
               or (v_path ~ '^research/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx)$'
                   and exists (select 1 from private.research_documents d
                               where d.object_name = v_path and d.status = 'ready'))) then
      perform private.api_error(400, 'invalid_file', 'Dokumen harus diunggah dari Hub untuk akun resmi ini');
    end if;
    if v_path = any (v_seen) then
      perform private.api_error(400, 'duplicate_file', 'Dokumen yang sama dipasang dua kali');
    end if;
    v_seen := v_seen || v_path;
    v_name := btrim(coalesce(v_item #>> '{file,name}', ''));
    if char_length(v_name) not between 1 and 120 or v_name ~ '[[:cntrl:]/\\]' then
      perform private.api_error(400, 'invalid_file_name', 'Nama dokumen 1–120 karakter tanpa garis miring');
    end if;
    v_ext := substring(v_path from '\.([a-z]+)$');
    select t.mime, t.max_bytes into v_mime, v_max from private.post_file_type(v_ext) t;
    select (o.metadata ->> 'size')::bigint, o.metadata ->> 'mimetype' into v_size, v_stored
    from storage.objects o
    where o.bucket_id = 'post-files' and o.name = v_path;
    if not found then
      perform private.api_error(404, 'file_not_found', 'Dokumen belum terunggah');
    end if;
    if coalesce(v_size, 0) not between 1 and v_max then
      perform private.api_error(400, 'file_too_large', 'Ukuran dokumen melebihi batas');
    end if;
    if v_stored is distinct from v_mime then
      perform private.api_error(400, 'invalid_file_type', 'Jenis dokumen tidak sesuai dengan ekstensinya');
    end if;
    v_result := v_result || jsonb_build_array(jsonb_build_object('type', 'file', 'file', jsonb_build_object(
      'bucket', 'post-files', 'path', v_path, 'name', v_name, 'mime', v_mime, 'size', v_size)));
  end loop;
  return v_result;
end;
$$;

create or replace function private.posts_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_media jsonb := new.attachments;
  v_card  jsonb := '[]';
  v_files jsonb := '[]';
begin
  if new.deleted_at is null then
    new.body := regexp_replace(new.body, '^\s+|\s+$', '', 'g');
    if jsonb_typeof(new.attachments) = 'array' then
      select coalesce(jsonb_agg(e.value order by e.ordinality)
                        filter (where coalesce(e.value ->> 'type', '') not in ('card', 'file')), '[]'),
             coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'card'), '[]'),
             coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'file'), '[]')
        into v_media, v_card, v_files
      from jsonb_array_elements(new.attachments) with ordinality e;
    end if;
    perform private.validate_attachments(v_media, 'posts/' || new.author_id || '/');
    if (jsonb_array_length(v_card) > 0 or jsonb_array_length(v_files) > 0)
       and (tg_op = 'INSERT' or new.attachments is distinct from old.attachments) then
      if private.is_end_user() then
        perform private.api_error(400, 'invalid_attachments', 'Kartu dan dokumen hanya bisa dibuat staf atau layanan riset');
      end if;
      if jsonb_array_length(v_card) > 1
         or (jsonb_array_length(v_card) = 1 and not private.card_document_valid(v_card -> 0 -> 'document')) then
        perform private.api_error(400, 'invalid_attachments', 'Kartu tidak valid');
      end if;
      if jsonb_array_length(v_files) > 5
         or exists (select 1 from jsonb_array_elements(v_files) f
                    where coalesce(f.value #>> '{file,bucket}', '') <> 'post-files'
                       or coalesce(f.value #>> '{file,path}', '') !~ ('^(' || new.author_id::text || '|research)/')) then
        perform private.api_error(400, 'invalid_attachments', 'Dokumen tidak valid');
      end if;
    end if;
  end if;
  if tg_op = 'UPDATE' then
    new.updated_at := now();
    if new.deleted_at is null and new.body is distinct from old.body then
      new.edited_at := now();
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.post_files_maintenance()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name  text;
  v_count integer := 0;
begin
  for v_name in
    select o.name
    from storage.objects o
    where o.bucket_id = 'post-files' and o.created_at < now() - interval '1 day'
      and not exists (select 1 from cs.community_posts c
                      where c.attachments @> jsonb_build_array(jsonb_build_object('type', 'file',
                                                                 'file', jsonb_build_object('path', o.name))))
      and not exists (select 1 from private.research_documents d
                      where d.object_name = o.name and d.status <> 'rejected')
      and not exists (select 1 from private.storage_cleanup_queue q
                      where q.bucket_id = 'post-files' and q.done_at is null
                        and q.prefix = regexp_replace(o.name, '[^/]+$', ''))
    order by o.created_at
    limit 500
  loop
    insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
    values ('post-files', regexp_replace(v_name, '[^/]+$', ''), 'post_file_unused');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function private.research_file_external(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'api_version', 1, 'id', f.id, 'status', f.status, 'sha256', f.sha256, 'size_bytes', f.size_bytes,
    'received_at', f.created_at, 'finished_at', f.finished_at,
    'retry_at', case when f.status = 'queued' and f.attempts > 0 then f.available_at end,
    'error', case when f.error_code is not null and f.status = 'rejected'
                  then jsonb_build_object('code', f.error_code, 'detail', f.error_detail) end,
    'report', private.research_report_ref(f.report_id),
    'documents', coalesce((select jsonb_agg(private.research_document_external(d.id) order by d.created_at, d.id)
                           from private.research_documents d where d.file_id = f.id), '[]'))
  from private.research_files f
  where f.id = p_id;
$$;

create or replace function public.research_complete(p_file uuid, p_instance text, p_report jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  f        private.research_files := private.research_claimed(p_file, p_instance);
  v_sha    text := p_report ->> 'sha256';
  v_code   text := private.research_text(p_report -> 'entity_code', 12);
  v_name   text := private.research_text(p_report -> 'entity_name', 200);
  v_kind   text := p_report ->> 'kind';
  v_doc    jsonb := coalesce(p_report -> 'document', '{}');
  v_start  date := private.research_date(p_report -> 'period_start');
  v_end    date := private.research_date(p_report -> 'period_end');
  v_author uuid;
  v_old    private.research_reports;
  r        private.research_reports;
  v_warn   jsonb := coalesce(p_report -> 'warnings', '[]');
begin
  if coalesce(v_sha, '') !~ '^[0-9a-f]{64}$' or (f.sha256 is not null and f.sha256 <> v_sha) then
    perform private.api_error(400, 'checksum_mismatch', 'Sidik file tidak sama dengan yang diterima');
  end if;

  select * into r from private.research_reports where sha256 = v_sha;
  if found then
    update private.research_files
       set status = 'duplicate', sha256 = v_sha, report_id = r.id, finished_at = now(), locked_until = null,
           locked_by = null, error_code = null, error_detail = null
     where id = f.id;
    perform private.research_sync_post(r.id);
    return jsonb_build_object('status', 'duplicate', 'report_id', r.id);
  end if;

  if coalesce(v_kind, '') not in ('financial_report') or not private.card_document_valid(v_doc)
     or coalesce(v_code, '') !~ '^[A-Z][A-Z0-9]{1,11}$' or v_name is null or v_start is null or v_end is null
     or v_end <= v_start or coalesce(p_report ->> 'period', '') not in ('Q1', 'Q2', 'Q3', 'FY')
     or coalesce(p_report ->> 'audit', '') not in ('audited', 'unaudited', 'unknown')
     or coalesce(p_report ->> 'currency', '') !~ '^[A-Z]{3}$'
     or coalesce(p_report ->> 'template', '') not in ('bank', 'general', 'basic')
     or jsonb_typeof(p_report -> 'facts') is distinct from 'object' or pg_column_size(p_report -> 'facts') > 1048576
     or jsonb_typeof(p_report -> 'metrics') is distinct from 'object' or pg_column_size(p_report -> 'metrics') > 262144
     or private.research_text(p_report -> 'summary', 2000) is null
     or jsonb_typeof(v_warn) is distinct from 'array' or jsonb_array_length(v_warn) > 50 then
    perform private.api_error(400, 'invalid_report', 'Data laporan dari worker tidak lengkap atau tidak valid');
  end if;

  select * into v_old from private.research_reports
   where kind = v_kind and entity_code = v_code and period_start = v_start and period_end = v_end
     and superseded_at is null
   for update;
  if found then
    update private.research_reports set superseded_at = now() where id = v_old.id;
    update cs.community_posts
       set status = 'cancelled', updated_at = now(), version = version + 1
     where id = v_old.community_post_id and status in ('draft', 'pending', 'scheduled');
    v_warn := v_warn || jsonb_build_array(jsonb_build_object('code', 'revision', 'supersedes', v_old.id,
                                                             'received_at', v_old.created_at));
  end if;

  insert into private.research_reports (sha256, kind, entity_code, entity_name, sector, subsector, period,
                                        period_start, period_end, audit, currency, template, facts, metrics, document,
                                        summary, warnings, supersedes)
  values (v_sha, v_kind, v_code, v_name, private.research_text(p_report -> 'sector', 120),
          private.research_text(p_report -> 'subsector', 120), p_report ->> 'period', v_start, v_end,
          p_report ->> 'audit', p_report ->> 'currency', p_report ->> 'template', p_report -> 'facts',
          p_report -> 'metrics', v_doc, private.research_text(p_report -> 'summary', 2000), v_warn, v_old.id)
  returning * into r;

  update private.research_files
     set status = 'done', sha256 = v_sha, report_id = r.id, finished_at = now(), locked_until = null, locked_by = null,
         error_code = null, error_detail = null
   where id = f.id;

  if f.source = 'api' then
    select k.created_by into v_author from private.integration_keys k where k.id = f.key_id;
  else
    v_author := f.uploaded_by;
  end if;
  perform private.research_make_post(r.id, v_author);
  perform cs.audit('research.report_ingest', null, null,
                   jsonb_build_object('report', r.id, 'kind', r.kind, 'file', f.id, 'entity', r.entity_code,
                                      'period', r.period,
                                      'period_end', r.period_end, 'source', f.source));
  return jsonb_build_object('status', 'done', 'report', private.research_report_ref(r.id));
end;
$$;

create or replace function cs.research_config_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'official_account', case when c.official_account_id is not null
                             then cs.community_account_ref(c.official_account_id) end,
    'official_active', c.official_account_id is not null and cs.official_active(c.official_account_id),
    'auto_publish', c.auto_publish, 'updated_by', cs.staff_ref(c.updated_by), 'updated_at', c.updated_at,
    'max_file_bytes', 8388608, 'max_document_bytes', 20971520, 'max_documents', 3)
  from private.research_config c
  where c.singleton;
$$;

create or replace function cs_api.research_report(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_community(cs.community_permission_codes());
  r    private.research_reports;
begin
  select * into r from private.research_reports where id = p_id;
  if not found then
    perform private.api_error(404, 'report_not_found', 'Laporan tidak ditemukan');
  end if;
  return private.research_report_ref(r.id) || jsonb_build_object(
    'sector', r.sector, 'subsector', r.subsector, 'metrics', r.metrics, 'document', r.document,
    'summary', r.summary,
    'warnings', r.warnings, 'created_at', r.created_at, 'superseded_at', r.superseded_at,
    'supersedes', private.research_report_ref(r.supersedes),
    'superseded_by', (select private.research_report_ref(n.id) from private.research_reports n where n.supersedes = r.id),
    'post', case when r.community_post_id is not null then cs.community_post_view(r.community_post_id) end,
    'can_create_post', r.superseded_at is null
      and (r.community_post_id is null
           or (select c.status in ('rejected', 'cancelled', 'failed') from cs.community_posts c
               where c.id = r.community_post_id)),
    'files', coalesce((select jsonb_agg(cs.research_file_view(f.id) order by f.created_at)
                       from private.research_files f where f.report_id = r.id), '[]'),
    'documents', coalesce((select jsonb_agg(private.research_document_view(d.id) order by d.created_at, d.id)
                           from private.research_documents d join private.research_files f on f.id = d.file_id
                           where f.report_id = r.id), '[]'),
    'history', coalesce((select jsonb_agg(private.research_report_ref(h.id) order by h.period_end desc)
                         from (select x.id, x.period_end from private.research_reports x
                               where x.entity_code = r.entity_code and x.superseded_at is null and x.id <> r.id
                               order by x.period_end desc limit 12) h), '[]'));
end;
$$;

revoke execute on function private.research_document_label(uuid, text) from public;
revoke execute on function private.research_document_items(uuid) from public;
revoke execute on function private.research_merge_files(jsonb, jsonb) from public;
revoke execute on function private.research_sync_post(uuid) from public;
revoke execute on function private.research_document_view(uuid) from public;
revoke execute on function private.research_document_external(uuid) from public;
revoke execute on function private.research_document_name(text) from public;
revoke execute on function private.research_document_insert(uuid, uuid, uuid, text, text, text) from public;
revoke execute on function private.research_document_claimed(uuid, text) from public;
revoke execute on function public.research_document_submit(uuid, uuid, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.research_document_claim(text, integer) from public, anon, authenticated;
revoke execute on function public.research_document_done(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.research_document_fail(uuid, text, text, text, boolean) from public, anon, authenticated;
revoke execute on function cs_api.research_add_document(uuid, text, text) from public;
revoke execute on function cs_api.research_remove_document(uuid) from public;

grant execute on function public.research_document_submit(uuid, uuid, text, text, text, text) to service_role;
grant execute on function public.research_document_claim(text, integer) to service_role;
grant execute on function public.research_document_done(uuid, text, text) to service_role;
grant execute on function public.research_document_fail(uuid, text, text, text, boolean) to service_role;
grant execute on function cs_api.research_add_document(uuid, text, text) to authenticated;
grant execute on function cs_api.research_remove_document(uuid) to authenticated;
