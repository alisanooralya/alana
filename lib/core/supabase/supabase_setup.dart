import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/config/app_config.dart';
import 'package:alana/core/diagnostics/error_log.dart';

import 'secure_auth_storage.dart';

class SupabaseSetup {
  const SupabaseSetup._();

  static bool _siap = false;

  static String? lastError;

  static bool get siap => _siap;

  static Future<void> init() async {
    if (_siap) return;
    if (!AppConfig.supabaseTerkonfigurasi) {
      lastError =
          'SUPABASE_URL / SUPABASE_ANON_KEY belum diisi (lihat README).';
      return;
    }
    try {
      final kunciSesi = kunciSesiSupabase(AppConfig.supabaseUrl);
      await _pindahkanSesiLama();
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(persistSessionKey: kunciSesi),
          pkceAsyncStorage: SecureGotrueAsyncStorage(),
        ),
      );
      _siap = true;
    } catch (error) {
      lastError = error.toString();
    }
  }

  static Future<void> _pindahkanSesiLama() async {
    try {
      final hasil = await migrasiTokenKeAman(
        prefsLama: TokoPrefsLama(),
        prefsAsync: TokoPrefsAsync(),
        aman: TokoAman(),
        urlSupabase: AppConfig.supabaseUrl,
      );
      if (hasil.gagal > 0) {
        ErrorLog.catat(
          StateError('${hasil.gagal} kunci auth gagal dipindahkan ke keystore'),
          StackTrace.current,
        );
      }
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
    }
  }

  static SupabaseClient get instance => Supabase.instance.client;
}
