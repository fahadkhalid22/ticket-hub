class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final String supabaseUrl;
  final String supabasePublishableKey;

  // Supabase publishable credentials are designed for client applications.
  // Authorization and data protection remain enforced by Row Level Security.
  static const String _defaultSupabaseUrl =
      'https://geeeryyrfhsznmjwkknk.supabase.co';
  static const String _defaultSupabasePublishableKey =
      'sb_publishable_fDkjw8gdo3P_ALPsXziSEg_UONLOsKn';

  factory AppEnv.fromDefines() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _defaultSupabaseUrl,
    );
    const key = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: _defaultSupabasePublishableKey,
    );

    return const AppEnv(
      supabaseUrl: url,
      supabasePublishableKey: key,
    );
  }
}
