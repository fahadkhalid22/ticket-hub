# Final Source Audit

This audit describes what is present in the ZIP and what still requires a real Flutter/Supabase runtime.

## Traceability

All R-01 through R-33 are mapped in `docs/REQUIREMENTS_TRACEABILITY.md`. The main end-to-end implementation path is:

`owner registration -> admin approval -> listing/schedule/ticket inventory -> customer discovery -> hold_tickets -> checkout contact -> simulated payment -> confirm_booking -> digital ticket -> validate_ticket`.

## Security / integrity review

- RLS is enabled on all application tables in the exposed `public` schema.
- User-editable profile metadata is not trusted for authorization; persisted `profiles.role` is protected against self-escalation.
- Business approval and protected aggregate fields cannot be changed by a normal owner request.
- Ticket `sold_qty` / `held_qty` counters and schedule-seat booking state are server-maintained.
- Holds and confirmations lock schedule/inventory rows and enforce `sold_qty + held_qty <= total_qty`.
- QR validation locks the ticket row before the Used transition; replay returns `Already Used`.
- Public discovery RPCs expose only approved businesses and active/open listings.
- Client code receives only the Supabase publishable key; the demo seed server secret remains server-side.

## Static verification completed here

- 22 Dart files: delimiter/string/comment structural scan passed.
- 9 SQL files: quote/dollar-quote/comment/parenthesis structural scan passed.
- YAML/JSON parse checks passed.
- Every relative Dart import resolves to an existing file.
- Every external Dart package import is declared in `pubspec.yaml`.
- `scripts/seed_demo.mjs` passed `node --check`.
- `scripts/bootstrap_platforms.py` passed Python bytecode compilation.
- `scripts/bootstrap.sh` passed `bash -n`.
- Code scan found no TODO/FIXME/`UnimplementedError`/placeholder-code markers.
- No zero-byte source files were found.

## Runtime verification still required

The packaging environment does not contain Flutter/Dart, Supabase CLI, PostgreSQL client, Android SDK/emulator, or a user-owned Supabase project. Therefore it cannot honestly certify compilation, migrations, device permissions, or end-to-end network behavior.

Before submission run the commands in `README.md`, then execute:

1. `flutter analyze` and `flutter test`.
2. `supabase db push` against a disposable development project.
3. `node scripts/seed_demo.mjs` with a server secret in the shell only.
4. `supabase/tests/rls_tests.sql`.
5. `supabase/tests/qr_validation_tests.sql`.
6. The two-session race procedure in `supabase/tests/concurrency_test.md`.
7. The full manual demo flow in `docs/DEMO_SCRIPT.md` and capture the checklist in `docs/SCREENSHOT_CHECKLIST.md`.

## Source-readiness assessment

The source package covers the specified product, backend schema, guarded RPCs, all three role surfaces, tests, setup/build instructions, and submission documentation. Runtime-dependent evidence (compiled APK/AAB, live Supabase test output, screenshots, and demo recording) is intentionally not fabricated and must be generated in the target development environment.
