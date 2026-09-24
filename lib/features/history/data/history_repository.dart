import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';

import 'reading_history.dart';

/// Repository riwayat baca, reaktif + persisten (Hive).
class HistoryRepository extends Notifier<Map<String, MangaReadingProgress>> {
  @override
  Map<String, MangaReadingProgress> build() {
    final box = AppStorage.historyBox;
    final entries = <String, MangaReadingProgress>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final progress = MangaReadingProgress.fromMap(
        Map<String, dynamic>.from(raw),
      );
      if (progress.mangaId.isNotEmpty) {
        entries[progress.mangaId] = progress;
      }
    }
    return Map.unmodifiable(entries);
  }

  MangaReadingProgress? progressUntuk(String mangaId) => state[mangaId];

  Set<String> idDibacaUntuk(String mangaId) {
    return state[mangaId]?.readChapterIds ?? const {};
  }

  bool sudahDibaca(String mangaId, String chapterId) {
    return state[mangaId]?.readChapterIds.contains(chapterId) ?? false;
  }

  void _tulis(MangaReadingProgress progress) {
    AppStorage.historyBox.put(progress.mangaId, progress.toMap());
    state = Map.unmodifiable({...state, progress.mangaId: progress});
  }

  MangaReadingProgress _denganIdentitas(
    MangaReadingProgress progress,
    String mangaTitle,
    String mangaThumbnail,
  ) {
    if (mangaTitle.isEmpty && mangaThumbnail.isEmpty) return progress;
    return progress.copyWith(
      mangaTitle: mangaTitle.isEmpty ? progress.mangaTitle : mangaTitle,
      mangaThumbnail: mangaThumbnail.isEmpty
          ? progress.mangaThumbnail
          : mangaThumbnail,
    );
  }

  /// Mencatat chapter sebagai sudah dibaca sekaligus
  /// menjadikannya posisi terakhir.
  void tandaiDibaca({
    required String mangaId,
    String mangaTitle = '',
    String mangaThumbnail = '',
    required String chapterId,
    required String chapterName,
  }) {
    final lama = state[mangaId];
    final dibaca = {...?lama?.readChapterIds, chapterId};
    var baru =
        (lama ??
                MangaReadingProgress(
                  mangaId: mangaId,
                  updatedAt: DateTime.now(),
                ))
            .copyWith(
              lastChapterId: chapterId,
              lastChapterName: chapterName,
              readChapterIds: dibaca,
              updatedAt: DateTime.now(),
            );
    _tulis(_denganIdentitas(baru, mangaTitle, mangaThumbnail));
  }

  /// Menyimpan posisi scroll chapter yang sedang dibaca.
  /// Dipanggil berkala oleh reader (debounce).
  void simpanPosisi({
    required String mangaId,
    String mangaTitle = '',
    String mangaThumbnail = '',
    required String chapterId,
    String chapterName = '',
    required double scrollOffset,
    required int pageCount,
  }) {
    final lama =
        state[mangaId] ??
        MangaReadingProgress(mangaId: mangaId, updatedAt: DateTime.now());
    var baru = lama.copyWith(
      lastChapterId: chapterId,
      lastChapterName: chapterName.isEmpty ? lama.lastChapterName : chapterName,
      scrollOffset: scrollOffset,
      pageCount: pageCount,
      updatedAt: DateTime.now(),
    );
    _tulis(_denganIdentitas(baru, mangaTitle, mangaThumbnail));
  }

  /// Menghapus satu entri riwayat. Aman bila ID tidak ada.
  void hapus(String mangaId) {
    if (!state.containsKey(mangaId)) return;
    final next = Map<String, MangaReadingProgress>.of(state)..remove(mangaId);
    AppStorage.historyBox.delete(mangaId);
    state = Map.unmodifiable(next);
  }
}

final historyRepositoryProvider =
    NotifierProvider<HistoryRepository, Map<String, MangaReadingProgress>>(
      () => HistoryRepository(),
    );
