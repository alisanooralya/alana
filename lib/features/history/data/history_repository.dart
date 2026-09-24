import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reading_history.dart';

/// Repository riwayat baca, reaktif.
///
/// Fase 3: in-memory. Dipakai halaman detail untuk tombol
/// "Lanjut Baca" dan tanda chapter sudah dibaca.
/// Fase 5: persistensi lokal tanpa mengubah API publik ini.
class HistoryRepository extends Notifier<Map<String, MangaReadingProgress>> {
  @override
  Map<String, MangaReadingProgress> build() => const {};

  MangaReadingProgress? progressUntuk(String mangaId) => state[mangaId];

  Set<String> idDibacaUntuk(String mangaId) {
    return state[mangaId]?.readChapterIds ?? const {};
  }

  bool sudahDibaca(String mangaId, String chapterId) {
    return state[mangaId]?.readChapterIds.contains(chapterId) ?? false;
  }

  /// Mencatat chapter sebagai sudah dibaca sekaligus
  /// menjadikannya posisi terakhir.
  void tandaiDibaca({
    required String mangaId,
    required String chapterId,
    required String chapterName,
  }) {
    final lama = state[mangaId];
    final dibaca = {...?lama?.readChapterIds, chapterId};
    final baru = (lama ?? MangaReadingProgress(mangaId: mangaId)).copyWith(
      lastChapterId: chapterId,
      lastChapterName: chapterName,
      readChapterIds: dibaca,
    );
    state = Map.unmodifiable({...state, mangaId: baru});
  }
}

final historyRepositoryProvider =
    NotifierProvider<HistoryRepository, Map<String, MangaReadingProgress>>(
      () => HistoryRepository(),
    );
