insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('faq-images', 'faq-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.can_manage_faq()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.has_role('{cs_super_admin,cs_content}');
$$;

create policy olt_faq_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'faq-images'
              and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
              and (select private.can_manage_faq()));

create policy olt_faq_images_read on storage.objects for select to authenticated
  using (bucket_id = 'faq-images' and (select private.can_manage_faq()));

create or replace function cs.faq_check_markdown(p_text text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_image text := 'https?://[^\s/?#]+(/[^\s?#]*)?/storage/v1/object/public/faq-images/'
                  || '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)\)';
begin
  if p_text ~ '<[A-Za-z/!?]' then
    perform private.api_error(400, 'invalid_answer', 'Jawaban tidak boleh memuat tag HTML');
  end if;
  if p_text ~ ('!\[[^\]]*\]\(\s*(?!' || v_image || ')') then
    perform private.api_error(400, 'invalid_answer', 'Gambar di jawaban harus diunggah dari Hub');
  end if;
  if p_text ~* ('(^|[^!])\[[^\]]*\]\(\s*(?!https://)') then
    perform private.api_error(400, 'invalid_answer', 'Tautan di jawaban harus https://');
  end if;
end;
$$;

revoke execute on function private.can_manage_faq() from public;
grant execute on function private.can_manage_faq() to authenticated;
