-- 0014_content_integrity.sql
-- Integritas konten tulis (docs/PROMPT-PRODUCTION.md 2, 3, 4.7 dan
-- docs/PROMPT-FEATURES.md 2.3):
--   - client_id idempoten untuk post & komentar (pesan chat sudah sejak 0008);
--   - validasi server: karakter kontrol, maks link / mention / tag saham;
--   - anti-spam: konten sama >= 3x dalam 5 menit ditolak;
--   - user yang di-mute/ban tidak bisa mengirim konten;
--   - Syarat & Ketentuan / Pedoman Komunitas: wajib disetujui (versi terbaru)
--     sebelum posting, berkomentar, atau chat. Ditegakkan di server.
-- Semua pemeriksaan hanya berlaku untuk user aplikasi (bukan seed/service_role).

insert into private.settings (key, value, description) values
  ('content.max_links', '3', 'Maks link per post/komentar/pesan'),
  ('content.max_mentions', '10', 'Maks @mention per konten'),
  ('content.max_stock_tags', '10', 'Maks $KODE per konten'),
  ('content.duplicate_window_seconds', '300', 'Jendela deteksi konten sama (detik)'),
  ('content.duplicate_max', '3', 'Kiriman ke-n dengan isi sama dalam jendela ditolak'),
  ('content.duplicate_min_length', '10', 'Teks lebih pendek dari ini tidak dicek duplikat (mis. "ok")'),
  ('legal.required_kinds', '["terms","community_guidelines"]', 'Dokumen yang wajib disetujui sebelum menulis')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- client_id idempoten (post & komentar)
-- ---------------------------------------------------------------------------
alter table public.posts add column if not exists client_id uuid;
create unique index if not exists posts_client_id_key
  on public.posts (author_id, client_id) where client_id is not null;
grant insert (client_id) on public.posts to authenticated;

alter table public.comments add column if not exists client_id uuid;
create unique index if not exists comments_client_id_key
  on public.comments (author_id, client_id) where client_id is not null;
grant insert (client_id) on public.comments to authenticated;

-- Buat post secara idempoten: kirim ulang dengan client_id yang sama
-- mengembalikan post yang sudah ada, bukan membuat duplikat.
create or replace function public.create_post(
  p_body        text,
  p_sentiment   text default null,
  p_attachments jsonb default '[]'::jsonb,
  p_client_id   uuid default null
)
returns setof public.feed_post
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;

  insert into public.posts (author_id, body, sentiment, attachments, client_id)
  values (auth.uid(), coalesce(p_body, ''), p_sentiment, coalesce(p_attachments, '[]'::jsonb), p_client_id)
  on conflict (author_id, client_id) where client_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.posts where author_id = auth.uid() and client_id = p_client_id;
  end if;

  return query select * from private.feed_posts(array[v_id]);
end;
$$;

-- Versi baru create_comment dengan p_client_id opsional. Pemanggilan lama
-- (3 parameter bernama) tetap jalan karena p_client_id punya default.
drop function if exists public.create_comment(uuid, uuid, text);
create or replace function public.create_comment(
  p_post_id   uuid,
  p_parent_id uuid,
  p_body      text,
  p_client_id uuid default null
)
returns setof public.thread_comment
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_body text := regexp_replace(coalesce(p_body, ''), '^\s+|\s+$', '', 'g');
  v_id   uuid;
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if char_length(v_body) = 0 then
    perform private.api_error(400, 'empty_body', 'Komentar tidak boleh kosong');
  end if;
  if char_length(v_body) > 1000 then
    perform private.api_error(400, 'body_too_long', 'Komentar maksimal 1000 karakter');
  end if;

  insert into public.comments (post_id, parent_id, author_id, body, client_id)
  values (p_post_id, p_parent_id, auth.uid(), v_body, p_client_id)
  on conflict (author_id, client_id) where client_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.comments where author_id = auth.uid() and client_id = p_client_id;
  end if;

  return query select * from private.thread_comments(array[v_id]);
end;
$$;

-- ---------------------------------------------------------------------------
-- Validasi teks & anti-duplikat
-- ---------------------------------------------------------------------------
create or replace function private.validate_text(p_text text, p_kind text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_links integer;
begin
  if p_text is null or p_text = '' then
    return;
  end if;
  -- Karakter kontrol selain tab/newline/carriage return.
  if p_text ~ '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]' then
    perform private.api_error(422, 'invalid_characters', 'Teks mengandung karakter yang tidak diizinkan');
  end if;
  if p_kind not in ('post', 'comment', 'message') then
    return;
  end if;

  select count(*) into v_links
  from regexp_matches(p_text, '(https?://|www\.)[^\s]+', 'gi');
  if v_links > private.setting_num('content.max_links', 3) then
    perform private.api_error(422, 'too_many_links',
      format('Maksimal %s link per konten', private.setting_num('content.max_links', 3)));
  end if;
  if cardinality(private.extract_mentions(p_text)) > private.setting_num('content.max_mentions', 10) then
    perform private.api_error(422, 'too_many_mentions',
      format('Maksimal %s mention per konten', private.setting_num('content.max_mentions', 10)));
  end if;
  if cardinality(private.extract_cashtags(p_text)) > private.setting_num('content.max_stock_tags', 10) then
    perform private.api_error(422, 'too_many_stock_tags',
      format('Maksimal %s kode saham per konten', private.setting_num('content.max_stock_tags', 10)));
  end if;
end;
$$;

-- Kiriman ke-n (default 3) dengan isi sama oleh user yang sama dalam jendela waktu ditolak.
create or replace function private.check_duplicate_content(
  p_table regclass, p_user_column text, p_user uuid, p_text text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_norm  text := lower(regexp_replace(btrim(coalesce(p_text, '')), '\s+', ' ', 'g'));
  v_count integer;
begin
  if char_length(v_norm) < private.setting_num('content.duplicate_min_length', 10) then
    return;
  end if;
  execute format(
    'select count(*) from %s where %I = $1 and deleted_at is null'
    ' and created_at > now() - make_interval(secs => $2)'
    ' and lower(regexp_replace(btrim(body), ''\s+'', '' '', ''g'')) = $3',
    p_table, p_user_column)
  into v_count
  using p_user, private.setting_num('content.duplicate_window_seconds', 300)::double precision, v_norm;

  if v_count >= private.setting_num('content.duplicate_max', 3) - 1 then
    perform private.api_error(422, 'duplicate_content',
      'Konten yang sama sudah dikirim berulang kali. Coba lagi beberapa menit lagi.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Syarat & Ketentuan / Pedoman Komunitas
-- ---------------------------------------------------------------------------
create table if not exists public.legal_documents (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null,
  version      integer not null,
  title        text not null,
  body         text not null,
  effective_at timestamptz not null default now(),
  created_by   uuid,
  created_at   timestamptz not null default now(),
  constraint legal_documents_kind check (kind in ('terms', 'community_guidelines', 'privacy')),
  constraint legal_documents_version check (version > 0),
  constraint legal_documents_kind_version unique (kind, version)
);
alter table public.legal_documents enable row level security;
revoke all on public.legal_documents from anon, authenticated;
grant select on public.legal_documents to authenticated;
drop policy if exists legal_documents_select on public.legal_documents;
create policy legal_documents_select on public.legal_documents
  for select to authenticated using (effective_at <= now());

create table if not exists public.user_consents (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  document_id uuid not null references public.legal_documents(id) on delete cascade,
  accepted_at timestamptz not null default now(),
  primary key (user_id, document_id)
);
alter table public.user_consents enable row level security;
revoke all on public.user_consents from anon, authenticated;
grant select on public.user_consents to authenticated;
drop policy if exists user_consents_select_own on public.user_consents;
create policy user_consents_select_own on public.user_consents
  for select to authenticated using (user_id = (select auth.uid()));

-- Dokumen wajib versi terbaru (yang sudah berlaku) yang belum disetujui user.
create or replace function private.missing_consents(p_user uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(d.kind order by d.kind), '{}')
  from (
    select distinct on (ld.kind) ld.id, ld.kind
    from public.legal_documents ld
    where ld.effective_at <= now()
      and ld.kind in (select jsonb_array_elements_text(
            private.setting_json('legal.required_kinds', '["terms","community_guidelines"]')))
    order by ld.kind, ld.version desc
  ) d
  where not exists (
    select 1 from public.user_consents c where c.user_id = p_user and c.document_id = d.id
  );
$$;

create or replace function public.get_pending_consents()
returns table (id uuid, kind text, version integer, title text, body text, effective_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select d.id, d.kind, d.version, d.title, d.body, d.effective_at
  from (
    select distinct on (ld.kind) ld.*
    from public.legal_documents ld
    where ld.effective_at <= now()
    order by ld.kind, ld.version desc
  ) d
  where d.kind = any (private.missing_consents(auth.uid()));
$$;

create or replace function public.accept_legal_document(p_document_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  if not exists (select 1 from public.legal_documents where id = p_document_id and effective_at <= now()) then
    perform private.api_error(404, 'document_not_found', 'Dokumen tidak ditemukan');
  end if;
  insert into public.user_consents (user_id, document_id) values (auth.uid(), p_document_id)
  on conflict do nothing;
end;
$$;

-- Terbitkan versi baru (compliance_admin / super_admin). User wajib menyetujui
-- ulang begitu versi baru berlaku.
create or replace function admin_api.publish_legal_document(
  p_kind text, p_title text, p_body text, p_effective_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role    text := private.require_admin('{super_admin,compliance_admin}');
  v_version integer;
  v_id      uuid;
begin
  select coalesce(max(version), 0) + 1 into v_version from public.legal_documents where kind = p_kind;
  insert into public.legal_documents (kind, version, title, body, effective_at, created_by)
  values (p_kind, v_version, p_title, p_body, coalesce(p_effective_at, now()), auth.uid())
  returning id into v_id;
  perform private.audit('publish_legal_document', 'legal_document', v_id::text,
                        jsonb_build_object('kind', p_kind, 'version', v_version, 'effective_at', p_effective_at));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger integritas: post, komentar, pesan (argumen: jenis, kolom user)
-- Urutan: rate limit (10) -> before write (20) -> integritas (25) -> filter kata (30)
-- ---------------------------------------------------------------------------
create or replace function private.enforce_content_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind        text := tg_argv[0];
  v_user_column text := tg_argv[1];
  v_row         jsonb := to_jsonb(new);
  v_user        uuid := (v_row ->> v_user_column)::uuid;
  v_missing     text[];
begin
  if not private.is_end_user() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Retry idempoten (client_id sama) tidak diperiksa ulang.
    if private.client_id_exists(tg_relid::regclass, v_user_column, v_user, (v_row ->> 'client_id')::uuid) then
      return new;
    end if;
    if private.is_muted(v_user) then
      perform private.api_error(403, 'user_muted', 'Akun Anda sedang dibatasi dan belum bisa mengirim konten');
    end if;
    v_missing := private.missing_consents(v_user);
    if cardinality(v_missing) > 0 then
      perform private.api_error(403, 'consent_required', array_to_string(v_missing, ','));
    end if;
  end if;

  if new.deleted_at is null then
    perform private.validate_text(new.body, v_kind);
    if tg_op = 'INSERT' then
      perform private.check_duplicate_content(tg_relid::regclass, v_user_column, v_user, new.body);
    end if;
  end if;
  return new;
end;
$$;

create or replace trigger posts_25_integrity
  before insert or update of body on public.posts
  for each row execute function private.enforce_content_integrity('post', 'author_id');
create or replace trigger comments_25_integrity
  before insert or update of body on public.comments
  for each row execute function private.enforce_content_integrity('comment', 'author_id');
create or replace trigger messages_25_integrity
  before insert or update of body on public.messages
  for each row execute function private.enforce_content_integrity('message', 'sender_id');

-- Teks profil & nama grup: tolak karakter kontrol.
create or replace function private.enforce_profile_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_end_user() then
    perform private.validate_text(new.display_name, 'profile');
    perform private.validate_text(new.bio, 'profile');
  end if;
  return new;
end;
$$;

create or replace trigger profiles_25_text
  before update of display_name, bio on public.profiles
  for each row execute function private.enforce_profile_text();

create or replace function private.enforce_room_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_end_user() then
    perform private.validate_text(new.name, 'room');
  end if;
  return new;
end;
$$;

create or replace trigger chat_rooms_25_name
  before insert or update of name on public.chat_rooms
  for each row execute function private.enforce_room_name();

-- ---------------------------------------------------------------------------
-- Hak akses
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public;
revoke all on all functions in schema admin_api from public;
grant execute on all functions in schema admin_api to authenticated;
revoke execute on all functions in schema public from public, anon;
grant execute on function public.create_post(text, text, jsonb, uuid) to authenticated;
grant execute on function public.create_comment(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.get_pending_consents() to authenticated;
grant execute on function public.accept_legal_document(uuid) to authenticated;
