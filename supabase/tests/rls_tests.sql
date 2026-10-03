-- Run after seed_demo.mjs with psql as a database owner.
-- This script proves customer isolation and owner isolation by impersonating authenticated JWT subjects.
\set ON_ERROR_STOP on
begin;

select id as customer1 from auth.users where email='customer1@tickethub.demo' \gset
select id as customer2 from auth.users where email='customer2@tickethub.demo' \gset
select id as owner1 from auth.users where email='owner1@tickethub.demo' \gset
select id as owner2 from auth.users where email='owner2@tickethub.demo' \gset

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',:'customer1',true);

do $$ begin
  if exists(select 1 from public.bookings where customer_id <> auth.uid()) then
    raise exception 'RLS failure: customer can see another customer booking';
  end if;
end $$;

select set_config('request.jwt.claim.sub',:'owner1',true);
do $$ declare other_listing uuid; visible int; begin
  reset role;
  select l.id into other_listing from public.listings l join public.businesses b on b.id=l.business_id where b.owner_id=:'owner2'::uuid limit 1;
  set local role authenticated;
  perform set_config('request.jwt.claim.role','authenticated',true);
  perform set_config('request.jwt.claim.sub',:'owner1',true);
  update public.listings set title=title||' SHOULD_NOT_WRITE' where id=other_listing;
  get diagnostics visible = row_count;
  if visible <> 0 then raise exception 'RLS failure: owner edited another owner listing'; end if;
end $$;
rollback;
