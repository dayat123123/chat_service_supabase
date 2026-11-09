update storage.buckets
   set allowed_mime_types = array['application/pdf',
                                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                                  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
                                  'text/plain', 'text/csv'],
       file_size_limit = 10485760
 where id = 'cs-documents';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cs-videos', 'cs-videos', false, 26214400, array['video/mp4', 'video/quicktime', 'video/webm', 'image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy olt_cs_videos_read on storage.objects for select to authenticated
  using (bucket_id = 'cs-videos' and (storage.foldername(name))[1] = 'rooms'
         and (cs.is_support_owner_text((storage.foldername(name))[2])
              or cs.can_read_room_text((storage.foldername(name))[2])));

create policy olt_cs_videos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-videos' and (storage.foldername(name))[1] = 'rooms'
              and (storage.foldername(name))[3] = (select auth.uid())::text
              and cs.can_upload_support_document((storage.foldername(name))[2])
              and (select private.upload_verified()));

insert into cs.cs_settings (key, value, description)
values ('attachments.cs',
        '{"documents": {"enabled": true, "max_mb": 10, "formats": ["pdf", "docx", "xlsx", "pptx", "txt", "csv"]},
          "images": {"enabled": true, "max_mb": 5, "formats": ["jpeg", "png", "webp", "gif"]},
          "videos": {"enabled": true, "max_mb": 25, "max_seconds": 120, "formats": ["mp4", "mov", "webm"]}}'::jsonb,
        'Format dan batas lampiran chat CS per jenis (dokumen, gambar, video); diatur Super Admin dari Hub')
on conflict (key) do nothing;

create or replace function cs.attachment_catalog()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select '{
    "documents": {"bucket": "cs-documents", "ceiling_mb": 10, "formats": {
      "pdf": {"mime": "application/pdf", "ext": "pdf"},
      "docx": {"mime": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "ext": "docx"},
      "xlsx": {"mime": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "ext": "xlsx"},
      "pptx": {"mime": "application/vnd.openxmlformats-officedocument.presentationml.presentation", "ext": "pptx"},
      "txt": {"mime": "text/plain", "ext": "txt"},
      "csv": {"mime": "text/csv", "ext": "csv"}}},
    "images": {"bucket": "attachments", "ceiling_mb": 5, "formats": {
      "jpeg": {"mime": "image/jpeg", "ext": "jpg"},
      "png": {"mime": "image/png", "ext": "png"},
      "webp": {"mime": "image/webp", "ext": "webp"},
      "gif": {"mime": "image/gif", "ext": "gif"}}},
    "videos": {"bucket": "cs-videos", "ceiling_mb": 25, "ceiling_seconds": 120, "formats": {
      "mp4": {"mime": "video/mp4", "ext": "mp4"},
      "mov": {"mime": "video/quicktime", "ext": "mov"},
      "webm": {"mime": "video/webm", "ext": "webm"}}}
  }'::jsonb;
$$;

create or replace function cs.attachment_policy_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_object_agg(k.kind, jsonb_strip_nulls(jsonb_build_object(
           'enabled', coalesce((s.value -> k.kind ->> 'enabled')::boolean, false),
           'bucket', k.spec ->> 'bucket',
           'max_bytes', least(coalesce((s.value -> k.kind ->> 'max_mb')::integer, 0), (k.spec ->> 'ceiling_mb')::integer)
                        * 1048576,
           'max_seconds', case when k.kind = 'videos'
                               then least(coalesce((s.value -> k.kind ->> 'max_seconds')::integer, 0),
                                          (k.spec ->> 'ceiling_seconds')::integer) end,
           'formats', coalesce((select jsonb_agg(jsonb_build_object('code', f.code, 'mime', k.spec -> 'formats' -> f.code ->> 'mime',
                                                                    'ext', k.spec -> 'formats' -> f.code ->> 'ext')
                                                 order by f.ord)
                                from jsonb_array_elements_text(s.value -> k.kind -> 'formats') with ordinality as f(code, ord)
                                where k.spec -> 'formats' ? f.code), '[]'))))
  from jsonb_each(cs.attachment_catalog()) as k(kind, spec)
  left join cs.cs_settings s on s.key = 'attachments.cs';
$$;

create or replace function cs_api.attachment_policy()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or (cs.current_customer_id() is null and cs.current_agent_id() is null) then
    perform private.api_error(403, 'forbidden', 'Hanya untuk pengguna yang sudah masuk');
  end if;
  return cs.attachment_policy_view();
end;
$$;

create or replace function public.media_attachment_policy()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.attachment_policy_view();
$$;

create or replace function cs_api.admin_attachment_policy()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return jsonb_build_object(
    'policy', coalesce(cs.setting('attachments.cs'), '{}'::jsonb),
    'catalog', cs.attachment_catalog(),
    'updated_at', (select s.updated_at from cs.cs_settings s where s.key = 'attachments.cs'),
    'updated_by', (select g.display_name from cs.cs_settings s join cs.agents g on g.user_id = s.updated_by
                   where s.key = 'attachments.cs'));
end;
$$;

create or replace function cs_api.admin_set_attachment_policy(p_policy jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_super_admin}');
  v_catalog jsonb := cs.attachment_catalog();
  v_old     jsonb := cs.setting('attachments.cs');
  v_value   jsonb := '{}'::jsonb;
  v_kind    text;
  v_spec    jsonb;
  v_item    jsonb;
  v_formats jsonb;
  v_mb      integer;
  v_seconds integer;
begin
  if jsonb_typeof(p_policy) is distinct from 'object'
     or exists (select 1 from jsonb_object_keys(p_policy) k where not v_catalog ? k) then
    perform private.api_error(400, 'invalid_attachment_policy', 'Kebijakan harus berisi documents, images, dan videos');
  end if;
  for v_kind, v_spec in select * from jsonb_each(v_catalog) loop
    v_item := p_policy -> v_kind;
    if jsonb_typeof(v_item) is distinct from 'object' or jsonb_typeof(v_item -> 'enabled') is distinct from 'boolean'
       or jsonb_typeof(v_item -> 'formats') is distinct from 'array'
       or jsonb_typeof(v_item -> 'max_mb') is distinct from 'number' then
      perform private.api_error(400, 'invalid_attachment_policy', 'Setiap jenis butuh enabled, max_mb, dan formats');
    end if;
    v_mb := (v_item ->> 'max_mb')::numeric::integer;
    if (v_item ->> 'max_mb')::numeric <> v_mb or v_mb not between 1 and (v_spec ->> 'ceiling_mb')::integer then
      perform private.api_error(400, 'invalid_attachment_policy',
        format('Batas ukuran %s 1–%s MB', v_kind, v_spec ->> 'ceiling_mb'));
    end if;
    select coalesce(jsonb_agg(f order by o), '[]') into v_formats
      from (select f, min(o) as o
            from jsonb_array_elements_text(v_item -> 'formats') with ordinality as x(f, o)
            group by f) y;
    if exists (select 1 from jsonb_array_elements_text(v_formats) f where not v_spec -> 'formats' ? f) then
      perform private.api_error(400, 'invalid_attachment_policy', format('Format %s tidak dikenal', v_kind));
    end if;
    if (v_item ->> 'enabled')::boolean and jsonb_array_length(v_formats) = 0 then
      perform private.api_error(400, 'invalid_attachment_policy', format('Pilih minimal satu format %s', v_kind));
    end if;
    v_value := v_value || jsonb_build_object(v_kind, jsonb_build_object(
      'enabled', (v_item ->> 'enabled')::boolean, 'max_mb', v_mb, 'formats', v_formats));
    if v_kind = 'videos' then
      if jsonb_typeof(v_item -> 'max_seconds') is distinct from 'number' then
        perform private.api_error(400, 'invalid_attachment_policy', 'Video butuh max_seconds');
      end if;
      v_seconds := (v_item ->> 'max_seconds')::numeric::integer;
      if v_seconds not between 5 and (v_spec ->> 'ceiling_seconds')::integer then
        perform private.api_error(400, 'invalid_attachment_policy',
          format('Durasi video 5–%s detik', v_spec ->> 'ceiling_seconds'));
      end if;
      v_value := jsonb_set(v_value, '{videos,max_seconds}', to_jsonb(v_seconds));
    end if;
  end loop;
  perform cs.set_setting('attachments.cs', v_value, v_me);
  perform cs.audit('attachments.policy', null, null, jsonb_build_object('before', v_old, 'after', v_value));
  return cs_api.admin_attachment_policy();
end;
$$;

create or replace function private.check_message_media(p_attachments jsonb, p_room_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_support boolean := exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support');
  v_policy  jsonb := case when v_support then cs.attachment_policy_view() end;
  v_item    jsonb;
  v_bucket  text;
  v_mime    text;
  v_kind    text;
  v_rule    jsonb;
  v_format  jsonb;
begin
  for v_item in select value from jsonb_array_elements(coalesce(p_attachments, '[]'::jsonb)) loop
    v_bucket := coalesce(v_item ->> 'bucket', 'attachments');
    v_mime := lower(coalesce(v_item ->> 'mime', ''));
    if v_item ? 'name' and (jsonb_typeof(v_item -> 'name') <> 'string' or char_length(v_item ->> 'name') > 200) then
      perform private.api_error(400, 'invalid_attachments', 'Nama file lampiran tidak valid');
    end if;
    if not v_support then
      if v_bucket = 'attachments' and v_mime in ('', 'image/jpeg', 'image/png', 'image/webp', 'image/gif') then
        continue;
      end if;
      perform private.api_error(400, 'attachment_not_allowed', 'Chat ini hanya menerima gambar (JPEG, PNG, WebP, GIF)');
    end if;

    v_kind := case v_bucket when 'attachments' then 'images' when 'cs-documents' then 'documents'
                            when 'cs-videos' then 'videos' end;
    v_rule := v_policy -> v_kind;
    if v_kind = 'images' and v_mime = '' and (v_rule ->> 'enabled')::boolean then
      continue;
    end if;
    v_format := null;
    select f into v_format from jsonb_array_elements(coalesce(v_rule -> 'formats', '[]')) f where f ->> 'mime' = v_mime;
    if v_rule is null or not (v_rule ->> 'enabled')::boolean or v_format is null
       or (v_kind <> 'images' and (v_item ->> 'path') !~* ('\.' || (v_format ->> 'ext') || '$')) then
      perform private.api_error(400, 'attachment_not_allowed', 'Format lampiran ini tidak diterima di chat CS');
    end if;
    if jsonb_typeof(v_item -> 'size') = 'number' and (v_item ->> 'size')::numeric > (v_rule ->> 'max_bytes')::numeric then
      perform private.api_error(400, 'attachment_too_large',
        format('Lampiran maksimal %s MB', (v_rule ->> 'max_bytes')::bigint / 1048576));
    end if;
    if v_kind = 'videos' then
      if jsonb_typeof(v_item -> 'duration') is distinct from 'number' or (v_item ->> 'duration')::numeric <= 0
         or (v_item ->> 'duration')::numeric > (v_rule ->> 'max_seconds')::numeric then
        perform private.api_error(400, 'attachment_too_long',
          format('Video maksimal %s detik', v_rule ->> 'max_seconds'));
      end if;
      if v_item ? 'thumbnail' and (jsonb_typeof(v_item -> 'thumbnail') <> 'string'
                                   or (v_item ->> 'thumbnail') !~ ('^rooms/' || p_room_id::text || '/[^/]+/[^/]+\.jpg$')) then
        perform private.api_error(400, 'invalid_attachments', 'Thumbnail video tidak valid');
      end if;
    end if;
  end loop;
end;
$$;

create or replace function private.queue_user_files(p_user_id uuid, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  with rooms as (
    select m.room_id from public.messages m where m.sender_id = p_user_id
    union
    select cm.room_id from public.chat_members cm where cm.user_id = p_user_id
    union
    select r.id from public.chat_rooms r where r.type = 'support' and r.customer_id = p_user_id
  )
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select 'avatars', p_user_id::text || '/', p_reason
  union all
  select 'attachments', 'posts/' || p_user_id::text || '/', p_reason
  union all
  select 'attachments', 'rooms/' || r.room_id::text || '/' || p_user_id::text || '/', p_reason
  from rooms r
  union all
  select b.bucket, 'rooms/' || r.room_id::text || '/' || p_user_id::text || '/', p_reason
  from rooms r
  join public.chat_rooms c on c.id = r.room_id and c.type = 'support'
  cross join (values ('cs-documents'), ('cs-videos')) as b(bucket);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function cs.attachment_catalog() from public;
revoke execute on function cs.attachment_policy_view() from public;
revoke execute on function cs_api.attachment_policy() from public;
revoke execute on function public.media_attachment_policy() from public, anon, authenticated;
revoke execute on function cs_api.admin_attachment_policy() from public;
revoke execute on function cs_api.admin_set_attachment_policy(jsonb) from public;
grant execute on function cs_api.attachment_policy() to authenticated;
grant execute on function public.media_attachment_policy() to service_role;
grant execute on function cs_api.admin_attachment_policy() to authenticated;
grant execute on function cs_api.admin_set_attachment_policy(jsonb) to authenticated;
