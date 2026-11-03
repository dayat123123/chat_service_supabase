insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidence', 'evidence', false, 52428800, null)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = null;

insert into private.settings (key, value, description) values
  ('retention.evidence_days', '730',
   'Masa simpan bukti karantina (hari) sejak bukti terakhir direkam. Legal hold menangguhkan penghapusan.')
on conflict (key) do nothing;

create or replace function private.evidence_sha256(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(pg_catalog.sha256(convert_to(coalesce(p_text, ''), 'UTF8')), 'hex');
$$;

create or replace function private.evidence_time(p_at timestamptz)
returns text
language sql
immutable
set search_path = ''
as $$
  select to_char(p_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
$$;

create table private.evidence (
  id             uuid primary key default gen_random_uuid(),
  seq            bigint generated always as identity unique,
  source         text not null
                 check (source in ('report', 'moderator_remove', 'system_remove', 'media_removed', 'zero_tolerance')),
  target_type    text not null check (target_type in ('post', 'comment', 'message', 'user', 'media')),
  target_id      text not null check (char_length(target_id) between 1 and 1100),
  author_id      uuid,
  content        jsonb not null check (jsonb_typeof(content) = 'object'),
  context        jsonb not null default '{}' check (jsonb_typeof(context) = 'object'),
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  body_sha256    text not null check (body_sha256 ~ '^[0-9a-f]{64}$'),
  record_sha256  text not null check (record_sha256 ~ '^[0-9a-f]{64}$'),
  captured_at    timestamptz not null default clock_timestamp(),
  captured_by    uuid,
  retain_until   timestamptz not null,
  legal_hold     boolean not null default false,
  hold_reason    text check (char_length(hold_reason) between 10 and 500),
  hold_by        uuid,
  hold_at        timestamptz,
  constraint evidence_hold check (
    legal_hold = (hold_reason is not null) and legal_hold = (hold_by is not null) and legal_hold = (hold_at is not null)),
  constraint evidence_target unique (target_type, target_id, content_sha256)
);
create index evidence_author_idx on private.evidence (author_id, seq desc);
create index evidence_retain_idx on private.evidence (retain_until) where not legal_hold;
alter table private.evidence enable row level security;

create table private.evidence_files (
  id            bigint generated always as identity primary key,
  evidence_id   uuid not null references private.evidence (id) on delete cascade,
  position      smallint not null check (position between 1 and 100),
  source_bucket text not null check (char_length(source_bucket) between 1 and 100),
  source_name   text not null check (char_length(source_name) between 1 and 1024),
  object_name   text not null unique check (char_length(object_name) between 1 and 1024),
  meta          jsonb not null default '{}' check (jsonb_typeof(meta) = 'object'),
  status        text not null default 'pending' check (status in ('pending', 'copied', 'missing', 'failed')),
  sha256        text check (sha256 ~ '^[0-9a-f]{64}$'),
  size          bigint check (size >= 0),
  copied_at     timestamptz,
  failures      integer not null default 0,
  available_at  timestamptz not null default now(),
  locked_until  timestamptz,
  locked_by     text check (char_length(locked_by) <= 100),
  error         text check (char_length(error) <= 500),
  constraint evidence_files_position unique (evidence_id, position),
  constraint evidence_files_copied check (
    (status = 'copied') = (sha256 is not null) and (status = 'copied') = (size is not null)
    and (status = 'copied') = (copied_at is not null))
);
create index evidence_files_ready_idx on private.evidence_files (available_at, id) where status = 'pending';
create index evidence_files_source_idx on private.evidence_files (source_bucket, source_name) where status = 'pending';
alter table private.evidence_files enable row level security;

create table private.evidence_custody (
  id           bigint generated always as identity primary key,
  evidence_id  uuid not null references private.evidence (id) on delete cascade,
  at           timestamptz not null default clock_timestamp(),
  actor_id     uuid,
  actor_type   text not null check (actor_type in ('customer', 'agent', 'service', 'system')),
  actor_roles  text[] not null default '{}',
  action       text not null check (action in ('captured', 'linked', 'file_copied', 'file_missing', 'file_failed',
                                               'viewed', 'verified', 'file_verified', 'exported', 'hold_set',
                                               'hold_released')),
  details      jsonb not null default '{}' check (jsonb_typeof(details) = 'object'),
  prev_sha256  text check (prev_sha256 ~ '^[0-9a-f]{64}$'),
  entry_sha256 text not null check (entry_sha256 ~ '^[0-9a-f]{64}$')
);
create index evidence_custody_evidence_idx on private.evidence_custody (evidence_id, id);
create index evidence_custody_report_idx on private.evidence_custody ((details ->> 'report_id'))
  where details ? 'report_id';
create index evidence_custody_access_idx on private.evidence_custody (actor_id, at desc)
  where action in ('viewed', 'verified', 'exported');
alter table private.evidence_custody enable row level security;

create or replace function private.evidence_record_hash(e private.evidence)
returns text
language sql
immutable
set search_path = ''
as $$
  select private.evidence_sha256(jsonb_build_object(
    'id', e.id, 'seq', e.seq, 'source', e.source, 'target_type', e.target_type, 'target_id', e.target_id,
    'author_id', e.author_id, 'content_sha256', e.content_sha256, 'body_sha256', e.body_sha256,
    'context', e.context, 'captured_at', private.evidence_time(e.captured_at), 'captured_by', e.captured_by)::text);
$$;

create or replace function private.evidence_custody_hash(c private.evidence_custody)
returns text
language sql
immutable
set search_path = ''
as $$
  select private.evidence_sha256(concat_ws('|', coalesce(c.prev_sha256, ''), c.evidence_id::text,
    private.evidence_time(c.at), coalesce(c.actor_id::text, ''), c.actor_type, array_to_string(c.actor_roles, ','),
    c.action, c.details::text));
$$;

create or replace function private.evidence_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.captured_at := clock_timestamp();
  new.content_sha256 := private.evidence_sha256(new.content::text);
  new.body_sha256 := private.evidence_sha256(new.content ->> 'body');
  new.record_sha256 := private.evidence_record_hash(new);
  new.legal_hold := false;
  new.hold_reason := null;
  new.hold_by := null;
  new.hold_at := null;
  if new.retain_until is null then
    new.retain_until := new.captured_at
      + make_interval(days => greatest(private.setting_num('retention.evidence_days', 730)::integer, 1));
  end if;
  return new;
end;
$$;

create trigger evidence_10_before_insert
before insert on private.evidence
for each row execute function private.evidence_before_insert();

create or replace function private.evidence_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_mutable text[] := '{legal_hold,hold_reason,hold_by,hold_at,retain_until}';
begin
  if tg_op = 'TRUNCATE' then
    perform private.api_error(409, 'evidence_immutable', 'Bukti karantina tidak bisa dihapus massal');
  elsif tg_op = 'UPDATE' then
    if (to_jsonb(new) - v_mutable) is distinct from (to_jsonb(old) - v_mutable)
       or new.retain_until < old.retain_until then
      perform private.api_error(409, 'evidence_immutable', 'Isi bukti karantina tidak bisa diubah');
    end if;
    return new;
  end if;
  if old.legal_hold or old.retain_until >= now() then
    perform private.api_error(409, 'evidence_retained', 'Bukti masih dalam masa simpan atau legal hold');
  end if;
  return old;
end;
$$;

create trigger evidence_20_guard
before update or delete on private.evidence
for each row execute function private.evidence_guard();

create trigger evidence_no_truncate
before truncate on private.evidence
for each statement execute function private.evidence_guard();

create or replace function private.evidence_files_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'TRUNCATE' then
    perform private.api_error(409, 'evidence_immutable', 'File bukti tidak bisa dihapus massal');
  elsif tg_op = 'UPDATE' then
    if old.status <> 'pending'
       or (new.id, new.evidence_id, new.position, new.source_bucket, new.source_name, new.object_name, new.meta)
          is distinct from
          (old.id, old.evidence_id, old.position, old.source_bucket, old.source_name, old.object_name, old.meta) then
      perform private.api_error(409, 'evidence_immutable', 'File bukti yang sudah disalin tidak bisa diubah');
    end if;
    return new;
  end if;
  if exists (select 1 from private.evidence e where e.id = old.evidence_id) then
    perform private.api_error(409, 'evidence_retained', 'File bukti hanya terhapus bersama buktinya');
  end if;
  return old;
end;
$$;

create trigger evidence_files_guard
before update or delete on private.evidence_files
for each row execute function private.evidence_files_guard();

create trigger evidence_files_no_truncate
before truncate on private.evidence_files
for each statement execute function private.evidence_files_guard();

create or replace function private.evidence_custody_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and not exists (select 1 from private.evidence e where e.id = old.evidence_id) then
    return old;
  end if;
  perform private.api_error(409, 'evidence_immutable', 'Jejak penanganan bukti bersifat tambah-saja');
  return null;
end;
$$;

create trigger evidence_custody_guard
before update or delete on private.evidence_custody
for each row execute function private.evidence_custody_guard();

create trigger evidence_custody_no_truncate
before truncate on private.evidence_custody
for each statement execute function private.evidence_custody_guard();

create or replace function private.evidence_log(p_evidence uuid, p_action text, p_details jsonb default '{}',
                                                p_actor uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text := cs.actor_type();
  c      private.evidence_custody;
begin
  perform pg_advisory_xact_lock(hashtextextended('evidence:' || p_evidence::text, 0));
  c.evidence_id := p_evidence;
  c.at := clock_timestamp();
  c.actor_type := v_type;
  c.actor_id := coalesce(p_actor, case when v_type in ('agent', 'customer') then auth.uid() end);
  c.actor_roles := cs.current_roles();
  c.action := p_action;
  c.details := coalesce(p_details, '{}');
  select x.entry_sha256 into c.prev_sha256
  from private.evidence_custody x
  where x.evidence_id = p_evidence
  order by x.id desc
  limit 1;
  c.entry_sha256 := private.evidence_custody_hash(c);
  insert into private.evidence_custody (evidence_id, at, actor_id, actor_type, actor_roles, action, details,
                                        prev_sha256, entry_sha256)
  values (c.evidence_id, c.at, c.actor_id, c.actor_type, c.actor_roles, c.action, c.details,
          c.prev_sha256, c.entry_sha256);
end;
$$;

create or replace function private.evidence_profile(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name,
                            'olt_user_id', p.olt_user_id, 'deleted', p.deleted_at is not null)
  from public.profiles p
  where p.id = p_user;
$$;

create or replace function private.evidence_avatar_path(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_url is null or btrim(p_url) = '' then null
    when p_url ~ '^[a-z][a-z0-9+.-]*://' then
      nullif(substring(p_url from '/storage/v1/object/(?:public|authenticated|sign)/avatars/([^?#]+)'), '')
    else nullif(regexp_replace(p_url, '^/+', ''), '')
  end;
$$;

create or replace function private.evidence_capture(p_source text, p_target_type text, p_target_id text,
                                                    p_author uuid, p_body text, p_attachments jsonb, p_extra jsonb,
                                                    p_context jsonb, p_actor uuid, p_link jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_content jsonb;
  v_id      uuid;
  v_until   timestamptz := now()
    + make_interval(days => greatest(private.setting_num('retention.evidence_days', 730)::integer, 1));
  v_files   integer;
  v_missing integer;
begin
  v_content := jsonb_build_object('target_type', p_target_type, 'target_id', p_target_id, 'author_id', p_author,
                                  'body', p_body,
                                  'attachments', case when jsonb_typeof(p_attachments) = 'array'
                                                      then p_attachments else '[]'::jsonb end)
               || coalesce(p_extra, '{}');
  insert into private.evidence (source, target_type, target_id, author_id, content, context, captured_by, retain_until)
  values (p_source, p_target_type, p_target_id, p_author, v_content,
          coalesce(p_context, '{}') || jsonb_build_object('author', private.evidence_profile(p_author)),
          p_actor, v_until)
  on conflict (target_type, target_id, content_sha256) do nothing
  returning id into v_id;
  if v_id is null then
    update private.evidence e
       set retain_until = greatest(e.retain_until, v_until)
     where e.target_type = p_target_type and e.target_id = p_target_id
       and e.content_sha256 = private.evidence_sha256(v_content::text)
    returning e.id into v_id;
    perform private.evidence_log(v_id, 'linked', jsonb_build_object('source', p_source) || coalesce(p_link, '{}'),
                                 p_actor);
    return v_id;
  end if;
  insert into private.evidence_files (evidence_id, position, source_bucket, source_name, object_name, meta, status)
  select v_id, a.ordinality, a.bucket, a.path,
         v_id::text || '/' || lpad(a.ordinality::text, 2, '0') || '-'
           || coalesce(nullif(left(regexp_replace(regexp_replace(a.path, '^.*/', ''), '[^A-Za-z0-9._-]+', '_', 'g'),
                                   120), ''), 'file'),
         a.value,
         case when exists (select 1 from storage.objects o where o.bucket_id = a.bucket and o.name = a.path)
              then 'pending' else 'missing' end
  from (
    select e.value, e.ordinality, coalesce(nullif(e.value ->> 'bucket', ''), 'attachments') as bucket,
           e.value ->> 'path' as path
    from jsonb_array_elements(v_content -> 'attachments') with ordinality e
    where jsonb_typeof(e.value) = 'object' and coalesce(e.value ->> 'path', '') <> '' and e.ordinality <= 100
  ) a;
  select count(*), count(*) filter (where f.status = 'missing') into v_files, v_missing
  from private.evidence_files f
  where f.evidence_id = v_id;
  perform private.evidence_log(v_id, 'captured',
    jsonb_build_object('source', p_source, 'content_sha256', private.evidence_sha256(v_content::text),
                       'files', v_files, 'files_missing', v_missing) || coalesce(p_link, '{}'),
    p_actor);
  return v_id;
end;
$$;

create or replace function private.evidence_capture_target(p_source text, p_target_type text, p_target_id uuid,
                                                           p_actor uuid, p_link jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post    public.posts;
  v_comment public.comments;
  v_message public.messages;
  v_profile public.profiles;
  v_archive private.content_archive;
  v_body    text;
  v_files   jsonb;
  v_avatar  text;
begin
  if p_target_type in ('post', 'comment', 'message') then
    select * into v_archive
    from private.content_archive a
    where a.target_type = p_target_type and a.target_id = p_target_id
    order by a.deleted_at desc, a.id desc
    limit 1;
  end if;
  if p_target_type = 'post' then
    select * into v_post from public.posts where id = p_target_id;
    if not found then
      return null;
    end if;
    v_body := case when v_post.deleted_at is not null and v_archive.id is not null then v_archive.body else v_post.body end;
    v_files := case when v_post.deleted_at is not null and v_archive.id is not null
                    then coalesce(v_archive.attachments, '[]') else v_post.attachments end;
    return private.evidence_capture(p_source, 'post', p_target_id::text, v_post.author_id, v_body, v_files, null,
      jsonb_build_object('post', to_jsonb(v_post) - 'body' - 'attachments'), p_actor, p_link);
  elsif p_target_type = 'comment' then
    select * into v_comment from public.comments where id = p_target_id;
    if not found then
      return null;
    end if;
    v_body := case when v_comment.deleted_at is not null and v_archive.id is not null
                   then v_archive.body else v_comment.body end;
    return private.evidence_capture(p_source, 'comment', p_target_id::text, v_comment.author_id, v_body, '[]', null,
      jsonb_build_object('comment', to_jsonb(v_comment) - 'body'), p_actor, p_link);
  elsif p_target_type = 'message' then
    select * into v_message from public.messages where id = p_target_id;
    if not found then
      return null;
    end if;
    v_body := case when v_message.deleted_at is not null and v_archive.id is not null
                   then v_archive.body else v_message.body end;
    v_files := case when v_message.deleted_at is not null and v_archive.id is not null
                    then coalesce(v_archive.attachments, '[]') else v_message.attachments end;
    return private.evidence_capture(p_source, 'message', p_target_id::text, v_message.sender_id, v_body, v_files, null,
      jsonb_build_object('message', to_jsonb(v_message) - 'body' - 'attachments',
                         'room', (select jsonb_build_object('id', r.id, 'type', r.type, 'name', r.name,
                                                            'stock_code', r.stock_code)
                                  from public.chat_rooms r where r.id = v_message.room_id)),
      p_actor, p_link);
  elsif p_target_type = 'user' then
    select * into v_profile from public.profiles where id = p_target_id;
    if not found then
      return null;
    end if;
    v_avatar := private.evidence_avatar_path(v_profile.avatar_url);
    return private.evidence_capture(p_source, 'user', p_target_id::text, v_profile.id, v_profile.bio,
      case when v_avatar is null then '[]'::jsonb
           else jsonb_build_array(jsonb_build_object('bucket', 'avatars', 'path', v_avatar, 'kind', 'avatar')) end,
      jsonb_build_object('username', v_profile.username, 'display_name', v_profile.display_name,
                         'avatar_url', v_profile.avatar_url),
      jsonb_build_object('profile', to_jsonb(v_profile) - 'bio'), p_actor, p_link);
  end if;
  return null;
end;
$$;

create or replace function private.evidence_on_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.evidence_capture_target('report', new.target_type, new.target_id, new.reporter_id,
    jsonb_build_object('report_id', new.id, 'reason', new.reason));
  return null;
end;
$$;

create trigger reports_90_evidence
after insert on public.reports
for each row execute function private.evidence_on_report();

create or replace function private.evidence_on_archive()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_live jsonb;
begin
  if new.reason not in ('moderator_remove', 'policy_block') or new.target_type not in ('post', 'comment', 'message') then
    return null;
  end if;
  v_live := case new.target_type
    when 'post' then (select jsonb_build_object('post', to_jsonb(p) - 'body' - 'attachments')
                      from public.posts p where p.id = new.target_id)
    when 'comment' then (select jsonb_build_object('comment', to_jsonb(c) - 'body')
                         from public.comments c where c.id = new.target_id)
    else (select jsonb_build_object('message', to_jsonb(m) - 'body' - 'attachments',
                                    'room', jsonb_build_object('id', r.id, 'type', r.type, 'name', r.name,
                                                               'stock_code', r.stock_code))
          from public.messages m left join public.chat_rooms r on r.id = m.room_id
          where m.id = new.target_id)
  end;
  perform private.evidence_capture(
    case new.reason when 'policy_block' then 'system_remove' else 'moderator_remove' end,
    new.target_type, new.target_id::text, new.author_id, new.body,
    case when new.target_type = 'comment' then '[]'::jsonb else coalesce(new.attachments, '[]') end, null,
    coalesce(v_live, '{}') || jsonb_build_object('archive', jsonb_build_object(
      'id', new.id, 'reason', new.reason, 'category', new.category, 'deleted_by', new.deleted_by,
      'deleted_at', new.deleted_at)),
    new.deleted_by, jsonb_build_object('archive_id', new.id, 'reason', new.reason));
  return null;
end;
$$;

create trigger content_archive_90_evidence
after insert on private.content_archive
for each row execute function private.evidence_on_archive();

create or replace function private.evidence_on_media_removed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.evidence_capture('media_removed', 'media', new.bucket || '/' || new.name, new.uploader, null,
    jsonb_build_array(jsonb_build_object('bucket', new.bucket, 'path', new.name, 'kind', 'media')), null,
    jsonb_build_object('media_review', to_jsonb(new) - 'name' - 'bucket'), new.decided_by,
    jsonb_build_object('media_review_id', new.id));
  return null;
end;
$$;

create trigger media_reviews_90_evidence
after update of status on private.media_reviews
for each row when (new.status = 'removed' and old.status is distinct from 'removed')
execute function private.evidence_on_media_removed();

create or replace function private.evidence_on_zero_tolerance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_link jsonb := jsonb_build_object('sanction_id', new.id);
  r      record;
begin
  perform private.evidence_capture_target('zero_tolerance', 'user', new.user_id, new.created_by, v_link);
  for r in
    select 'post' as kind, p.id from public.posts p
    where p.author_id = new.user_id and p.deleted_at is null
    order by p.created_at desc limit 500
  loop
    perform private.evidence_capture_target('zero_tolerance', r.kind, r.id, new.created_by, v_link);
  end loop;
  for r in
    select 'comment' as kind, c.id from public.comments c
    where c.author_id = new.user_id and c.deleted_at is null
    order by c.created_at desc limit 500
  loop
    perform private.evidence_capture_target('zero_tolerance', r.kind, r.id, new.created_by, v_link);
  end loop;
  for r in
    select 'message' as kind, m.id from public.messages m
    where m.sender_id = new.user_id and m.deleted_at is null and m.session_id is null
    order by m.created_at desc limit 500
  loop
    perform private.evidence_capture_target('zero_tolerance', r.kind, r.id, new.created_by, v_link);
  end loop;
  return null;
end;
$$;

create trigger user_sanctions_90_evidence
after insert on private.user_sanctions
for each row when (new.category = 'zero_tolerance')
execute function private.evidence_on_zero_tolerance();

create or replace function private.evidence_pending_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lock text;
begin
  if tg_op = 'UPDATE' and new.bucket_id = old.bucket_id and new.name = old.name
     and new.version is not distinct from old.version then
    return new;
  end if;
  v_lock := case
    when exists (select 1 from private.evidence_files f
                 where f.status = 'pending' and f.source_bucket = old.bucket_id and f.source_name = old.name)
      then 'pending'
    when old.bucket_id = 'evidence' and exists (select 1 from private.evidence_files f
                                                where f.object_name = old.name and f.status = 'copied')
      then 'retained'
  end;
  if v_lock = 'pending' and current_setting('role', true) in ('authenticated', 'anon') then
    perform private.api_error(409, 'evidence_pending', 'File sedang diamankan sebagai bukti, coba lagi sebentar');
  elsif v_lock = 'retained' then
    perform private.api_error(409, 'evidence_retained', 'File bukti masih dalam masa simpan atau legal hold');
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger _05_evidence_pending_guard
before update or delete on storage.objects
for each row execute function private.evidence_pending_guard();

create or replace function private.storage_cleanup_queue_evidence_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.bucket_id = 'evidence'
     and (new.reason <> 'evidence_expired'
          or exists (select 1 from private.evidence e where e.id::text = split_part(new.prefix, '/', 1))) then
    perform private.api_error(403, 'evidence_protected',
      'File bukti karantina hanya dihapus setelah masa simpannya habis');
  end if;
  return new;
end;
$$;

create trigger storage_cleanup_queue_evidence_guard
before insert or update of bucket_id, prefix, reason on private.storage_cleanup_queue
for each row execute function private.storage_cleanup_queue_evidence_guard();

create or replace function public.storage_cleanup_claim(p_instance text, p_limit integer default 20,
                                                        p_objects integer default 1000,
                                                        p_lease_seconds integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entries jsonb;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance janitor tidak valid');
  end if;
  if coalesce(p_limit, 0) not between 1 and 100 or coalesce(p_objects, 0) not between 1 and 1000
     or coalesce(p_lease_seconds, 0) not between 30 and 3600 then
    perform private.api_error(400, 'invalid_claim', 'Batas claim di luar rentang');
  end if;
  with picked as (
    select q.id
    from private.storage_cleanup_queue q
    where q.done_at is null
      and q.available_at <= now()
      and (q.locked_until is null or q.locked_until < now())
      and not exists (
        select 1 from private.evidence_files f
        where f.status = 'pending' and f.source_bucket = q.bucket_id
          and (starts_with(f.source_name, q.prefix) or f.source_name = left(q.prefix, -1)))
      and not (q.bucket_id = 'evidence'
               and exists (select 1 from private.evidence e where e.id::text = split_part(q.prefix, '/', 1)))
    order by q.available_at, q.id
    limit p_limit
    for update skip locked
  ), claimed as (
    update private.storage_cleanup_queue q
       set locked_until = now() + make_interval(secs => p_lease_seconds), locked_by = p_instance
      from picked
     where q.id = picked.id
    returning q.id, q.bucket_id, q.prefix, q.queued_at
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'bucket', c.bucket_id, 'prefix', c.prefix,
           'objects', to_jsonb(private.storage_folder_objects(c.bucket_id, c.prefix, c.queued_at, p_objects)))
         order by c.id), '[]')
    into v_entries
  from claimed c;
  return v_entries;
end;
$$;

create or replace function public.evidence_copy_claim(p_instance text, p_limit integer default 20,
                                                      p_lease_seconds integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jobs jsonb;
begin
  if char_length(coalesce(p_instance, '')) not between 1 and 100 then
    perform private.api_error(400, 'invalid_instance', 'Nama instance janitor tidak valid');
  end if;
  if coalesce(p_limit, 0) not between 1 and 100 or coalesce(p_lease_seconds, 0) not between 30 and 3600 then
    perform private.api_error(400, 'invalid_claim', 'Batas claim di luar rentang');
  end if;
  with picked as (
    select f.id
    from private.evidence_files f
    where f.status = 'pending'
      and f.available_at <= now()
      and (f.locked_until is null or f.locked_until < now())
    order by f.available_at, f.id
    limit p_limit
    for update skip locked
  ), claimed as (
    update private.evidence_files f
       set locked_until = now() + make_interval(secs => p_lease_seconds), locked_by = p_instance
      from picked
     where f.id = picked.id
    returning f.id, f.source_bucket, f.source_name, f.object_name
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'source_bucket', c.source_bucket,
                                               'source_name', c.source_name, 'object_name', c.object_name)
                            order by c.id), '[]')
    into v_jobs
  from claimed c;
  return v_jobs;
end;
$$;

create or replace function public.evidence_copy_report(p_instance text, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r         record;
  f         private.evidence_files;
  v_error   text;
  v_size    bigint;
  v_updated integer := 0;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_results', 'Hasil janitor harus berupa array');
  end if;
  for r in
    select x.id, lower(btrim(coalesce(x.sha256, ''))) as sha256, x.size, coalesce(x.missing, false) as missing,
           nullif(btrim(coalesce(x.error, '')), '') as error, coalesce(x.release, false) as release
    from jsonb_to_recordset(p_results) as x(id bigint, sha256 text, size bigint, missing boolean, error text,
                                             release boolean)
  loop
    select * into f
    from private.evidence_files ef
    where ef.id = r.id and ef.locked_by = p_instance and ef.status = 'pending'
    for update;
    if not found then
      continue;
    end if;
    v_updated := v_updated + 1;
    v_error := r.error;
    if v_error is null and r.release then
      update private.evidence_files set locked_until = null, locked_by = null where id = f.id;
      continue;
    end if;
    if v_error is null and r.missing then
      if exists (select 1 from storage.objects o where o.bucket_id = f.source_bucket and o.name = f.source_name) then
        v_error := 'Storage melaporkan file sumber tidak ada, padahal objeknya masih tercatat';
      else
        update private.evidence_files
           set status = 'missing', locked_until = null, locked_by = null, error = null
         where id = f.id;
        perform private.evidence_log(f.evidence_id, 'file_missing', jsonb_build_object(
          'file_id', f.id, 'position', f.position, 'source_bucket', f.source_bucket, 'source_name', f.source_name));
        continue;
      end if;
    end if;
    if v_error is null then
      select (o.metadata ->> 'size')::bigint into v_size
      from storage.objects o
      where o.bucket_id = 'evidence' and o.name = f.object_name;
      if r.sha256 !~ '^[0-9a-f]{64}$' or r.size is null or r.size < 0 then
        v_error := 'Hash atau ukuran salinan tidak valid';
      elsif not found then
        v_error := 'Salinan bukti tidak ditemukan di storage';
      elsif v_size is not null and v_size <> r.size then
        v_error := 'Ukuran salinan bukti tidak cocok dengan storage';
      end if;
    end if;
    if v_error is null then
      update private.evidence_files
         set status = 'copied', sha256 = r.sha256, size = r.size, copied_at = now(),
             locked_until = null, locked_by = null, error = null
       where id = f.id;
      perform private.evidence_log(f.evidence_id, 'file_copied', jsonb_build_object(
        'file_id', f.id, 'position', f.position, 'object_name', f.object_name, 'sha256', r.sha256, 'size', r.size));
    elsif f.failures + 1 >= 30 then
      update private.evidence_files
         set status = 'failed', failures = f.failures + 1, error = left(v_error, 500),
             locked_until = null, locked_by = null
       where id = f.id;
      perform private.evidence_log(f.evidence_id, 'file_failed', jsonb_build_object(
        'file_id', f.id, 'position', f.position, 'error', left(v_error, 500), 'failures', f.failures + 1));
    else
      update private.evidence_files
         set failures = f.failures + 1, error = left(v_error, 500), locked_until = null, locked_by = null,
             available_at = now() + least(interval '6 hours', interval '1 minute' * power(2, least(f.failures, 12)))
                                    * (0.8 + random() * 0.4)
       where id = f.id;
    end if;
  end loop;
  return v_updated;
end;
$$;

create or replace function private.evidence_purge()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  e       record;
  v_count integer := 0;
begin
  for e in
    select x.id, x.seq, x.author_id, x.target_type, x.target_id, x.content_sha256,
           exists (select 1 from private.evidence_files f where f.evidence_id = x.id) as has_files
    from private.evidence x
    where x.retain_until < now() and not x.legal_hold
    order by x.retain_until
    limit 1000
    for update skip locked
  loop
    delete from private.evidence where id = e.id;
    if e.has_files then
      insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
      values ('evidence', e.id::text || '/', 'evidence_expired');
    end if;
    perform cs.audit('evidence.purged', null, e.author_id, jsonb_build_object(
      'evidence_id', e.id, 'code', 'EV-' || lpad(e.seq::text, 6, '0'), 'target_type', e.target_type,
      'target_id', e.target_id, 'content_sha256', e.content_sha256));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

select cron.schedule('evidence-purge', '33 3 * * *', 'select private.evidence_purge()');

create or replace function private.evidence_object_readable(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.current_agent_id() is not null
    and cs.has_role('{compliance,cs_super_admin}')
    and exists (
      select 1
      from private.evidence_files f
      join private.evidence_custody c on c.evidence_id = f.evidence_id
      where f.object_name = p_name and f.status = 'copied'
        and c.actor_id = auth.uid()
        and c.action in ('viewed', 'verified', 'exported')
        and c.at > now() - interval '15 minutes');
$$;

create policy evidence_quarantine_read on storage.objects for select to authenticated
  using (bucket_id = 'evidence' and (select private.evidence_object_readable(name)));

create or replace function cs.evidence_code(p_seq bigint)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'EV-' || lpad(p_seq::text, 6, '0');
$$;

create or replace function cs.evidence_actor(p_id uuid, p_type text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_id is null then null
    when exists (select 1 from cs.agents a where a.user_id = p_id) then
      (select jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code)
       from cs.agents a where a.user_id = p_id)
    else (select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username)
          from public.profiles p where p.id = p_id)
  end;
$$;

create or replace function cs.evidence_row(e private.evidence)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', e.id,
    'code', cs.evidence_code(e.seq),
    'seq', e.seq,
    'source', e.source,
    'target_type', e.target_type,
    'target_id', e.target_id,
    'author', coalesce(e.context -> 'author', case when e.author_id is not null then jsonb_build_object('id', e.author_id) end),
    'captured_at', e.captured_at,
    'retain_until', e.retain_until,
    'legal_hold', e.legal_hold,
    'hold', case when e.legal_hold then jsonb_build_object('reason', e.hold_reason, 'at', e.hold_at,
                                                           'by', cs.evidence_actor(e.hold_by, 'agent')) end,
    'files', (select jsonb_build_object('total', count(*),
                                        'copied', count(*) filter (where f.status = 'copied'),
                                        'pending', count(*) filter (where f.status = 'pending'),
                                        'missing', count(*) filter (where f.status = 'missing'),
                                        'failed', count(*) filter (where f.status = 'failed'))
              from private.evidence_files f where f.evidence_id = e.id),
    'links', (select count(*) from private.evidence_custody c
              where c.evidence_id = e.id and c.action in ('captured', 'linked')));
$$;

create or replace function cs.evidence_custody_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'at', c.at, 'action', c.action, 'actor_type', c.actor_type,
           'actor_roles', to_jsonb(c.actor_roles), 'actor', cs.evidence_actor(c.actor_id, c.actor_type),
           'details', c.details, 'entry_sha256', c.entry_sha256)
         order by c.id desc), '[]')
  from (select * from private.evidence_custody x where x.evidence_id = p_id order by x.id desc limit 1000) c;
$$;

create or replace function cs.evidence_files_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', f.id, 'position', f.position, 'bucket', 'evidence', 'object_name', f.object_name,
           'source_bucket', f.source_bucket, 'source_name', f.source_name, 'meta', f.meta, 'status', f.status,
           'sha256', f.sha256, 'size', f.size, 'copied_at', f.copied_at, 'failures', f.failures, 'error', f.error)
         order by f.position), '[]')
  from private.evidence_files f
  where f.evidence_id = p_id;
$$;

create or replace function cs.evidence_status(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.evidence_row(e) || jsonb_build_object('custody', cs.evidence_custody_view(e.id))
  from private.evidence e
  where e.id = p_id;
$$;

create or replace function cs.evidence_view(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select cs.evidence_row(e) || jsonb_build_object(
    'content', e.content,
    'context', e.context,
    'content_sha256', e.content_sha256,
    'body_sha256', e.body_sha256,
    'record_sha256', e.record_sha256,
    'captured_by', cs.evidence_actor(e.captured_by, null),
    'files_detail', cs.evidence_files_view(e.id),
    'custody', cs.evidence_custody_view(e.id),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at,
               'reporter', jsonb_build_object('id', p.id, 'username', p.username, 'display_name', p.display_name))
             order by r.created_at)
      from public.reports r
      left join public.profiles p on p.id = r.reporter_id
      where e.target_type in ('post', 'comment', 'message', 'user')
        and r.target_type = e.target_type
        and r.target_id::text = e.target_id), '[]'))
  from private.evidence e
  where e.id = p_id;
$$;

create or replace function cs.evidence_find(p_id uuid)
returns private.evidence
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e private.evidence;
begin
  select * into e from private.evidence x where x.id = p_id;
  if not found then
    perform private.api_error(404, 'evidence_not_found', 'Bukti tidak ditemukan');
  end if;
  return e;
end;
$$;

create or replace function cs_api.evidence_list(p_query text default null, p_filter text default null,
                                                p_source text default null, p_before_seq bigint default null,
                                                p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_term  text := nullif(btrim(coalesce(p_query, '')), '');
  v_seq   bigint;
  v_uuid  uuid;
  v_like  text;
  v_rows  jsonb;
  v_count integer;
  v_last  bigint;
begin
  if p_filter is not null and p_filter not in ('held', 'pending', 'problem', 'expiring') then
    perform private.api_error(400, 'invalid_filter', 'Filter: held, pending, problem, atau expiring');
  end if;
  if p_source is not null and p_source not in ('report', 'moderator_remove', 'system_remove', 'media_removed',
                                               'zero_tolerance') then
    perform private.api_error(400, 'invalid_source', 'Sumber bukti tidak dikenal');
  end if;
  if v_term ~* '^(ev-?)?[0-9]{1,12}$' then
    v_seq := regexp_replace(v_term, '[^0-9]', '', 'g')::bigint;
  elsif v_term ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_uuid := v_term::uuid;
  else
    v_like := cs.like_pattern(v_term);
  end if;
  select coalesce(jsonb_agg(cs.evidence_row(x.ev) order by x.seq desc), '[]'), count(*)
    into v_rows, v_count
  from (
    select e as ev, e.seq
    from private.evidence e
    where (p_before_seq is null or e.seq < p_before_seq)
      and (p_source is null or e.source = p_source)
      and (p_filter is null
           or (p_filter = 'held' and e.legal_hold)
           or (p_filter = 'expiring' and not e.legal_hold and e.retain_until < now() + interval '30 days')
           or (p_filter = 'pending' and exists (select 1 from private.evidence_files f
                                                where f.evidence_id = e.id and f.status = 'pending'))
           or (p_filter = 'problem' and exists (select 1 from private.evidence_files f
                                                where f.evidence_id = e.id and f.status in ('missing', 'failed'))))
      and (v_term is null
           or (v_seq is not null and e.seq = v_seq)
           or (v_uuid is not null and (e.id = v_uuid or e.author_id = v_uuid or e.target_id = v_uuid::text
                                       or exists (select 1 from private.evidence_custody c
                                                  where c.evidence_id = e.id
                                                    and c.details ? 'report_id'
                                                    and c.details ->> 'report_id' = v_uuid::text)))
           or (v_like is not null and (e.context -> 'author' ->> 'username' ilike v_like
                                       or e.context -> 'author' ->> 'display_name' ilike v_like
                                       or e.content ->> 'username' ilike v_like
                                       or e.target_id ilike v_like)))
    order by e.seq desc
    limit v_limit + 1
  ) x;
  if v_count > v_limit then
    v_rows := v_rows - v_limit;
    v_last := (v_rows -> (v_limit - 1) ->> 'seq')::bigint;
  else
    v_last := null;
  end if;
  return jsonb_build_object(
    'rows', v_rows,
    'next', case when v_last is not null then jsonb_build_object('before_seq', v_last) end,
    'can_manage', cs.has_role('{compliance}'),
    'summary', case when p_before_seq is null then (
      select jsonb_build_object(
        'total', count(*),
        'held', count(*) filter (where e.legal_hold),
        'expiring', count(*) filter (where not e.legal_hold and e.retain_until < now() + interval '30 days'),
        'pending_files', (select count(*) from private.evidence_files f where f.status = 'pending'),
        'problem_files', (select count(*) from private.evidence_files f where f.status in ('missing', 'failed')),
        'retention_days', greatest(private.setting_num('retention.evidence_days', 730)::integer, 1))
      from private.evidence e) end);
end;
$$;

create or replace function cs_api.evidence_detail(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance,cs_super_admin}');
  e    private.evidence := cs.evidence_find(p_id);
begin
  perform private.evidence_log(e.id, 'viewed');
  perform cs.audit('evidence.view', null, e.author_id,
                   jsonb_build_object('evidence_id', e.id, 'code', cs.evidence_code(e.seq)));
  return cs.evidence_view(e.id) || jsonb_build_object('can_manage', cs.has_role('{compliance}'));
end;
$$;

create or replace function cs_api.evidence_verify(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me        uuid := cs.require_agent('{compliance,cs_super_admin}');
  e           private.evidence := cs.evidence_find(p_id);
  c           private.evidence_custody;
  v_prev      text;
  v_broken    bigint;
  v_entries   integer := 0;
  v_files     jsonb;
  v_files_ok  boolean;
  v_content   boolean;
  v_body      boolean;
  v_record    boolean;
  v_result    jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('evidence:' || e.id::text, 0));
  v_content := e.content_sha256 = private.evidence_sha256(e.content::text);
  v_body := e.body_sha256 = private.evidence_sha256(e.content ->> 'body');
  v_record := e.record_sha256 = private.evidence_record_hash(e);
  for c in select * from private.evidence_custody x where x.evidence_id = e.id order by x.id loop
    v_entries := v_entries + 1;
    if v_broken is null and (c.prev_sha256 is distinct from v_prev
                             or c.entry_sha256 <> private.evidence_custody_hash(c)) then
      v_broken := c.id;
    end if;
    v_prev := c.entry_sha256;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', f.id, 'position', f.position, 'status', f.status, 'sha256', f.sha256, 'size', f.size,
           'object_exists', o.id is not null,
           'stored_size', (o.metadata ->> 'size')::bigint,
           'ok', f.status <> 'copied'
                 or (o.id is not null and coalesce((o.metadata ->> 'size')::bigint, f.size) = f.size))
         order by f.position), '[]'),
         coalesce(bool_and(f.status <> 'copied'
                           or (o.id is not null and coalesce((o.metadata ->> 'size')::bigint, f.size) = f.size)), true)
    into v_files, v_files_ok
  from private.evidence_files f
  left join storage.objects o on o.bucket_id = 'evidence' and o.name = f.object_name
  where f.evidence_id = e.id;
  v_result := jsonb_build_object(
    'ok', v_content and v_body and v_record and v_broken is null and v_files_ok,
    'content_ok', v_content,
    'body_ok', v_body,
    'record_ok', v_record,
    'custody_ok', v_broken is null,
    'custody_entries', v_entries,
    'custody_broken_at', v_broken,
    'files_ok', v_files_ok,
    'files', v_files,
    'checked_at', now());
  perform private.evidence_log(e.id, 'verified', v_result - 'files' - 'checked_at');
  perform cs.audit('evidence.verify', null, e.author_id,
                   jsonb_build_object('evidence_id', e.id, 'code', cs.evidence_code(e.seq), 'ok', v_result -> 'ok'));
  return v_result || jsonb_build_object('status', cs.evidence_status(e.id));
end;
$$;

create or replace function cs_api.evidence_file_checked(p_file_id bigint, p_sha256 text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_hash  text := lower(btrim(coalesce(p_sha256, '')));
  f       private.evidence_files;
  e       private.evidence;
  v_match boolean;
begin
  if v_hash !~ '^[0-9a-f]{64}$' then
    perform private.api_error(400, 'invalid_hash', 'Sidik file harus SHA-256 (64 karakter hex)');
  end if;
  select * into f from private.evidence_files x where x.id = p_file_id;
  if not found then
    perform private.api_error(404, 'evidence_file_not_found', 'File bukti tidak ditemukan');
  end if;
  if f.status <> 'copied' then
    perform private.api_error(409, 'evidence_file_not_copied', 'File bukti belum tersalin');
  end if;
  e := cs.evidence_find(f.evidence_id);
  v_match := f.sha256 = v_hash;
  perform private.evidence_log(e.id, 'file_verified', jsonb_build_object(
    'file_id', f.id, 'position', f.position, 'sha256', v_hash, 'match', v_match));
  perform cs.audit('evidence.file_verify', null, e.author_id, jsonb_build_object(
    'evidence_id', e.id, 'code', cs.evidence_code(e.seq), 'file_id', f.id, 'match', v_match));
  return jsonb_build_object('file_id', f.id, 'match', v_match, 'expected', f.sha256, 'actual', v_hash);
end;
$$;

create or replace function cs_api.evidence_set_hold(p_id uuid, p_hold boolean, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_reason text := btrim(coalesce(p_reason, ''));
  e        private.evidence;
begin
  if p_hold is null then
    perform private.api_error(400, 'invalid_hold', 'Pilih pasang atau lepas legal hold');
  end if;
  if char_length(v_reason) not between 10 and 500 then
    perform private.api_error(400, 'reason_required', 'Alasan legal hold 10–500 karakter');
  end if;
  perform cs.evidence_find(p_id);
  select * into e from private.evidence x where x.id = p_id for update;
  if e.legal_hold = p_hold then
    perform private.api_error(409, 'hold_unchanged',
      case when p_hold then 'Bukti ini sudah dalam legal hold' else 'Bukti ini tidak dalam legal hold' end);
  end if;
  update private.evidence
     set legal_hold = p_hold,
         hold_reason = case when p_hold then v_reason end,
         hold_by = case when p_hold then v_me end,
         hold_at = case when p_hold then now() end,
         retain_until = case when p_hold then retain_until else greatest(retain_until, now() + interval '30 days') end
   where id = e.id;
  perform private.evidence_log(e.id, case when p_hold then 'hold_set' else 'hold_released' end,
                               jsonb_build_object('reason', v_reason));
  perform cs.audit('evidence.legal_hold', null, e.author_id, jsonb_build_object(
    'evidence_id', e.id, 'code', cs.evidence_code(e.seq), 'hold', p_hold, 'reason', v_reason));
  return cs.evidence_status(e.id);
end;
$$;

create or replace function cs_api.evidence_export(p_id uuid, p_purpose text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{compliance}');
  v_purpose  text := btrim(coalesce(p_purpose, ''));
  e          private.evidence;
  v_manifest jsonb;
  v_hash     text;
begin
  if char_length(v_purpose) not between 5 and 500 then
    perform private.api_error(400, 'purpose_required', 'Tujuan ekspor 5–500 karakter');
  end if;
  e := cs.evidence_find(p_id);
  perform pg_advisory_xact_lock(hashtextextended('evidence:' || e.id::text, 0));
  v_manifest := jsonb_build_object(
    'format', 'olt-evidence-bundle/1',
    'hash_algorithm', 'SHA-256',
    'generated_at', private.evidence_time(now()),
    'generated_by', cs.evidence_actor(v_me, 'agent'),
    'purpose', v_purpose,
    'evidence', jsonb_build_object(
      'id', e.id, 'code', cs.evidence_code(e.seq), 'seq', e.seq, 'source', e.source,
      'target_type', e.target_type, 'target_id', e.target_id, 'author_id', e.author_id,
      'captured_at', private.evidence_time(e.captured_at), 'captured_by', e.captured_by,
      'retain_until', private.evidence_time(e.retain_until), 'legal_hold', e.legal_hold,
      'hold_reason', e.hold_reason, 'content', e.content, 'context', e.context,
      'content_sha256', e.content_sha256, 'body_sha256', e.body_sha256, 'record_sha256', e.record_sha256),
    'files', (select coalesce(jsonb_agg(jsonb_build_object(
                'position', f.position, 'bucket', 'evidence', 'object_name', f.object_name,
                'source_bucket', f.source_bucket, 'source_name', f.source_name, 'meta', f.meta, 'status', f.status,
                'sha256', f.sha256, 'size', f.size,
                'copied_at', case when f.copied_at is not null then private.evidence_time(f.copied_at) end)
              order by f.position), '[]')
              from private.evidence_files f where f.evidence_id = e.id),
    'custody', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', c.id, 'at', private.evidence_time(c.at), 'actor_id', c.actor_id, 'actor_type', c.actor_type,
                  'actor_roles', to_jsonb(c.actor_roles), 'action', c.action, 'details', c.details,
                  'prev_sha256', c.prev_sha256, 'entry_sha256', c.entry_sha256)
                order by c.id), '[]')
                from private.evidence_custody c where c.evidence_id = e.id),
    'reports', coalesce(cs.evidence_view(e.id) -> 'reports', '[]'));
  v_hash := private.evidence_sha256(v_manifest::text);
  perform private.evidence_log(e.id, 'exported', jsonb_build_object('purpose', v_purpose, 'manifest_sha256', v_hash));
  perform cs.audit('evidence.export', null, e.author_id, jsonb_build_object(
    'evidence_id', e.id, 'code', cs.evidence_code(e.seq), 'purpose', v_purpose, 'manifest_sha256', v_hash));
  return v_manifest || jsonb_build_object('manifest_sha256', v_hash);
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select x.id, x.target_type, x.target_id, x.reporter_id, x.reason
    from public.reports x
    where x.status in ('open', 'reviewing')
    order by x.created_at
  loop
    perform private.evidence_capture_target('report', r.target_type, r.target_id, r.reporter_id,
      jsonb_build_object('report_id', r.id, 'reason', r.reason, 'backfill', true));
  end loop;
  for r in
    select a.*
    from private.content_archive a
    where a.reason in ('moderator_remove', 'policy_block') and a.target_type in ('post', 'comment', 'message')
      and (a.retain_until is null or a.retain_until > now())
    order by a.deleted_at
  loop
    perform private.evidence_capture(
      case r.reason when 'policy_block' then 'system_remove' else 'moderator_remove' end,
      r.target_type, r.target_id::text, r.author_id, r.body,
      case when r.target_type = 'comment' then '[]'::jsonb else coalesce(r.attachments, '[]') end, null,
      jsonb_build_object('archive', jsonb_build_object('id', r.id, 'reason', r.reason, 'category', r.category,
                                                       'deleted_by', r.deleted_by, 'deleted_at', r.deleted_at)),
      r.deleted_by, jsonb_build_object('archive_id', r.id, 'reason', r.reason, 'backfill', true));
  end loop;
end;
$$;

revoke all on private.evidence, private.evidence_files, private.evidence_custody from public, anon, authenticated;

revoke execute on function private.evidence_sha256(text) from public;
revoke execute on function private.evidence_time(timestamptz) from public;
revoke execute on function private.evidence_record_hash(private.evidence) from public;
revoke execute on function private.evidence_custody_hash(private.evidence_custody) from public;
revoke execute on function private.evidence_before_insert() from public;
revoke execute on function private.evidence_guard() from public;
revoke execute on function private.evidence_files_guard() from public;
revoke execute on function private.evidence_custody_guard() from public;
revoke execute on function private.evidence_log(uuid, text, jsonb, uuid) from public;
revoke execute on function private.evidence_profile(uuid) from public;
revoke execute on function private.evidence_avatar_path(text) from public;
revoke execute on function private.evidence_capture(text, text, text, uuid, text, jsonb, jsonb, jsonb, uuid, jsonb)
  from public;
revoke execute on function private.evidence_capture_target(text, text, uuid, uuid, jsonb) from public;
revoke execute on function private.evidence_on_report() from public;
revoke execute on function private.evidence_on_archive() from public;
revoke execute on function private.evidence_on_media_removed() from public;
revoke execute on function private.evidence_on_zero_tolerance() from public;
revoke execute on function private.evidence_pending_guard() from public;
revoke execute on function private.storage_cleanup_queue_evidence_guard() from public;
revoke execute on function private.evidence_purge() from public;
revoke execute on function private.evidence_object_readable(text) from public;
revoke execute on function cs.evidence_code(bigint) from public;
revoke execute on function cs.evidence_actor(uuid, text) from public;
revoke execute on function cs.evidence_row(private.evidence) from public;
revoke execute on function cs.evidence_custody_view(uuid) from public;
revoke execute on function cs.evidence_files_view(uuid) from public;
revoke execute on function cs.evidence_status(uuid) from public;
revoke execute on function cs.evidence_view(uuid) from public;
revoke execute on function cs.evidence_find(uuid) from public;
revoke execute on function public.storage_cleanup_claim(text, integer, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.evidence_copy_claim(text, integer, integer) from public, anon, authenticated;
revoke execute on function public.evidence_copy_report(text, jsonb) from public, anon, authenticated;
revoke execute on function cs_api.evidence_list(text, text, text, bigint, integer) from public;
revoke execute on function cs_api.evidence_detail(uuid) from public;
revoke execute on function cs_api.evidence_verify(uuid) from public;
revoke execute on function cs_api.evidence_file_checked(bigint, text) from public;
revoke execute on function cs_api.evidence_set_hold(uuid, boolean, text) from public;
revoke execute on function cs_api.evidence_export(uuid, text) from public;

grant execute on function private.evidence_object_readable(text) to authenticated;
grant execute on function public.storage_cleanup_claim(text, integer, integer, integer) to service_role;
grant execute on function public.evidence_copy_claim(text, integer, integer) to service_role;
grant execute on function public.evidence_copy_report(text, jsonb) to service_role;
grant execute on function cs_api.evidence_list(text, text, text, bigint, integer) to authenticated;
grant execute on function cs_api.evidence_detail(uuid) to authenticated;
grant execute on function cs_api.evidence_verify(uuid) to authenticated;
grant execute on function cs_api.evidence_file_checked(bigint, text) to authenticated;
grant execute on function cs_api.evidence_set_hold(uuid, boolean, text) to authenticated;
grant execute on function cs_api.evidence_export(uuid, text) to authenticated;
