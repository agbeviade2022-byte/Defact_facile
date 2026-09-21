/// Build-time configuration injected with `--dart-define-from-file`
/// (see mobile/flutter_app/env/*.json). Only public values live here:
/// the Supabase anon key is a public key by design, every privileged secret
/// stays on the backend.
enum AppEnvironment { development, staging, production }

abstract final class AppConfig {
  static const String _env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String appName = 'DEFACT FACILE';
  static const String tagline = 'Devis. Factures. Gestion. Facile.';
  static const String defaultCurrency = 'XOF';
  static const String defaultLocale = 'fr';

  static bool get hasSupabaseConfig =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  static AppEnvironment get environment => switch (_env) {
    'production' => AppEnvironment.production,
    'staging' => AppEnvironment.staging,
    _ => AppEnvironment.development,
  };

  static bool get isProduction => environment == AppEnvironment.production;
}
