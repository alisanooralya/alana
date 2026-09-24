import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/config/app_config.dart';

/// Inisialisasi dan akses klien Supabase.
///
/// Dipanggil sekali dari [Bootstrap] sebelum router dipakai.
/// Sesi tersimpan otomatis oleh supabase_flutter sehingga
/// user tetap login setelah aplikasi ditutup.
class SupabaseSetup {
  const SupabaseSetup._();

  static bool _siap = false;

  /// Penyebab kegagalan [init] terakhir, bila ada.
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
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      _siap = true;
    } catch (error) {
      lastError = error.toString();
    }
  }

  /// Klien aktif. Hanya dipakai setelah [siap] bernilai true.
  static SupabaseClient get instance => Supabase.instance.client;
}
