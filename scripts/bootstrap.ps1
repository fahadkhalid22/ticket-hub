$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter is required.' }
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tickethub_" + [Guid]::NewGuid().ToString('N'))
try {
  flutter create (Join-Path $tmp 'tickethub_runner') --project-name tickethub --platforms=android,ios,web --org com.tickethub
  Remove-Item android,ios,web -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item (Join-Path $tmp 'tickethub_runner/android') ./android -Recurse
  Copy-Item (Join-Path $tmp 'tickethub_runner/ios') ./ios -Recurse
  Copy-Item (Join-Path $tmp 'tickethub_runner/web') ./web -Recurse
  python scripts/bootstrap_platforms.py
  flutter pub get
  Write-Host "Platform runners generated without replacing lib/ or pubspec.yaml. Configure .env.json, then run: flutter run --dart-define-from-file=.env.json"
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
