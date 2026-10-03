-- Customers can correct contact details only while their own booking is still pending and held.
create or replace function public.update_pending_booking_contact(
  p_booking_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_customer_email text
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  uid uuid := private.require_user();
  b public.bookings%rowtype;
begin
  select * into b from public.bookings where id=p_booking_id for update;
  if not found or b.customer_id<>uid then raise exception 'Booking not found'; end if;
  if b.status<>'pending' then raise exception 'Only a pending booking can be edited'; end if;
  if b.hold_expires_at is null or b.hold_expires_at<=now() then raise exception 'Booking hold expired'; end if;
  if char_length(trim(coalesce(p_customer_name,'')))<2 then raise exception 'Enter a valid customer name'; end if;
  if char_length(trim(coalesce(p_customer_phone,'')))<7 then raise exception 'Enter a valid phone number'; end if;
  if position('@' in coalesce(p_customer_email,''))<2 then raise exception 'Enter a valid email address'; end if;
  update public.bookings set
    customer_name=trim(p_customer_name),
    customer_phone=trim(p_customer_phone),
    customer_email=lower(trim(p_customer_email))
  where id=b.id;
end;$$;

revoke all on function public.update_pending_booking_contact(uuid,text,text,text) from public,anon;
grant execute on function public.update_pending_booking_contact(uuid,text,text,text) to authenticated;
