import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const secret = process.env.SUPABASE_SECRET_KEY
if (!url || !secret) throw new Error('Set SUPABASE_URL and SUPABASE_SECRET_KEY')
const db = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } })

async function ensureUser(email, password, fullName, requestedRole) {
  const { data: page, error: listError } = await db.auth.admin.listUsers({ page: 1, perPage: 1000 })
  if (listError) throw listError
  const existing = page.users.find((u) => u.email === email)
  if (existing) return existing.id
  const { data, error } = await db.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { full_name: fullName, requested_role: requestedRole },
  })
  if (error) throw error
  return data.user.id
}
async function insertOne(table, values) {
  const { data, error } = await db.from(table).insert(values).select().single()
  if (error) throw new Error(`${table}: ${error.message}`)
  return data
}
async function maybeOne(table, filters) {
  let q = db.from(table).select('*')
  for (const [k, v] of Object.entries(filters)) q = q.eq(k, v)
  const { data, error } = await q.limit(1).maybeSingle()
  if (error) throw error
  return data
}

const users = {
  admin: await ensureUser('admin@tickethub.demo','TicketHub#Admin2026','Ayesha Admin','customer'),
  owner1: await ensureUser('owner1@tickethub.demo','TicketHub#Owner2026','Hamza Owner','owner'),
  owner2: await ensureUser('owner2@tickethub.demo','TicketHub#Owner2026','Sara Owner','owner'),
  customer1: await ensureUser('customer1@tickethub.demo','TicketHub#Customer2026','Fahad Customer','customer'),
  customer2: await ensureUser('customer2@tickethub.demo','TicketHub#Customer2026','Areeba Customer','customer'),
  customer3: await ensureUser('customer3@tickethub.demo','TicketHub#Customer2026','Ali Customer','customer'),
  customer4: await ensureUser('customer4@tickethub.demo','TicketHub#Customer2026','Noor Customer','customer'),
}
await db.from('profiles').update({ role: 'admin' }).eq('id', users.admin)

const categories = [
  ['Cinema','cinema','movie'],['Theatre','theatre','theater_comedy'],['Events','events','event'],['Concerts','concerts','music_note'],['Sports','sports','sports_soccer'],['Workshops','workshops','school'],['Attractions','attractions','attractions'],['Experiences','experiences','explore'],['Other Ticketed Services','other-ticketed-services','local_activity'],
]
for (let i=0;i<categories.length;i++) {
  const [name,slug,icon]=categories[i]
  await db.from('categories').upsert({name,slug,icon,is_active:true,sort_order:i+1},{onConflict:'slug'})
}
for (const [key,value] of [['service_fee_percent',2.5],['hold_minutes',10],['cancellation_hours',24]]) {
  await db.from('platform_settings').upsert({key,value},{onConflict:'key'})
}
const { data: categoryRows, error: categoryError } = await db.from('categories').select('id,slug')
if (categoryError) throw categoryError
const cid = Object.fromEntries(categoryRows.map((x)=>[x.slug,x.id]))

const businessDefs = [
  ['Grand Cinema Islamabad','cinema','Islamabad','approved',users.owner1],
  ['Pulse Live Pakistan','concerts','Islamabad','approved',users.owner2],
  ['Capital Sports Arena','sports','Islamabad','approved',users.owner1],
  ['Makers Lab Islamabad','workshops','Islamabad','approved',users.owner2],
  ['Adventure World Park','attractions','Rawalpindi','approved',users.owner1],
  ['StageCraft Theatre','theatre','Islamabad','pending',users.owner2],
  ['Skyline Experiences','experiences','Murree','suspended',users.owner2],
]
const businesses = {}
for (const [name,slug,city,status,owner_id] of businessDefs) {
  let row = await maybeOne('businesses',{name})
  if (!row) row = await insertOne('businesses',{owner_id,category_id:cid[slug],name,description:`${name} is seeded demo content for TicketHub.`,address:`Main Boulevard, ${city}`,city,phone:'+92 300 0000000',email:`${slug}@tickethub.demo`,status})
  else await db.from('businesses').update({status}).eq('id',row.id)
  businesses[name] = row
}

const listingDefs = [
  ['Grand Cinema Islamabad','cinema','Midnight Premiere','Cinema',true,'A red-carpet midnight premiere with premium cinema sound.','Grand Cinema Islamabad • Hall A','2026-10-19T14:00:00.000Z',800],
  ['Grand Cinema Islamabad','cinema','Family Animation Weekend','Cinema',true,'A colourful family animation screening for kids and parents.','Grand Cinema Islamabad • Hall A','2026-10-20T14:00:00.000Z',1075],
  ['Grand Cinema Islamabad','events','Director Q&A Night','Special Event',false,'A cinema screening followed by a live director question-and-answer session.','Grand Cinema Islamabad • Hall A','2026-10-21T14:00:00.000Z',1150],
  ['Pulse Live Pakistan','concerts','Islamabad Live 2026','Concert',true,'A large-scale live concert featuring local performers.','Pulse Live Pakistan • Islamabad','2026-10-22T14:00:00.000Z',1500],
  ['Pulse Live Pakistan','concerts','Acoustic Sunset','Concert',false,'An outdoor acoustic concert under the evening sky.','Pulse Live Pakistan • Islamabad','2026-10-23T14:00:00.000Z',1300],
  ['Capital Sports Arena','sports','Capital Derby','Football',true,'A high-energy football derby at Capital Sports Arena.','Capital Sports Arena • Islamabad','2026-10-24T14:00:00.000Z',1375],
  ['Capital Sports Arena','sports','Weekend Basketball Cup','Basketball',false,'A weekend basketball cup with general and courtside viewing.','Capital Sports Arena • Islamabad','2026-10-25T14:00:00.000Z',1450],
  ['Makers Lab Islamabad','workshops','Pottery for Beginners','Workshop',true,'A guided beginner pottery workshop with materials included.','Makers Lab Islamabad','2026-10-26T14:00:00.000Z',1525],
  ['Makers Lab Islamabad','workshops','Build Your First Robot','Workshop',false,'A hands-on beginner robotics workshop at Makers Lab Islamabad.','Makers Lab Islamabad','2026-10-27T14:00:00.000Z',1600],
  ['Adventure World Park','attractions','Adventure Day Pass','Attraction',true,'An evening pass for selected family rides and attractions.','Adventure World Park • Rawalpindi','2026-10-28T14:00:00.000Z',1675],
  ['Adventure World Park','experiences','Zipline Experience','Experience',false,'A guided sunset zipline experience at Adventure World Park.','Adventure World Park • Rawalpindi','2026-10-29T14:00:00.000Z',1750],
  ['Adventure World Park','events','Family Night Festival','Event',true,'A family night festival with rides, food and live activities.','Adventure World Park • Rawalpindi','2026-10-30T14:00:00.000Z',1825],
]
const listings=[]
for (const [businessName,slug,title,event_type,is_featured,description,location_text,starts_at,price] of listingDefs) {
  const business=businesses[businessName]
  let row=await maybeOne('listings',{business_id:business.id,title})
  const values={business_id:business.id,category_id:cid[slug],title,description,event_type,location_text,terms:'Venue rules apply. Eligible cancellations use the configured platform window.',status:'active',is_featured,booking_open:true}
  if(!row) row=await insertOne('listings',values)
  else { const {data,error}=await db.from('listings').update(values).eq('id',row.id).select().single(); if(error)throw error; row=data }
  listings.push({...row,starts_at,price})
}

for(let i=0;i<listings.length;i++){
  const start=new Date(listings[i].starts_at)
  const scheduleValues={starts_at:start.toISOString(),ends_at:new Date(start.getTime()+7200000).toISOString(),venue_or_hall:listings[i].location_text,capacity:i===3?650:120,booking_limit_per_user:6,status:'active'}
  let schedule=await maybeOne('schedules',{listing_id:listings[i].id})
  if(!schedule) schedule=await insertOne('schedules',{listing_id:listings[i].id,...scheduleValues})
  else { const {data,error}=await db.from('schedules').update(scheduleValues).eq('id',schedule.id).select().single(); if(error)throw error; schedule=data }
  const defs=i===0?[['Regular',800,80],['Premium',1200,30],['VIP',1800,10]]:i===3?[['General Admission',1500,500],['VIP',3000,100],['Premium',5000,50]]:[['General',listings[i].price,120]]
  for(let k=0;k<defs.length;k++){const [name,price,total_qty]=defs[k];const type=await maybeOne('ticket_types',{schedule_id:schedule.id,name});if(!type)await insertOne('ticket_types',{schedule_id:schedule.id,name,price,total_qty,sold_qty:0,held_qty:0,sort_order:k});else {const {error}=await db.from('ticket_types').update({price,total_qty,sort_order:k}).eq('id',type.id);if(error)throw error}}
}

// Create one visual seat map for the first cinema schedule.
const cinema = listings[0]
const { data: cinemaSchedule } = await db.from('schedules').select('*').eq('listing_id',cinema.id).limit(1).single()
let seatMap=await maybeOne('seat_maps',{business_id:businesses['Grand Cinema Islamabad'].id,name:'Hall A Demo Map'})
if(!seatMap){
  seatMap=await insertOne('seat_maps',{business_id:businesses['Grand Cinema Islamabad'].id,name:'Hall A Demo Map',layout:{rows:8,seats_per_row:10}})
  const seats=[];for(let r=0;r<8;r++)for(let n=1;n<=10;n++)seats.push({seat_map_id:seatMap.id,row_label:String.fromCharCode(65+r),seat_number:String(n),category:'Regular',x:n,y:r})
  const { error }=await db.from('seats').insert(seats);if(error)throw error
}
const { data: regular }=await db.from('ticket_types').select('*').eq('schedule_id',cinemaSchedule.id).eq('name','Regular').single()
const { count }=await db.from('schedule_seats').select('id',{count:'exact',head:true}).eq('schedule_id',cinemaSchedule.id)
if((count??0)===0){
  await db.from('schedules').update({seat_map_id:seatMap.id}).eq('id',cinemaSchedule.id)
  const { data: seats }=await db.from('seats').select('id').eq('seat_map_id',seatMap.id)
  const { error }=await db.from('schedule_seats').insert(seats.map((s)=>({schedule_id:cinemaSchedule.id,seat_id:s.id,ticket_type_id:regular.id,status:'available'})));if(error)throw error
  await db.from('ticket_types').update({total_qty:seats.length}).eq('id',regular.id)
}


// Sample bookings across all required statuses for evaluator/admin views.
const sampleSchedule = await (async()=>{ const {data}=await db.from('schedules').select('*').eq('listing_id',listings[1].id).limit(1).single(); return data })()
const sampleType = await (async()=>{ const {data}=await db.from('ticket_types').select('*').eq('schedule_id',sampleSchedule.id).limit(1).single(); return data })()
async function sampleBooking(code,status,customerId,withPaid=false,ticketState=null){
  if(await maybeOne('bookings',{booking_code:code})) return
  const profile = await (async()=>{const {data}=await db.from('profiles').select('*').eq('id',customerId).single();return data})()
  const activeInventory=['confirmed','paid','completed','used'].includes(status)
  const held=status==='pending'
  const booking=await insertOne('bookings',{booking_code:code,customer_id:customerId,schedule_id:sampleSchedule.id,status,total_amount:sampleType.price,customer_name:profile.full_name,customer_phone:profile.phone,customer_email:null,hold_expires_at:held?new Date(Date.now()+600000).toISOString():null})
  const item=await insertOne('booking_items',{booking_id:booking.id,ticket_type_id:sampleType.id,unit_price:sampleType.price,quantity:1})
  if(activeInventory){
    const {data:current,error:readError}=await db.from('ticket_types').select('sold_qty').eq('id',sampleType.id).single(); if(readError)throw readError
    const {error:updateError}=await db.from('ticket_types').update({sold_qty:(current.sold_qty??0)+1}).eq('id',sampleType.id); if(updateError)throw updateError
  }
  if(held){
    const {data:current,error:readError}=await db.from('ticket_types').select('held_qty').eq('id',sampleType.id).single(); if(readError)throw readError
    const {error:updateError}=await db.from('ticket_types').update({held_qty:(current.held_qty??0)+1}).eq('id',sampleType.id); if(updateError)throw updateError
  }
  if(ticketState){const {data:t}=await db.from('tickets').insert({booking_id:booking.id,booking_item_id:item.id,status:ticketState,used_at:ticketState==='used'?new Date().toISOString():null}).select().single(); void t}
  if(withPaid) await db.from('payments').insert({booking_id:booking.id,method:'card',provider_ref:`SEED-${code}`,amount:sampleType.price,status:status==='refunded'?'refunded':'paid'})
  else if(status==='confirmed') await db.from('payments').insert({booking_id:booking.id,method:'cash',provider_ref:`SEED-${code}`,amount:sampleType.price,status:'pending'})
  return booking
}
const sampleBookings=[]
sampleBookings.push(await sampleBooking('DEMO-PENDING-001','pending',users.customer1,false,null))
sampleBookings.push(await sampleBooking('DEMO-CONFIRMED-001','confirmed',users.customer2,false,'valid'))
sampleBookings.push(await sampleBooking('DEMO-PAID-001','paid',users.customer3,true,'valid'))
sampleBookings.push(await sampleBooking('DEMO-CANCELLED-001','cancelled',users.customer4,false,'cancelled'))
const completed=await sampleBooking('DEMO-COMPLETED-001','completed',users.customer1,true,'valid'); sampleBookings.push(completed)
sampleBookings.push(await sampleBooking('DEMO-USED-001','used',users.customer2,true,'used'))
sampleBookings.push(await sampleBooking('DEMO-REFUNDED-001','refunded',users.customer3,true,'refunded'))
if(completed && !await maybeOne('reviews',{booking_id:completed.id})) await db.from('reviews').insert({booking_id:completed.id,customer_id:users.customer1,business_id:businesses['Grand Cinema Islamabad'].id,listing_id:listings[1].id,rating:5,comment:'Smooth demo booking experience.'})

await db.from('notifications').insert([
  {user_id:users.customer1,type:'welcome',title:'Welcome to TicketHub',body:'Discover and book your next experience.',data:{}},
  {user_id:users.owner1,type:'owner_welcome',title:'Owner dashboard ready',body:'Your approved businesses can publish active listings.',data:{}},
])
console.log('TicketHub demo seed complete.')
console.log(users)
