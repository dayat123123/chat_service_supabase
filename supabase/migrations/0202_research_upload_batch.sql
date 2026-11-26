drop function cs_api.research_upload(text);

create or replace function public.research_claim(p_instance text, p_lease_seconds integer default 120)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := private.setting_num('research.max_attempts', 5)::integer;
  f     private.research_files;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Instance worker tidak valid');
  end if;
  loop
    select * into f from private.research_files
     where status in ('queued', 'processing') and available_at <= now()
       and (status = 'queued' or locked_until < now())
       and not exists (select 1 from private.research_documents d
                       where d.file_id = research_files.id and d.status in ('queued', 'processing'))
     order by available_at, created_at
     limit 1
     for update skip locked;
    if not found then
      return null;
    end if;
    if f.attempts >= v_max then
      update private.research_files
         set status = 'rejected', error_code = 'too_many_attempts',
             error_detail = left(coalesce(error_detail, 'Worker stopped while processing this file'), 500),
             locked_until = null, locked_by = null, finished_at = now()
       where id = f.id;
      continue;
    end if;
    update private.research_files
       set status = 'processing', attempts = attempts + 1, locked_by = p_instance,
           locked_until = now() + make_interval(secs => greatest(30, least(coalesce(p_lease_seconds, 120), 900)))
     where id = f.id
    returning * into f;
    return jsonb_build_object('id', f.id, 'object_name', f.object_name, 'sha256', f.sha256,
                              'size_bytes', f.size_bytes, 'attempts', f.attempts);
  end loop;
end;
$$;

create or replace function cs_api.research_upload(p_object text, p_documents jsonb default '[]')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_community('{community.post}');
  v_name text := btrim(coalesce(p_object, ''));
  v_size bigint;
  v_id   uuid;
  v_docs jsonb := coalesce(p_documents, '[]');
  v_doc  jsonb;
begin
  if jsonb_typeof(v_docs) <> 'array' then
    perform private.api_error(400, 'invalid_object', 'Daftar dokumen tidak valid');
  end if;
  if jsonb_array_length(v_docs) > 3 then
    perform private.api_error(409, 'too_many_documents', 'Maksimal 3 dokumen per laporan');
  end if;
  if v_name !~ '^hub/[0-9a-f-]{36}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/report\.zip$'
     or split_part(v_name, '/', 2) <> v_me::text then
    perform private.api_error(400, 'invalid_object', 'Lokasi file unggahan tidak valid');
  end if;
  select (o.metadata ->> 'size')::bigint into v_size
  from storage.objects o
  where o.bucket_id = 'financial-reports' and o.name = v_name and o.owner_id = v_me::text;
  if not found then
    perform private.api_error(404, 'object_not_found', 'File belum terunggah ke storage');
  end if;
  if exists (select 1 from private.research_files f where f.object_name = v_name) then
    perform private.api_error(409, 'already_submitted', 'File ini sudah diajukan');
  end if;
  insert into private.research_files (source, uploaded_by, object_name, size_bytes)
  values ('hub', v_me, v_name, case when v_size between 1 and 8388608 then v_size::integer end)
  returning id into v_id;
  for v_doc in select e.value from jsonb_array_elements(v_docs) with ordinality e order by e.ordinality loop
    if jsonb_typeof(v_doc) <> 'object' then
      perform private.api_error(400, 'invalid_object', 'Lokasi dokumen tidak valid');
    end if;
    perform private.research_document_insert(v_id, null, v_me, v_doc ->> 'object',
                                             private.research_document_name(v_doc ->> 'name'), null);
  end loop;
  perform cs.audit('research.upload', null, null,
                   jsonb_build_object('file', v_id, 'size', v_size, 'documents', jsonb_array_length(v_docs)));
  return cs.research_file_view(v_id);
end;
$$;

revoke execute on function cs_api.research_upload(text, jsonb) from public;
grant execute on function cs_api.research_upload(text, jsonb) to authenticated;
