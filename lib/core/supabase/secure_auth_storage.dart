import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../diagnostics/error_log.dart';

String kunciSesiSupabase(String url) =>
    'sb-${Uri.parse(url).host.split('.').first}-auth-token';

const kunciVerifierPkce = 'supabase.auth.token-code-verifier';
const kunciSesiLama = 'supabase.auth.token';

abstract class TokoKunciNilai {
  const TokoKunciNilai();

  Future<String?> baca(String kunci);

  Future<void> tulis(String kunci, String nilai);

  Future<void> hapus(String kunci);

  Future<Set<String>> semuaKunci();
}

class TokoAman implements TokoKunciNilai {
  TokoAman([FlutterSecureStorage? store]) : _store = store ?? _bawaan();

  final FlutterSecureStorage _store;

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

class HasilMigrasiToken {
  const HasilMigrasiToken({
    required this.dipindahkan,
    required this.dihapus,
    required this.gagal,
  });

  final int dipindahkan;
  final int dihapus;
  final int gagal;
}

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
        if (nilai == null) continue;

        if (await aman.baca(kunci) == null) {
          await aman.tulis(kunci, nilai);
        }

        await tokoLama.hapus(kunci);
        dipindahkan += 1;
        dihapus += 1;
      } catch (error, stack) {
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

class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey, TokoKunciNilai? store})
    : _toko = store ?? TokoAman();

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
