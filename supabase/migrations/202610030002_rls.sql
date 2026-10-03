-- TicketHub RLS and authorization helpers
create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'); $$;

create or replace function private.owns_business(p_business_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.businesses b where b.id=p_business_id and b.owner_id=(select auth.uid())); $$;

create or replace function private.staff_for_business(p_business_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.staff s where s.business_id=p_business_id and s.user_id=(select auth.uid())); $$;

create or replace function private.can_manage_business(p_business_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select private.is_admin() or private.owns_business(p_business_id); $$;

create or replace function private.business_is_public(p_business_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.businesses b where b.id=p_business_id and b.status='approved'); $$;

revoke all on function private.is_admin() from public, anon;
revoke all on function private.owns_business(uuid) from public, anon;
revoke all on function private.staff_for_business(uuid) from public, anon;
revoke all on function private.can_manage_business(uuid) from public, anon;
revoke all on function private.business_is_public(uuid) from public;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.owns_business(uuid) to authenticated;
grant execute on function private.staff_for_business(uuid) to authenticated;
grant execute on function private.can_manage_business(uuid) to authenticated;
grant execute on function private.business_is_public(uuid) to anon, authenticated;


-- Profiles may edit personal details but may not self-escalate their role.
create or replace function private.protect_profile_fields()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user = 'authenticated' and not private.is_admin() and (new.role is distinct from old.role or new.created_at is distinct from old.created_at) then
    raise exception 'Role and creation time can only be changed by an admin';
  end if;
  return new;
end;$$;
revoke all on function private.protect_profile_fields() from public, anon, authenticated;
create trigger profiles_protected_fields before update on public.profiles for each row execute function private.protect_profile_fields();

-- Ticket inventory counters are server-maintained. Owners can edit pricing/capacity,
-- but direct authenticated requests cannot forge sold/held counters.
create or replace function private.protect_ticket_inventory_fields()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user = 'authenticated' and (new.sold_qty is distinct from old.sold_qty or new.held_qty is distinct from old.held_qty) then
    raise exception 'sold_qty and held_qty are managed by booking transactions';
  end if;
  return new;
end;$$;
create trigger ticket_types_protected_inventory before update on public.ticket_types for each row execute function private.protect_ticket_inventory_fields();

-- Prevent owners from self-approving or changing protected aggregate fields.
create or replace function private.protect_business_fields()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user = 'authenticated' and not private.is_admin() then
    if new.owner_id is distinct from old.owner_id or new.status is distinct from old.status or
       new.rejection_reason is distinct from old.rejection_reason or new.rating_avg is distinct from old.rating_avg or
       new.rating_count is distinct from old.rating_count then
      raise exception 'Protected business fields can only be changed by an admin/system operation';
    end if;
  end if;
  return new;
end;$$;
revoke all on function private.protect_business_fields() from public, anon, authenticated;
create trigger businesses_protected_fields before update on public.businesses for each row execute function private.protect_business_fields();

create or replace function private.protect_notification_fields()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_user = 'authenticated' and not private.is_admin() and (new.user_id,new.type,new.title,new.body,new.data) is distinct from (old.user_id,old.type,old.title,old.body,old.data) then
    raise exception 'Only is_read may be changed by the recipient';
  end if;
  return new;
end;$$;
revoke all on function private.protect_notification_fields() from public, anon, authenticated;
create trigger notifications_protected_fields before update on public.notifications for each row execute function private.protect_notification_fields();

-- Enable RLS on every public app table.
do $$ declare t text; begin
  foreach t in array array['profiles','categories','businesses','staff','listings','seat_maps','seats','schedules','ticket_types','bookings','booking_items','schedule_seats','tickets','payments','reviews','favorites','notifications','platform_settings','audit_log'] loop
    execute format('alter table public.%I enable row level security',t);
  end loop;
end $$;

-- Data API grants. RLS remains authoritative.
grant usage on schema public to anon, authenticated;
grant select on public.categories,public.businesses,public.listings,public.schedules,public.ticket_types,public.reviews to anon;
grant select,insert,update,delete on all tables in schema public to authenticated;

-- Profiles
create policy profiles_self_or_admin_select on public.profiles for select to authenticated using (id=(select auth.uid()) or private.is_admin());
create policy profiles_self_update on public.profiles for update to authenticated using (id=(select auth.uid()) or private.is_admin()) with check (id=(select auth.uid()) or private.is_admin());

-- Categories
create policy categories_public_read on public.categories for select to anon,authenticated using (is_active or private.is_admin());
create policy categories_admin_insert on public.categories for insert to authenticated with check (private.is_admin());
create policy categories_admin_update on public.categories for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy categories_admin_delete on public.categories for delete to authenticated using (private.is_admin());

-- Businesses: approved public; owner/admin can see their non-public rows.
create policy businesses_public_read on public.businesses for select to anon using (status='approved');
create policy businesses_auth_read on public.businesses for select to authenticated using (status='approved' or owner_id=(select auth.uid()) or private.is_admin());
create policy businesses_owner_insert on public.businesses for insert to authenticated with check (
  owner_id=(select auth.uid()) and status='pending' and
  exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='owner')
);
create policy businesses_owner_admin_update on public.businesses for update to authenticated using (owner_id=(select auth.uid()) or private.is_admin()) with check (owner_id=(select auth.uid()) or private.is_admin());
create policy businesses_admin_delete on public.businesses for delete to authenticated using (private.is_admin());

-- Staff
create policy staff_business_read on public.staff for select to authenticated using (user_id=(select auth.uid()) or private.owns_business(business_id) or private.is_admin());
create policy staff_owner_write on public.staff for insert to authenticated with check (private.owns_business(business_id) or private.is_admin());
create policy staff_owner_delete on public.staff for delete to authenticated using (private.owns_business(business_id) or private.is_admin());

-- Listings
create policy listings_public_read on public.listings for select to anon using (status='active' and booking_open and private.business_is_public(business_id));
create policy listings_auth_read on public.listings for select to authenticated using ((status='active' and booking_open and private.business_is_public(business_id)) or private.can_manage_business(business_id));
create policy listings_owner_insert on public.listings for insert to authenticated with check (private.can_manage_business(business_id));
create policy listings_owner_update on public.listings for update to authenticated using (private.can_manage_business(business_id)) with check (private.can_manage_business(business_id));
create policy listings_owner_delete on public.listings for delete to authenticated using (private.can_manage_business(business_id));

-- Seat maps / seats
create policy seat_maps_owner_read on public.seat_maps for select to authenticated using (private.can_manage_business(business_id));
create policy seat_maps_owner_insert on public.seat_maps for insert to authenticated with check (private.can_manage_business(business_id));
create policy seat_maps_owner_update on public.seat_maps for update to authenticated using (private.can_manage_business(business_id)) with check (private.can_manage_business(business_id));
create policy seat_maps_owner_delete on public.seat_maps for delete to authenticated using (private.can_manage_business(business_id));
create policy seats_owner_read on public.seats for select to authenticated using (exists(select 1 from public.seat_maps m where m.id=seat_map_id and private.can_manage_business(m.business_id)));
create policy seats_owner_insert on public.seats for insert to authenticated with check (exists(select 1 from public.seat_maps m where m.id=seat_map_id and private.can_manage_business(m.business_id)));
create policy seats_owner_update on public.seats for update to authenticated using (exists(select 1 from public.seat_maps m where m.id=seat_map_id and private.can_manage_business(m.business_id))) with check (exists(select 1 from public.seat_maps m where m.id=seat_map_id and private.can_manage_business(m.business_id)));
create policy seats_owner_delete on public.seats for delete to authenticated using (exists(select 1 from public.seat_maps m where m.id=seat_map_id and private.can_manage_business(m.business_id)));

-- Schedules
create policy schedules_public_read on public.schedules for select to anon using (exists(select 1 from public.listings l where l.id=listing_id and l.status='active' and l.booking_open and private.business_is_public(l.business_id)));
create policy schedules_auth_read on public.schedules for select to authenticated using (exists(select 1 from public.listings l where l.id=listing_id and ((l.status='active' and l.booking_open and private.business_is_public(l.business_id)) or private.can_manage_business(l.business_id))));
create policy schedules_owner_insert on public.schedules for insert to authenticated with check (exists(select 1 from public.listings l where l.id=listing_id and private.can_manage_business(l.business_id)));
create policy schedules_owner_update on public.schedules for update to authenticated using (exists(select 1 from public.listings l where l.id=listing_id and private.can_manage_business(l.business_id))) with check (exists(select 1 from public.listings l where l.id=listing_id and private.can_manage_business(l.business_id)));
create policy schedules_owner_delete on public.schedules for delete to authenticated using (exists(select 1 from public.listings l where l.id=listing_id and private.can_manage_business(l.business_id)));

-- Ticket types
create policy ticket_types_public_read on public.ticket_types for select to anon using (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and s.status='active' and l.status='active' and l.booking_open and private.business_is_public(l.business_id)));
create policy ticket_types_auth_read on public.ticket_types for select to authenticated using (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and ((s.status='active' and l.status='active' and l.booking_open and private.business_is_public(l.business_id)) or private.can_manage_business(l.business_id))));
create policy ticket_types_owner_insert on public.ticket_types for insert to authenticated with check (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and private.can_manage_business(l.business_id)));
create policy ticket_types_owner_update on public.ticket_types for update to authenticated using (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and private.can_manage_business(l.business_id))) with check (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and private.can_manage_business(l.business_id)));
create policy ticket_types_owner_delete on public.ticket_types for delete to authenticated using (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and private.can_manage_business(l.business_id)));

-- Schedule seats are private mutable inventory. Customers receive a safe projection via RPC.
create policy schedule_seats_owner_read on public.schedule_seats for select to authenticated using (exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and (private.can_manage_business(l.business_id) or held_by=(select auth.uid()))));
-- schedule_seats are mutated only through guarded SECURITY DEFINER RPCs. Owners may read but cannot directly change booking seat state.

-- Bookings and children
create policy bookings_related_read on public.bookings for select to authenticated using (customer_id=(select auth.uid()) or private.is_admin() or exists(select 1 from public.schedules s join public.listings l on l.id=s.listing_id where s.id=schedule_id and private.owns_business(l.business_id)));
create policy booking_items_related_read on public.booking_items for select to authenticated using (exists(select 1 from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where b.id=booking_id and (b.customer_id=(select auth.uid()) or private.is_admin() or private.owns_business(l.business_id))));
create policy tickets_related_read on public.tickets for select to authenticated using (exists(select 1 from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where b.id=booking_id and (b.customer_id=(select auth.uid()) or private.is_admin() or private.owns_business(l.business_id) or private.staff_for_business(l.business_id))));
create policy payments_related_read on public.payments for select to authenticated using (exists(select 1 from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where b.id=booking_id and (b.customer_id=(select auth.uid()) or private.is_admin() or private.owns_business(l.business_id))));

-- Reviews. Only completed/used bookings may create one review and values must match booking context.
create policy reviews_public_read on public.reviews for select to anon using (not is_hidden);
create policy reviews_auth_read on public.reviews for select to authenticated using (not is_hidden or customer_id=(select auth.uid()) or private.is_admin());
create policy reviews_customer_insert on public.reviews for insert to authenticated with check (
  customer_id=(select auth.uid()) and exists(
    select 1 from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id
    where b.id=booking_id and b.customer_id=(select auth.uid()) and b.status in ('completed','used') and l.id=listing_id and l.business_id=business_id
  )
);
create policy reviews_admin_update on public.reviews for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy reviews_admin_delete on public.reviews for delete to authenticated using (private.is_admin());

-- Favorites
create policy favorites_self_select on public.favorites for select to authenticated using (customer_id=(select auth.uid()));
create policy favorites_self_insert on public.favorites for insert to authenticated with check (customer_id=(select auth.uid()) and private.business_is_public(business_id));
create policy favorites_self_delete on public.favorites for delete to authenticated using (customer_id=(select auth.uid()));

-- Notifications
create policy notifications_self_select on public.notifications for select to authenticated using (user_id=(select auth.uid()) or private.is_admin());
create policy notifications_self_update on public.notifications for update to authenticated using (user_id=(select auth.uid()) or private.is_admin()) with check (user_id=(select auth.uid()) or private.is_admin());

-- Settings/audit admin only.
create policy settings_admin_all on public.platform_settings for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy audit_admin_read on public.audit_log for select to authenticated using (private.is_admin());

-- Public storage reads; writes restricted to user folder or owned business folder.
create policy business_media_public_read on storage.objects for select to anon,authenticated using (bucket_id='business-media');
create policy listing_media_public_read on storage.objects for select to anon,authenticated using (bucket_id='listing-media');
create policy business_media_owner_insert on storage.objects for insert to authenticated with check (
  bucket_id='business-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())))
);
create policy business_media_owner_update on storage.objects for update to authenticated using (
  bucket_id='business-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())))
) with check (
  bucket_id='business-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())))
);
create policy business_media_owner_delete on storage.objects for delete to authenticated using (
  bucket_id='business-media' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid())))
);
create policy listing_media_owner_insert on storage.objects for insert to authenticated with check (
  bucket_id='listing-media' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid()))
);
create policy listing_media_owner_update on storage.objects for update to authenticated using (
  bucket_id='listing-media' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid()))
) with check (
  bucket_id='listing-media' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid()))
);
create policy listing_media_owner_delete on storage.objects for delete to authenticated using (
  bucket_id='listing-media' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and b.owner_id=(select auth.uid()))
);
