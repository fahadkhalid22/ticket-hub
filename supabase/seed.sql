insert into public.categories(name,slug,icon,is_active,sort_order) values
('Cinema','cinema','movie',true,1),('Theatre','theatre','theater_comedy',true,2),('Events','events','event',true,3),('Concerts','concerts','music_note',true,4),('Sports','sports','sports_soccer',true,5),('Workshops','workshops','school',true,6),('Attractions','attractions','attractions',true,7),('Experiences','experiences','explore',true,8),('Other Ticketed Services','other-ticketed-services','local_activity',true,9)
on conflict(slug) do update set name=excluded.name,icon=excluded.icon,is_active=excluded.is_active,sort_order=excluded.sort_order;

insert into public.platform_settings(key,value) values
('service_fee_percent','2.5'::jsonb),('hold_minutes','10'::jsonb),('cancellation_hours','24'::jsonb)
on conflict(key) do update set value=excluded.value,updated_at=now();
