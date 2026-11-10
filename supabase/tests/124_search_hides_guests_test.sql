begin;
select plan(4);

select tests.create_user('sg_pencari') as pencari \gset
select tests.create_user('sg_nasabah') as nasabah \gset
select tests.create_user('tamu_sg0001') as tamu \gset
update public.profiles set display_name = 'Zulkarnaenqx' where id in (:'nasabah', :'tamu');
update public.profiles set is_guest = true where id = :'tamu';

select tests.authenticate_as(:'pencari');

select ok(exists (select 1 from jsonb_array_elements(public.search('Zulkarnaenqx', 'users') -> 'users') u
                  where u ->> 'id' = :'nasabah'),
  'Nasabah biasa tetap muncul di pencarian pengguna');
select ok(not exists (select 1 from jsonb_array_elements(public.search('Zulkarnaenqx', 'users') -> 'users') u
                      where u ->> 'id' = :'tamu'),
  'Profil tamu tidak muncul di tab Pengguna');
select ok(not exists (select 1 from jsonb_array_elements(public.search('Zulkarnaenqx', 'all') -> 'users') u
                      where u ->> 'id' = :'tamu'),
  'Profil tamu tidak muncul di tab Semua');
select ok(not exists (select 1 from jsonb_array_elements(public.search('tamu_sg0001', 'users') -> 'users') u
                      where u ->> 'id' = :'tamu'),
  'Profil tamu tidak ditemukan lewat username');

select * from finish();
rollback;
