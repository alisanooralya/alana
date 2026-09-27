import 'package:flutter_test/flutter_test.dart';

import 'package:alana/core/supabase/secure_auth_storage.dart';

/// Toko in-memory yang bisa dibuat gagal per-kunci.
class TokoPalsu implements TokoKunciNilai {
  TokoPalsu([Map<String, String>? awal]) : isi = {...?awal}, gagalPada = {};

  final Map<String, String> isi;

  /// Kunci yang melempar saat dibaca, ditulis, atau dihapus.
  final Set<String> gagalPada;

  @override
  Future<String?> baca(String kunci) async {
    if (gagalPada.contains(kunci)) throw StateError('gagal baca $kunci');
    return isi[kunci];
  }

  @override
  Future<void> tulis(String kunci, String nilai) async {
    if (gagalPada.contains(kunci)) throw StateError('gagal tulis $kunci');
    isi[kunci] = nilai;
  }

  @override
  Future<void> hapus(String kunci) async {
    if (gagalPada.contains(kunci)) throw StateError('gagal hapus $kunci');
    isi.remove(kunci);
  }

  @override
  Future<Set<String>> semuaKunci() async => isi.keys.toSet();
}

const _url = 'https://abcdefghijklmno.supabase.co';
const _sesi = 'sb-abcdefghijklmno-auth-token';

Future<HasilMigrasiToken> _jalankan({
  TokoPalsu? prefsLama,
  TokoPalsu? prefsAsync,
  TokoPalsu? aman,
}) {
  return migrasiTokenKeAman(
    prefsLama: prefsLama ?? TokoPalsu(),
    prefsAsync: prefsAsync ?? TokoPalsu(),
    aman: aman ?? TokoPalsu(),
    urlSupabase: _url,
  );
}

void main() {
  test('kunci sesi mengikuti rumus yang dipakai SDK', () {
    expect(kunciSesiSupabase(_url), _sesi);
    expect(kunciSesiSupabase('https://zzz.supabase.co'), 'sb-zzz-auth-token');
  });

  group('pemindahan token ke penyimpanan aman', () {
    test('sesi pindah dan salinan lamanya dihapus', () async {
      final lama = TokoPalsu({_sesi: '{"access_token":"a"}'});
      final aman = TokoPalsu();

      final hasil = await _jalankan(prefsLama: lama, aman: aman);

      expect(hasil.dipindahkan, 1);
      expect(hasil.dihapus, 1);
      expect(hasil.gagal, 0);
      expect(aman.isi[_sesi], '{"access_token":"a"}');
      // Token lama tidak boleh tertinggal di SharedPreferences.
      expect(lama.isi.containsKey(_sesi), isFalse);
    });

    test('code verifier PKCE ikut pindah', () async {
      // Dipakai alur lupa password: verifier harus bertahan lintas restart.
      final lama = TokoPalsu({
        _sesi: 'sesi',
        kunciVerifierPkce: 'verifier/passwordRecovery',
      });
      final aman = TokoPalsu();

      final hasil = await _jalankan(prefsLama: lama, aman: aman);

      expect(hasil.dipindahkan, 2);
      expect(aman.isi[kunciVerifierPkce], 'verifier/passwordRecovery');
      expect(lama.isi, isEmpty);
    });

    test('kunci sesi versi lama ikut pindah', () async {
      final lama = TokoPalsu({kunciSesiLama: 'lama'});
      final aman = TokoPalsu();

      final hasil = await _jalankan(prefsLama: lama, aman: aman);

      expect(hasil.dipindahkan, 1);
      expect(aman.isi[kunciSesiLama], 'lama');
    });

    test('kunci lain di SharedPreferences tidak disentuh', () async {
      // Onboarding, setelan, dan pengingat berbagi prefs yang sama.
      final lama = TokoPalsu({
        _sesi: 'sesi',
        'flutter.onboarding_done': 'true',
        'flutter.pengingat_aktif': '1',
      });
      final aman = TokoPalsu();

      await _jalankan(prefsLama: lama, aman: aman);

      expect(aman.isi.keys, {_sesi});
      expect(lama.isi['flutter.onboarding_done'], 'true');
      expect(lama.isi['flutter.pengingat_aktif'], '1');
    });

    test('aman diulang dan idempoten', () async {
      final lama = TokoPalsu({_sesi: 'sesi'});
      final aman = TokoPalsu();

      await _jalankan(prefsLama: lama, aman: aman);
      final kedua = await _jalankan(prefsLama: lama, aman: aman);

      expect(kedua.dipindahkan, 0);
      expect(kedua.dihapus, 0);
      expect(aman.isi, {_sesi: 'sesi'});
    });

    test('kunci yang gagal pindah tidak hilang dari lokasi lama', () async {
      // Kehilangan token berarti seluruh pengguna keluar akun.
      final lama = TokoPalsu({_sesi: 'sesi'});
      final aman = TokoPalsu()..gagalPada.add(_sesi);

      final hasil = await _jalankan(prefsLama: lama, aman: aman);

      expect(hasil.gagal, 1);
      expect(hasil.dipindahkan, 0);
      expect(aman.isi, isEmpty);
      expect(lama.isi[_sesi], 'sesi');
    });

    test('nilai yang sudah ada di keystore tidak ditimpa', () async {
      // Migrasi yang sempat terhenti setelah menulis tapi sebelum menghapus.
      final lama = TokoPalsu({_sesi: 'lama'});
      final aman = TokoPalsu({_sesi: 'baru'});

      final hasil = await _jalankan(prefsLama: lama, aman: aman);

      expect(aman.isi[_sesi], 'baru');
      expect(lama.isi.containsKey(_sesi), isFalse);
      expect(hasil.dihapus, 1);
    });

    test('sumber yang gagal tidak menghentikan sumber lain', () async {
      final prefsAsync = TokoPalsu({_sesi: 'dari-async'});
      final lama = TokoPalsu({kunciSesiLama: 'dari-lama'})
        ..gagalPada.add(kunciSesiLama);
      final aman = TokoPalsu();

      final hasil = await _jalankan(
        prefsLama: lama,
        prefsAsync: prefsAsync,
        aman: aman,
      );

      expect(hasil.dipindahkan, 1);
      expect(hasil.gagal, 1);
      expect(aman.isi[_sesi], 'dari-async');
    });

    test('prefsLama tanpa prefsAsync tetap jalan', () async {
      final lama = TokoPalsu({_sesi: 'sesi'});
      final aman = TokoPalsu();

      final hasil = await migrasiTokenKeAman(
        prefsLama: lama,
        aman: aman,
        urlSupabase: _url,
      );

      expect(hasil.dipindahkan, 1);
    });
  });

  group('SecureLocalStorage', () {
    test('menyimpan, membaca, dan menghapus sesi di keystore', () async {
      final storage = SecureLocalStorage(
        persistSessionKey: _sesi,
        store: TokoPalsu(),
      );
      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession('json-sesi');
      expect(await storage.accessToken(), 'json-sesi');
      expect(await storage.hasAccessToken(), isTrue);

      await storage.removePersistedSession();
      expect(await storage.accessToken(), isNull);
    });
  });

  group('SecureGotrueAsyncStorage', () {
    test('menyimpan dan membaca code verifier', () async {
      final storage = SecureGotrueAsyncStorage(store: TokoPalsu());

      await storage.setItem(key: kunciVerifierPkce, value: 'verifier');
      expect(await storage.getItem(key: kunciVerifierPkce), 'verifier');

      await storage.removeItem(key: kunciVerifierPkce);
      expect(await storage.getItem(key: kunciVerifierPkce), isNull);
    });
  });
}
