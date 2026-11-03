alter table public.legal_documents add column change_summary text;
alter table public.legal_documents add column approved_by uuid;
alter table public.legal_documents add constraint legal_documents_change_summary
  check (char_length(change_summary) <= 2000);

create table cs.legal_drafts (
  id             uuid primary key default gen_random_uuid(),
  kind           text not null check (kind in ('terms', 'community_guidelines', 'privacy')),
  title          text not null check (char_length(btrim(title)) between 3 and 150),
  body           text not null check (char_length(btrim(body)) between 50 and 100000),
  change_summary text check (char_length(change_summary) <= 2000),
  effective_at   timestamptz,
  status         text not null default 'draft'
                 check (status in ('draft', 'pending', 'published', 'rejected', 'deleted')),
  created_by     uuid not null,
  created_at     timestamptz not null default now(),
  updated_by     uuid not null,
  updated_at     timestamptz not null default now(),
  submitted_by   uuid,
  submitted_at   timestamptz,
  reviewed_by    uuid,
  reviewed_at    timestamptz,
  review_note    text check (char_length(review_note) <= 1000),
  document_id    uuid references public.legal_documents(id) on delete set null
);
create index legal_drafts_open_idx on cs.legal_drafts (updated_at desc) where status in ('draft', 'pending', 'rejected');
alter table cs.legal_drafts enable row level security;
revoke all on cs.legal_drafts from public, anon, authenticated;

create or replace function cs.legal_kinds()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['terms', 'community_guidelines', 'privacy'];
$$;

create or replace function cs.legal_required_kinds()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(k order by k), '{}')
  from jsonb_array_elements_text(private.setting_json('legal.required_kinds', '["terms","community_guidelines"]')) k;
$$;

create or replace function cs.legal_reviewer_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from cs.agents a where a.disabled_at is null and 'compliance' = any (a.roles);
$$;

create or replace function cs.legal_active_users()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) from public.profiles p where p.deleted_at is null;
$$;

create or replace function cs.legal_document_view(p_id uuid, p_with_body boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'version', d.version, 'title', d.title,
    'body', case when p_with_body then d.body end,
    'change_summary', d.change_summary, 'effective_at', d.effective_at, 'created_at', d.created_at,
    'created_by', cs.agent_name(d.created_by), 'approved_by', cs.agent_name(d.approved_by),
    'in_effect', d.effective_at <= now(),
    'accepted', (select count(*) from public.user_consents c
                 join public.profiles p on p.id = c.user_id and p.deleted_at is null
                 where c.document_id = d.id)))
  from public.legal_documents d
  where d.id = p_id;
$$;

create or replace function cs.legal_draft_view(p_id uuid, p_with_body boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'title', d.title,
    'body', case when p_with_body then d.body end,
    'body_length', char_length(d.body),
    'change_summary', d.change_summary, 'effective_at', d.effective_at, 'status', d.status,
    'created_by', cs.agent_name(d.created_by), 'created_by_id', d.created_by, 'created_at', d.created_at,
    'updated_by', cs.agent_name(d.updated_by), 'updated_by_id', d.updated_by, 'updated_at', d.updated_at,
    'submitted_by', cs.agent_name(d.submitted_by), 'submitted_at', d.submitted_at,
    'reviewed_by', cs.agent_name(d.reviewed_by), 'reviewed_at', d.reviewed_at, 'review_note', d.review_note,
    'document_id', d.document_id))
  from cs.legal_drafts d
  where d.id = p_id;
$$;

create or replace function cs.legal_check_draft(p_kind text, p_title text, p_body text, p_change_summary text,
                                                p_effective_at timestamptz)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_kind is null or not (p_kind = any (cs.legal_kinds())) then
    perform private.api_error(400, 'invalid_legal_kind', 'Jenis dokumen tidak dikenal');
  end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 150 then
    perform private.api_error(400, 'invalid_legal_title', 'Judul 3–150 karakter');
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 50 and 100000 then
    perform private.api_error(400, 'invalid_legal_body', 'Isi dokumen 50–100.000 karakter');
  end if;
  if char_length(coalesce(p_change_summary, '')) > 2000 then
    perform private.api_error(400, 'invalid_legal_summary', 'Ringkasan perubahan maksimal 2.000 karakter');
  end if;
  if p_effective_at is not null and p_effective_at < now() - interval '1 minute' then
    perform private.api_error(400, 'legal_effective_past', 'Tanggal berlaku tidak boleh di masa lalu');
  end if;
end;
$$;

create or replace function cs_api.legal_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{compliance}');
  v_required text[] := cs.legal_required_kinds();
begin
  return jsonb_build_object(
    'active_users', cs.legal_active_users(),
    'reviewers', cs.legal_reviewer_count(),
    'four_eyes', cs.legal_reviewer_count() >= 2,
    'required_kinds', to_jsonb(v_required),
    'kinds', (
      select jsonb_agg(jsonb_build_object(
        'kind', k.kind,
        'required', k.kind = any (v_required),
        'current', (select cs.legal_document_view(d.id) from public.legal_documents d
                    where d.kind = k.kind and d.effective_at <= now() order by d.version desc limit 1),
        'scheduled', (select cs.legal_document_view(d.id) from public.legal_documents d
                      where d.kind = k.kind and d.effective_at > now() order by d.version desc limit 1),
        'history', coalesce((select jsonb_agg(cs.legal_document_view(h.id) order by h.version desc)
                             from (select d.id, d.version from public.legal_documents d
                                   where d.kind = k.kind order by d.version desc limit 20) h), '[]'))
        order by k.ord)
      from unnest(cs.legal_kinds()) with ordinality k(kind, ord)),
    'drafts', coalesce((
      select jsonb_agg(cs.legal_draft_view(d.id) order by d.updated_at desc)
      from cs.legal_drafts d where d.status in ('draft', 'pending', 'rejected')), '[]'));
end;
$$;

create or replace function cs_api.legal_document(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_view jsonb := cs.legal_document_view(p_id, true);
begin
  if v_view is null then
    perform private.api_error(404, 'document_not_found', 'Dokumen tidak ditemukan');
  end if;
  return v_view;
end;
$$;

create or replace function cs_api.legal_draft(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_view jsonb;
begin
  select cs.legal_draft_view(d.id, true) into v_view from cs.legal_drafts d where d.id = p_id and d.status <> 'deleted';
  if v_view is null then
    perform private.api_error(404, 'legal_draft_not_found', 'Draf tidak ditemukan');
  end if;
  return v_view;
end;
$$;

create or replace function cs_api.legal_draft_save(
  p_id uuid, p_kind text, p_title text, p_body text, p_change_summary text default null,
  p_effective_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_draft   cs.legal_drafts;
  v_summary text := nullif(btrim(coalesce(p_change_summary, '')), '');
begin
  perform cs.legal_check_draft(p_kind, p_title, p_body, v_summary, p_effective_at);
  if p_id is null then
    insert into cs.legal_drafts (kind, title, body, change_summary, effective_at, created_by, updated_by)
    values (p_kind, btrim(p_title), p_body, v_summary, p_effective_at, v_me, v_me)
    returning * into v_draft;
    perform cs.audit('legal.draft_created', null, null,
                     jsonb_build_object('draft', v_draft.id, 'kind', p_kind, 'title', v_draft.title));
    return cs.legal_draft_view(v_draft.id, true);
  end if;

  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status = 'deleted' then
    perform private.api_error(404, 'legal_draft_not_found', 'Draf tidak ditemukan');
  end if;
  if v_draft.status not in ('draft', 'rejected') then
    perform private.api_error(409, 'legal_draft_locked', 'Draf yang sedang ditinjau atau sudah terbit tidak bisa diubah');
  end if;
  update cs.legal_drafts d
     set kind = p_kind, title = btrim(p_title), body = p_body, change_summary = v_summary,
         effective_at = p_effective_at, status = 'draft', updated_by = v_me, updated_at = now()
   where d.id = p_id;
  return cs.legal_draft_view(p_id, true);
end;
$$;

create or replace function cs_api.legal_draft_submit(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_draft cs.legal_drafts;
begin
  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status = 'deleted' then
    perform private.api_error(404, 'legal_draft_not_found', 'Draf tidak ditemukan');
  end if;
  if v_draft.status not in ('draft', 'rejected') then
    perform private.api_error(409, 'legal_draft_locked', 'Draf ini tidak bisa diajukan');
  end if;
  perform cs.legal_check_draft(v_draft.kind, v_draft.title, v_draft.body, v_draft.change_summary, v_draft.effective_at);
  update cs.legal_drafts d
     set status = 'pending', submitted_by = v_me, submitted_at = now(),
         reviewed_by = null, reviewed_at = null, review_note = null
   where d.id = p_id;
  perform cs.audit('legal.submitted', null, null,
                   jsonb_build_object('draft', p_id, 'kind', v_draft.kind, 'title', v_draft.title));
  return cs.legal_draft_view(p_id, true);
end;
$$;

create or replace function cs_api.legal_draft_withdraw(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_draft cs.legal_drafts;
begin
  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status <> 'pending' then
    perform private.api_error(409, 'legal_draft_not_pending', 'Draf tidak sedang menunggu persetujuan');
  end if;
  update cs.legal_drafts d set status = 'draft', updated_by = v_me, updated_at = now() where d.id = p_id;
  perform cs.audit('legal.withdrawn', null, null, jsonb_build_object('draft', p_id, 'kind', v_draft.kind));
  return cs.legal_draft_view(p_id, true);
end;
$$;

create or replace function cs_api.legal_draft_reject(p_id uuid, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_note  text := btrim(coalesce(p_note, ''));
  v_draft cs.legal_drafts;
begin
  if char_length(v_note) not between 5 and 1000 then
    perform private.api_error(400, 'legal_note_required', 'Tulis alasan penolakan (5–1.000 karakter)');
  end if;
  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status <> 'pending' then
    perform private.api_error(409, 'legal_draft_not_pending', 'Draf tidak sedang menunggu persetujuan');
  end if;
  update cs.legal_drafts d
     set status = 'rejected', reviewed_by = v_me, reviewed_at = now(), review_note = v_note
   where d.id = p_id;
  perform cs.audit('legal.rejected', null, null,
                   jsonb_build_object('draft', p_id, 'kind', v_draft.kind, 'note', v_note));
  return cs.legal_draft_view(p_id, true);
end;
$$;

create or replace function cs_api.legal_draft_approve(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{compliance}');
  v_draft     cs.legal_drafts;
  v_self      boolean;
  v_effective timestamptz;
  v_version   integer;
  v_doc       uuid;
begin
  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status <> 'pending' then
    perform private.api_error(409, 'legal_draft_not_pending', 'Draf tidak sedang menunggu persetujuan');
  end if;
  v_self := v_me in (v_draft.created_by, v_draft.updated_by, v_draft.submitted_by);
  if v_self and cs.legal_reviewer_count() >= 2 then
    perform private.api_error(403, 'four_eyes', 'Dokumen harus disetujui staf kepatuhan lain, bukan penyusunnya');
  end if;
  perform pg_advisory_xact_lock(hashtext('legal_documents:' || v_draft.kind));
  if exists (select 1 from public.legal_documents d where d.kind = v_draft.kind and d.effective_at > now()) then
    perform private.api_error(409, 'legal_scheduled_exists',
                              'Sudah ada versi terjadwal untuk dokumen ini. Batalkan jadwalnya dulu.');
  end if;
  v_effective := greatest(coalesce(v_draft.effective_at, now()), now());
  select coalesce(max(d.version), 0) + 1 into v_version from public.legal_documents d where d.kind = v_draft.kind;
  insert into public.legal_documents (kind, version, title, body, effective_at, created_by, approved_by, change_summary)
  values (v_draft.kind, v_version, v_draft.title, v_draft.body, v_effective, v_draft.created_by, v_me,
          v_draft.change_summary)
  returning id into v_doc;
  update cs.legal_drafts d
     set status = 'published', reviewed_by = v_me, reviewed_at = now(), document_id = v_doc
   where d.id = p_id;
  perform cs.audit('legal.published', null, null, jsonb_build_object(
    'draft', p_id, 'document', v_doc, 'kind', v_draft.kind, 'version', v_version, 'title', v_draft.title,
    'effective_at', v_effective, 'self_approved', v_self));
  return cs.legal_document_view(v_doc, true);
end;
$$;

create or replace function cs_api.legal_cancel_scheduled(p_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_doc   public.legal_documents;
  v_draft uuid;
begin
  select * into v_doc from public.legal_documents d where d.id = p_document_id for update;
  if not found then
    perform private.api_error(404, 'document_not_found', 'Dokumen tidak ditemukan');
  end if;
  if v_doc.effective_at <= now() then
    perform private.api_error(409, 'legal_already_effective', 'Dokumen sudah berlaku dan tidak bisa dibatalkan');
  end if;
  update cs.legal_drafts d
     set status = 'draft', document_id = null, updated_by = v_me, updated_at = now(),
         reviewed_by = null, reviewed_at = null
   where d.document_id = p_document_id
  returning d.id into v_draft;
  delete from public.legal_documents d where d.id = p_document_id;
  perform cs.audit('legal.schedule_cancelled', null, null, jsonb_build_object(
    'document', p_document_id, 'kind', v_doc.kind, 'version', v_doc.version, 'effective_at', v_doc.effective_at,
    'draft', v_draft));
  return jsonb_build_object('draft', v_draft);
end;
$$;

create or replace function cs_api.legal_draft_delete(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_draft cs.legal_drafts;
begin
  select * into v_draft from cs.legal_drafts d where d.id = p_id for update;
  if not found or v_draft.status = 'deleted' then
    perform private.api_error(404, 'legal_draft_not_found', 'Draf tidak ditemukan');
  end if;
  if v_draft.status not in ('draft', 'rejected') then
    perform private.api_error(409, 'legal_draft_locked', 'Draf yang sedang ditinjau atau sudah terbit tidak bisa dihapus');
  end if;
  update cs.legal_drafts d set status = 'deleted', updated_by = v_me, updated_at = now() where d.id = p_id;
  perform cs.audit('legal.draft_deleted', null, null,
                   jsonb_build_object('draft', p_id, 'kind', v_draft.kind, 'title', v_draft.title));
end;
$$;

create or replace function cs_api.legal_set_required(p_kinds text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_old   text[] := cs.legal_required_kinds();
  v_kinds text[] := coalesce((select array_agg(distinct k order by k) from unnest(coalesce(p_kinds, '{}')) k), '{}');
begin
  if not (v_kinds <@ cs.legal_kinds()) then
    perform private.api_error(400, 'invalid_legal_kind', 'Jenis dokumen tidak dikenal');
  end if;
  insert into private.settings (key, value, description)
  values ('legal.required_kinds', to_jsonb(v_kinds), 'Jenis dokumen hukum yang wajib disetujui sebelum membuat konten')
  on conflict (key) do update set value = excluded.value, updated_at = now();
  perform cs.audit('legal.required_changed', null, null,
                   jsonb_build_object('old', to_jsonb(v_old), 'new', to_jsonb(v_kinds)));
  return to_jsonb(v_kinds);
end;
$$;

create or replace function public.get_legal_documents()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'version', d.version, 'title', d.title, 'body', d.body,
    'change_summary', d.change_summary, 'effective_at', d.effective_at,
    'required', d.kind = any (cs.legal_required_kinds()),
    'accepted', exists (select 1 from public.user_consents c where c.user_id = auth.uid() and c.document_id = d.id))
    order by array_position(cs.legal_kinds(), d.kind)), '[]')
  from (
    select distinct on (ld.kind) ld.*
    from public.legal_documents ld
    where ld.effective_at <= now()
    order by ld.kind, ld.version desc
  ) d;
$$;

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
    if private.client_id_exists(tg_relid::regclass, v_user_column, v_user, (v_row ->> 'client_id')::uuid) then
      return new;
    end if;
    if private.is_muted(v_user) then
      perform private.api_error(403, 'user_muted', 'Akun Anda sedang dibatasi dan belum bisa mengirim konten');
    end if;
    if not (v_kind = 'message' and exists (select 1 from public.chat_rooms r
                                           where r.id = (v_row ->> 'room_id')::uuid and r.type = 'support')) then
      v_missing := private.missing_consents(v_user);
      if cardinality(v_missing) > 0 then
        perform private.api_error(403, 'consent_required', array_to_string(v_missing, ','));
      end if;
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

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.api_error(401, 'not_authenticated');
  end if;
  perform private.consume_rate_limit(v_uid, 'data_export');
  perform private.log_personal_data_access(v_uid, 'self_export', '{all}');

  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) - 'olt_user_id' from public.profiles p where p.id = v_uid),
    'email', (select up.email from private.user_private up where up.user_id = v_uid),
    'posts', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'body', body, 'sentiment', sentiment, 'attachments', attachments,
        'created_at', created_at, 'edited_at', edited_at) order by created_at)
      from public.posts where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'polls', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', pl.post_id, 'ends_at', pl.ends_at,
        'options', (select jsonb_agg(o.label order by o.position)
                    from public.post_poll_options o where o.post_id = pl.post_id))
        order by pl.created_at)
      from public.post_polls pl join public.posts p on p.id = pl.post_id
      where p.author_id = v_uid and p.deleted_at is null), '[]'::jsonb),
    'poll_votes', coalesce((select jsonb_agg(jsonb_build_object(
        'post_id', v.post_id, 'option', o.label, 'created_at', v.created_at) order by v.created_at)
      from public.post_poll_votes v join public.post_poll_options o on o.id = v.option_id
      where v.user_id = v_uid), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'post_id', post_id, 'parent_id', parent_id, 'body', body, 'created_at', created_at)
        order by created_at)
      from public.comments where author_id = v_uid and deleted_at is null), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'room_id', room_id, 'body', body, 'attachments', attachments, 'created_at', created_at)
        order by created_at)
      from public.messages where sender_id = v_uid and deleted_at is null), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) - 'user_id') from public.reactions r
      where r.user_id = v_uid), '[]'::jsonb),
    'following', coalesce((select jsonb_agg(f.following_id) from public.follows f
      where f.follower_id = v_uid), '[]'::jsonb),
    'blocked', coalesce((select jsonb_agg(b.blocked_id) from public.blocks b
      where b.blocker_id = v_uid), '[]'::jsonb),
    'muted_users', coalesce((select jsonb_agg(m.muted_id) from public.mutes m
      where m.muter_id = v_uid), '[]'::jsonb),
    'muted_keywords', coalesce((select jsonb_agg(k.keyword) from public.muted_keywords k
      where k.user_id = v_uid), '[]'::jsonb),
    'muted_stocks', coalesce((select jsonb_agg(s.stock_code) from public.muted_stocks s
      where s.user_id = v_uid), '[]'::jsonb),
    'watchlist', coalesce((select jsonb_agg(w.stock_code) from public.stock_watchers w
      where w.user_id = v_uid), '[]'::jsonb),
    'reports_made', coalesce((select jsonb_agg(jsonb_build_object(
        'target_type', target_type, 'target_id', target_id, 'reason', reason,
        'status', status, 'created_at', created_at))
      from public.reports where reporter_id = v_uid), '[]'::jsonb),
    'consents', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', d.kind, 'version', d.version, 'title', d.title, 'accepted_at', c.accepted_at)
        order by c.accepted_at)
      from public.user_consents c join public.legal_documents d on d.id = c.document_id
      where c.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', kind, 'category', category, 'reason', reason, 'starts_at', starts_at, 'ends_at', ends_at))
      from private.user_sanctions where user_id = v_uid), '[]'::jsonb),
    'support_tickets', coalesce((select jsonb_agg(jsonb_build_object(
        'ticket_number', t.ticket_number, 'topic', t.topic, 'status', t.status, 'created_at', t.created_at,
        'closed_at', t.closed_at, 'rating', t.rating, 'rating_comment', t.rating_comment)
        order by t.created_at)
      from cs.tickets t where t.customer_id = v_uid), '[]'::jsonb),
    'push_devices', coalesce((select jsonb_agg(jsonb_build_object(
        'platform', d.platform, 'locale', d.locale, 'app_version', d.app_version,
        'created_at', d.created_at, 'last_seen_at', d.last_seen_at) order by d.created_at)
      from private.push_devices d where d.user_id = v_uid), '[]'::jsonb)
  );
end;
$$;

revoke execute on function cs.legal_kinds() from public;
revoke execute on function cs.legal_required_kinds() from public;
revoke execute on function cs.legal_reviewer_count() from public;
revoke execute on function cs.legal_active_users() from public;
revoke execute on function cs.legal_document_view(uuid, boolean) from public;
revoke execute on function cs.legal_draft_view(uuid, boolean) from public;
revoke execute on function cs.legal_check_draft(text, text, text, text, timestamptz) from public;
revoke execute on function cs_api.legal_overview() from public;
revoke execute on function cs_api.legal_document(uuid) from public;
revoke execute on function cs_api.legal_draft(uuid) from public;
revoke execute on function cs_api.legal_draft_save(uuid, text, text, text, text, timestamptz) from public;
revoke execute on function cs_api.legal_draft_submit(uuid) from public;
revoke execute on function cs_api.legal_draft_withdraw(uuid) from public;
revoke execute on function cs_api.legal_draft_reject(uuid, text) from public;
revoke execute on function cs_api.legal_draft_approve(uuid) from public;
revoke execute on function cs_api.legal_cancel_scheduled(uuid) from public;
revoke execute on function cs_api.legal_draft_delete(uuid) from public;
revoke execute on function cs_api.legal_set_required(text[]) from public;
revoke execute on function public.get_legal_documents() from public, anon;

grant execute on function cs.legal_kinds() to authenticated;
grant execute on function cs.legal_required_kinds() to authenticated;
grant execute on function cs_api.legal_overview() to authenticated;
grant execute on function cs_api.legal_document(uuid) to authenticated;
grant execute on function cs_api.legal_draft(uuid) to authenticated;
grant execute on function cs_api.legal_draft_save(uuid, text, text, text, text, timestamptz) to authenticated;
grant execute on function cs_api.legal_draft_submit(uuid) to authenticated;
grant execute on function cs_api.legal_draft_withdraw(uuid) to authenticated;
grant execute on function cs_api.legal_draft_reject(uuid, text) to authenticated;
grant execute on function cs_api.legal_draft_approve(uuid) to authenticated;
grant execute on function cs_api.legal_cancel_scheduled(uuid) to authenticated;
grant execute on function cs_api.legal_draft_delete(uuid) to authenticated;
grant execute on function cs_api.legal_set_required(text[]) to authenticated;
grant execute on function public.get_legal_documents() to authenticated;
