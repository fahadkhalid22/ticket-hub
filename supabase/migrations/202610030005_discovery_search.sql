-- Server-side discovery/search read model.
-- Cross-table filters remain authoritative on the backend and expose only approved/active listings.
create or replace function public.search_listings(
  p_query text default null,
  p_business_query text default null,
  p_category_id uuid default null,
  p_location text default null,
  p_start_date timestamptz default null,
  p_end_date timestamptz default null,
  p_min_price numeric default null,
  p_max_price numeric default null,
  p_event_type text default null,
  p_available_only boolean default true,
  p_sort text default 'newest',
  p_limit integer default 100
)
returns table(
  id uuid,
  business_id uuid,
  category_id uuid,
  title text,
  description text,
  poster_url text,
  event_type text,
  location_text text,
  terms text,
  status text,
  is_featured boolean,
  booking_open boolean,
  business_name text,
  business_rating numeric,
  next_start timestamptz,
  min_price numeric,
  remaining bigint,
  sold_count bigint,
  created_at timestamptz
)
language sql
stable
security definer
set search_path=''
as $$
  with candidates as (
    select
      l.id,
      l.business_id,
      l.category_id,
      l.title,
      l.description,
      l.poster_url,
      l.event_type,
      l.location_text,
      l.terms,
      l.status::text as status,
      l.is_featured,
      l.booking_open,
      b.name as business_name,
      b.rating_avg as business_rating,
      (
        select min(s.starts_at)
        from public.schedules s
        where s.listing_id=l.id and s.status='active' and s.starts_at>now()
      ) as next_start,
      (
        select min(tt.price)
        from public.schedules s
        join public.ticket_types tt on tt.schedule_id=s.id
        where s.listing_id=l.id and s.status='active' and s.starts_at>now()
      ) as min_price,
      (
        select coalesce(sum(greatest(tt.total_qty-tt.sold_qty-tt.held_qty,0)),0)::bigint
        from public.schedules s
        join public.ticket_types tt on tt.schedule_id=s.id
        where s.listing_id=l.id and s.status='active' and s.starts_at>now()
      ) as remaining,
      (
        select count(*)::bigint
        from public.tickets t
        join public.bookings bk on bk.id=t.booking_id
        join public.schedules s on s.id=bk.schedule_id
        where s.listing_id=l.id and t.status in ('valid','used')
      ) as sold_count,
      l.created_at
    from public.listings l
    join public.businesses b on b.id=l.business_id
    where b.status='approved'
      and l.status='active'
      and l.booking_open
      and (
        p_query is null or trim(p_query)='' or
        l.title ilike '%'||trim(p_query)||'%' or
        coalesce(l.description,'') ilike '%'||trim(p_query)||'%'
      )
      and (
        p_business_query is null or trim(p_business_query)='' or
        b.name ilike '%'||trim(p_business_query)||'%'
      )
      and (p_category_id is null or l.category_id=p_category_id)
      and (
        p_location is null or trim(p_location)='' or
        coalesce(l.location_text,'') ilike '%'||trim(p_location)||'%' or
        coalesce(b.city,'') ilike '%'||trim(p_location)||'%'
      )
      and (
        p_event_type is null or trim(p_event_type)='' or
        coalesce(l.event_type,'') ilike '%'||trim(p_event_type)||'%'
      )
      and exists (
        select 1 from public.schedules sx
        where sx.listing_id=l.id
          and sx.status='active'
          and sx.starts_at>now()
          and (p_start_date is null or sx.starts_at>=p_start_date)
          and (p_end_date is null or sx.starts_at<=p_end_date)
      )
      and (
        (p_min_price is null and p_max_price is null) or exists (
          select 1
          from public.schedules sx
          join public.ticket_types tx on tx.schedule_id=sx.id
          where sx.listing_id=l.id
            and sx.status='active'
            and sx.starts_at>now()
            and (p_min_price is null or tx.price>=p_min_price)
            and (p_max_price is null or tx.price<=p_max_price)
        )
      )
      and (
        not p_available_only or exists (
          select 1
          from public.schedules sx
          join public.ticket_types tx on tx.schedule_id=sx.id
          where sx.listing_id=l.id
            and sx.status='active'
            and sx.starts_at>now()
            and (tx.total_qty-tx.sold_qty-tx.held_qty)>0
        )
      )
  )
  select * from candidates c
  order by
    case when lower(p_sort)='popular' then c.sold_count end desc nulls last,
    case when lower(p_sort)='price low-high' then c.min_price end asc nulls last,
    case when lower(p_sort)='price high-low' then c.min_price end desc nulls last,
    case when lower(p_sort)='highest rated' then c.business_rating end desc nulls last,
    case when lower(p_sort)='upcoming' then c.next_start end asc nulls last,
    case when lower(p_sort)='newest' then c.created_at end desc nulls last,
    c.created_at desc
  limit greatest(1,least(coalesce(p_limit,100),200));
$$;

revoke all on function public.search_listings(text,text,uuid,text,timestamptz,timestamptz,numeric,numeric,text,boolean,text,integer) from public;
grant execute on function public.search_listings(text,text,uuid,text,timestamptz,timestamptz,numeric,numeric,text,boolean,text,integer) to anon,authenticated;
