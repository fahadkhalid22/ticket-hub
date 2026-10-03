# Validation Report

## Checks performed in the packaging environment

- Repository/file inventory checked and a package manifest generated.
- Dependency compatibility update: `google_fonts` is pinned to `8.2.1` so the project keeps Flutter Material `TextTheme` compatibility; run `flutter pub get` to regenerate `pubspec.lock` before analysis.
- `pubspec.yaml` parsed as YAML.
- JSON configuration files parsed successfully.
- All relative Dart imports checked for an existing target file.
- Route target widgets checked against declared classes.
- Node demo seeder passed `node --check`.
- Python platform bootstrap script passed `py_compile`.
- Bash bootstrap script passed `bash -n`.
- 22 Dart files passed a delimiter/string/comment structural scan; 9 SQL files passed quote/dollar-quote/comment/parenthesis structural scanning.
- External Dart package imports were checked against `pubspec.yaml`; all are declared.
- Source scanned for TODO/FIXME/placeholder/Unimplemented markers: none found.
- `supabase/tests/qr_validation_tests.sql` was added to verify first-use/replay QR semantics inside a rollback transaction.
- Security review tightened profile role protection, business-registration role checks, storage update ownership, and direct seat-state/inventory mutation boundaries.

## Environment limitation

Flutter/Dart, Supabase CLI, and PostgreSQL client binaries are not installed in the packaging environment. Therefore the following must be run on a development machine before final submission:

```bash
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
supabase db push
```

Then perform the connected flow and SQL security/concurrency tests described in `README.md`, `docs/TEST_REPORT.md`, and `supabase/tests/concurrency_test.md`.

This package does **not** claim that an APK was built or that migrations were executed against a live Supabase project in the packaging environment.
