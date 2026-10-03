# TicketHub — Multi-Business Ticketing & Booking Marketplace

TicketHub is the submission-ready source project for **Task #06 – Mobile App Development Internship**. It is a general-purpose Flutter + Supabase marketplace for cinemas, theatres, concerts, sports, workshops, attractions, experiences and other ticketed services.

## Roles

- **Customer** — discovers businesses/listings, filters/searches, favorites, holds tickets/seats, checks out, receives digital QR tickets, manages bookings/payments/notifications and reviews eligible bookings.
- **Business Owner** — registers a business, waits for admin approval, manages listings/schedules/ticket types/inventory/seat maps/bookings/analytics/staff and scans tickets.
- **Platform Admin** — manages users, businesses, approval states, listings, tickets, bookings, payments, reviews, categories, reports, settings and audit visibility.

## Complete demo flow

`Business Registration -> Admin Approval -> Event/Service Creation -> Ticket Inventory -> Customer Discovery -> Ticket/Seat Selection -> Server Hold -> Checkout -> Simulated Payment -> Booking Confirmation -> Digital Ticket -> Atomic QR Validation`

## Technology stack

| Layer | Choice | Purpose |
|---|---|---|
| Mobile | Flutter + Dart, Material 3 | Android/iOS/web-capable UI |
| State/DI | Riverpod | Async state and repository injection |
| Navigation | go_router | Deep links and role-aware routes |
| Backend | Supabase | Auth, PostgreSQL, Storage, API, Cron |
| Security | PostgreSQL RLS + guarded RPCs | Server-authoritative authorization |
| QR | qr_flutter + mobile_scanner | Render and validate ticket QR codes |
| Analytics | fl_chart | Owner/admin visualizations |
| Images | image_picker + cached_network_image | Upload/cache business/event media |
| Tests | flutter_test + integration_test + SQL tests | Client and backend evidence |

Package versions are pinned in `pubspec.yaml` for reproducible dependency resolution.

## Repository layout

```text
lib/
  app/                  App shell
  core/                 Config, router, theme, formatters, shared widgets
  shared/               Models, providers, repositories, payment interface
  features/
    auth/ customer/ booking/ tickets/ reviews/ owner/ admin/
supabase/
  migrations/           Schema, RLS, RPCs, analytics/admin functions, cron
  seed.sql              Static categories/settings
  tests/                 RLS/concurrency/QR verification material
scripts/
  seed_demo.mjs         Creates demo Auth users + complete demo data
  bootstrap_platforms.py Generates Flutter runner boilerplate safely
  bootstrap.ps1/.sh     Convenience setup scripts
test/                    Unit/model tests
integration_test/        Connected app smoke test
docs/                    Architecture/features/test/submission documentation
```

## Prerequisites

- Flutter **3.47+ stable** with Dart satisfying `>=3.13.0 <4.0.0`
- A Supabase project
- Supabase CLI for migration workflow
- Node.js 22+ for the demo seeder
- Python 3 for the safe platform-runner bootstrap script

## 1. Generate Flutter platform runners

Generated Android/iOS/web runner boilerplate is intentionally reproducible instead of checked into this ZIP. From the project root:

### Windows PowerShell

```powershell
./scripts/bootstrap.ps1
```

### macOS/Linux

```bash
./scripts/bootstrap.sh
```

This creates `android/`, `ios/`, and `web/` in a temporary Flutter project, copies only those runner folders into TicketHub, and adds the required camera/photo permissions. It does not replace `lib/` or `pubspec.yaml`.

## 2. Create/link Supabase

Create a development Supabase project, then:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

If the Cron migration reports that `pg_cron` is disabled, enable the **Cron** database extension in Supabase and rerun `supabase db push`.

All public tables have RLS enabled. Critical `SECURITY DEFINER` functions explicitly revoke default PUBLIC execution and grant only the intended roles.

## 3. Seed demo accounts and data

The static `supabase/seed.sql` contains the data-driven categories/settings. The Auth-aware seeder creates demo identities through the Supabase Admin Auth API, then seeds businesses, 12 listings, schedules, ticket types, a cinema seat map, sample bookings across all required statuses, reviews, favorites and notifications.

Set **server-side** values only in the terminal running the seed script:

### PowerShell

```powershell
$env:SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
$env:SUPABASE_SECRET_KEY="sb_secret_REPLACE_ME"
node scripts/seed_demo.mjs
```

### macOS/Linux

```bash
SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co" \
SUPABASE_SECRET_KEY="sb_secret_REPLACE_ME" \
node scripts/seed_demo.mjs
```

**Never put the server secret in Flutter. Never commit it.**

Demo credentials created by the seed script:

| Role | Email | Password |
|---|---|---|
| Admin | `admin@tickethub.demo` | `TicketHub#Admin2026` |
| Owner | `owner1@tickethub.demo` | `TicketHub#Owner2026` |
| Owner | `owner2@tickethub.demo` | `TicketHub#Owner2026` |
| Customer | `customer1@tickethub.demo` | `TicketHub#Customer2026` |
| Customer 2–4 | `customer2..4@tickethub.demo` | `TicketHub#Customer2026` |

These are demo-only credentials. Change/remove them for any real deployment.

## 4. Configure the Flutter client

Copy `.env.example.json` to `.env.json` and set only public client values:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_REPLACE_ME"
}
```

Run:

```bash
flutter pub get
flutter run
```

The publishable key is expected to be present in a client app; authorization is enforced by RLS/RPC checks. A service/secret key must never be passed with `--dart-define`.

## 5. Run quality checks

```bash
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Connected integration smoke test:

```bash
flutter test integration_test/app_smoke_test.dart \
  --dart-define-from-file=.env.json
```

RLS tests require the demo seed and a privileged SQL connection:

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_tests.sql
```

Follow `supabase/tests/concurrency_test.md` to demonstrate two-customer seat/inventory racing and two-scanner QR replay protection.

## 6. Build submission artifacts

Android APK:

```bash
flutter build apk --release --dart-define-from-file=.env.json
```

Android App Bundle:

```bash
flutter build appbundle --release --dart-define-from-file=.env.json
```

iOS (macOS/Xcode signing required):

```bash
flutter build ios --release --dart-define-from-file=.env.json
```

## Security model

- Customer/owner registration sanitizes the requested role; no public registration path can request `admin`.
- RLS is enabled for all exposed app tables.
- Customers can read/write only their own private booking/ticket/payment/favorite/notification data.
- Owners can manage only their own business resources; authorized staff can scan only their assigned business tickets.
- Pending/rejected/suspended businesses are excluded from public discovery.
- Business approval state is protected from owner-side modification.
- Ticket holds, booking confirmation, cancellation/refund and QR consumption are server transactions.
- `ticket_types` enforces `sold_qty + held_qty <= total_qty`.
- `validate_ticket` locks the ticket row before marking it Used, preventing double-success scanning.
- Secrets are excluded by `.gitignore`.

## Simulated payments

The internship requires a payment-method step but not live money movement. TicketHub therefore exposes Cash, Card, JazzCash, Easypaisa and Wallet through `PaymentProvider`; the included `SimulatedPaymentProvider` returns demo provider references. Swap that implementation for a certified gateway without rewriting booking domain logic.

## Submission documents

- `docs/ARCHITECTURE.md`
- `docs/FEATURES.md`
- `docs/REQUIREMENTS_TRACEABILITY.md`
- `docs/TEST_REPORT.md`
- `docs/KNOWN_LIMITATIONS.md`
- `docs/SCREENSHOT_CHECKLIST.md`
- `docs/DEMO_SCRIPT.md`
- `docs/PRESENTATION_OUTLINE.md`
- `docs/LINKEDIN_POSTS.md`
- `docs/VALIDATION_REPORT.md`

## Verification note

Source and database logic can be statically inspected in this package. A final internship submission should additionally attach screenshots from a real Android/iOS run, a Supabase-backed end-to-end test run, and the QR double-scan demonstration described in the supplied checklist/report.
