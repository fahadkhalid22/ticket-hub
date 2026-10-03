# TicketHub Features

## Customer
- Email/password registration and login with Customer/Owner-safe signup role selection.
- Home discovery, categories, business profiles, ratings, favorites, search and listing discovery.
- Multiple schedules and ticket types with live remaining inventory.
- Quantity booking for unseated listings and visual seat selection for seated schedules.
- 10-minute server hold with checkout countdown.
- Cash/Pay-at-venue, Card, JazzCash, Easypaisa and Wallet through a simulated provider interface.
- Booking confirmation, cancellation/refund logic, booking history and payment history.
- Digital tickets with non-guessable QR tokens and ticket status.
- Notifications, favorites, profile/settings and review-ready data model.

## Business Owner
- Business registration starts Pending and cannot self-approve.
- Business profile, listing CRUD, images, schedules, ticket types, inventory and booking limits.
- Simple seat-map creator that can configure seated schedules.
- Dashboard KPIs, sales-per-event analytics and owner bookings list.
- In-app QR scanner; authorization is re-checked by the database before ticket use.
- Suspension state hides public content while preserving existing bookings/tickets.

## Platform Admin
- Dashboard KPIs and analytics.
- Pending/approved/rejected/suspended business queue.
- Approve, reject with reason, suspend and reactivate RPC.
- Users, listings, bookings, payments, reviews, categories, reports, settings and audit log surfaces.
- Review hide/restore moderation and data-driven category management.

## Backend integrity
- RLS on every public application table.
- Server-side ownership checks for customer/owner/admin data.
- `sold_qty + held_qty <= total_qty` database check.
- Row locks for holds and QR scanning.
- Booking transition trigger.
- Rating aggregate trigger excluding hidden reviews.
- Event schedule change notification trigger.
- Storage upload policies for owner-controlled folders.
