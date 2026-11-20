delete from private.settings where key = 'trust.new_account_hours';

update private.settings
   set description = 'Masa akun baru (hari sejak daftar atau bergabung lagi): tanpa gambar, tanpa tautan, DM ke non-mutual lewat permintaan pesan, batas kecepatan dikali rate_limit.new_account_factor. 0 = tanpa batasan'
 where key = 'safety.new_account_days';

update private.settings
   set description = 'Pengali batas rate limit selama masa akun baru (safety.new_account_days)'
 where key = 'rate_limit.new_account_factor';

create or replace function private.is_new_account(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.trust_level <= 1
       and greatest(
             case when p.trust_level = 0 then p.created_at end,
             (select s.signed_up_at from private.account_signups s where s.user_id = p.id)
           ) > now() - private.setting_num('safety.new_account_days', 3) * interval '1 day'
    from public.profiles p
    where p.id = p_user), false);
$$;

create or replace function private.rate_limit_factor(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when p.trust_level >= 2 then private.setting_num('rate_limit.trusted_factor', 2)
      when private.is_new_account(p.id) then private.setting_num('rate_limit.new_account_factor', 0.5)
      else 1
    end
    from public.profiles p where p.id = p_user
  ), 1);
$$;

create or replace function private.promote_new_accounts()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.profiles p
     set trust_level = 1
   where p.trust_level = 0
     and p.deleted_at is null
     and p.created_at <= now() - private.setting_num('safety.new_account_days', 3) * interval '1 day'
     and not private.has_active_sanction(p.id, '{mute,ban}');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function private.is_new_account(uuid) from public;
revoke execute on function private.rate_limit_factor(uuid) from public;
revoke execute on function private.promote_new_accounts() from public;
