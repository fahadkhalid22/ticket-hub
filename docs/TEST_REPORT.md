# Test Report

`Static` means verified by source inspection in the packaging environment. `Runtime required` means execute against a real Flutter SDK/Supabase project before final submission.

| ID | Scenario | Expected | Packaged status |
|---|---|---|---|
| T01 | Pricing utility | Correct unit × quantity + fee | Unit test included |
| T02 | Email/password validation | Invalid values rejected | Unit test included |
| T03 | Customer reads another booking | 0 unauthorized rows | SQL RLS script included |
| T04 | Owner edits another owner's listing | Update blocked | SQL RLS script included |
| T05 | Two users hold final inventory | Exactly one succeeds | Concurrency procedure included; runtime required |
| T06 | Hold expires | Pending -> Cancelled, inventory restored | RPC + cron implemented; runtime required |
| T07 | Confirm booking | Held -> sold; tickets/payment/notifications created atomically | RPC implemented; runtime required |
| T08 | Cancel paid booking | Inventory released; payment/ticket/booking refund states | RPC implemented; runtime required |
| T09 | First QR scan | Valid + ticket becomes Used | RPC implemented; runtime required |
| T10 | Second simultaneous QR scan | Already Used | Row-lock logic + procedure included; runtime required |
| T11 | Scanner from wrong business | Authorization error | RPC implemented; runtime required |
| T12 | Pending business discovery | Not publicly readable | RLS policy implemented; runtime required |
| T13 | Owner self-approval attempt | Protected-field trigger blocks it | Trigger implemented; runtime required |
| T14 | Review before completed/used booking | Insert rejected | RLS policy implemented; runtime required |
| T15 | App connected smoke | App reaches auth/onboarding UI | Integration test included; runtime required |

## Required execution before submission

```bash
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart --dart-define-from-file=.env.json
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_tests.sql
```

Then execute `supabase/tests/concurrency_test.md` with two customer sessions and two authorized scanner sessions.
