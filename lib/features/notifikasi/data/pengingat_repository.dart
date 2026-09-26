import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

/// Pengingat baca lokal: menjadwalkan notifikasi untuk bacaan yang
/// sudah 2+ hari tidak dilanjutkan. Dijadwalkan ulang tiap aplikasi
/// dibuka (tanpa background service).
class PengingatRepository {
  PengingatRepository(this.ref);

  final Ref ref;

  static const kunciAktif = 'pengingat_baca';

  /// Prefixes kunci penanda "sudah diberi tahu", satu per judul.
  static const _prefixDiberiTahukan = 'pengingat_diberitahu_';

  /// Jeda sebelum judul yang sama boleh diingatkan lagi.
  static const Duration jedaUlang = Duration(days: 7);

  /// Kapan judul ini terakhir diberi tahu, null bila belum pernah.
  DateTime? _terakhirDiberiTahukan(String mangaId) {
    final iso = ref
        .read(sharedPreferencesProvider)
        .getString('$_prefixDiberiTahukan$mangaId');
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> _tandaiDiberiTahukan(String mangaId) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString('$_prefixDiberiTahukan$mangaId', DateTime.now().toIso8601String());
  }

  /// Jadwalkan ulang untuk [uid]. Batalkan dulu semua milik kita.
  /// [maksimal]: batasi jumlah notifikasi.
  ///
  /// Sebelumnya Always memilih 3 judul terlama setiap kali aplikasi dibuka,
  /// tanpa mencatat bahwa pengingatnya sudah dikirim. Akibatnya user dengan
  /// 10 bacaan terlantar mendapat notifikasi yang sama untuk judul yang sama
  /// setiap pagi selamanya, sementara 7 judul yang lebih baru tidak pernah
  /// disinggung karena selalu kalah oleh 3 yang paling lama. Judul yang sudah
  /// diberi tahu dalam [jedaUlang] dilewati, sehingga giliran bergilir.
  Future<void> jadwalkanUlang(String? uid, {int maksimal = 3}) async {
    await LayananNotifikasi.batalkanPengingat(_idTerjadwal(ref));
    if (uid == null || uid.isEmpty) return;
    final box = await AppStorage.bukaBoxUser('rh', uid);
    if (box == null) return;

    final batas = DateTime.now().subtract(const Duration(days: 2));
    final basi = <MangaReadingProgress>[];
    for (final key in box.keys) {
      if (key == AppStorage.tombsKey) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final p = MangaReadingProgress.fromMap(Map<String, dynamic>.from(raw));
      if (p.mangaId.isEmpty) continue;
      if (p.updatedAt.isBefore(batas)) basi.add(p);
    }
    // Urut berdasarkan kapan terakhir diberi tahu, bukan kapan terakhir
    // dibaca. Urut berdasarkan usia bacaan selalu mengembalikan 3 judul yang
    // sama: begitu jedaUlang habis, 3 judul tertua langsung memenuhi syarat
    // lagi dan giliran tidak pernah sampai ke sisanya. Dengan urutan ini,
    // yang belum pernah diberi tahu didahulukan, lalu yang paling lama
    //_since_ diberi tahu - sehingga giliran benar-benar bergilir.
    basi.sort((a, b) {
      final ta = _terakhirDiberiTahukan(a.mangaId);
      final tb = _terakhirDiberiTahukan(b.mangaId);
      if (ta == null && tb == null) return a.updatedAt.compareTo(b.updatedAt);
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });
    final sekarang = DateTime.now();
    final terpilih = <MangaReadingProgress>[];
    for (final p in basi) {
      if (terpilih.length >= maksimal) break;
      final t = _terakhirDiberiTahukan(p.mangaId);
      if (t != null && sekarang.difference(t) < jedaUlang) continue;
      terpilih.add(p);
    }

    final kapan = _berikutnyaJam9();
    final idsTerjadwal = <int>[];
    var i = 0;
    for (final p in terpilih) {
      if (i >= maksimal) break;
      await _tandaiDiberiTahukan(p.mangaId);
      idsTerjadwal.add(p.mangaId.hashCode & 0x7fffffff);
      final judul = p.mangaTitle.isEmpty ? p.mangaId : p.mangaTitle;
      await LayananNotifikasi.jadwalkan(
        id: p.mangaId.hashCode & 0x7fffffff,
        judul: 'Lanjutkan membaca $judul',
        isi: p.lastChapterName.isEmpty
            ? 'Bacaanmu menunggumu.'
            : 'Terakhir: ${p.lastChapterName}.',
        kapan: kapan,
        payload: p.lastChapterId.isEmpty
            ? mangaDeepLink(p.mangaId)
            : chapterDeepLink(p.mangaId, p.lastChapterId),
      );
      i++;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_kunciIdTerjadwal, [
          for (final id in idsTerjadwal) '$id',
        ]);
  }

  /// Jam 9 pagi berikutnya (waktu lokal perangkat).
  tz.TZDateTime _berikutnyaJam9() {
    final kini = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, kini.year, kini.month, kini.day, 9);
    if (!target.isAfter(kini)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// Kunci daftar ID notifikasi yang sudah dijadwalkan.
  ///
  /// Pembatalan memakai daftar ini, bukan cancelAll(), supaya notifikasi lain
  /// - termasuk push chapter baru - tidak ikut terhapus.
  static const _kunciIdTerjadwal = 'pengingat_ids';

  static List<int> _idTerjadwal(Ref ref) {
    return ref
            .read(sharedPreferencesProvider)
            .getStringList(_kunciIdTerjadwal)
            ?.map((n) => int.tryParse(n))
            .whereType<int>()
            .toList() ??
        const [];
  }

  static List<int> idTerjadwal(WidgetRef ref) => _idTerjadwal(ref);

  /// Kirim satu notifikasi uji.
  ///
  /// Payload diambil dari riwayat baca supaya mengetuk notifikasi ini juga
  /// menguji alur navigasi. Sebelumnya tidak ada payload sama sekali, sehingga
  /// ketuk tidak melakukan apa-apa - padahal teksnya menjanjikan sebaliknya,
  /// dan tidak ada jalan lain menguji navigasi dari notifikasi.
  Future<void> kirimUji() async {
    final uid = ref.read(userIdProvider);
    var payload = '';
    var isi = 'Notifikasi pengingat akan muncul pukul 09:00.';
    if (uid != null && uid.isNotEmpty) {
      final box = await AppStorage.bukaBoxUser('rh', uid);
      for (final key in box?.keys ?? const <dynamic>[]) {
        if (key == AppStorage.tombsKey) continue;
        final raw = box?.get(key);
        if (raw is! Map) continue;
        final p = MangaReadingProgress.fromMap(Map<String, dynamic>.from(raw));
        if (p.mangaId.isEmpty) continue;
        payload = p.lastChapterId.isEmpty
            ? mangaDeepLink(p.mangaId)
            : chapterDeepLink(p.mangaId, p.lastChapterId);
        isi =
            'Ketuk untuk membuka ${p.lastChapterName.isEmpty ? 'chapter terakhir' : p.lastChapterName}.';
        break;
      }
    }
    await LayananNotifikasi.tampilkanSekarang(
      id: 999001,
      judul: 'Uji pengingat baca',
      isi: isi,
      payload: payload.isEmpty ? null : payload,
    );
  }
}

/// On/off pengingat (per-perangkat, SharedPreferences). Default: nyala.
class PengingatStatus extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(PengingatRepository.kunciAktif) ??
        true;
  }

  Future<void> atur(bool aktif) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PengingatRepository.kunciAktif, aktif);
    state = aktif;
    if (!aktif) {
      await LayananNotifikasi.batalkanPengingat(
        PengingatRepository.idTerjadwal(ref),
      );
    }
  }
}

final pengingatRepositoryProvider = Provider<PengingatRepository>((ref) {
  return PengingatRepository(ref);
});

final pengingatAktifProvider = NotifierProvider<PengingatStatus, bool>(
  () => PengingatStatus(),
);
