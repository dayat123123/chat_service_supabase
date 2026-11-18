begin;
select plan(8);

select tests.create_agent('Pandu Produk', '{product}', '{}') as product \gset
select tests.create_agent('Cici CS', '{cs_agent}', '{"general": 1}') as cici \gset

select is((select count(*)::int from public.feed_filters), 4, 'Tab Stream tetap empat tab bawaan');
select throws_ok($$insert into public.feed_filters (key, label_en, label_id) values ('video', 'Video', 'Video')$$,
  '23514', null, 'Tab Stream baru ditolak');
select hasnt_function('cs_api', 'admin_save_feed_filter', 'Tidak ada lagi RPC tambah/ubah tab Stream');
select hasnt_function('cs_api', 'admin_delete_feed_filter', 'Tidak ada lagi RPC hapus tab Stream');

select tests.authenticate_agent(:'cici');
select throws_ok($$select cs_api.admin_set_feed_filter_enabled('media', false)$$, 'PT403', null,
  'Agen CS tidak bisa mematikan tab Stream');
select tests.authenticate_agent(:'product');
select is((select e ->> 'enabled' from jsonb_array_elements(cs_api.admin_set_feed_filter_enabled('MEDIA', false)) e
            where e ->> 'key' = 'media'), 'false', 'Product mematikan tab Grafik & Media');
select throws_ok($$select cs_api.admin_set_feed_filter_enabled('video', false)$$, 'PT404', 'filter_not_found',
  'Tab yang tidak ada ditolak');
select cs_api.admin_set_feed_filter_enabled('media', false);
reset role;
select is((select count(*)::int from cs.cs_audit_log where action = 'feed_filter.enabled' and actor_id = :'product'), 1,
  'Hanya perubahan nyata yang tercatat di audit');

select * from finish();
rollback;
