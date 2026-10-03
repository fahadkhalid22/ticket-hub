-- Run after scripts/seed_demo.mjs with psql as a database owner.
-- Sequentially proves atomic state semantics: first valid scan succeeds, replay is Already Used.
\set ON_ERROR_STOP on
begin;

select id as owner1 from auth.users where email='owner1@tickethub.demo' \gset
select t.qr_token as paid_qr
from public.tickets t
join public.bookings b on b.id=t.booking_id
where b.booking_code='DEMO-PAID-001'
limit 1 \gset

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',:'owner1',true);

do $$
declare first_result text; second_result text;
begin
  first_result := public.validate_ticket(:'paid_qr', :'owner1'::uuid)->>'result';
  if first_result <> 'Valid' then
    raise exception 'Expected first scan Valid, got %', first_result;
  end if;

  second_result := public.validate_ticket(:'paid_qr', :'owner1'::uuid)->>'result';
  if second_result <> 'Already Used' then
    raise exception 'Expected replay Already Used, got %', second_result;
  end if;
end $$;

rollback;
