-- Struktur skema & hak akses dasar.
begin;
select plan(12);

select tables_are('public', array[
  'appeals', 'banned_words', 'blocks', 'bookmarks', 'chat_members', 'chat_rooms', 'comments', 'follows',
  'legal_documents', 'link_previews', 'message_reactions', 'messages', 'muted_keywords', 'muted_stocks',
  'mutes', 'notifications', 'post_drafts', 'post_hashtags', 'post_mentions', 'post_poll_options', 'post_poll_votes',
  'post_polls', 'post_stocks', 'posts', 'profiles', 'reactions', 'reports',
  'stock_watchers', 'user_consents'
], 'Tabel public sesuai skema');

select is(
  (select count(*)::int
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname in ('public', 'private') and c.relkind = 'r' and not c.relrowsecurity),
  0, 'RLS aktif di semua tabel public & private');

select is(
  (select count(*)::int
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and (has_table_privilege('anon', c.oid, 'SELECT')
          or has_table_privilege('anon', c.oid, 'INSERT')
          or has_table_privilege('anon', c.oid, 'UPDATE')
          or has_table_privilege('anon', c.oid, 'DELETE'))),
  0, 'anon tidak punya hak apa pun di tabel public');

select is(
  (select count(*)::int
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'EXECUTE')
     and p.oid <> 'public.get_client_config(text,text)'::regprocedure),
  0, 'anon tidak bisa memanggil RPC apa pun selain konfigurasi klien');
select ok(
  has_function_privilege('anon', 'public.get_client_config(text,text)', 'EXECUTE'),
  'Konfigurasi klien (kill switch, versi minimum) bisa dibaca sebelum login');

select ok(
  not has_function_privilege('authenticated', 'public.upsert_olt_profile(uuid,text,text,text,text)', 'EXECUTE'),
  'upsert_olt_profile tidak bisa dipanggil user');
select ok(
  has_function_privilege('service_role', 'public.upsert_olt_profile(uuid,text,text,text,text)', 'EXECUTE'),
  'upsert_olt_profile bisa dipanggil service_role (auth-bridge)');
select ok(
  not has_column_privilege('authenticated', 'public.profiles', 'olt_user_id', 'SELECT'),
  'olt_user_id tidak bisa dibaca user');
select ok(
  not has_table_privilege('authenticated', 'public.banned_words', 'SELECT'),
  'Daftar kata terlarang tidak bisa dibaca user');

select has_index('public', 'comments', 'comments_path_gist_idx', 'Index GiST pada comments.path');
select has_index('public', 'comments', 'comments_post_path_idx', 'Index (post_id, path) pada comments');

select is(
  (select count(distinct action)::int from private.rate_limits where action in ('post', 'comment')),
  2, 'Rate limit post & komentar terkonfigurasi');

select * from finish();
rollback;
