create or replace function private.upload_verified()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select auth.jwt()) ->> 'media_verified', '') = 'true'
      or cs.is_staff((select auth.uid()));
$$;

revoke execute on function private.upload_verified() from public;
grant execute on function private.upload_verified() to authenticated;

alter policy olt_avatars_insert on storage.objects
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select private.not_banned())
    and (select private.upload_verified())
  );

alter policy olt_avatars_update on storage.objects
  using (bucket_id = 'avatars' and owner_id = (select auth.uid())::text)
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select private.upload_verified())
  );

alter policy olt_attachments_insert on storage.objects
  with check (
    bucket_id = 'attachments'
    and (select private.not_banned())
    and (select private.upload_verified())
    and (
      ((storage.foldername(name))[1] = 'posts' and (storage.foldername(name))[2] = (select auth.uid())::text)
      or ((storage.foldername(name))[1] = 'rooms'
          and (storage.foldername(name))[3] = (select auth.uid())::text
          and private.is_room_member_text((storage.foldername(name))[2]))
    )
  );

alter policy olt_cs_attachments_insert on storage.objects
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'rooms'
    and (storage.foldername(name))[3] = (select auth.uid())::text
    and cs.is_support_owner_text((storage.foldername(name))[2])
    and (select private.upload_verified())
  );

alter policy olt_cs_documents_insert on storage.objects
  with check (
    bucket_id = 'cs-documents'
    and (storage.foldername(name))[1] = 'rooms'
    and (storage.foldername(name))[3] = (select auth.uid())::text
    and cs.can_upload_support_document((storage.foldername(name))[2])
    and (select private.upload_verified())
  );
