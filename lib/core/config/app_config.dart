/// Konfigurasi aplikasi dari `--dart-define`.
///
/// Tidak ada kredensial yang di-hardcode atau di-commit.
/// Lihat README untuk cara menjalankan dan Secrets yang dibutuhkan CI.
class AppConfig {
  const AppConfig._();

  /// URL project Supabase.
  /// `--dart-define=SUPABASE_URL=https://xyz.supabase.co`
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Anon/publishable key Supabase.
  /// `--dart-define=SUPABASE_ANON_KEY=...`
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Web Client ID Google (untuk Google Sign-In native).
  /// `--dart-define=GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com`
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// `true` bila kredensial Supabase terisi.
  static bool get supabaseTerkonfigurasi =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
