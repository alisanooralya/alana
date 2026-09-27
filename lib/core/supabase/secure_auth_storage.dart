import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../diagnostics/error_log.dart';

/// Kunci tempat supabase_flutter 2.17.2 menyimpan sesi.
///
/// Rumus ini disalin persis dari `Supabase.initialize`, yang menghitungnya
/// inline: `sb-<project-ref>-auth-token`. Versi ini tidak mengekspor fungsi
/// pembantu seperti `defaultPersistSessionKey`, jadi perhitungannya diulang
/// di sini.
///
/// Kalau rumus di SDK berubah, migrasi tidak lagi menemukan sesi lama —
/// gejalanya user keluar akun sekali setelah pembaruan, bukan data rusak.
String kunciSesiSupabase(String url) =>
    'sb-${Uri.parse(url).host.split('.').first}-auth-token';

/// Kunci code verifier PKCE di gotrue 2.27.2.
///
/// Berbeda dengan kunci sesi, ini konstanta tetap yang tidak ikut URL:
/// `Constants.defaultStorageKey` digabung dengan `-code-verifier`.
const kunciVerifierPkce = 'supabase.auth.token-code-verifier';

/// Kunci sesi versi lama (supabase_flutter v2).
const kunciSesiLama = 'supabase.auth.token';

/// Penyimpanan kunci-nilai, dipakai untuk memindahkan nilai lama.
///
/// Dipisah dari plugin supaya logika migrasi bisa diuji tanpa platform
/// channel. Sengaja dibuat sempit: hanya operasi yang benar-benar dipakai.
abstract class TokoKunciNilai {
  const TokoKunciNilai();

  Future<String?> baca(String kunci);

  Future<void> tulis(String kunci, String nilai);

  Future<void> hapus(String kunci);

  Future<Set<String>> semuaKunci();
}

/// Pembungkus [FlutterSecureStorage] sebagai [TokoKunciNilai].
class TokoAman implements TokoKunciNilai {
  TokoAman([FlutterSecureStorage? store]) : _store = store ?? _bawaan();

  final FlutterSecureStorage _store;

  /// `resetOnError` membuat plugin menghapus entri yang gagal dibaca lalu
  /// mengembalikan `null`, alih-alih melempar.
  ///
  /// Kasus yang dicakup: kunci AES-nya tinggal di Android Keystore dan tidak
  /// ikut ter-backup ke Google Drive, jadi setelah restore ke perangkat lain
  /// setiap pembacaan gagal dengan `InvalidKeyException: Failed to unwrap
  /// key`. Dengan reset, kondisi itu diperlakukan sebagai "tidak ada sesi"
  /// sehingga aplikasi meminta login ulang, bukan terjebak mengulang error
  /// yang sama setiap kali start.
  static FlutterSecureStorage _bawaan() =>
      const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true));

  @override
  Future<String?> baca(String kunci) => _store.read(key: kunci);

  @override
  Future<void> tulis(String kunci, String nilai) =>
      _store.write(key: kunci, value: nilai);

  @override
  Future<void> hapus(String kunci) => _store.delete(key: kunci);

  @override
  Future<Set<String>> semuaKunci() async =>
      (await _store.readAll()).keys.toSet();
}

/// Pembungkus [SharedPreferences] API lama sebagai [TokoKunciNilai].
///
/// Inilah tempat supabase_flutter 2.17.2 menaruh sesi dan code verifier
/// PKCE, jadi ini sumber utama migrasi.
class TokoPrefsLama implements TokoKunciNilai {
  TokoPrefsLama([SharedPreferences? prefs]) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<SharedPreferences?> _siap() async {
    if (_prefs != null) return _prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
      return null;
    }
  }

  @override
  Future<String?> baca(String kunci) async => (await _siap())?.getString(kunci);

  @override
  Future<void> tulis(String kunci, String nilai) async =>
      (await _siap())?.setString(kunci, nilai);

  @override
  Future<void> hapus(String kunci) async => (await _siap())?.remove(kunci);

  @override
  Future<Set<String>> semuaKunci() async =>
      (await _siap())?.getKeys() ?? const {};
}

/// Pembungkus [SharedPreferencesAsync] sebagai [TokoKunciNilai].
///
/// Bukan tempat token pada 2.17.2, tapi ikut disapu supaya migrasi tetap
/// benar bila supabase_flutter nanti naik ke versi yang memakai API async,
/// dan tidak menyakitkan kalau ternyata kosong.
class TokoPrefsAsync implements TokoKunciNilai {
  TokoPrefsAsync([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> baca(String kunci) => _prefs.getString(kunci);

  @override
  Future<void> tulis(String kunci, String nilai) =>
      _prefs.setString(kunci, nilai);

  @override
  Future<void> hapus(String kunci) => _prefs.remove(kunci);

  @override
  Future<Set<String>> semuaKunci() => _prefs.getKeys();
}

/// Laporan hasil pemindahan token dari SharedPreferences ke penyimpanan aman.
class HasilMigrasiToken {
  const HasilMigrasiToken({
    required this.dipindahkan,
    required this.dihapus,
    required this.gagal,
  });

  /// Kunci yang berhasil disalin ke penyimpanan aman.
  final int dipindahkan;

  /// Kunci yang berhasil dihapus dari SharedPreferences.
  final int dihapus;

  /// Kunci yang tidak bisa dipindahkan. Nilai lamanya masih utuh di sana.
  final int gagal;
}

/// Memindahkan sesi dan code verifier PKCE dari SharedPreferences ke
/// [flutter_secure_storage].
///
/// Dipanggil sekali sebelum `Supabase.initialize`, bukan di dalam
/// `accessToken`. `Supabase.initialize` memulihkan sesi saat dipanggil, jadi
/// migrasi yang menyala saat itu bisa menulis nilai yang baru saja dibaca.
///
/// Nilai ditulis ke penyimpanan aman **sebelum** dihapus dari
/// SharedPreferences. Kalau aplikasi mati di tengah jalan, nilai masih ada
/// di salah satu tempat, tidak pernah hilang di keduanya.
///
/// Code verifier ikut dipindah karena alur lupa password bergantung
/// padanya. Kalau hanya sesi yang dipindah, permintaan reset yang sedang
/// berjalan tepat saat aplikasi diperbarui akan gagal menukar kode recovery
/// karena verifier-nya sudah hilang.
Future<HasilMigrasiToken> migrasiTokenKeAman({
  required TokoKunciNilai prefsLama,
  required TokoKunciNilai aman,
  required String urlSupabase,
  TokoKunciNilai? prefsAsync,
}) async {
  var dipindahkan = 0;
  var dihapus = 0;
  var gagal = 0;

  final sesi = kunciSesiSupabase(urlSupabase);

  bool milikAuth(String kunci) =>
      kunci == sesi ||
      kunci == kunciSesiLama ||
      kunci.startsWith(kunciVerifierPkce);

  for (final tokoLama in <TokoKunciNilai>[prefsLama, ?prefsAsync]) {
    Set<String> semua;
    try {
      semua = await tokoLama.semuaKunci();
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
      continue;
    }

    for (final kunci in semua) {
      if (!milikAuth(kunci)) continue;

      try {
        final nilai = await tokoLama.baca(kunci);
        // Null berarti sudah dikosongkan, misalnya oleh logout di sesi lalu.
        if (nilai == null) continue;

        // Penyimpanan aman menang kalau isinya sudah ada: itu migrasi yang
        // sempat terhenti setelah menulis tapi sebelum menghapus, jadi
        // nilainya lebih baru.
        if (await aman.baca(kunci) == null) {
          await aman.tulis(kunci, nilai);
        }

        await tokoLama.hapus(kunci);
        dipindahkan += 1;
        dihapus += 1;
      } catch (error, stack) {
        // Satu kunci gagal tidak menghentikan yang lain, dan nilai lamanya
        // masih ada di SharedPreferences sehingga tidak ada yang hilang.
        gagal += 1;
        ErrorLog.catat(error, stack);
      }
    }
  }

  return HasilMigrasiToken(
    dipindahkan: dipindahkan,
    dihapus: dihapus,
    gagal: gagal,
  );
}

/// [LocalStorage] Supabase yang menyimpan sesi lewat [flutter_secure_storage]
/// (Android Keystore) sebagai ganti SharedPreferences.
///
/// Dipasang lewat `FlutterAuthClientOptions.localStorage`. Sesi disimpan
/// sebagai satu string JSON di bawah [persistSessionKey], persis seperti
/// [SharedPreferencesLocalStorage] supaya formatnya di sisi SDK tidak
/// berubah.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey, TokoKunciNilai? store})
    : _toko = store ?? TokoAman();

  /// Kunci yang sama dengan yang dipakai SDK, sehingga pergantian storage
  /// dimulai dari titik yang sama.
  final String persistSessionKey;

  final TokoKunciNilai _toko;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() => _toko.baca(persistSessionKey);

  @override
  Future<void> removePersistedSession() => _toko.hapus(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _toko.tulis(persistSessionKey, persistSessionString);
}

/// [GotrueAsyncStorage] Supabase yang menyimpan code verifier PKCE lewat
/// [flutter_secure_storage] sebagai ganti SharedPreferences.
///
/// Dipasang lewat `FlutterAuthClientOptions.pkceAsyncStorage`. Dibiarkan
/// memakai penyimpanan aman yang sama dengan sesi karena keduanya adalah
/// rahasia yang tidak boleh tersimpan terbuka; memisahkannya hanya menambah
/// tempat yang harus ditutup saat logout.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  SecureGotrueAsyncStorage({TokoKunciNilai? store})
    : _toko = store ?? TokoAman();

  final TokoKunciNilai _toko;

  @override
  Future<String?> getItem({required String key}) => _toko.baca(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _toko.tulis(key, value);

  @override
  Future<void> removeItem({required String key}) => _toko.hapus(key);
}
