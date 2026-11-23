alter table private.integration_keys
  add column deleted_at timestamptz,
  add column deleted_by uuid,
  add constraint integration_keys_delete_revoked check (deleted_at is null or revoked_at is not null);

create or replace function cs_api.integration_keys()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  return coalesce((
    select jsonb_agg(cs.integration_key_view(k.id) order by k.revoked_at nulls first, k.created_at desc)
    from private.integration_keys k
    where k.deleted_at is null), '[]');
end;
$$;

create or replace function cs_api.integration_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_super_admin}');
  v_days  integer := greatest(1, least(coalesce(p_days, 7), 90));
  v_from  date := private.integration_day() - (v_days - 1);
  v_since timestamptz := v_from::timestamp at time zone 'Asia/Jakarta';
  v_link  integer := private.setting_num('integration.account_link_days', 30)::integer;
begin
  return jsonb_build_object(
    'days', v_days,
    'from', v_from,
    'keys', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', k.id, 'name', k.name, 'prefix', k.prefix, 'scopes', to_jsonb(k.scopes),
               'status', case when k.revoked_at is not null then 'revoked'
                              when k.disabled_at is not null then 'disabled' else 'active' end,
               'last_used_at', k.last_used_at,
               'received', coalesce(d.received, 0), 'queued', coalesce(d.queued, 0),
               'devices', coalesce(d.devices, 0), 'no_recipient', coalesce(d.no_recipient, 0),
               'duplicate', coalesce(d.duplicate, 0), 'invalid', coalesce(d.invalid, 0),
               'posts', coalesce(d.posts, 0), 'posts_rejected', coalesce(d.posts_rejected, 0),
               'accepted', coalesce(d.accepted, 0), 'inbox', coalesce(d.inbox, 0),
               'broadcasts', jsonb_build_object(
                 'total', coalesce(bc.total, 0), 'active', coalesce(bc.active, 0), 'done', coalesce(bc.done, 0),
                 'failed', coalesce(bc.failed, 0), 'recipients', coalesce(bc.recipients, 0),
                 'devices', coalesce(bc.devices, 0), 'inbox', coalesce(bc.inbox, 0),
                 'capped', coalesce(bc.capped, 0), 'pref_skipped', coalesce(bc.pref_skipped, 0)),
               'push', jsonb_build_object(
                 'sent', coalesce(s.sent, 0), 'failed', coalesce(s.failed, 0), 'invalid', coalesce(s.invalid, 0),
                 'expired', coalesce(s.expired, 0) + coalesce(s.cancelled, 0),
                 'pending', (select count(*) from private.push_queue q
                             where q.status = 'queued' and q.expires_at > now()
                               and q.ref like 'olt:' || k.id::text || ':%')))
             order by k.revoked_at nulls first, k.created_at desc)
      from private.integration_keys k
      left join lateral (
        select sum(x.received) as received, sum(x.queued) as queued, sum(x.devices) as devices,
               sum(x.no_recipient) as no_recipient, sum(x.duplicate) as duplicate, sum(x.invalid) as invalid,
               sum(x.posts) as posts, sum(x.posts_rejected) as posts_rejected, sum(x.accepted) as accepted,
               sum(x.inbox) as inbox
        from private.integration_daily x where x.key_id = k.id and x.day >= v_from) d on true
      left join lateral (
        select count(*) as total, count(*) filter (where b.status in ('queued', 'sending')) as active,
               count(*) filter (where b.status = 'done') as done, count(*) filter (where b.status = 'failed') as failed,
               sum(b.recipients) as recipients, sum(b.devices) as devices, sum(b.inbox) as inbox,
               sum(b.capped) as capped, sum(b.pref_skipped) as pref_skipped
        from private.integration_broadcasts b where b.key_id = k.id and b.created_at >= v_since) bc on true
      left join lateral (
        select sum(r.sent) as sent, sum(r.failed) as failed, sum(r.invalid) as invalid, sum(r.expired) as expired,
               sum(r.cancelled) as cancelled
        from private.push_ref_stats r
        where r.ref in (select private.integration_ref(k.id, v_from + i) from generate_series(0, v_days - 1) i)) s on true
      where k.deleted_at is null
        and k.scopes && array['notify', 'bot_post']
        and (k.revoked_at is null or k.revoked_at > v_from or d.received is not null or d.posts is not null)), '[]'),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', x.day, 'received', x.received, 'queued', x.queued,
                                          'no_recipient', x.no_recipient, 'posts', x.posts,
                                          'accepted', x.accepted) order by x.day)
      from (select y.day, sum(y.received) as received, sum(y.queued) as queued, sum(y.no_recipient) as no_recipient,
                   sum(y.posts) as posts, sum(y.accepted) as accepted
            from private.integration_daily y where y.day >= v_from group by y.day) x), '[]'),
    'broadcasts', (
      select jsonb_build_object(
               'total', count(*), 'active', count(*) filter (where b.status in ('queued', 'sending')),
               'done', count(*) filter (where b.status = 'done'), 'failed', count(*) filter (where b.status = 'failed'),
               'recipients', coalesce(sum(b.recipients), 0), 'devices', coalesce(sum(b.devices), 0),
               'inbox', coalesce(sum(b.inbox), 0), 'capped', coalesce(sum(b.capped), 0),
               'pref_skipped', coalesce(sum(b.pref_skipped), 0))
      from private.integration_broadcasts b where b.created_at >= v_since),
    'linked', (
      select jsonb_build_object('accounts', count(distinct l.cust_id), 'profiles', count(distinct l.profile_id))
      from private.account_links l
      where l.seen_at > now() - make_interval(days => v_link)));
end;
$$;

create or replace function cs_api.integration_key_delete(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
  k    private.integration_keys;
begin
  select * into k from private.integration_keys where id = p_id for update;
  if not found or k.deleted_at is not null then
    perform private.api_error(404, 'key_not_found', 'API key tidak ditemukan');
  end if;
  if k.revoked_at is null then
    perform private.api_error(409, 'key_not_revoked', 'Cabut API key dulu sebelum menghapusnya');
  end if;
  update private.integration_keys set deleted_at = now(), deleted_by = v_me where id = p_id;
  perform cs.audit('integration.key_delete', null, null,
    jsonb_build_object('key_id', k.id, 'name', k.name, 'prefix', k.prefix, 'scopes', to_jsonb(k.scopes)));
  return jsonb_build_object('id', k.id, 'deleted', true);
end;
$$;

revoke execute on function cs_api.integration_key_delete(uuid) from public;
grant execute on function cs_api.integration_key_delete(uuid) to authenticated;
