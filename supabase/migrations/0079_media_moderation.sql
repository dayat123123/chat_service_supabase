create or replace function private.media_categories()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['drawings', 'hentai', 'neutral', 'porn', 'sexy'];
$$;

create or replace function private.media_thresholds_problem(p_thresholds jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_key   text;
  v_value jsonb;
  v_hold  numeric;
  v_block numeric;
begin
  if jsonb_typeof(p_thresholds) is distinct from 'object' then
    return 'not_object';
  end if;
  for v_key, v_value in select e.key, e.value from jsonb_each(p_thresholds) e loop
    if not (v_key = any (private.media_categories())) then
      return 'unknown_category:' || v_key;
    end if;
    if jsonb_typeof(v_value) = 'null' then
      continue;
    end if;
    if jsonb_typeof(v_value) <> 'object'
       or exists (select 1 from jsonb_object_keys(v_value) k where k not in ('hold', 'block'))
       or coalesce(jsonb_typeof(v_value -> 'hold'), 'null') not in ('number', 'null')
       or coalesce(jsonb_typeof(v_value -> 'block'), 'null') not in ('number', 'null') then
      return 'invalid_limits:' || v_key;
    end if;
    v_hold := (v_value ->> 'hold')::numeric;
    v_block := (v_value ->> 'block')::numeric;
    if v_hold not between 0 and 1 or v_block not between 0 and 1 then
      return 'out_of_range:' || v_key;
    end if;
    if v_hold > v_block then
      return 'hold_above_block:' || v_key;
    end if;
  end loop;
  if coalesce(p_thresholds #>> '{porn,hold}', p_thresholds #>> '{porn,block}') is null then
    return 'porn_required';
  end if;
  return null;
end;
$$;

create or replace function private.media_thresholds_normalize(p_thresholds jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(x.key, x.value order by x.key), '{}')
  from (
    select e.key, jsonb_strip_nulls(e.value) as value
    from jsonb_each(p_thresholds) e
    where jsonb_typeof(e.value) = 'object'
  ) x
  where x.value <> '{}';
$$;

create table private.media_moderation (
  singleton  boolean primary key default true check (singleton),
  revision   bigint not null default 1,
  thresholds jsonb not null check (private.media_thresholds_problem(thresholds) is null),
  updated_by uuid,
  updated_at timestamptz not null default now()
);
alter table private.media_moderation enable row level security;

insert into private.media_moderation (singleton, thresholds) values (true, jsonb_build_object(
  'porn', jsonb_build_object('hold', 0.5, 'block', 0.9),
  'hentai', jsonb_build_object('hold', 0.6, 'block', 0.95),
  'sexy', jsonb_build_object('hold', 0.85)));

create table private.media_reviews (
  id                  bigint generated always as identity primary key,
  bucket              text not null check (bucket = 'attachments'),
  name                text not null check (char_length(name) between 3 and 1024),
  uploader            uuid not null,
  status              text not null default 'pending' check (status in ('pending', 'approved', 'removed')),
  model               text not null check (char_length(model) between 1 and 200),
  scores              jsonb not null check (jsonb_typeof(scores) = 'object' and pg_column_size(scores) <= 2048),
  category            text not null check (category ~ '^[a-z][a-z0-9_]{0,31}$'),
  score               numeric(5, 4) not null check (score between 0 and 1),
  thresholds_revision bigint,
  created_at          timestamptz not null default now(),
  decided_by          uuid,
  decided_at          timestamptz,
  note                text check (char_length(note) <= 500),
  stripped            jsonb not null default '[]',
  object_deleted_at   timestamptz,
  constraint media_reviews_object unique (bucket, name),
  constraint media_reviews_decided check ((status = 'pending') = (decided_at is null))
);
create index media_reviews_status_idx on private.media_reviews (status, id);
create index media_reviews_uploader_idx on private.media_reviews (uploader);
alter table private.media_reviews enable row level security;

create or replace function private.media_visible(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not exists (
      select 1 from private.media_reviews r
      where r.bucket = p_bucket and r.name = p_name and r.object_deleted_at is null
        and (r.status = 'removed' or (r.status = 'pending' and r.uploader is distinct from (select auth.uid()))))
      then true
    else cs.has_community('{community.moderate}')
  end;
$$;

create or replace function private.media_review_readable(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from private.media_reviews r where r.bucket = p_bucket and r.name = p_name)
      then cs.has_community('{community.moderate}')
    else false
  end;
$$;

alter policy olt_attachments_read on storage.objects
  using (
    bucket_id = 'attachments'
    and (
      (storage.foldername(name))[1] = 'posts'
      or ((storage.foldername(name))[1] = 'rooms' and private.is_room_member_text((storage.foldername(name))[2]))
    )
    and private.media_visible(bucket_id, name)
  );

alter policy olt_cs_attachments_read on storage.objects
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = 'rooms'
    and cs.can_read_room_text((storage.foldername(name))[2])
    and private.media_visible(bucket_id, name)
  );

create policy olt_media_review_read on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and private.media_review_readable(bucket_id, name));

create or replace function private.media_review_object_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.media_reviews r
     set object_deleted_at = now()
   where r.bucket = old.bucket_id and r.name = old.name and r.object_deleted_at is null;
  return null;
end;
$$;

create trigger _60_media_review_object_deleted after delete on storage.objects
  for each row when (old.bucket_id = 'attachments') execute function private.media_review_object_deleted();

create or replace function private.storage_folder_objects(p_bucket text, p_prefix text, p_before timestamptz,
                                                         p_limit integer)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(o.name order by o.name collate "C"), '{}')
  from (
    select o.name
    from storage.objects o
    where o.bucket_id = p_bucket
      and ((o.name collate "C" >= p_prefix
            and o.name collate "C" < left(p_prefix, -1) || '0'
            and starts_with(o.name, p_prefix))
           or o.name = left(p_prefix, -1))
      and o.created_at <= p_before
    order by o.name collate "C"
    limit p_limit
  ) o;
$$;

create or replace function public.media_moderation_config(p_revision bigint default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_revision is not distinct from m.revision then jsonb_build_object('revision', m.revision, 'unchanged', true)
    else jsonb_build_object('revision', m.revision, 'thresholds', m.thresholds, 'updated_at', m.updated_at)
  end
  from private.media_moderation m
  where m.singleton;
$$;

create or replace function public.media_hold(p_bucket text, p_name text, p_uploader uuid, p_model text,
                                             p_scores jsonb, p_category text, p_score numeric,
                                             p_revision bigint default null)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
  v_id    bigint;
begin
  if p_bucket is distinct from 'attachments' then
    perform private.api_error(400, 'bucket_not_holdable', 'Hanya lampiran yang bisa ditahan untuk ditinjau');
  end if;
  if p_uploader is null or char_length(coalesce(p_name, '')) not between 3 and 1024 or position('..' in p_name) > 0
     or not ((v_parts[1] = 'posts' and v_parts[2] = p_uploader::text and cardinality(v_parts) >= 3)
             or (v_parts[1] = 'rooms' and v_parts[3] = p_uploader::text and cardinality(v_parts) >= 4)) then
    perform private.api_error(403, 'not_owner', 'Lokasi file bukan milik pengunggah');
  end if;
  if jsonb_typeof(p_scores) is distinct from 'object' or pg_column_size(p_scores) > 2048
     or char_length(coalesce(p_model, '')) not between 1 and 200
     or p_score is null or p_score not between 0 and 1
     or coalesce(p_category, '') !~ '^[a-z][a-z0-9_]{0,31}$' then
    perform private.api_error(400, 'invalid_review', 'Hasil klasifikasi tidak valid');
  end if;
  if exists (select 1 from storage.objects o where o.bucket_id = p_bucket and o.name = p_name) then
    perform private.api_error(409, 'already_exists', 'File dengan nama yang sama sudah ada');
  end if;
  insert into private.media_reviews as r (bucket, name, uploader, model, scores, category, score, thresholds_revision)
  values (p_bucket, p_name, p_uploader, p_model, p_scores, p_category, round(p_score, 4), p_revision)
  on conflict (bucket, name) do update
     set uploader = excluded.uploader, status = 'pending', model = excluded.model, scores = excluded.scores,
         category = excluded.category, score = excluded.score, thresholds_revision = excluded.thresholds_revision,
         created_at = now(), decided_by = null, decided_at = null, note = null, stripped = '[]',
         object_deleted_at = null
  returning r.id into v_id;
  return v_id;
end;
$$;

create or replace function public.media_hold_cancel(p_id bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows integer;
begin
  delete from private.media_reviews r
   where r.id = p_id and r.status = 'pending'
     and not exists (select 1 from storage.objects o where o.bucket_id = r.bucket and o.name = r.name);
  get diagnostics v_rows = row_count;
  return v_rows > 0;
end;
$$;

create or replace function cs.media_thresholds_view()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'revision', m.revision, 'thresholds', m.thresholds, 'categories', to_jsonb(private.media_categories()),
    'updated_at', m.updated_at, 'updated_by', cs.agent_name(m.updated_by))
  from private.media_moderation m
  where m.singleton;
$$;

create or replace function cs_api.compliance_image_thresholds()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  return cs.media_thresholds_view();
end;
$$;

create or replace function cs_api.compliance_set_image_thresholds(p_thresholds jsonb, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_problem text := private.media_thresholds_problem(p_thresholds);
  v_new     jsonb;
  v_old     jsonb;
begin
  if v_problem is not null then
    perform private.api_error(400, 'invalid_image_thresholds', v_problem);
  end if;
  if char_length(coalesce(p_note, '')) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 500 karakter');
  end if;
  v_new := private.media_thresholds_normalize(p_thresholds);
  select m.thresholds into v_old from private.media_moderation m where m.singleton for update;
  if v_old is distinct from v_new then
    update private.media_moderation m
       set thresholds = v_new, revision = m.revision + 1, updated_by = v_me, updated_at = now()
     where m.singleton;
    perform cs.audit('media.thresholds_set', null, null, jsonb_strip_nulls(jsonb_build_object(
      'from', v_old, 'to', v_new, 'note', nullif(btrim(coalesce(p_note, '')), ''))));
  end if;
  return cs.media_thresholds_view();
end;
$$;

create or replace function cs.media_review_view(p_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id, 'bucket', r.bucket, 'path', r.name, 'status', r.status, 'category', r.category,
    'score', r.score, 'scores', r.scores, 'model', r.model, 'thresholds_revision', r.thresholds_revision,
    'created_at', r.created_at, 'decided_at', r.decided_at, 'decided_by', cs.agent_name(r.decided_by),
    'note', r.note, 'stripped', r.stripped,
    'object_exists', r.object_deleted_at is null
                     and exists (select 1 from storage.objects o where o.bucket_id = r.bucket and o.name = r.name),
    'uploader', jsonb_build_object('id', r.uploader, 'username', p.username, 'display_name', p.display_name,
                                   'deleted', p.deleted_at is not null),
    'used_in', coalesce((
        select jsonb_agg(jsonb_build_object('type', 'post', 'id', po.id, 'created_at', po.created_at,
                                            'deleted', po.deleted_at is not null) order by po.created_at)
        from public.posts po
        where (string_to_array(r.name, '/'))[1] = 'posts' and po.author_id = r.uploader
          and po.attachments @> jsonb_build_array(jsonb_build_object('path', r.name))), '[]')
      || coalesce((
        select jsonb_agg(jsonb_build_object('type', 'message', 'id', m.id, 'room_id', m.room_id, 'room_type', c.type,
                                            'created_at', m.created_at, 'deleted', m.deleted_at is not null)
                         order by m.created_at)
        from public.messages m
        join public.chat_rooms c on c.id = m.room_id
        where (string_to_array(r.name, '/'))[1] = 'rooms' and m.room_id::text = (string_to_array(r.name, '/'))[2]
          and m.sender_id = r.uploader
          and m.attachments @> jsonb_build_array(jsonb_build_object('path', r.name))), '[]'))
  from private.media_reviews r
  left join public.profiles p on p.id = r.uploader
  where r.id = p_id;
$$;

create or replace function cs_api.community_media_reviews(p_status text default 'pending', p_cursor bigint default null,
                                                           p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_community('{community.moderate}');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_ids   bigint[];
begin
  if coalesce(p_status, '') not in ('pending', 'approved', 'removed') then
    perform private.api_error(400, 'invalid_status', 'Status: pending, approved, atau removed');
  end if;
  select array_agg(x.id order by x.ord) into v_ids
  from (
    select r.id, row_number() over (order by case when p_status = 'pending' then r.id else -r.id end) as ord
    from private.media_reviews r
    where r.status = p_status
      and (p_status <> 'pending' or r.object_deleted_at is null)
      and (p_cursor is null
           or (p_status = 'pending' and r.id > p_cursor)
           or (p_status <> 'pending' and r.id < p_cursor))
    order by case when p_status = 'pending' then r.id else -r.id end
    limit v_limit + 1
  ) x;
  v_ids := coalesce(v_ids, '{}');
  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(cs.media_review_view(i.id) order by i.ord)
                       from unnest(v_ids[1:v_limit]) with ordinality as i(id, ord)), '[]'),
    'next_cursor', case when cardinality(v_ids) > v_limit then v_ids[v_limit] end,
    'pending', (select count(*) from private.media_reviews r where r.status = 'pending' and r.object_deleted_at is null));
end;
$$;

create or replace function private.media_strip_references(p_review private.media_reviews)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parts    text[] := string_to_array(p_review.name, '/');
  v_item     jsonb := jsonb_build_array(jsonb_build_object('path', p_review.name));
  v_stripped jsonb := '[]';
  v_rows     jsonb;
begin
  if v_parts[1] = 'posts' then
    with changed as (
      update public.posts po
         set attachments = (select coalesce(jsonb_agg(e.value order by e.ordinality), '[]')
                            from jsonb_array_elements(po.attachments) with ordinality e
                            where e.value ->> 'path' is distinct from p_review.name
                               or coalesce(e.value ->> 'bucket', 'attachments') <> p_review.bucket)
       where po.author_id = p_review.uploader and po.attachments @> v_item
      returning po.id)
    select coalesce(jsonb_agg(jsonb_build_object('type', 'post', 'id', c.id)), '[]') into v_rows from changed c;
    v_stripped := v_stripped || v_rows;
  elsif v_parts[1] = 'rooms' then
    with changed as (
      update public.messages m
         set attachments = (select coalesce(jsonb_agg(e.value order by e.ordinality), '[]')
                            from jsonb_array_elements(m.attachments) with ordinality e
                            where e.value ->> 'path' is distinct from p_review.name
                               or coalesce(e.value ->> 'bucket', 'attachments') <> p_review.bucket)
       where m.room_id::text = v_parts[2] and m.sender_id = p_review.uploader and m.session_id is null
         and m.attachments @> v_item
      returning m.id, m.room_id)
    select coalesce(jsonb_agg(jsonb_build_object('type', 'message', 'id', c.id, 'room_id', c.room_id)), '[]')
      into v_rows from changed c;
    v_stripped := v_stripped || v_rows;
  end if;
  return v_stripped;
end;
$$;

create or replace function cs_api.community_media_review_decide(p_id bigint, p_decision text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_community('{community.moderate}');
  v_review   private.media_reviews;
  v_note     text := nullif(btrim(coalesce(p_note, '')), '');
  v_stripped jsonb := '[]';
begin
  if coalesce(p_decision, '') not in ('approve', 'remove') then
    perform private.api_error(400, 'invalid_decision', 'Keputusan: approve atau remove');
  end if;
  if char_length(coalesce(v_note, '')) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan maksimal 500 karakter');
  end if;
  if p_decision = 'remove' and char_length(coalesce(v_note, '')) < 5 then
    perform private.api_error(400, 'reason_required', 'Alasan penghapusan 5–500 karakter');
  end if;
  select * into v_review from private.media_reviews r where r.id = p_id for update;
  if not found then
    perform private.api_error(404, 'media_review_not_found', 'Gambar tidak ada di antrean');
  end if;
  if v_review.status <> 'pending' then
    perform private.api_error(409, 'media_review_decided', 'Gambar ini sudah diputuskan');
  end if;
  if p_decision = 'remove' then
    v_stripped := private.media_strip_references(v_review);
    if v_review.object_deleted_at is null then
      insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
      values (v_review.bucket, v_review.name || '/', 'media_removed');
    end if;
  end if;
  update private.media_reviews r
     set status = case when p_decision = 'approve' then 'approved' else 'removed' end,
         decided_by = v_me, decided_at = now(), note = v_note, stripped = v_stripped
   where r.id = p_id;
  perform cs.audit('community.media_' || p_decision, null, v_review.uploader, jsonb_strip_nulls(jsonb_build_object(
    'review_id', v_review.id, 'path', v_review.name, 'category', v_review.category, 'score', v_review.score,
    'note', v_note, 'stripped', case when p_decision = 'remove' then v_stripped end)));
  return cs.media_review_view(p_id);
end;
$$;

create or replace function private.media_reviews_purge()
returns integer
language sql
security definer
set search_path = ''
as $$
  with gone as (
    delete from private.media_reviews r
     where r.object_deleted_at < now() - interval '90 days'
        or (r.status = 'approved' and r.decided_at < now() - interval '180 days')
        or (r.status = 'pending' and r.object_deleted_at is null and r.created_at < now() - interval '1 day'
            and not exists (select 1 from storage.objects o where o.bucket_id = r.bucket and o.name = r.name))
    returning 1)
  select count(*)::integer from gone;
$$;

select cron.schedule('media-reviews-purge', '53 3 * * *', 'select private.media_reviews_purge()');

revoke execute on function private.media_categories() from public;
revoke execute on function private.media_thresholds_problem(jsonb) from public;
revoke execute on function private.media_thresholds_normalize(jsonb) from public;
revoke execute on function private.media_visible(text, text) from public;
revoke execute on function private.media_review_readable(text, text) from public;
revoke execute on function private.media_review_object_deleted() from public;
revoke execute on function private.storage_folder_objects(text, text, timestamptz, integer) from public;
revoke execute on function private.media_strip_references(private.media_reviews) from public;
revoke execute on function private.media_reviews_purge() from public;
revoke execute on function public.media_moderation_config(bigint) from public, anon, authenticated;
revoke execute on function public.media_hold(text, text, uuid, text, jsonb, text, numeric, bigint)
  from public, anon, authenticated;
revoke execute on function public.media_hold_cancel(bigint) from public, anon, authenticated;
revoke execute on function cs.media_thresholds_view() from public;
revoke execute on function cs.media_review_view(bigint) from public;
revoke execute on function cs_api.compliance_image_thresholds() from public;
revoke execute on function cs_api.compliance_set_image_thresholds(jsonb, text) from public;
revoke execute on function cs_api.community_media_reviews(text, bigint, integer) from public;
revoke execute on function cs_api.community_media_review_decide(bigint, text, text) from public;

grant execute on function private.media_visible(text, text) to authenticated;
grant execute on function private.media_review_readable(text, text) to authenticated;
grant execute on function public.media_moderation_config(bigint) to service_role;
grant execute on function public.media_hold(text, text, uuid, text, jsonb, text, numeric, bigint) to service_role;
grant execute on function public.media_hold_cancel(bigint) to service_role;
grant execute on function cs_api.compliance_image_thresholds() to authenticated;
grant execute on function cs_api.compliance_set_image_thresholds(jsonb, text) to authenticated;
grant execute on function cs_api.community_media_reviews(text, bigint, integer) to authenticated;
grant execute on function cs_api.community_media_review_decide(bigint, text, text) to authenticated;
