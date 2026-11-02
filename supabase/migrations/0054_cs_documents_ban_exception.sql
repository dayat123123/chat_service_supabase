drop policy if exists olt_cs_documents_insert on storage.objects;

create policy olt_cs_documents_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-documents' and (storage.foldername(name))[1] = 'rooms'
              and (storage.foldername(name))[3] = (select auth.uid())::text
              and cs.can_upload_support_document((storage.foldername(name))[2]));
