-- 0011_storage.sql
-- Bucket storage (gambar saja):
--   avatars     : publik, maks 2 MB,  path avatars/<user_id>/<file>
--   attachments : privat, maks 5 MB,  path
--                 posts/<user_id>/<file>             -> dibaca semua user login
--                 rooms/<room_id>/<user_id>/<file>   -> dibaca anggota room saja

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 2097152,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('attachments', 'attachments', false, 5242880,
   array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Aman untuk teks apa pun (bukan UUID -> false).
create or replace function private.is_room_member_text(p_room_id text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_room_id is null
     or p_room_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return exists (
    select 1 from public.chat_members
    where room_id = p_room_id::uuid and user_id = auth.uid()
  );
end;
$$;

revoke all on function private.is_room_member_text(text) from public;
grant execute on function private.is_room_member_text(text) to authenticated;

-- avatars ------------------------------------------------------------------
drop policy if exists olt_avatars_read on storage.objects;
create policy olt_avatars_read on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

drop policy if exists olt_avatars_insert on storage.objects;
create policy olt_avatars_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists olt_avatars_update on storage.objects;
create policy olt_avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and owner_id = (select auth.uid())::text)
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists olt_avatars_delete on storage.objects;
create policy olt_avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and owner_id = (select auth.uid())::text);

-- attachments ----------------------------------------------------------------
drop policy if exists olt_attachments_read on storage.objects;
create policy olt_attachments_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (
      (storage.foldername(name))[1] = 'posts'
      or (
        (storage.foldername(name))[1] = 'rooms'
        and private.is_room_member_text((storage.foldername(name))[2])
      )
    )
  );

drop policy if exists olt_attachments_insert on storage.objects;
create policy olt_attachments_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (
      (
        (storage.foldername(name))[1] = 'posts'
        and (storage.foldername(name))[2] = (select auth.uid())::text
      )
      or (
        (storage.foldername(name))[1] = 'rooms'
        and (storage.foldername(name))[3] = (select auth.uid())::text
        and private.is_room_member_text((storage.foldername(name))[2])
      )
    )
  );

drop policy if exists olt_attachments_delete on storage.objects;
create policy olt_attachments_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'attachments' and owner_id = (select auth.uid())::text);
