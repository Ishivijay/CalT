/// Optional build configuration. Keeping these as Dart defines means a fresh
/// checkout can run offline without a generated, secret-bearing source file.
/// Pass real values only for features that need them, e.g.
/// `--dart-define=SUPABASE_PROJECT_URL=https://...`.
abstract final class Env {
  static const String fdcApiKey = String.fromEnvironment('FDC_API_KEY');
  static const String sentryDns = String.fromEnvironment('SENTRY_DNS');
  static const String supabaseProjectUrl =
      String.fromEnvironment('SUPABASE_PROJECT_URL');
  static const String supabaseProjectAnonKey =
      String.fromEnvironment('SUPABASE_PROJECT_ANON_KEY');

  static bool get hasSupabaseConfig =>
      supabaseProjectUrl.isNotEmpty && supabaseProjectAnonKey.isNotEmpty;
}
