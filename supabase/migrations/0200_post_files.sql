insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-files', 'post-files', false, 20971520,
        array['application/pdf',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'text/csv',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'application/vnd.openxmlformats-officedocument.presentationml.presentation'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy olt_post_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'post-files'
              and name ~ '^[0-9a-f-]{36}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx|csv|docx|pptx)$'
              and cs.can_upload_official(split_part(name, '/', 1), 'community.post'));

create policy olt_post_files_read on storage.objects for select to authenticated
  using (bucket_id = 'post-files');

create or replace function private.post_file_type(p_ext text)
returns table (mime text, max_bytes bigint)
language sql
immutable
set search_path = ''
as $$
  select t.mime, t.max_bytes
  from (values ('pdf', 'application/pdf', 20971520::bigint),
               ('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 20971520::bigint),
               ('csv', 'text/csv', 10485760::bigint),
               ('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 20971520::bigint),
               ('pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation', 20971520::bigint))
       as t (ext, mime, max_bytes)
  where t.ext = p_ext;
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
       or v_path !~ ('^' || p_account::text
                     || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/file\.(pdf|xlsx|csv|docx|pptx)$') then
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
                       or coalesce(f.value #>> '{file,path}', '') !~ ('^' || new.author_id::text || '/')) then
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

create or replace function cs_api.community_save_post(
  p_id          uuid,
  p_account_id  uuid,
  p_kind        text,
  p_title       text,
  p_body        text,
  p_attachments jsonb default '[]',
  p_pin_scope   text default null,
  p_pin_stock   text default null,
  p_pin_until   timestamptz default null,
  p_notify      boolean default false,
  p_publish_at  timestamptz default null,
  p_version     integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_community('{community.post}');
  v_kind   text := coalesce(p_kind, 'post');
  v_title  text := nullif(btrim(coalesce(p_title, '')), '');
  v_body   text := btrim(coalesce(p_body, ''));
  v_scope  text := nullif(btrim(coalesce(p_pin_scope, '')), '');
  v_stock  text := private.stock_code(nullif(btrim(coalesce(p_pin_stock, '')), ''));
  v_media  jsonb := coalesce(p_attachments, '[]');
  v_card   jsonb := private.manual_card(p_attachments);
  v_files  jsonb := '[]';
  v_at     timestamptz := case when p_publish_at > now() then p_publish_at end;
  c        cs.community_posts;
begin
  if not cs.official_active(p_account_id) then
    perform private.api_error(400, 'official_inactive', 'Pilih akun resmi yang aktif');
  end if;
  if v_kind not in ('post', 'announcement') then
    perform private.api_error(400, 'invalid_kind', 'Jenis harus postingan atau pengumuman');
  end if;
  if v_kind = 'announcement' then
    if char_length(coalesce(v_title, '')) not between 3 and 80 then
      perform private.api_error(400, 'invalid_title', 'Judul pengumuman 3–80 karakter');
    end if;
    v_scope := coalesce(v_scope, 'global');
  else
    v_title := null;
  end if;
  if jsonb_typeof(v_media) = 'array' then
    select coalesce(jsonb_agg(e.value order by e.ordinality)
                      filter (where coalesce(e.value ->> 'type', '') not in ('card', 'file')), '[]'),
           coalesce(jsonb_agg(e.value order by e.ordinality) filter (where e.value ->> 'type' = 'file'), '[]')
      into v_media, v_files
    from jsonb_array_elements(v_media) with ordinality e;
  end if;
  v_files := private.post_files_clean(p_account_id, v_files);
  if v_card is not null then
    v_body := btrim(private.card_text(v_card -> 'document', v_card ->> 'stock_code'));
  end if;
  if char_length(v_body) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Isi postingan 1–2000 karakter');
  end if;
  perform private.validate_text(v_body, 'post');
  perform private.apply_content_policy(v_body);
  perform private.validate_attachments(v_media, 'posts/' || p_account_id || '/');
  v_media := v_media || v_files;
  if v_card is not null then
    v_media := v_media || jsonb_build_array(v_card);
  end if;
  if v_scope is not null and v_scope not in ('global', 'stock') then
    perform private.api_error(400, 'invalid_pin', 'Sematkan di stream umum atau stream saham');
  end if;
  if v_scope = 'stock' and v_stock is null then
    perform private.api_error(400, 'invalid_stock', 'Kode saham atau indeks tidak valid');
  end if;
  if v_scope is distinct from 'stock' then
    v_stock := null;
  end if;
  if v_scope is null and p_pin_until is not null then
    perform private.api_error(400, 'invalid_pin', 'Batas sematan hanya untuk postingan yang disematkan');
  end if;
  if p_pin_until is not null and p_pin_until <= coalesce(v_at, now()) then
    perform private.api_error(400, 'invalid_pin_until', 'Batas sematan harus setelah waktu terbit');
  end if;

  if p_id is null then
    insert into cs.community_posts (account_id, kind, title, body, attachments, pin_scope, pin_stock, pin_until,
                                    notify, publish_at, created_by)
    values (p_account_id, v_kind, v_title, v_body, v_media, v_scope, v_stock, p_pin_until,
            coalesce(p_notify, false), v_at, v_me)
    returning * into c;
  else
    select * into c from cs.community_posts where id = p_id for update;
    if not found then
      perform private.api_error(404, 'post_not_found', 'Postingan tidak ditemukan');
    end if;
    if c.created_by <> v_me then
      perform private.api_error(403, 'not_post_owner', 'Hanya pembuat yang bisa mengubah draf ini');
    end if;
    if c.status not in ('draft', 'rejected', 'failed') then
      perform private.api_error(409, 'invalid_status', 'Postingan ini tidak bisa diubah lagi');
    end if;
    perform cs.check_version(c.version, p_version);
    update cs.community_posts
       set account_id = p_account_id, kind = v_kind, title = v_title, body = v_body, attachments = v_media,
           pin_scope = v_scope, pin_stock = v_stock, pin_until = p_pin_until, notify = coalesce(p_notify, false),
           publish_at = v_at, status = 'draft', error = null, updated_at = now(), version = version + 1
     where id = c.id
    returning * into c;
  end if;
  perform cs.audit('community.post_save', null, null,
                   jsonb_build_object('post', c.id, 'kind', c.kind, 'card', v_card is not null,
                                      'files', jsonb_array_length(v_files)));
  return cs.community_post_view(c.id);
end;
$$;

select cron.schedule('post-files-maintenance', '37 18 * * *', 'select private.post_files_maintenance()');

revoke execute on function private.post_file_type(text) from public;
revoke execute on function private.post_files_clean(uuid, jsonb) from public;
revoke execute on function private.post_files_maintenance() from public;
