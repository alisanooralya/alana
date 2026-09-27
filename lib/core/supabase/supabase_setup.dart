import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/config/app_config.dart';
import 'package:alana/core/diagnostics/error_log.dart';

import 'secure_auth_storage.dart';

/// Inisialisasi dan akses klien Supabase.
///
/// Dipanggil sekali dari [Bootstrap] sebelum router dipakai.
/// Sesi dan code verifier PKCE disimpan di keystore perangkat lewat
/// [SecureLocalStorage] dan [SecureGotrueAsyncStorage] sehingga user tetap
/// login setelah aplikasi ditutup, dan refresh token tidak tersimpan terbuka
/// di SharedPreferences.
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

  /// Memindahkan sesi dari SharedPreferences ke keystore, sekali saja.
  ///
  /// Harus jalan sebelum [Supabase.initialize] supaya sesi dipulihkan dari
  /// tempat yang benar sejak awal, bukan ditulis ulang ke SharedPreferences
  /// dulu lalu dipindah.
  ///
  /// Kegagalan tidak menentukan hasil [init]. Kalau tidak bisa memindahkan,
  /// aplikasi tetap jalan: sesi lama masih utuh di SharedPreferences dan
  /// masih bisa dibaca, hanya belum terenkripsi.
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

  /// Klien aktif. Hanya dipakai setelah [siap] bernilai true.
  static SupabaseClient get instance => Supabase.instance.client;
}
