# Supabase connection

TicketHub is connected to the Supabase project `TicketHub`.

The Flutter app contains the project URL and **publishable** key as client-side fallback values in `lib/core/config/env.dart`. This is safe for a Supabase client application because the publishable key is not a server secret; database authorization is enforced by Row Level Security (RLS).

You can therefore run the app directly:

```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

Optional environment override:

```powershell
flutter run -d chrome --dart-define-from-file=.env.json
```

Never place a Supabase `sb_secret_...` key or legacy `service_role` key in Flutter source code or `.env.json` used by the client.
