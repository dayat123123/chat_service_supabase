create or replace function private.banner_link_schemes()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select array_agg(x order by n)
                   from jsonb_array_elements_text(
                          case when jsonb_typeof(cs.setting('banners.deep_link_schemes')) = 'array'
                               then cs.setting('banners.deep_link_schemes') else '["rendezvous-olt"]' end) with ordinality t(x, n)
                   where x ~ '^[a-z][a-z0-9+.-]{0,31}$' and x <> all (private.banner_forbidden_schemes())), '{}');
$$;

select cs.set_setting('banners.deep_link_schemes',
         (select coalesce(jsonb_agg(x order by n), '[]'::jsonb)
          from (select x, min(n) as n
                from (select case when x = 'olt' then 'rendezvous-olt' else x end as x, n
                      from jsonb_array_elements_text(s.value) with ordinality t(x, n)) r
                group by x) d),
         null)
from cs.cs_settings s
where s.key = 'banners.deep_link_schemes'
  and jsonb_typeof(s.value) = 'array'
  and s.value ? 'olt';

update cs.cs_settings
   set description = 'Skema deep link aplikasi yang boleh dipakai sebagai tautan banner, mis. rendezvous-olt untuk rendezvous-olt://promo/akhir-tahun. Skema pertama dipakai tombol Buka di aplikasi pada tautan berbagi'
 where key = 'banners.deep_link_schemes';
