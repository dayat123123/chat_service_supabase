#!/usr/bin/env bash
# Hapus data uji beban/keamanan: profil lt_* (cascade ke postingan, pesan, notifikasi, keanggotaan room,
# watchlist, dll.), room saham uji ($LTHOT, $LTPOST, $PROBE), direct room yang semua anggotanya lt_*,
# kode saham/agregat trending/alert manipulasi untuk kode uji, dan baris tanpa FK yang memuat id lt_*.
# Tabel audit/bukti/log (append-only) tidak disentuh; key integrasi uji yang sudah dicabut dibiarkan
# sebagai jejak audit. Dry run: cleanup.sh --dry-run
set -uo pipefail
source /olt/tests/lib/common.sh

CODES="'LTHOT','LTPOST','PROBE'"
mode=commit
[ "${1:-}" = --dry-run ] && mode=rollback
n=$(sql "select count(*) from public.profiles where username like 'lt\_%'")
log "profil lt_*: $n (mode $mode)"
psql -X -v ON_ERROR_STOP=1 <<SQL
begin;
create temp table lt_ids on commit drop as select id from public.profiles where username like 'lt\_%';
create temp table lt_rooms on commit drop as
  select r.id from public.chat_rooms r
  where (r.type = 'stock' and r.stock_code in ($CODES))
     or (r.type in ('direct', 'group') and exists (select 1 from public.chat_members m where m.room_id = r.id)
         and not exists (select 1 from public.chat_members m where m.room_id = r.id and m.user_id not in (select id from lt_ids)));
select 'room uji: ' || count(*) from lt_rooms;
select 'pesan lt_* di room lain: ' || count(*) from public.messages where sender_id in (select id from lt_ids) and room_id not in (select id from lt_rooms);
delete from public.messages where sender_id in (select id from lt_ids);
delete from public.chat_rooms where id in (select id from lt_rooms);
do \$\$
declare
  r record;
  v_count bigint;
begin
  for r in
    select c.table_schema, c.table_name, c.column_name
    from information_schema.columns c join information_schema.tables t using (table_schema, table_name)
    where t.table_type = 'BASE TABLE' and c.data_type = 'uuid'
      and c.table_schema in ('public', 'private', 'cs')
      and c.column_name in ('user_id', 'profile_id', 'author_id', 'actor_id', 'sender_id', 'target_user_id', 'recipient_id', 'follower_id', 'following_id', 'blocker_id', 'blocked_id', 'muter_id', 'muted_id')
      and c.table_name !~ '(audit|evidence|_log$|logs|history|archive)'
      and not (c.table_schema = 'public' and c.table_name = 'profiles')
  loop
    begin
      execute format('delete from %I.%I where %I in (select id from lt_ids)', r.table_schema, r.table_name, r.column_name);
      get diagnostics v_count = row_count;
      if v_count > 0 then raise notice 'hapus %.%.% : %', r.table_schema, r.table_name, r.column_name, v_count; end if;
    exception when others then
      raise notice 'lewati %.% (%): %', r.table_schema, r.table_name, r.column_name, sqlerrm;
    end;
  end loop;
end
\$\$;
delete from public.profiles where id in (select id from lt_ids);
delete from cs.manipulation_alerts where stock in ($CODES);
delete from public.stock_watchers where stock_code in ($CODES);
delete from private.stock_mention_buckets where stock_code in ($CODES);
delete from private.stock_codes where code in ($CODES);
select 'sisa profil lt_*: ' || count(*) from public.profiles where username like 'lt\_%';
$mode;
SQL
