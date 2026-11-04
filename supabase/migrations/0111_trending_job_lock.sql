create or replace function private.trending_tick()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buckets integer;
begin
  perform pg_advisory_xact_lock(hashtext('private.trending'));
  v_buckets := private.trending_refresh(now() - interval '1 hour');
  return private.trending_compute() || jsonb_build_object('buckets', v_buckets);
end;
$$;

create or replace function private.trending_rebuild()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buckets integer;
  v_purged  integer;
begin
  perform pg_advisory_xact_lock(hashtext('private.trending'));
  v_buckets := private.trending_refresh(now() - interval '15 days');
  delete from private.stock_mention_buckets
   where bucket < now() - make_interval(days => private.setting_num('trending.bucket_retention_days', 35)::integer);
  get diagnostics v_purged = row_count;
  return private.trending_compute() || jsonb_build_object('buckets', v_buckets, 'purged', v_purged);
end;
$$;

revoke execute on function private.trending_tick() from public;
revoke execute on function private.trending_rebuild() from public;
