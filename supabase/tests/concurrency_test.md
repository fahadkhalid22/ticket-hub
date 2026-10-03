# Concurrency / QR Verification

Use two customer sessions against one schedule with only one remaining ticket (or one available seat).

1. Session A calls `hold_tickets` for the last ticket/seat.
2. At the same time Session B calls `hold_tickets` for the same inventory.
3. Expected: one transaction succeeds; the other raises an availability error. `sold_qty + held_qty` never exceeds `total_qty`.
4. Let a hold expire or call `release_expired_holds`; expected inventory returns to available and the pending booking becomes Cancelled.
5. Confirm one booking, copy its QR token, then have two authorized scanner sessions call `validate_ticket` concurrently.
6. Expected: exactly one result is `Valid` and commits `Used`; the other returns `Already Used` after the row lock is released.
7. Try the QR with staff assigned to a different business. Expected: authorization error.

Database evidence: `hold_tickets` locks ticket/seat rows using `FOR UPDATE`; `validate_ticket` locks the ticket row before status mutation.
