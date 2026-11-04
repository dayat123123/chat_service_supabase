update private.settings
   set value = (select jsonb_agg(distinct x order by x)
                from jsonb_array_elements_text(value || '["auth-bridge"]') x)
 where key = 'health.expected_services';
