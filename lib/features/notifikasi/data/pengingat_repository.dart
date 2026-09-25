import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';

/// Pengingat baca lokal: menjadwalkan notifikasi untuk bacaan yang
/// sudah 2+ hari tidak dilanjutkan. Dijadwalkan ulang tiap aplikasi
/// dibuka (tanpa background service).
class PengingatRepository {
  const PengingatRepository();

  static const kunciAktif = 'pengingat_baca';

  /// Jadwalkan ulang untuk [uid]. Batalkan dulu semua milik kita.
  /// [maksimal]: batasi jumlah notifikasi (terlama dulu).
  Future<void> jadwalkanUlang(String? uid, {int maksimal = 3}) async {
    await LayananNotifikasi.batalkanSemua();
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
    basi.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final kapan = _berikutnyaJam9();
    var i = 0;
    for (final p in basi) {
      if (i >= maksimal) break;
      final judul = p.mangaTitle.isEmpty ? p.mangaId : p.mangaTitle;
      await LayananNotifikasi.jadwalkan(
        id: p.mangaId.hashCode & 0x7fffffff,
        judul: 'Lanjutkan membaca $judul',
        isi: p.lastChapterName.isEmpty
            ? 'Bacaanmu menunggumu.'
            : 'Terakhir: ${p.lastChapterName}.',
        kapan: kapan,
        payload: '${p.mangaId}|${p.lastChapterId}',
      );
      i++;
    }
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

  /// Kirim satu notifikasi uji langsung (untuk mengetes alur ketuk).
  Future<void> kirimUji() async {
    await LayananNotifikasi.tampilkanSekarang(
      id: 999001,
      judul: 'Uji pengingat baca',
      isi: 'Ketuk untuk memastikan navigasi berjalan.',
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
      await LayananNotifikasi.batalkanSemua();
    }
  }
}

final pengingatRepositoryProvider = Provider<PengingatRepository>((ref) {
  return const PengingatRepository();
});

final pengingatAktifProvider = NotifierProvider<PengingatStatus, bool>(
  () => PengingatStatus(),
);
