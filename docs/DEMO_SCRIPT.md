# 3–5 Minute Demo Script

**0:00–0:30 — Product:** Explain TicketHub as a general-purpose marketplace, not a cinema-only app. Show the customer Home and categories.

**0:30–1:10 — Owner:** Sign in as owner, show an existing business/dashboard, create or edit an event/service, add a schedule and ticket types. Mention that a newly registered business remains Pending until admin review.

**1:10–1:35 — Admin approval:** Sign in as admin, open Business Approvals, approve the pending business, and show the admin KPI dashboard.

**1:35–2:40 — Customer booking:** Sign in as customer. Discover a listing, select a schedule, choose tickets or seats, show the 10-minute hold timer, choose a clearly labeled simulated payment method and confirm. Open Booking Confirmation and My Tickets.

**2:40–3:20 — QR:** Open the digital ticket and QR. Sign in as owner/staff, scan it. Show Valid. Scan again and show Already Used. Explain that the second scan is stopped atomically in PostgreSQL.

**3:20–4:00 — Integrity/analytics:** Show ticket inventory, owner analytics and admin management. Briefly explain RLS, separate held/sold inventory, cancellation/refund release and audit logging.

**4:00–4:30 — Generality:** Point out that cinema seats, concert general admission, sports, workshops and attractions all use the same listing/schedule/ticket engine.
