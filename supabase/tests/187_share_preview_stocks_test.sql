begin;
select plan(4);

update private.rate_limits set max_count = 1000 where action in ('post', 'post_share_link');
update private.settings set value = '0' where key = 'safety.new_account_days';
update cs.cs_settings set value = '["rendezvous-olt"]' where key = 'banners.deep_link_schemes';
update cs.cs_settings set value = '{"enabled": true, "base_url": "http://192.168.0.235:8000", "preview": true}' where key = 'share.links';

insert into private.market_instruments (code, name) values ('ZZIDX', 'Indeks Uji');
insert into private.market_instrument_aliases (alias, code) values ('ZZAL', 'ZZIDX');
insert into private.market_instruments (code, name, enabled) values ('ZZOFF', 'Indeks Mati', false);

select tests.create_user('sp_ani') as ani \gset
insert into public.posts (author_id, body)
values (:'ani', '$bbni naik, $ZZAL ikut, $BBNI lagi, $ZZOFF, $DDDD') returning id as post \gset
insert into public.posts (author_id, body) values (:'ani', 'Tanpa saham') returning id as plain \gset

select tests.authenticate_as(:'ani');
select public.post_share_link(:'post') ->> 'code' as code \gset
select public.post_share_link(:'plain') ->> 'code' as plain_code \gset
reset role;

select tests.authenticate_service();
select is(public.share_post_preview(:'code') -> 'stocks',
  '[{"code": "BBNI", "name": null}, {"code": "ZZIDX", "name": "Indeks Uji"}, {"code": "ZZOFF", "name": null}]'::jsonb,
  'Pratinjau membawa tiga saham pertama sesuai urutan di teks, alias jadi kode indeks dengan namanya');
select is(jsonb_array_length(public.share_post_preview(:'code') -> 'stocks'), 3, 'Saham dibatasi tiga');
select is(public.share_post_preview(:'plain_code') -> 'stocks', '[]'::jsonb, 'Post tanpa saham membawa daftar kosong');
select is(public.share_post_preview(:'code') ->> 'body', '$bbni naik, $ZZAL ikut, $BBNI lagi, $ZZOFF, $DDDD',
  'Isi pratinjau tetap utuh');
reset role;

select * from finish();
rollback;
