-- TicketHub core schema
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create type public.user_role as enum ('customer','owner','admin');
create type public.business_status as enum ('pending','approved','rejected','suspended');
create type public.listing_status as enum ('draft','active','paused','cancelled','completed');
create type public.seat_status as enum ('available','held','booked');
create type public.booking_status as enum ('pending','confirmed','paid','cancelled','completed','used','refunded');
create type public.ticket_status as enum ('valid','used','cancelled','refunded');
create type public.payment_status as enum ('pending','paid','failed','refunded');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 2 and 120),
  phone text,
  avatar_url text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  icon text,
  is_active boolean not null default true,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid references public.categories(id),
  name text not null check (char_length(trim(name)) between 2 and 160),
  logo_url text,
  cover_url text,
  description text,
  address text,
  city text,
  lat numeric(9,6),
  lng numeric(9,6),
  phone text,
  email text,
  status public.business_status not null default 'pending',
  rejection_reason text,
  rating_avg numeric(3,2) not null default 0 check (rating_avg between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  created_at timestamptz not null default now()
);

create table public.staff (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (business_id,user_id)
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid references public.categories(id),
  title text not null check (char_length(trim(title)) between 2 and 180),
  description text,
  poster_url text,
  gallery jsonb not null default '[]'::jsonb check (jsonb_typeof(gallery)='array'),
  event_type text,
  location_text text,
  terms text,
  status public.listing_status not null default 'draft',
  is_featured boolean not null default false,
  booking_open boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.seat_maps (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  layout jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.seats (
  id uuid primary key default gen_random_uuid(),
  seat_map_id uuid not null references public.seat_maps(id) on delete cascade,
  row_label text not null,
  seat_number text not null,
  category text not null default 'General',
  x numeric not null default 0,
  y numeric not null default 0,
  created_at timestamptz not null default now(),
  unique(seat_map_id,row_label,seat_number)
);

create table public.schedules (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  venue_or_hall text,
  seat_map_id uuid references public.seat_maps(id),
  capacity integer not null check (capacity > 0),
  booking_limit_per_user integer not null default 10 check (booking_limit_per_user between 1 and 100),
  status text not null default 'active' check (status in ('active','paused','cancelled','completed')),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table public.ticket_types (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.schedules(id) on delete cascade,
  name text not null,
  price numeric(12,2) not null check (price >= 0),
  total_qty integer not null check (total_qty >= 0),
  sold_qty integer not null default 0 check (sold_qty >= 0),
  held_qty integer not null default 0 check (held_qty >= 0),
  seat_category text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(schedule_id,name),
  check (sold_qty + held_qty <= total_qty)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique default ('TH-' || upper(substr(encode(gen_random_bytes(6),'hex'),1,12))),
  customer_id uuid not null references public.profiles(id),
  schedule_id uuid not null references public.schedules(id),
  status public.booking_status not null default 'pending',
  total_amount numeric(12,2) not null check (total_amount >= 0),
  customer_name text not null,
  customer_phone text,
  customer_email text,
  hold_expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  ticket_type_id uuid not null references public.ticket_types(id),
  seat_id uuid references public.seats(id),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now()
);

create table public.schedule_seats (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.schedules(id) on delete cascade,
  seat_id uuid not null references public.seats(id) on delete cascade,
  ticket_type_id uuid not null references public.ticket_types(id),
  status public.seat_status not null default 'available',
  held_by uuid references public.profiles(id),
  held_until timestamptz,
  booking_id uuid references public.bookings(id),
  created_at timestamptz not null default now(),
  unique(schedule_id,seat_id)
);

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_code text not null unique default ('TKT-' || upper(substr(encode(gen_random_bytes(8),'hex'),1,16))),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  booking_item_id uuid not null references public.booking_items(id) on delete cascade,
  qr_token text not null unique default encode(gen_random_bytes(32),'hex'),
  status public.ticket_status not null default 'valid',
  used_at timestamptz,
  used_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  method text not null check (method in ('cash','pay_at_venue','card','jazzcash','easypaisa','wallet')),
  provider_ref text,
  amount numeric(12,2) not null check (amount >= 0),
  status public.payment_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null check (char_length(trim(comment)) between 2 and 2000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.favorites (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(customer_id,business_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.platform_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor uuid references public.profiles(id),
  action text not null,
  entity text not null,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index businesses_owner_idx on public.businesses(owner_id);
create index businesses_public_idx on public.businesses(status,category_id,city);
create index listings_discovery_idx on public.listings(status,booking_open,category_id,created_at desc);
create index listings_business_idx on public.listings(business_id);
create index schedules_listing_time_idx on public.schedules(listing_id,starts_at);
create index ticket_types_schedule_idx on public.ticket_types(schedule_id);
create index bookings_customer_idx on public.bookings(customer_id,created_at desc);
create index bookings_schedule_idx on public.bookings(schedule_id,status);
create index schedule_seats_schedule_status_idx on public.schedule_seats(schedule_id,status);
create index tickets_booking_idx on public.tickets(booking_id);
create index tickets_qr_idx on public.tickets(qr_token);
create index payments_booking_idx on public.payments(booking_id);
create index notifications_user_idx on public.notifications(user_id,created_at desc);
create index reviews_business_idx on public.reviews(business_id,is_hidden,created_at desc);

-- New-user trigger: user-editable metadata can request only customer/owner, never admin.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare safe_role public.user_role;
begin
  safe_role := case when new.raw_user_meta_data->>'requested_role' = 'owner' then 'owner'::public.user_role else 'customer'::public.user_role end;
  insert into public.profiles(id,full_name,phone,role)
  values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'TicketHub User'),new.raw_user_meta_data->>'phone',safe_role);
  return new;
end;$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

create or replace function private.enforce_booking_transition()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.status = new.status then return new; end if;
  if not (
    (old.status='pending' and new.status in ('confirmed','paid','cancelled')) or
    (old.status='confirmed' and new.status in ('paid','cancelled','used','completed')) or
    (old.status='paid' and new.status in ('cancelled','refunded','used','completed')) or
    (old.status='cancelled' and new.status='refunded') or
    (old.status='completed' and new.status='used')
  ) then raise exception 'Invalid booking status transition: % -> %', old.status, new.status; end if;
  return new;
end;$$;
create trigger bookings_status_transition before update of status on public.bookings for each row execute function private.enforce_booking_transition();

create or replace function private.refresh_business_rating()
returns trigger language plpgsql security definer set search_path='' as $$
declare bid uuid := coalesce(new.business_id, old.business_id);
begin
  update public.businesses b set
    rating_avg = coalesce((select round(avg(r.rating)::numeric,2) from public.reviews r where r.business_id=bid and not r.is_hidden),0),
    rating_count = (select count(*) from public.reviews r where r.business_id=bid and not r.is_hidden)
  where b.id=bid;
  return coalesce(new,old);
end;$$;
revoke all on function private.refresh_business_rating() from public, anon, authenticated;
create trigger reviews_rating_refresh after insert or update or delete on public.reviews for each row execute function private.refresh_business_rating();

create or replace function private.notify_schedule_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if (old.starts_at,old.ends_at,old.venue_or_hall) is distinct from (new.starts_at,new.ends_at,new.venue_or_hall) then
    insert into public.notifications(user_id,type,title,body,data)
    select distinct b.customer_id,'event_changed','Event details changed','The date, time, or venue for one of your bookings changed.',jsonb_build_object('schedule_id',new.id)
    from public.bookings b where b.schedule_id=new.id and b.status in ('confirmed','paid');
  end if;
  return new;
end;$$;
revoke all on function private.notify_schedule_change() from public, anon, authenticated;
create trigger schedules_change_notification after update on public.schedules for each row execute function private.notify_schedule_change();

-- Storage buckets for public marketplace imagery. Upload policies are added with RLS.
insert into storage.buckets(id,name,public) values('business-media','business-media',true),('listing-media','listing-media',true)
on conflict(id) do update set public=excluded.public;
