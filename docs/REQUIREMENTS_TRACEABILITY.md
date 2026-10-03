# TicketHub Requirements Traceability — R-01 to R-33

This matrix maps the master-prompt contract to concrete source/database artifacts. “Implemented” means source is present in this package. Runtime proof still requires executing the Flutter app and Supabase migrations in a real environment.

| ID | Requirement | Evidence | Source status |
|---|---|---|---|
| R-01 | Customer, Owner, Admin roles + RBAC | `profiles.role`, auth trigger, RLS helpers/policies, `app_router.dart` guards | Implemented |
| R-02 | General-purpose marketplace | Generic Business → Listing → Schedule → Ticket Type → optional Seat Map model | Implemented |
| R-03 | Home content | `CustomerHomeScreen`, categories, banner, businesses, events | Implemented; dynamic expansion supported |
| R-04 | Admin-editable categories | `categories` table, admin category screen, seed categories | Implemented |
| R-05 | Business discovery/profile | repository discovery methods, business cards/details/reviews | Implemented |
| R-06 | Event/service details | listing/schedule/ticket-type models and detail screen | Implemented |
| R-07 | Search/filter/sort | `SearchScreen`, `search_listings` RPC, business/category/location/date/price/type/availability filters + required sorts | Implemented |
| R-08 | Favorites | `favorites` table/RLS, toggle/list UI | Implemented |
| R-09 | Multiple ticket types + inventory | `ticket_types` schema/check constraint, owner ticket management | Implemented |
| R-10 | Visual seats / quantity mode | `schedule_seats`, seat map RPC, `SeatSelectionScreen`, `TicketSelectionScreen` | Implemented |
| R-11 | Temporary reservation | `hold_tickets`, `held_qty`, `held_until`, release RPC/cron, checkout countdown | Implemented |
| R-12 | Booking flow | ticket/seat select → hold → checkout → confirmation routes/screens | Implemented |
| R-13 | Simulated payment provider | `PaymentProvider`, `SimulatedPaymentProvider`, payments table/history | Implemented |
| R-14 | Booking statuses/transitions | enum + transition trigger + `StatusChip` | Implemented |
| R-15 | Cancellation/refund | `cancel_booking` transaction + UI actions | Implemented |
| R-16 | Digital ticket | `tickets` table, detail RPC, QR ticket screen | Implemented |
| R-17 | Atomic QR validation | `validate_ticket` row lock + owner scanner | Implemented |
| R-18 | Customer account | profile, tickets, history, favorites, notifications, payments, settings | Implemented |
| R-19 | Reviews/ratings | eligible-review RLS, rating trigger, customer/admin screens | Implemented |
| R-20 | Business management | registration/profile/update + media storage | Implemented |
| R-21 | Listing management | owner listing CRUD, schedules, ticket types, media | Implemented |
| R-22 | Owner dashboard | stats RPC, chart/KPIs, sales-by-event | Implemented |
| R-23 | Owner screens | owner dashboard/profile/listings/tickets/inventory/bookings/analytics/scanner/settings | Implemented |
| R-24 | Admin management | users/businesses/listings/tickets/bookings/payments/reviews/categories/settings/audit screens | Implemented |
| R-25 | Admin dashboard | stats RPC + admin KPI/charts | Implemented |
| R-26 | Business approval workflow | status enum, visibility RLS, admin status RPC/UI | Implemented |
| R-27 | Notifications | notification table/RLS; booking/cancel/event-change/upcoming triggers | Implemented |
| R-28 | Technical expectations | Flutter architecture, Supabase backend, RLS, CRUD, validation, QR, tests/docs | Implemented in source; runtime verification required |
| R-29 | Customer screens | route map in `app_router.dart` and customer/auth/ticket/booking screen files | Implemented |
| R-30 | End-to-end flow | schema/RPC/UI route chain + demo seeder | Implemented in source; connected run required |
| R-31 | Submission package | source, schema, README, docs, tests, demo script, presentation outline | Implemented; screenshots/build binary require runtime |
| R-32 | Daily LinkedIn posts | `docs/LINKEDIN_POSTS.md` | Implemented |
| R-33 | Evaluation targets | architecture and docs organized around rubric | Implemented as project target |

## Critical security evidence

- `supabase/migrations/202610030002_rls.sql`: all exposed app tables use RLS; role/ownership policies are server-side.
- `private.protect_profile_fields`: blocks self-escalation to admin.
- `private.protect_ticket_inventory_fields`: blocks forged sold/held counters from direct authenticated updates.
- `public.hold_tickets`: creates temporary holds transactionally.
- `public.confirm_booking`: converts held inventory to sold inventory and creates tickets/payments atomically.
- `public.cancel_booking`: releases inventory/seats and applies cancel/refund state.
- `public.validate_ticket`: locks the ticket row and atomically marks it used.
- `supabase/tests/rls_tests.sql` and `supabase/tests/concurrency_test.md`: verification procedures for cross-user access and races.
