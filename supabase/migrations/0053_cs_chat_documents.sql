insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cs-documents', 'cs-documents', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function cs.can_upload_support_document(p_room text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_room ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and exists (select 1 from public.chat_rooms r where r.id = p_room::uuid and r.type = 'support')
     and (cs.is_support_owner_text(p_room)
          or (cs.current_agent_id() is not null and private.is_room_member_text(p_room)));
$$;

create policy olt_cs_documents_read on storage.objects for select to authenticated
  using (bucket_id = 'cs-documents' and (storage.foldername(name))[1] = 'rooms'
         and (cs.is_support_owner_text((storage.foldername(name))[2])
              or cs.can_read_room_text((storage.foldername(name))[2])));

create policy olt_cs_documents_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-documents' and (storage.foldername(name))[1] = 'rooms'
              and (storage.foldername(name))[3] = (select auth.uid())::text
              and (select private.not_banned())
              and cs.can_upload_support_document((storage.foldername(name))[2]));

create or replace function private.check_message_media(p_attachments jsonb, p_room_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_support boolean := exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support');
  v_item    jsonb;
  v_bucket  text;
  v_mime    text;
begin
  for v_item in select value from jsonb_array_elements(coalesce(p_attachments, '[]'::jsonb)) loop
    v_bucket := coalesce(v_item ->> 'bucket', 'attachments');
    v_mime := lower(coalesce(v_item ->> 'mime', ''));
    if v_bucket = 'attachments' and v_mime in ('', 'image/jpeg', 'image/png', 'image/webp', 'image/gif') then
      continue;
    end if;
    if not (v_support and v_bucket = 'cs-documents' and v_mime = 'application/pdf'
            and (v_item ->> 'path') ~* '\.pdf$') then
      perform private.api_error(400, 'attachment_not_allowed',
        case when v_support then 'Chat CS hanya menerima gambar (JPEG, PNG, WebP, GIF) dan PDF'
             else 'Chat ini hanya menerima gambar (JPEG, PNG, WebP, GIF)' end);
    end if;
    if jsonb_typeof(v_item -> 'size') = 'number' and (v_item ->> 'size')::numeric > 10485760 then
      perform private.api_error(400, 'attachment_too_large', 'PDF maksimal 10 MB');
    end if;
    if v_item ? 'name' and (jsonb_typeof(v_item -> 'name') <> 'string' or char_length(v_item ->> 'name') > 200) then
      perform private.api_error(400, 'invalid_attachments', 'Nama file lampiran tidak valid');
    end if;
  end loop;
end;
$$;

create or replace function private.messages_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    perform private.validate_attachments(
      new.attachments, 'rooms/' || new.room_id || '/' || new.sender_id || '/');
    perform private.check_message_media(new.attachments, new.room_id);
    if new.reply_to_id is not null
       and not exists (select 1 from public.messages
                       where id = new.reply_to_id and room_id = new.room_id) then
      perform private.api_error(400, 'invalid_reply', 'Pesan yang dibalas tidak ada di room ini');
    end if;
  elsif new.deleted_at is null and new.body is distinct from old.body then
    new.body := regexp_replace(coalesce(new.body, ''), '^\s+|\s+$', '', 'g');
    new.edited_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function cs.can_upload_support_document(text) from public;
revoke execute on function private.check_message_media(jsonb, uuid) from public;
grant execute on function cs.can_upload_support_document(text) to authenticated;
