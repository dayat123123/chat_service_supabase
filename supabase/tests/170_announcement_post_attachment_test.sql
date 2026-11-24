begin;
select plan(4);

update private.settings set value = '0' where key = 'safety.new_account_days';

select tests.create_user('ap_resmi') as resmi \gset
select tests.create_user('ap_ani') as ani \gset

insert into public.posts (author_id, body, attachments)
values (:'resmi', 'Pengumuman bergambar',
        jsonb_build_array(jsonb_build_object('path', 'posts/' || :'resmi' || '/info.pdf', 'mime', 'application/pdf'),
                          jsonb_build_object('path', 'posts/' || :'resmi' || '/banner.png', 'mime', 'image/png')))
returning id as post \gset
insert into public.posts (author_id, body) values (:'resmi', 'Pengumuman tanpa gambar') returning id as plain \gset

insert into public.notifications (user_id, actor_id, type, payload) values
  (:'ani', :'resmi', 'announcement',
   jsonb_build_object('campaign_id', gen_random_uuid(), 'title', 'Kampanye bergambar', 'body', 'Isi', 'post_id', :'post')),
  (:'ani', :'resmi', 'announcement',
   jsonb_build_object('campaign_id', gen_random_uuid(), 'title', 'Kampanye polos', 'body', 'Isi', 'post_id', :'plain')),
  (:'ani', null, 'announcement', jsonb_build_object('title', 'Siaran tanpa post', 'body', 'Isi'));

select tests.authenticate_as(:'ani');
select is((select payload -> 'post_attachment' from public.get_notifications()
           where payload ->> 'title' = 'Kampanye bergambar'),
  jsonb_build_object('path', 'posts/' || :'resmi' || '/banner.png', 'mime', 'image/png'),
  'Pengumuman kampanye membawa gambar pertama post, bukan PDF');
select is((select count(*)::integer from public.get_notifications()
           where type = 'announcement' and payload ? 'post_attachment'), 1,
  'Pengumuman tanpa gambar atau tanpa post tidak membawa thumbnail');
reset role;

update public.posts set moderation_status = 'hidden' where id = :'post';
select tests.authenticate_as(:'ani');
select ok((select not payload ? 'post_attachment' from public.get_notifications()
           where payload ->> 'title' = 'Kampanye bergambar'),
  'Post pengumuman yang disembunyikan tidak menampilkan gambar');
reset role;

update public.posts set moderation_status = 'visible', deleted_at = now(), body = '' where id = :'post';
select tests.authenticate_as(:'ani');
select ok((select not payload ? 'post_attachment' from public.get_notifications()
           where payload ->> 'title' = 'Kampanye bergambar'),
  'Post pengumuman yang dihapus tidak menampilkan gambar');
reset role;

select * from finish();
rollback;
