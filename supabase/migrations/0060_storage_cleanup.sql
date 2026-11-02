alter table private.storage_cleanup_queue
  add column available_at  timestamptz not null default now(),
  add column locked_until  timestamptz,
  add column locked_by     text check (char_length(locked_by) <= 100),
  add column failures      integer not null default 0,
  add column deleted_count integer not null default 0,
  add column error         text check (char_length(error) <= 500),
  add constraint storage_cleanup_queue_prefix
    check (prefix ~ '^[^/]+(/[^/]+)*/$' and char_length(prefix) <= 1024);

create index storage_cleanup_queue_ready_idx on private.storage_cleanup_queue (available_at, id) where done_at is null;
create index storage_cleanup_queue_done_idx on private.storage_cleanup_queue (done_at) where done_at is not null;

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
      and o.name collate "C" >= p_prefix
      and o.name collate "C" < left(p_prefix, -1) || '0'
      and starts_with(o.name, p_prefix)
      and o.created_at <= p_before
    order by o.name collate "C"
    limit p_limit
  ) o;
$$;

create or replace function private.queue_user_files(p_user_id uuid, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  with rooms as (
    select m.room_id from public.messages m where m.sender_id = p_user_id
    union
    select cm.room_id from public.chat_members cm where cm.user_id = p_user_id
    union
    select r.id from public.chat_rooms r where r.type = 'support' and r.customer_id = p_user_id
  )
  insert into private.storage_cleanup_queue (bucket_id, prefix, reason)
  select 'avatars', p_user_id::text || '/', p_reason
  union all
  select 'attachments', 'posts/' || p_user_id::text || '/', p_reason
  union all
  select 'attachments', 'rooms/' || r.room_id::text || '/' || p_user_id::text || '/', p_reason
  from rooms r
  union all
  select 'cs-documents', 'rooms/' || r.room_id::text || '/' || p_user_id::text || '/', p_reason
  from rooms r
  join public.chat_rooms c on c.id = r.room_id and c.type = 'support';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.delete_my_account()
returns void
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
  if not exists (select 1 from public.profiles where id = v_uid and deleted_at is null) then
    perform private.api_error(404, 'user_not_found', 'Akun tidak ditemukan');
  end if;

  perform private.queue_user_files(v_uid, 'account_delete');

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'post', id, author_id, body, attachments, v_uid, 'account_delete'
  from public.posts where author_id = v_uid and deleted_at is null;
  update public.posts set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, deleted_by, reason)
  select 'comment', id, author_id, body, v_uid, 'account_delete'
  from public.comments where author_id = v_uid and deleted_at is null;
  update public.comments set deleted_at = now(), body = ''
   where author_id = v_uid and deleted_at is null;

  insert into private.content_archive (target_type, target_id, author_id, body, attachments, deleted_by, reason)
  select 'message', id, sender_id, body, attachments, v_uid, 'account_delete'
  from public.messages where sender_id = v_uid and deleted_at is null;
  update public.messages set deleted_at = now(), body = '', attachments = '[]'::jsonb
   where sender_id = v_uid and deleted_at is null;

  delete from public.reactions where user_id = v_uid;
  delete from public.follows where follower_id = v_uid or following_id = v_uid;
  delete from public.blocks where blocker_id = v_uid or blocked_id = v_uid;
  delete from public.mutes where muter_id = v_uid or muted_id = v_uid;
  delete from public.muted_keywords where user_id = v_uid;
  delete from public.muted_stocks where user_id = v_uid;
  delete from public.stock_watchers where user_id = v_uid;
  delete from public.chat_members where user_id = v_uid;
  delete from public.notifications where user_id = v_uid or actor_id = v_uid;
  delete from public.user_consents where user_id = v_uid;
  delete from private.user_private where user_id = v_uid;

  update public.profiles
     set username = 'deleted_' || substr(md5(id::text), 1, 12),
         display_name = null, bio = null, avatar_url = null,
         is_verified = false, deleted_at = now()
   where id = v_uid;

  perform private.revoke_sessions(v_uid, 'account_delete');
  perform private.log_personal_data_access(v_uid, 'account_delete', '{all}');
end;
$$;

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

create or replace function public.storage_cleanup_report(p_instance text, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r         record;
  v_left    boolean;
  v_error   text;
  v_updated integer := 0;
  v_rows    integer;
begin
  if jsonb_typeof(p_results) is distinct from 'array' then
    perform private.api_error(400, 'invalid_results', 'Hasil janitor harus berupa array');
  end if;
  for r in
    select x.id, greatest(coalesce(x.deleted, 0), 0) as deleted, nullif(btrim(coalesce(x.error, '')), '') as error,
           coalesce(x.release, false) as release
    from jsonb_to_recordset(p_results) as x(id bigint, deleted integer, error text, release boolean)
  loop
    select exists (
      select 1 from private.storage_cleanup_queue q
      where q.id = r.id
        and private.storage_folder_objects(q.bucket_id, q.prefix, q.queued_at, 1) <> '{}'
    ) into v_left;
    v_error := r.error;
    if v_error is null and not r.release and v_left and r.deleted = 0 then
      v_error := 'Objek tidak terhapus oleh layanan storage';
    end if;
    update private.storage_cleanup_queue q
       set deleted_count = q.deleted_count + r.deleted,
           locked_until = null,
           locked_by = null,
           failures = case when v_error is not null then q.failures + 1 when r.release then q.failures else 0 end,
           error = case when v_error is null and r.release then q.error else left(v_error, 500) end,
           available_at = case
             when v_error is null then now()
             else now() + least(interval '6 hours', interval '1 minute' * power(2, least(q.failures, 12)))
                        * (0.8 + random() * 0.4)
           end,
           done_at = case when v_error is null and not r.release and not v_left then now() end
     where q.id = r.id and q.locked_by = p_instance and q.done_at is null;
    get diagnostics v_rows = row_count;
    v_updated := v_updated + v_rows;
  end loop;
  return v_updated;
end;
$$;

create or replace function private.storage_cleanup_purge()
returns integer
language sql
security definer
set search_path = ''
as $$
  with gone as (
    delete from private.storage_cleanup_queue q where q.done_at < now() - interval '90 days' returning 1)
  select count(*)::integer from gone;
$$;

select cron.schedule('storage-cleanup-purge', '27 3 * * *', 'select private.storage_cleanup_purge()');

revoke execute on function private.storage_folder_objects(text, text, timestamptz, integer) from public;
revoke execute on function private.queue_user_files(uuid, text) from public;
revoke execute on function private.storage_cleanup_purge() from public;
revoke execute on function public.storage_cleanup_claim(text, integer, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.storage_cleanup_report(text, jsonb) from public, anon, authenticated;

grant execute on function public.storage_cleanup_claim(text, integer, integer, integer) to service_role;
grant execute on function public.storage_cleanup_report(text, jsonb) to service_role;
