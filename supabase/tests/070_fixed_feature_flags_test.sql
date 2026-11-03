begin;
select plan(17);

select tests.create_agent('Sinta FF', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina FF', '{cs_agent}', '{"general": 1}') as rina \gset

select is(private.known_feature_flags(),
  array['search', 'trending', 'bookmarks', 'post_edit', 'message_reactions', 'share_post_to_chat', 'notification_prefs', 'analytics'],
  'Daftar fitur tetap berisi delapan kunci yang dibaca aplikasi');
select is((select count(*)::integer from private.feature_flags where key = any (private.known_feature_flags())), 8,
  'Semua fitur yang dikenal tersedia di tabel');
select is((select count(*)::integer from private.feature_flags where not (key = any (private.known_feature_flags()))), 0,
  'Tidak ada flag di luar daftar tetap');

update private.feature_flags set percentage = 40, platforms = '{ios}', min_app_version = '2.0.0', description = 'Deskripsi uji'
 where key = 'bookmarks';

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_toggle_feature_flag('bookmarks', false)$$, 'PT403', 'role_forbidden',
  'Agen CS tidak bisa menyalakan atau mematikan fitur');
reset role;

select tests.authenticate_agent(:'sinta');
select is((select jsonb_agg(f ->> 'key') from jsonb_array_elements(cs_api.admin_feature_flags() -> 'flags') f),
  '["search", "trending", "bookmarks", "post_edit", "message_reactions", "share_post_to_chat", "notification_prefs", "analytics"]'::jsonb,
  'Daftar fitur untuk Super Admin mengikuti urutan tetap');
select throws_ok($$select cs_api.admin_toggle_feature_flag('beta.baru', true)$$, 'PT400', 'unknown_flag',
  'Fitur di luar daftar tidak bisa dibuat lewat sakelar');
select throws_ok($$select cs_api.admin_set_feature_flag('beta.baru', true)$$, 'PT400', 'unknown_flag',
  'Fitur baru tidak bisa dibuat lewat RPC lama');
select throws_ok($$select cs_api.admin_toggle_feature_flag('bookmarks', null)$$, 'PT400', 'invalid_flag',
  'Status sakelar wajib diisi');
select throws_ok($$select cs_api.admin_delete_feature_flag('bookmarks')$$, 'PT400', 'flag_not_deletable',
  'Fitur tidak bisa dihapus');
select throws_ok($$select cs_api.admin_delete_feature_flag('beta.baru')$$, 'PT400', 'flag_not_deletable',
  'Penghapusan selalu ditolak');
select ok(cs_api.admin_toggle_feature_flag(' Bookmarks ', false) -> 'flags' @> '[{"key": "bookmarks", "enabled": false}]',
  'Super Admin mematikan fitur');
reset role;

select is((select row(enabled, percentage, platforms, min_app_version, description)::text
           from private.feature_flags where key = 'bookmarks'),
  row(false, 40, '{ios}'::text[], '2.0.0', 'Deskripsi uji')::text, 'Sakelar hanya mengubah status aktif');
select is((select details #>> '{before,enabled}' || '>' || (details #>> '{after,enabled}') from cs.cs_audit_log
           where action = 'feature_flag.set' and details ->> 'key' = 'bookmarks' order by id desc limit 1),
  'true>false', 'Perubahan sakelar tercatat di audit');
select is((select count(*)::integer from private.feature_flags where key = 'bookmarks'), 1, 'Fitur tetap ada setelah ditolak dihapus');

select tests.authenticate_agent(:'sinta');
select ok(cs_api.admin_toggle_feature_flag('bookmarks', true) -> 'flags' @> '[{"key": "bookmarks", "enabled": true}]',
  'Super Admin menyalakan kembali fitur');
select lives_ok($$select cs_api.admin_set_feature_flag('trending', true, 100)$$, 'RPC lama tetap jalan untuk fitur yang dikenal');
reset role;

select ok(not has_function_privilege('anon', 'cs_api.admin_toggle_feature_flag(text,boolean)', 'EXECUTE'),
  'Anonim tidak bisa memakai sakelar fitur');

select * from finish();
rollback;
