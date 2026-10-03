-- TicketHub transactional RPCs and read models.

create or replace function private.require_user()
returns uuid language plpgsql stable set search_path='' as $$
declare uid uuid := (select auth.uid()); begin if uid is null then raise exception 'Authentication required'; end if; return uid; end;$$;
revoke all on function private.require_user() from public, anon;
grant execute on function private.require_user() to authenticated;

create or replace function private.write_audit(p_action text,p_entity text,p_entity_id uuid,p_meta jsonb default '{}'::jsonb)
returns void language sql security definer set search_path='' as $$
  insert into public.audit_log(actor,action,entity,entity_id,meta) values((select auth.uid()),p_action,p_entity,p_entity_id,coalesce(p_meta,'{}'::jsonb));
$$;
revoke all on function private.write_audit(text,text,uuid,jsonb) from public, anon, authenticated;

create or replace function private.release_expired_holds_impl()
returns integer language plpgsql security definer set search_path='' as $$
declare released integer := 0;
begin
  with expired as (
    select id from public.bookings
    where status='pending' and hold_expires_at is not null and hold_expires_at <= now()
    for update skip locked
  ), grouped as (
    select bi.ticket_type_id, sum(bi.quantity)::int qty
    from public.booking_items bi join expired e on e.id=bi.booking_id
    group by bi.ticket_type_id
  )
  update public.ticket_types tt set held_qty=greatest(0,tt.held_qty-g.qty)
  from grouped g where tt.id=g.ticket_type_id;

  update public.schedule_seats ss set status='available',held_by=null,held_until=null,booking_id=null
  where ss.booking_id in (select id from public.bookings where status='pending' and hold_expires_at is not null and hold_expires_at <= now());

  with u as (
    update public.bookings set status='cancelled'
    where status='pending' and hold_expires_at is not null and hold_expires_at <= now()
    returning 1
  ) select count(*) into released from u;
  return released;
end;$$;
revoke all on function private.release_expired_holds_impl() from public, anon, authenticated;

create or replace function public.release_expired_holds()
returns integer language plpgsql security definer set search_path='' as $$
begin
  perform private.require_user();
  return private.release_expired_holds_impl();
end;$$;
revoke all on function public.release_expired_holds() from public, anon;
grant execute on function public.release_expired_holds() to authenticated;

create or replace function public.hold_tickets(p_schedule_id uuid,p_items jsonb,p_seat_ids uuid[] default array[]::uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare
  uid uuid := private.require_user();
  sch public.schedules%rowtype;
  prof public.profiles%rowtype;
  lst public.listings%rowtype;
  biz public.businesses%rowtype;
  booking_id uuid;
  hold_minutes integer;
  requested integer;
  existing integer;
  subtotal numeric(12,2) := 0;
  fee_percent numeric := 0;
  item jsonb;
  tt public.ticket_types%rowtype;
  qty integer;
  selected_count integer;
  selected_qty integer;
  item_qty integer;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'Select at least one ticket'; end if;
  if not exists(select 1 from public.profiles where id=uid and role='customer') then raise exception 'Only customer accounts can create bookings'; end if;

  perform private.release_expired_holds_impl();
  select * into sch from public.schedules where id=p_schedule_id for update;
  if not found then raise exception 'Schedule not found'; end if;
  select * into lst from public.listings where id=sch.listing_id;
  select * into biz from public.businesses where id=lst.business_id;
  if sch.status<>'active' or sch.starts_at<=now() or not lst.booking_open or lst.status<>'active' or biz.status<>'approved' then raise exception 'This schedule is not open for booking'; end if;

  select * into prof from public.profiles where id=uid;
  hold_minutes := coalesce((select (value #>> '{}')::int from public.platform_settings where key='hold_minutes'),10);
  fee_percent := coalesce((select (value #>> '{}')::numeric from public.platform_settings where key='service_fee_percent'),0);

  if exists(select 1 from jsonb_array_elements(p_items) x where coalesce((x->>'quantity')::int,0)<=0 or x->>'ticket_type_id' is null) then raise exception 'Invalid ticket quantities'; end if;
  if (select count(*) from jsonb_array_elements(p_items)) <> (select count(distinct x->>'ticket_type_id') from jsonb_array_elements(p_items) x) then raise exception 'Duplicate ticket types are not allowed'; end if;
  select coalesce(sum((x->>'quantity')::int),0) into requested from jsonb_array_elements(p_items) x;

  select coalesce(sum(bi.quantity),0)::int into existing
  from public.booking_items bi join public.bookings b on b.id=bi.booking_id
  where b.customer_id=uid and b.schedule_id=p_schedule_id and b.status in ('pending','confirmed','paid');
  if requested + existing > sch.booking_limit_per_user then raise exception 'Booking limit exceeded (maximum %)',sch.booking_limit_per_user; end if;

  if coalesce(array_length(p_seat_ids,1),0)>0 then
    if sch.seat_map_id is null then raise exception 'This schedule does not use seat selection'; end if;
    if requested <> array_length(p_seat_ids,1) then raise exception 'Selected seat count must equal ticket quantity'; end if;
    if array_length(p_seat_ids,1) <> (select count(distinct x) from unnest(p_seat_ids) x) then raise exception 'Duplicate seats selected'; end if;

    -- Lock the exact seats. They must all be available for this schedule.
    perform 1 from public.schedule_seats ss where ss.schedule_id=p_schedule_id and ss.seat_id=any(p_seat_ids) order by ss.seat_id for update;
    select count(*) into selected_count from public.schedule_seats ss where ss.schedule_id=p_schedule_id and ss.seat_id=any(p_seat_ids) and ss.status='available';
    if selected_count <> requested then raise exception 'One or more seats are no longer available'; end if;

    -- Each ticket-type quantity must match the mapped selected seats.
    for item in select * from jsonb_array_elements(p_items) loop
      qty := (item->>'quantity')::int;
      select * into tt from public.ticket_types where id=(item->>'ticket_type_id')::uuid and schedule_id=p_schedule_id for update;
      if not found then raise exception 'Ticket type not found for schedule'; end if;
      select count(*) into selected_qty from public.schedule_seats where schedule_id=p_schedule_id and seat_id=any(p_seat_ids) and ticket_type_id=tt.id;
      if selected_qty <> qty then raise exception 'Seat category and ticket type quantities do not match'; end if;
      if tt.total_qty-tt.sold_qty-tt.held_qty < qty then raise exception '% does not have enough remaining inventory',tt.name; end if;
      subtotal := subtotal + (tt.price*qty);
    end loop;

    insert into public.bookings(customer_id,schedule_id,status,total_amount,customer_name,customer_phone,customer_email,hold_expires_at)
    values(uid,p_schedule_id,'pending',round(subtotal*(1+fee_percent/100),2),prof.full_name,prof.phone,(select email from auth.users where id=uid),now()+make_interval(mins=>hold_minutes)) returning id into booking_id;

    insert into public.booking_items(booking_id,ticket_type_id,seat_id,unit_price,quantity)
    select booking_id,ss.ticket_type_id,ss.seat_id,tt.price,1
    from public.schedule_seats ss join public.ticket_types tt on tt.id=ss.ticket_type_id
    where ss.schedule_id=p_schedule_id and ss.seat_id=any(p_seat_ids);

    update public.schedule_seats set status='held',held_by=uid,held_until=now()+make_interval(mins=>hold_minutes),booking_id=booking_id
    where schedule_id=p_schedule_id and seat_id=any(p_seat_ids);

    update public.ticket_types tt set held_qty=tt.held_qty+g.qty
    from (select ss.ticket_type_id,count(*)::int qty from public.schedule_seats ss where ss.booking_id=booking_id group by ss.ticket_type_id) g
    where tt.id=g.ticket_type_id;
  else
    if sch.seat_map_id is not null then raise exception 'Seat selection is required for this schedule'; end if;
    for item in select * from jsonb_array_elements(p_items) loop
      qty := (item->>'quantity')::int;
      select * into tt from public.ticket_types where id=(item->>'ticket_type_id')::uuid and schedule_id=p_schedule_id for update;
      if not found then raise exception 'Ticket type not found for schedule'; end if;
      if tt.total_qty-tt.sold_qty-tt.held_qty < qty then raise exception '% does not have enough remaining inventory',tt.name; end if;
      subtotal := subtotal + (tt.price*qty);
    end loop;
    insert into public.bookings(customer_id,schedule_id,status,total_amount,customer_name,customer_phone,customer_email,hold_expires_at)
    values(uid,p_schedule_id,'pending',round(subtotal*(1+fee_percent/100),2),prof.full_name,prof.phone,(select email from auth.users where id=uid),now()+make_interval(mins=>hold_minutes)) returning id into booking_id;
    for item in select * from jsonb_array_elements(p_items) loop
      qty := (item->>'quantity')::int;
      select * into tt from public.ticket_types where id=(item->>'ticket_type_id')::uuid for update;
      update public.ticket_types set held_qty=held_qty+qty where id=tt.id;
      insert into public.booking_items(booking_id,ticket_type_id,unit_price,quantity) values(booking_id,tt.id,tt.price,qty);
    end loop;
  end if;
  return booking_id;
end;$$;
revoke all on function public.hold_tickets(uuid,jsonb,uuid[]) from public, anon;
grant execute on function public.hold_tickets(uuid,jsonb,uuid[]) to authenticated;

create or replace function public.confirm_booking(p_booking_id uuid,p_payment_method text,p_provider_ref text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  uid uuid:=private.require_user(); b public.bookings%rowtype; owner_id uuid; payment_state public.payment_status; booking_state public.booking_status;
  r record; n integer;
begin
  if p_payment_method not in ('cash','pay_at_venue','card','jazzcash','easypaisa','wallet') then raise exception 'Unsupported payment method'; end if;
  select * into b from public.bookings where id=p_booking_id for update;
  if not found or b.customer_id<>uid then raise exception 'Booking not found'; end if;
  if b.status<>'pending' then raise exception 'Booking is not pending'; end if;
  if b.hold_expires_at is null or b.hold_expires_at<=now() then perform private.release_expired_holds_impl(); raise exception 'Booking hold expired'; end if;

  for r in select ticket_type_id,sum(quantity)::int qty from public.booking_items where booking_id=b.id group by ticket_type_id loop
    perform 1 from public.ticket_types where id=r.ticket_type_id for update;
    update public.ticket_types set held_qty=held_qty-r.qty,sold_qty=sold_qty+r.qty where id=r.ticket_type_id and held_qty>=r.qty and sold_qty+r.qty<=total_qty;
    if not found then raise exception 'Inventory changed; confirmation aborted'; end if;
  end loop;
  update public.schedule_seats set status='booked',held_by=null,held_until=null where booking_id=b.id and status='held' and held_by=uid;

  for r in select * from public.booking_items where booking_id=b.id loop
    for n in 1..r.quantity loop
      insert into public.tickets(booking_id,booking_item_id,status) values(b.id,r.id,'valid');
    end loop;
  end loop;

  if p_payment_method in ('cash','pay_at_venue') then payment_state:='pending'; booking_state:='confirmed'; else payment_state:='paid'; booking_state:='paid'; end if;
  insert into public.payments(booking_id,method,provider_ref,amount,status) values(b.id,p_payment_method,p_provider_ref,b.total_amount,payment_state);
  update public.bookings set status=booking_state,hold_expires_at=null where id=b.id;

  select bu.owner_id into owner_id from public.schedules s join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id where s.id=b.schedule_id;
  insert into public.notifications(user_id,type,title,body,data) values(uid,'booking_confirmation','Booking confirmed','Your booking '||b.booking_code||' is confirmed.',jsonb_build_object('booking_id',b.id));
  if owner_id is not null then insert into public.notifications(user_id,type,title,body,data) values(owner_id,'new_booking','New booking','A customer completed booking '||b.booking_code||'.',jsonb_build_object('booking_id',b.id)); insert into public.notifications(user_id,type,title,body,data) values(owner_id,'ticket_sold','Ticket sold','Ticket inventory was sold for booking '||b.booking_code||'.',jsonb_build_object('booking_id',b.id)); end if;
  return jsonb_build_object('booking_id',b.id,'status',booking_state,'payment_status',payment_state);
end;$$;
revoke all on function public.confirm_booking(uuid,text,text) from public, anon;
grant execute on function public.confirm_booking(uuid,text,text) to authenticated;

create or replace function public.cancel_booking(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); b public.bookings%rowtype; sch public.schedules%rowtype; cancel_hours int; r record; paid boolean;
begin
  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if b.customer_id<>uid and not private.is_admin() then raise exception 'Not authorized'; end if;
  if b.status not in ('pending','confirmed','paid') then raise exception 'Booking cannot be cancelled in its current status'; end if;
  select * into sch from public.schedules where id=b.schedule_id;
  cancel_hours:=coalesce((select (value #>> '{}')::int from public.platform_settings where key='cancellation_hours'),24);
  if not private.is_admin() and sch.starts_at <= now()+make_interval(hours=>cancel_hours) then raise exception 'Cancellation window has closed'; end if;

  if b.status='pending' then
    for r in select ticket_type_id,sum(quantity)::int qty from public.booking_items where booking_id=b.id group by ticket_type_id loop
      update public.ticket_types set held_qty=greatest(0,held_qty-r.qty) where id=r.ticket_type_id;
    end loop;
  else
    for r in select ticket_type_id,sum(quantity)::int qty from public.booking_items where booking_id=b.id group by ticket_type_id loop
      update public.ticket_types set sold_qty=greatest(0,sold_qty-r.qty) where id=r.ticket_type_id;
    end loop;
  end if;
  update public.schedule_seats set status='available',held_by=null,held_until=null,booking_id=null where booking_id=b.id;
  select exists(select 1 from public.payments where booking_id=b.id and status='paid') into paid;
  if paid then
    update public.payments set status='refunded' where booking_id=b.id and status='paid';
    update public.tickets set status='refunded' where booking_id=b.id and status='valid';
    update public.bookings set status='refunded',hold_expires_at=null where id=b.id;
  else
    update public.tickets set status='cancelled' where booking_id=b.id and status='valid';
    update public.bookings set status='cancelled',hold_expires_at=null where id=b.id;
  end if;
  insert into public.notifications(user_id,type,title,body,data) values(b.customer_id,'booking_cancelled','Booking cancelled','Booking '||b.booking_code||' was cancelled and eligible inventory was released.',jsonb_build_object('booking_id',b.id));
  insert into public.notifications(user_id,type,title,body,data)
  select bu.owner_id,'booking_cancelled','Customer cancellation','Booking '||b.booking_code||' was cancelled.',jsonb_build_object('booking_id',b.id)
  from public.schedules s join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id where s.id=b.schedule_id;
  perform private.write_audit('BOOKING_CANCELLED','booking',b.id,jsonb_build_object('refunded',paid));
  return jsonb_build_object('booking_id',b.id,'status',case when paid then 'refunded' else 'cancelled' end);
end;$$;
revoke all on function public.cancel_booking(uuid) from public, anon;
grant execute on function public.cancel_booking(uuid) to authenticated;

create or replace function public.get_schedule_seats(p_schedule_id uuid)
returns table(schedule_seat_id uuid,seat_id uuid,row_label text,seat_number text,category text,status text,ticket_type_id uuid,price numeric,x numeric,y numeric)
language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); bid uuid;
begin
  perform private.release_expired_holds_impl();
  select l.business_id into bid from public.schedules s join public.listings l on l.id=s.listing_id where s.id=p_schedule_id;
  if bid is null then raise exception 'Schedule not found'; end if;
  if not private.business_is_public(bid) and not private.can_manage_business(bid) then raise exception 'Schedule is not available'; end if;
  return query select ss.id,se.id,se.row_label,se.seat_number,se.category,ss.status::text,ss.ticket_type_id,tt.price,se.x,se.y
  from public.schedule_seats ss join public.seats se on se.id=ss.seat_id join public.ticket_types tt on tt.id=ss.ticket_type_id
  where ss.schedule_id=p_schedule_id order by se.y,se.x,se.row_label,se.seat_number;
end;$$;
revoke all on function public.get_schedule_seats(uuid) from public, anon;
grant execute on function public.get_schedule_seats(uuid) to authenticated;

create or replace function public.configure_schedule_seat_map(p_schedule_id uuid,p_seat_map_id uuid,p_ticket_type_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare bid uuid; seat_count int;
begin
  perform private.require_user();
  select l.business_id into bid from public.schedules s join public.listings l on l.id=s.listing_id where s.id=p_schedule_id for update;
  if bid is null or not private.can_manage_business(bid) then raise exception 'Not authorized'; end if;
  if not exists(select 1 from public.seat_maps where id=p_seat_map_id and business_id=bid) then raise exception 'Seat map does not belong to business'; end if;
  if not exists(select 1 from public.ticket_types where id=p_ticket_type_id and schedule_id=p_schedule_id) then raise exception 'Ticket type does not belong to schedule'; end if;
  if exists(select 1 from public.bookings where schedule_id=p_schedule_id and status in ('pending','confirmed','paid','used','completed')) then raise exception 'Cannot replace seat map after bookings exist'; end if;
  delete from public.schedule_seats where schedule_id=p_schedule_id;
  update public.schedules set seat_map_id=p_seat_map_id where id=p_schedule_id;
  insert into public.schedule_seats(schedule_id,seat_id,ticket_type_id)
    select p_schedule_id,s.id,p_ticket_type_id from public.seats s where s.seat_map_id=p_seat_map_id;
  select count(*) into seat_count from public.seats where seat_map_id=p_seat_map_id;
  update public.ticket_types set total_qty=seat_count where id=p_ticket_type_id and sold_qty=0 and held_qty=0;
end;$$;
revoke all on function public.configure_schedule_seat_map(uuid,uuid,uuid) from public, anon;
grant execute on function public.configure_schedule_seat_map(uuid,uuid,uuid) to authenticated;

create or replace function public.validate_ticket(p_qr_token text,p_scanner_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); t public.tickets%rowtype; b public.bookings%rowtype; event_title text; business_name text; bid uuid; start_time timestamptz; location_text text; seat_label text;
begin
  if p_scanner_id is distinct from uid then raise exception 'Scanner identity mismatch'; end if;
  select * into t from public.tickets where qr_token=p_qr_token for update;
  if not found then return jsonb_build_object('result','Invalid'); end if;
  select * into b from public.bookings where id=t.booking_id;
  select l.title,bu.name,bu.id,s.starts_at,l.location_text,
         case when bi.seat_id is null then null else se.row_label||se.seat_number end
  into event_title,business_name,bid,start_time,location_text,seat_label
  from public.bookings bk join public.schedules s on s.id=bk.schedule_id join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id
  join public.booking_items bi on bi.id=t.booking_item_id left join public.seats se on se.id=bi.seat_id where bk.id=t.booking_id;
  if not (private.owns_business(bid) or private.staff_for_business(bid) or private.is_admin()) then raise exception 'Scanner is not authorized for this business'; end if;
  if t.status='used' then return jsonb_build_object('result','Already Used','event_title',event_title,'starts_at',start_time,'seat_label',seat_label); end if;
  if t.status in ('cancelled','refunded') or b.status in ('cancelled','refunded') then return jsonb_build_object('result','Cancelled','event_title',event_title,'starts_at',start_time); end if;
  if t.status<>'valid' then return jsonb_build_object('result','Invalid'); end if;
  update public.tickets set status='used',used_at=now(),used_by=uid where id=t.id;
  if not exists(select 1 from public.tickets where booking_id=b.id and id<>t.id and status='valid') and b.status in ('confirmed','paid','completed') then update public.bookings set status='used' where id=b.id; end if;
  perform private.write_audit('TICKET_USED','ticket',t.id,jsonb_build_object('booking_id',b.id));
  return jsonb_build_object('result','Valid','event_title',event_title,'business_name',business_name,'starts_at',start_time,'location',location_text,'seat_label',seat_label,'ticket_code',t.ticket_code);
end;$$;
revoke all on function public.validate_ticket(text,uuid) from public, anon;
grant execute on function public.validate_ticket(text,uuid) to authenticated;

create or replace function public.my_ticket_details()
returns table(id uuid,ticket_code text,qr_token text,status text,booking_id uuid,used_at timestamptz,event_title text,business_name text,starts_at timestamptz,location text,ticket_type text,seat_label text,customer_name text,total_amount numeric)
language sql security definer set search_path='' as $$
select t.id,t.ticket_code,t.qr_token,t.status::text,t.booking_id,t.used_at,l.title,bu.name,s.starts_at,l.location_text,tt.name,
       case when bi.seat_id is null then null else se.row_label||se.seat_number end,b.customer_name,b.total_amount
from public.tickets t join public.bookings b on b.id=t.booking_id join public.booking_items bi on bi.id=t.booking_item_id join public.ticket_types tt on tt.id=bi.ticket_type_id
join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id left join public.seats se on se.id=bi.seat_id
where b.customer_id=(select auth.uid()) order by s.starts_at;
$$;
revoke all on function public.my_ticket_details() from public, anon;
grant execute on function public.my_ticket_details() to authenticated;

create or replace function public.ticket_detail(p_ticket_id uuid)
returns table(id uuid,ticket_code text,qr_token text,status text,booking_id uuid,used_at timestamptz,event_title text,business_name text,starts_at timestamptz,location text,ticket_type text,seat_label text,customer_name text,total_amount numeric)
language sql security definer set search_path='' as $$
select t.id,t.ticket_code,t.qr_token,t.status::text,t.booking_id,t.used_at,l.title,bu.name,s.starts_at,l.location_text,tt.name,
       case when bi.seat_id is null then null else se.row_label||se.seat_number end,b.customer_name,b.total_amount
from public.tickets t join public.bookings b on b.id=t.booking_id join public.booking_items bi on bi.id=t.booking_item_id join public.ticket_types tt on tt.id=bi.ticket_type_id
join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id left join public.seats se on se.id=bi.seat_id
where t.id=p_ticket_id and (b.customer_id=(select auth.uid()) or private.is_admin() or private.owns_business(bu.id));
$$;
revoke all on function public.ticket_detail(uuid) from public, anon;
grant execute on function public.ticket_detail(uuid) to authenticated;

create or replace function public.business_reviews_public(p_business_id uuid)
returns table(id uuid,rating int,comment text,created_at timestamptz,customer_name text)
language sql security definer set search_path='' as $$
select r.id,r.rating,r.comment,r.created_at,p.full_name from public.reviews r join public.profiles p on p.id=r.customer_id
where r.business_id=p_business_id and not r.is_hidden order by r.created_at desc;
$$;
revoke all on function public.business_reviews_public(uuid) from public;
grant execute on function public.business_reviews_public(uuid) to anon,authenticated;

create or replace function public.owner_bookings(p_business_id uuid)
returns table(id uuid,booking_code text,customer_name text,status text,total_amount numeric,listing_title text,starts_at timestamptz,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_user(); if not private.can_manage_business(p_business_id) then raise exception 'Not authorized'; end if;
  return query select b.id,b.booking_code,b.customer_name,b.status::text,b.total_amount,l.title,s.starts_at,b.created_at from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id order by b.created_at desc;
end;$$;
revoke all on function public.owner_bookings(uuid) from public, anon;
grant execute on function public.owner_bookings(uuid) to authenticated;

create or replace function public.owner_dashboard_stats(p_business_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.require_user(); if not private.can_manage_business(p_business_id) then raise exception 'Not authorized'; end if;
 return jsonb_build_object(
  'bookings',(select count(*) from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id),
  'tickets_sold',(select count(*) from public.tickets t join public.bookings b on b.id=t.booking_id join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id and t.status in ('valid','used')),
  'revenue',(select coalesce(sum(p.amount),0) from public.payments p join public.bookings b on b.id=p.booking_id join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id and p.status='paid'),
  'upcoming_events',(select count(*) from public.schedules s join public.listings l on l.id=s.listing_id where l.business_id=p_business_id and s.status='active' and s.starts_at>now()),
  'active_listings',(select count(*) from public.listings where business_id=p_business_id and status='active'),
  'available_tickets',(select coalesce(sum(greatest(0,tt.total_qty-tt.sold_qty-tt.held_qty)),0) from public.ticket_types tt join public.schedules s on s.id=tt.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id and s.status='active' and s.starts_at>now()),
  'cancelled_bookings',(select count(*) from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id where l.business_id=p_business_id and b.status in ('cancelled','refunded'))
 );
end;$$;
revoke all on function public.owner_dashboard_stats(uuid) from public, anon;
grant execute on function public.owner_dashboard_stats(uuid) to authenticated;

create or replace function public.owner_sales_by_event(p_business_id uuid)
returns table(event_title text,tickets_sold bigint,revenue numeric)
language plpgsql security definer set search_path='' as $$
begin
 perform private.require_user(); if not private.can_manage_business(p_business_id) then raise exception 'Not authorized'; end if;
 return query
 select l.title,
   (select count(*) from public.tickets t join public.bookings b on b.id=t.booking_id join public.schedules s on s.id=b.schedule_id where s.listing_id=l.id and t.status in ('valid','used'))::bigint,
   (select coalesce(sum(p.amount),0) from public.payments p join public.bookings b on b.id=p.booking_id join public.schedules s on s.id=b.schedule_id where s.listing_id=l.id and p.status='paid')
 from public.listings l
 where l.business_id=p_business_id
 order by 3 desc, l.title;
end;$$;
revoke all on function public.owner_sales_by_event(uuid) from public, anon;
grant execute on function public.owner_sales_by_event(uuid) to authenticated;

create or replace function public.admin_dashboard_stats()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.require_user(); if not private.is_admin() then raise exception 'Admin access required'; end if;
 return jsonb_build_object('users',(select count(*) from public.profiles),'businesses',(select count(*) from public.businesses),'events',(select count(*) from public.listings),'tickets_sold',(select count(*) from public.tickets where status in ('valid','used')),'bookings',(select count(*) from public.bookings),'revenue',(select coalesce(sum(amount),0) from public.payments where status='paid'),'active_businesses',(select count(*) from public.businesses where status='approved'),'pending_businesses',(select count(*) from public.businesses where status='pending'));
end;$$;
revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

create or replace function public.admin_set_business_status(p_business_id uuid,p_status text,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 perform private.require_user(); if not private.is_admin() then raise exception 'Admin access required'; end if;
 if p_status not in ('pending','approved','rejected','suspended') then raise exception 'Invalid status'; end if;
 if p_status in ('rejected','suspended') and coalesce(trim(p_reason),'')='' then raise exception 'A reason is required'; end if;
 update public.businesses set status=p_status::public.business_status,rejection_reason=case when p_status in ('rejected','suspended') then p_reason else null end where id=p_business_id returning owner_id into owner_id;
 if not found then raise exception 'Business not found'; end if;
 insert into public.notifications(user_id,type,title,body,data) values(owner_id,'business_status','Business status updated','Your business is now '||p_status||'.',jsonb_build_object('business_id',p_business_id,'status',p_status,'reason',p_reason));
 perform private.write_audit('BUSINESS_'||upper(p_status),'business',p_business_id,jsonb_build_object('reason',p_reason));
end;$$;
revoke all on function public.admin_set_business_status(uuid,text,text) from public, anon;
grant execute on function public.admin_set_business_status(uuid,text,text) to authenticated;
