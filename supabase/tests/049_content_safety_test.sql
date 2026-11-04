begin;
select plan(175);
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
update cs.cs_settings set value = 'false' where key = 'compliance.policy_four_eyes';

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message', 'room_create');
delete from public.banned_words;
insert into public.banned_words (word, action) values
  ('bokep', 'block'), ('goblok', 'mask'), ('anjing', 'mask'), ('jaminan profit', 'block'), ('asu', 'mask'),
  ('pasti cuan', 'block'), ('bandar', 'mask');
insert into cs.policy_allowlist (term) values ('bandar saham');

create function pg_temp.blocked(p_text text)
returns boolean
language plpgsql
as $$
begin
  perform private.apply_content_policy(p_text);
  return false;
exception when sqlstate 'PT422' then
  return true;
end;
$$;

create function pg_temp.action(p_text text, p_surface text default 'post')
returns text
language sql
as $$
  select private.evaluate_content(p_text, p_surface) ->> 'action';
$$;

select ok(pg_temp.blocked(x), 'Penyamaran kata blokir tertangkap: ' || x)
from unnest(array[
  'b.o.k.e.p', 'b o k e p', 'b-o-k-e-p', 'b_o_k_e_p', 'b*o*k*e*p', 'B0K3P', 'b0kep gratis', 'bokeeeeep',
  'bOkEp', 'ｂｏｋｅｐ', 'ⓑⓞⓚⓔⓟ', 'вокер', E'bo​kep', 'bokép', 'b . o . k . e . p', 'b..o..k..e..p',
  'nonton b 0 k 3 p', 'jaminan pr0fit', 'j@minan profit', 'jaminan  profit', 'JAMINAN-PROFIT',
  'j a m i n a n p r o f i t', 'p4sti cu4n', 'pasti cuuuuan', 'PASTI CUAN 100%']) x;

select is(private.apply_content_policy(x[1]), x[2], 'Kata sensor tersamar disensor: ' || x[1])
from (values
  (array['dasar g0bl0k', 'dasar ******']),
  (array['kamu a.s.u ya', 'kamu *.*.* ya']),
  (array['anjjjjing lu', '********* lu']),
  (array['ANJING', '******']),
  (array['ini ａｎｊｉｎｇ', 'ini ******']),
  (array['g o b l o k banget', '* * * * * * banget']),
  (array['bandar judi', '****** judi'])) v(x);

select is(private.apply_content_policy(x), x, 'Obrolan saham wajar tidak diubah: ' || x)
from unnest(array[
  '$BBCA naik 5%', 'TP 9.250', 'cut loss di 8.900', 'ARA lagi besok', 'ARB dua hari berturut-turut',
  'masuk di 455, keluar 480', 'beli 10 lot BBRI', 'IHSG -1.2% hari ini', 'jam 08:55-09:30 ramai',
  'support 4.5 resistance 5.1', 'TF 15m dan 4h bullish', '2x lipat dari harga IPO', 'PER 12x masih murah',
  'BBCA.JK masuk indeks', 'masuk pasar pagi', 'target s.d. akhir bulan', 'average down di 1.000',
  'profit taking dulu', 'dividen yield 5,3%', 'PT Asuransi Sinarmas', 'saham anjlok parah', '@budi_santoso setuju',
  'bandar saham sedang akumulasi', 'cuan tipis tapi pasti', 'GOTO 1 2 3 lot']) x;

select ok(pg_temp.action(x) = 'hold', 'Kontak/pemendek ditahan di postingan: ' || x)
from unnest(array[
  'hubungi 0812-3456-7890', 'WA 0812 3456 7890', '+62 812-3456-7890', 'call 6281234567890', '(0812) 3456-7890',
  '0 8 1 2 3 4 5 6 7 8 9 0', 'wa.me/6281234567890', 'chat.whatsapp.com/AbCdEf', 't.me/grupcuan',
  'telegram.me/grupcuan', 'discord.gg/abc', 'line.me/ti/p/abc', 'bit.ly/3abc', 's.id/promo', 'tinyurl.com/xyz',
  'cutt.ly/abc', 'shorturl.at/abc', 'https://t.co/abc', 'T.ME/GRUPCUAN', 't[.]me/grup', 'bit(.)ly/abc',
  'wa(dot)me/628', 'ｔ．ｍｅ/grup', 'cek https://bit.ly/x?utm=1']) x;

select ok(pg_temp.action(x) = 'block', 'Tautan/promosi terlarang diblokir: ' || x)
from unnest(array[
  'daftar di slot88gacor.xyz', 'https://www.sbobet.com', 'main togelmaxwin.net', 'xvideos.com/abc',
  'grabify.link/abc', 'slot88 [dot] com', 'join grup vip sekarang', 'sinyal berbayar murah', 'J0IN PREMIUM',
  'g r u p v i p', 'situs bokep.site']) x;

select is(private.evaluate_content(x, 'post') - 'body',
          '{"action": "allow", "links": false, "categories": []}'::jsonb, 'Teks saham wajar lolos: ' || x)
from unnest(array[
  '$BBCA naik 5%', 'TP 9.250', 'cut loss', 'ARA', 'ARB', 'BBCA.JK naik', 'jam 08:55-09:30', 'harga 0.85 x 1000 lot',
  'order 2.500 lot di 8.125', 'nah.in aja', 'Rp 1.250.000', 'IHSG 7.012,45', 'cek idx.co.id/berita',
  'rilis ojk.go.id hari ini', 'grup diskusi saham', 'sinyal teknikal bagus']) x;

select is(private.evaluate_content('baca kontan.co.id/news', 'post') - 'body',
  '{"action": "allow", "links": true, "categories": []}'::jsonb, 'Tautan lain diizinkan tetapi tercatat sebagai tautan');
select is(pg_temp.action('hubungi 0812-3456-7890', 'direct'), 'allow', 'Nomor HP di DM tidak ditahan (cakupan publik)');
select is(pg_temp.action('cek bit.ly/x', 'group'), 'allow', 'Pemendek di grup privat tidak ditahan');
select is(pg_temp.action('main sbobet.com', 'direct'), 'block', 'Situs judi diblokir juga di DM');
select is(pg_temp.action('join t.me/x', 'stock'), 'hold', 'Tautan Telegram di room saham ditahan');
select is(private.extract_hosts('https://www.Slot88Gacor.xyz/daftar?ref=1 dan s.id/x'), '{s.id,slot88gacor.xyz}'::text[],
  'Domain diekstrak dengan dan tanpa skema');

select tests.create_user('cs_rina') as rina \gset
select tests.create_user('cs_lina') as lina \gset
select tests.create_user('cs_baru') as baru \gset
select tests.create_user('cs_mira') as mira \gset
select tests.create_user('cs_resmi') as resmi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 1}') as nadia \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';
update public.profiles set trust_level = 0 where id = :'baru';
insert into private.account_signups (user_id, signed_up_at) values (:'mira', now() - interval '1 day');
insert into cs.official_accounts (profile_id) values (:'resmi');

select ok(private.is_new_account(:'baru') and private.is_new_account(:'mira') and not private.is_new_account(:'rina'),
  'Akun baru: trust 0 atau terdaftar < 3 hari');
insert into public.profiles (id, olt_user_id, username, display_name, trust_level)
values ('a1690000-0000-4000-8000-000000000001', 'test:signup', 'cs_daftar', 'Daftar', 0);
select ok(exists (select 1 from private.account_signups where user_id = 'a1690000-0000-4000-8000-000000000001'),
  'Pendaftaran akun trust 0 tercatat untuk masa akun baru');

select tests.authenticate_as(:'rina');
select join_stock_room('KMSF') as stock_room \gset
select get_or_create_direct_room(:'lina') as dm \gset
insert into posts (id, author_id, body) values ('a1690000-0000-4000-8000-000000000011', auth.uid(), 'Info lengkap hubungi 0812-3456-7890');
insert into posts (id, author_id, body) values ('a1690000-0000-4000-8000-000000000012', auth.uid(), 'Analisa $KMSF naik 5%, TP 9.250');
select is((select moderation_status from posts where id = 'a1690000-0000-4000-8000-000000000011'), 'held',
  'Postingan bernomor HP ditahan untuk ditinjau');
select is((select moderation_status from posts where id = 'a1690000-0000-4000-8000-000000000012'), 'visible',
  'Postingan saham wajar langsung tampil');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'daftar slot88gacor.xyz bonus')$$,
  'PT422', 'link_blocked', 'Tautan judi ditolak dengan kode umum');
select is(tests.error_detail($$insert into posts (author_id, body) values (auth.uid(), 'daftar slot88gacor.xyz')$$),
  'Tautan ini tidak diizinkan.', 'Pesan error tidak membocorkan kategori atau daftar');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'Ayo join grup vip kami')$$,
  'PT422', 'content_blocked', 'Frasa promosi diblokir');
select throws_ok(format($$insert into messages (room_id, sender_id, body) values (%L, auth.uid(), 'main sbobet.com yuk')$$, :'dm'),
  'PT422', 'link_blocked', 'Tautan judi di DM ditolak');
insert into messages (id, room_id, sender_id, body)
values ('a1690000-0000-4000-8000-000000000021', :'dm', auth.uid(), 'nomorku 0812-3456-7890');
select is((select moderation_status from messages where id = 'a1690000-0000-4000-8000-000000000021'), 'visible',
  'Nomor HP di DM tetap terkirim');
insert into messages (room_id, sender_id, body) values (:'stock_room', auth.uid(), 'diskusi KMSF dibuka');
insert into messages (id, room_id, sender_id, body)
values ('a1690000-0000-4000-8000-000000000022', :'stock_room', auth.uid(), 'gabung t.me/kmsfcuan');
select is((select moderation_status from messages where id = 'a1690000-0000-4000-8000-000000000022'), 'held',
  'Tautan Telegram di room saham ditahan');
select is((select last_message_preview from chat_rooms where id = :'stock_room'), 'diskusi KMSF dibuka',
  'Cuplikan room tidak memuat pesan yang ditahan');
insert into comments (id, post_id, author_id, body)
values ('a1690000-0000-4000-8000-000000000031', 'a1690000-0000-4000-8000-000000000012', auth.uid(), 'cek bit.ly/kmsf @cs_lina');
select is((select moderation_status from comments where id = 'a1690000-0000-4000-8000-000000000031'), 'held',
  'Komentar berisi pemendek ditahan');
update posts set body = 'Revisi: info di s.id/kmsf' where id = 'a1690000-0000-4000-8000-000000000012';
select is((select moderation_status from posts where id = 'a1690000-0000-4000-8000-000000000012'), 'held',
  'Suntingan yang menambah pemendek ikut ditahan');

reset role;
select is((select categories from private.content_flags where target_id = 'a1690000-0000-4000-8000-000000000011'),
  '{phone}'::text[], 'Alasan penahanan tercatat untuk staf');
select is((select count(*)::int from notifications where user_id = :'lina' and type = 'mention'), 0,
  'Mention di komentar yang ditahan tidak dikirim');

select tests.authenticate_as(:'lina');
select is((select count(*)::int from posts where id = 'a1690000-0000-4000-8000-000000000011'), 0,
  'Postingan yang ditahan tidak terlihat orang lain');
select is((select count(*)::int from posts where id = 'a1690000-0000-4000-8000-000000000011' and author_id = :'rina'), 0,
  'Termasuk lewat filter penulis');

select tests.authenticate_as(:'baru');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'baca kontan.co.id/news')$$,
  'PT403', 'new_account_restricted', 'Akun baru tidak boleh membagikan tautan');
select is(tests.error_detail($$insert into posts (author_id, body) values (auth.uid(), 'baca kontan.co.id/news')$$),
  'link', 'Detail error menyebut jenis pembatasan');
select is(tests.error_detail(format($$insert into posts (author_id, body, attachments) values (auth.uid(), 'grafik', %L)$$,
                                    jsonb_build_array(jsonb_build_object('path', 'posts/' || :'baru' || '/g.png')))),
  'image', 'Akun baru tidak boleh melampirkan gambar');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'rilis resmi di idx.co.id')$$,
  'Domain tepercaya tetap boleh untuk akun baru');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'Halo semua, salam kenal $BBCA')$$,
  'Akun baru tetap bisa menulis teks biasa');

select tests.authenticate_as(:'mira');
select throws_ok($$insert into posts (author_id, body) values (auth.uid(), 'cek kontan.co.id')$$,
  'PT403', 'new_account_restricted', 'Akun trust 1 yang baru mendaftar juga dibatasi');

select tests.authenticate_as(:'resmi');
insert into posts (id, author_id, body) values ('a1690000-0000-4000-8000-000000000041', auth.uid(), 'Hubungi CS 0812-3456-7890 atau t.me/oltresmi');
select is((select moderation_status from posts where id = 'a1690000-0000-4000-8000-000000000041'), 'visible',
  'Akun resmi dikecualikan dari aturan kontak');

select tests.authenticate_agent(:'nadia');
select throws_ok('select cs_api.compliance_content_rules()', 'PT403', 'role_forbidden', 'CS biasa tidak mengatur aturan konten');
select throws_ok('select cs_api.community_held_content()', 'PT403', 'community_forbidden',
  'Antrean konten ditahan butuh izin moderasi');

select tests.authenticate_agent(:'dodi');
select ok((select count(*) from jsonb_array_elements(cs_api.community_held_content()) x
           where x ->> 'target_id' in ('a1690000-0000-4000-8000-000000000011', 'a1690000-0000-4000-8000-000000000022',
                                       'a1690000-0000-4000-8000-000000000031')) = 3,
  'Moderator melihat postingan, komentar, dan pesan yang ditahan');
select is((select x -> 'categories' from jsonb_array_elements(cs_api.community_held_content()) x
           where x ->> 'target_id' = 'a1690000-0000-4000-8000-000000000022'), '["messenger"]'::jsonb,
  'Antrean memuat alasan penahanan');
select lives_ok($$select cs_api.community_resolve_report('post', 'a1690000-0000-4000-8000-000000000011', 'approve', 'Nomor kantor resmi')$$,
  'Moderator meloloskan konten yang ditahan');
reset role;
select is((select moderation_status from posts where id = 'a1690000-0000-4000-8000-000000000011'), 'visible',
  'Konten yang diloloskan tampil');

select tests.authenticate_agent(:'kirana');
select is(jsonb_array_length(cs_api.compliance_content_rules() -> 'categories'), 9, 'Kepatuhan melihat semua kategori');
select throws_ok($$select cs_api.compliance_set_content_rule('phone', 'hapus')$$, 'PT400', 'invalid_action', 'Aksi divalidasi');
select throws_ok($$select cs_api.compliance_set_content_rule('nope', 'block')$$, 'PT404', 'category_not_found', 'Kategori divalidasi');
select is((select x ->> 'action' from jsonb_array_elements(cs_api.compliance_set_content_rule('phone', 'censor') -> 'categories') x
           where x ->> 'category' = 'phone'), 'censor', 'Aksi kategori bisa diubah');
select is((select x -> 'updated_by' ->> 'name' from jsonb_array_elements(cs_api.compliance_content_rules() -> 'categories') x
           where x ->> 'category' = 'phone'), 'Kirana', 'Pengubah aturan tercatat');
select is((select x ->> 'domain' from jsonb_array_elements(
             cs_api.compliance_save_blocked_domain('https://www.Judi-Baru.com/daftar', 'gambling', null, 'laporan nasabah') -> 'blocked_domains') x
           where x ->> 'domain' = 'judi-baru.com'), 'judi-baru.com', 'Domain dibersihkan dari skema, www, dan path');
select throws_ok($$select cs_api.compliance_save_blocked_domain('bukan domain', 'gambling')$$, 'PT400', 'invalid_domain',
  'Domain tidak valid ditolak');
select throws_ok($$select cs_api.compliance_save_blocked_domain('contoh.com', 'nope')$$, 'PT400', 'invalid_category',
  'Kategori domain divalidasi');
select lives_ok($$select cs_api.compliance_save_blocked_domain('pompom', 'blocked', 'hold', null, 'keyword')$$,
  'Kata kunci domain bisa ditambahkan');
select lives_ok($$select cs_api.compliance_save_allowed_domain('olt.example', 'Situs perusahaan')$$, 'Domain tepercaya ditambahkan');
select throws_ok($$select cs_api.compliance_add_allowlist_term('bandar saham')$$, 'PT409', 'term_exists',
  'Istilah pengecualian tidak dobel');
select lives_ok($$select cs_api.compliance_add_allowlist_term('Kode ASII')$$, 'Istilah pengecualian ditambahkan');
select lives_ok($$select cs_api.compliance_add_promo_phrase('kelas sinyal')$$, 'Frasa promosi ditambahkan');
select throws_ok($$select cs_api.compliance_add_promo_phrase('x!')$$, 'PT400', 'invalid_term', 'Frasa promosi divalidasi');
select throws_ok($$select cs_api.compliance_set_new_account_days(31)$$, 'PT400', 'invalid_setting', 'Masa akun baru 0–30 hari');
select is((cs_api.compliance_set_new_account_days(0) ->> 'new_account_days')::int, 0, 'Masa akun baru bisa diubah');
select is(cs_api.compliance_test_content('main di judi-baru.com', 'post') ->> 'action', 'block',
  'Uji teks memakai domain baru');
select is(cs_api.compliance_test_content('beli di pompomsaham.net', 'post') ->> 'action', 'hold',
  'Uji teks memakai kata kunci domain');
select is(cs_api.compliance_test_content('kunjungi olt.example/promo', 'post') ->> 'links', 'false',
  'Domain tepercaya tidak dihitung sebagai tautan');
select is(cs_api.compliance_test_content('ikut kelas sinyal', 'post') ->> 'action', 'block', 'Frasa promosi baru langsung berlaku');
select is(cs_api.compliance_test_content('dasar goblok', 'post') ->> 'banned_words', 'censor', 'Uji teks melaporkan sensor kata');
select throws_ok($$select cs_api.compliance_test_content('x', 'forum')$$, 'PT400', 'invalid_surface', 'Tempat uji divalidasi');
select lives_ok($$select cs_api.compliance_delete_blocked_domain('judi-baru.com')$$, 'Domain bisa dihapus dari daftar');
select throws_ok($$select cs_api.compliance_delete_blocked_domain('judi-baru.com')$$, 'PT404', 'domain_not_found',
  'Menghapus domain yang tidak ada ditolak');
select lives_ok($$select cs_api.compliance_delete_promo_phrase('kelas sinyal')$$, 'Frasa promosi bisa dihapus');
select lives_ok($$select cs_api.compliance_delete_allowlist_term('kode asii')$$, 'Istilah pengecualian bisa dihapus');
select lives_ok($$select cs_api.compliance_delete_allowed_domain('olt.example')$$, 'Domain tepercaya bisa dihapus');

reset role;
select is((select count(*)::int from cs.cs_audit_log where actor_id = :'kirana'
           and action in ('content_rule.update', 'blocked_domain.save', 'blocked_domain.delete', 'allowed_domain.save',
                          'allowed_domain.delete', 'policy_allowlist.add', 'policy_allowlist.delete', 'promo_phrase.add',
                          'promo_phrase.delete', 'content_rule.new_account_days')), 11,
  'Semua perubahan aturan tercatat di audit atas nama Kepatuhan');
select is(pg_temp.action('beli di judi-baru.com'), 'allow', 'Domain yang dihapus tidak lagi diblokir');

select tests.authenticate_as(:'mira');
select lives_ok($$insert into posts (author_id, body) values (auth.uid(), 'cek kontan.co.id hari ini')$$,
  'Masa akun baru 0 hari: akun lama-baru tidak lagi dibatasi');
select tests.authenticate_as(:'rina');
select is((select body from create_post('Kontak 0812-3456-7890 ya')), 'Kontak [nomor disensor] ya',
  'Aksi sensor mengganti nomor HP dan konten tetap tampil');

select * from finish();
rollback;
