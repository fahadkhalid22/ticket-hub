#!/usr/bin/env bash
set -euo pipefail
command -v flutter >/dev/null || { echo 'Flutter is required.'; exit 1; }
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
flutter create "$TMP_DIR/tickethub_runner" --project-name tickethub --platforms=android,ios,web --org com.tickethub
rm -rf android ios web
cp -R "$TMP_DIR/tickethub_runner/android" ./android
cp -R "$TMP_DIR/tickethub_runner/ios" ./ios
cp -R "$TMP_DIR/tickethub_runner/web" ./web
python3 scripts/bootstrap_platforms.py
flutter pub get
printf '\nPlatform runners generated without replacing lib/ or pubspec.yaml. Configure .env.json, then run: flutter run --dart-define-from-file=.env.json\n'
