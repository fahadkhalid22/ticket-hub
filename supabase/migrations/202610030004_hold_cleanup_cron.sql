-- Scheduled cleanup/reminders plus lazy cleanup inside availability reads.
create extension if not exists pg_cron;

create or replace function private.create_upcoming_event_reminders_impl()
returns integer language plpgsql security definer set search_path='' as $$
declare inserted_count int:=0;
begin
  with candidate as (
    select b.customer_id,b.id booking_id,s.id schedule_id,s.starts_at,l.title,bu.owner_id
    from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id
    where b.status in ('confirmed','paid') and s.starts_at between now()+interval '23 hours' and now()+interval '24 hours'
  ), ins as (
    insert into public.notifications(user_id,type,title,body,data)
    select c.customer_id,'upcoming_event','Event tomorrow',c.title||' starts in about 24 hours.',jsonb_build_object('booking_id',c.booking_id,'schedule_id',c.schedule_id)
    from candidate c where not exists(select 1 from public.notifications n where n.user_id=c.customer_id and n.type='upcoming_event' and n.data->>'schedule_id'=c.schedule_id::text)
    returning 1
  ) select count(*) into inserted_count from ins;

  insert into public.notifications(user_id,type,title,body,data)
  select distinct c.owner_id,'event_reminder','Upcoming event reminder',c.title||' has customers booked and starts in about 24 hours.',jsonb_build_object('schedule_id',c.schedule_id)
  from (
    select bu.owner_id,s.id schedule_id,l.title from public.bookings b join public.schedules s on s.id=b.schedule_id join public.listings l on l.id=s.listing_id join public.businesses bu on bu.id=l.business_id
    where b.status in ('confirmed','paid') and s.starts_at between now()+interval '23 hours' and now()+interval '24 hours'
  ) c where not exists(select 1 from public.notifications n where n.user_id=c.owner_id and n.type='event_reminder' and n.data->>'schedule_id'=c.schedule_id::text);
  return inserted_count;
end;$$;
revoke all on function private.create_upcoming_event_reminders_impl() from public,anon,authenticated;

select cron.unschedule(jobid) from cron.job where jobname in ('tickethub-release-holds','tickethub-event-reminders');
select cron.schedule('tickethub-release-holds','* * * * *',$$select private.release_expired_holds_impl();$$);
select cron.schedule('tickethub-event-reminders','0 * * * *',$$select private.create_upcoming_event_reminders_impl();$$);
