# TicketHub Architecture

## Runtime architecture

```mermaid
flowchart LR
  UI[Flutter Material 3 screens] --> STATE[Riverpod providers]
  STATE --> REPO[TicketHubRepository]
  REPO --> AUTH[Supabase Auth]
  REPO --> REST[Supabase Data API]
  REPO --> RPC[PostgreSQL RPC]
  REPO --> STORE[Supabase Storage]
  RPC --> DB[(PostgreSQL)]
  DB --> RLS[Row Level Security]
  DB --> CRON[pg_cron hold cleanup]
```

The client never decides authoritative inventory, approval, cancellation, or QR-use state. Critical mutations execute in PostgreSQL functions, while RLS protects direct table access.

## Core domain

```mermaid
erDiagram
  PROFILES ||--o{ BUSINESSES : owns
  CATEGORIES ||--o{ BUSINESSES : classifies
  BUSINESSES ||--o{ LISTINGS : publishes
  LISTINGS ||--o{ SCHEDULES : schedules
  SCHEDULES ||--o{ TICKET_TYPES : offers
  BUSINESSES ||--o{ SEAT_MAPS : owns
  SEAT_MAPS ||--o{ SEATS : contains
  SCHEDULES ||--o{ SCHEDULE_SEATS : allocates
  PROFILES ||--o{ BOOKINGS : creates
  BOOKINGS ||--|{ BOOKING_ITEMS : contains
  BOOKINGS ||--o{ TICKETS : generates
  BOOKINGS ||--o{ PAYMENTS : records
  BOOKINGS ||--o| REVIEWS : permits
  PROFILES ||--o{ FAVORITES : saves
  PROFILES ||--o{ NOTIFICATIONS : receives
```

## Booking transaction boundary

`hold_tickets` validates schedule visibility, booking limit, ticket quantities, seat state and inventory while relevant rows are locked. It creates a Pending booking and increases held inventory. `confirm_booking` converts held inventory to sold inventory, books seats, creates one QR ticket per admission entitlement, records payment, and emits notifications. `release_expired_holds` returns stale inventory; pg_cron invokes the private cleanup every minute and availability reads also invoke it lazily. `cancel_booking` restores eligible inventory and records refund state. `validate_ticket` locks the ticket row and atomically marks it Used.

## General-purpose model

A cinema, concert, sports match, workshop or attraction uses the same `business -> listing -> schedule -> ticket_type` hierarchy. `seat_map_id` is optional, so seated and general-admission products do not require separate code paths or schemas.
