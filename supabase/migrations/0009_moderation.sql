-- 0009_moderation.sql
-- Laporan konten/user dan antrean moderasi.
-- Moderator menindaklanjuti lewat Studio (service role): lihat private.report_queue,
-- hapus konten dengan delete_post/delete_comment/delete_message, lalu ubah status laporan.

create table if not exists public.reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null references public.profiles(id) on delete cascade,
  target_type     text not null,
  target_id       uuid not null,
  reason          text not null,
  details         text,
  status          text not null default 'open',
  resolution_note text,
  resolved_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint reports_target_type check (target_type in ('post', 'comment', 'message', 'user')),
  constraint reports_reason check (
    reason in ('spam', 'abuse', 'scam', 'pump_and_dump', 'misinformation', 'other')
  ),
  constraint reports_details_length check (char_length(details) <= 1000),
  constraint reports_status check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  -- Satu laporan per user per target.
  constraint reports_unique_target unique (reporter_id, target_type, target_id)
);
create index if not exists reports_status_idx on public.reports (status, created_at);
create index if not exists reports_target_idx on public.reports (target_type, target_id);
create index if not exists reports_reporter_created_idx on public.reports (reporter_id, created_at desc);

create or replace trigger reports_set_updated_at
  before update on public.reports
  for each row execute function private.set_updated_at();

-- Target laporan harus ada dan terlihat oleh pelapor.
create or replace function private.reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exists boolean;
begin
  v_exists := case new.target_type
    when 'post'    then exists (select 1 from public.posts where id = new.target_id)
    when 'comment' then exists (select 1 from public.comments where id = new.target_id)
    when 'message' then exists (
      select 1 from public.messages m
      join public.chat_members cm on cm.room_id = m.room_id and cm.user_id = new.reporter_id
      where m.id = new.target_id)
    when 'user'    then exists (select 1 from public.profiles where id = new.target_id)
  end;
  if not coalesce(v_exists, false) then
    perform private.api_error(404, 'target_not_found', 'Konten yang dilaporkan tidak ditemukan');
  end if;
  new.details := nullif(btrim(new.details), '');
  return new;
end;
$$;

create or replace trigger reports_10_rate_limit
  before insert on public.reports
  for each row execute function private.enforce_rate_limit('report', 'reporter_id');
create or replace trigger reports_20_before_insert
  before insert on public.reports
  for each row execute function private.reports_before_insert();

alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;
grant select on public.reports to authenticated;
grant insert (reporter_id, target_type, target_id, reason, details) on public.reports to authenticated;

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()));
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

-- Antrean moderasi: target dengan laporan terbuka, diurutkan dari yang paling
-- banyak dilaporkan. Hanya untuk Studio / service role.
create or replace view private.report_queue
with (security_invoker = true)
as
select r.target_type,
       r.target_id,
       count(*)                          as report_count,
       array_agg(distinct r.reason)      as reasons,
       min(r.created_at)                 as first_reported_at,
       max(r.created_at)                 as last_reported_at,
       coalesce(p.body, c.body, m.body, '@' || pr.username::text) as content,
       coalesce(p.author_id, c.author_id, m.sender_id, pr.id)     as author_id
from public.reports r
left join public.posts p    on r.target_type = 'post'    and p.id = r.target_id
left join public.comments c on r.target_type = 'comment' and c.id = r.target_id
left join public.messages m on r.target_type = 'message' and m.id = r.target_id
left join public.profiles pr on r.target_type = 'user'   and pr.id = r.target_id
where r.status in ('open', 'reviewing')
group by r.target_type, r.target_id, p.body, c.body, m.body, pr.username,
         p.author_id, c.author_id, m.sender_id, pr.id
order by count(*) desc, max(r.created_at) desc;

revoke all on private.report_queue from public, anon, authenticated;

revoke all on all functions in schema private from public;
revoke execute on all functions in schema public from public, anon;
