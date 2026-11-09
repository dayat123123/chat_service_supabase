update storage.buckets set file_size_limit = 10485760 where id = 'attachments';

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
    "images": {"bucket": "attachments", "ceiling_mb": 10, "formats": {
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


update cs.cs_settings
   set value = jsonb_set(value, '{images,max_mb}', '10')
 where key = 'attachments.cs' and (value -> 'images' ->> 'max_mb')::integer = 5;

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
        if jsonb_typeof(v_item -> 'size') = 'number' and (v_item ->> 'size')::numeric > 5242880 then
          perform private.api_error(400, 'attachment_too_large', 'Gambar maksimal 5 MB');
        end if;
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


create or replace function public.media_room_kind(p_room uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when r.type = 'support' then 'support' else 'other' end
  from public.chat_rooms r where r.id = p_room;
$$;

revoke execute on function public.media_room_kind(uuid) from public, anon, authenticated;
grant execute on function public.media_room_kind(uuid) to service_role;
