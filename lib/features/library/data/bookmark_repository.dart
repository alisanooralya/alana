import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookmarked_manga.dart';

/// Repository bookmark (Pustaka), reaktif.
///
/// Fase 3: in-memory agar tombol bookmark di halaman detail
/// langsung memperbarui ikon. Fase 5: persistensi lokal
/// (shared_preferences/hive) tanpa mengubah API publik ini.
class BookmarkRepository extends Notifier<Map<String, BookmarkedManga>> {
  @override
  Map<String, BookmarkedManga> build() => const {};

  bool isBookmarked(String mangaId) => state.containsKey(mangaId);

  /// Menandai bila belum ada, menghapus bila sudah ada.
  /// Mengembalikan status baru (`true` = ditandai).
  bool toggle(BookmarkedManga item) {
    final next = Map<String, BookmarkedManga>.of(state);
    final sudahAda = next.containsKey(item.mangaId);
    if (sudahAda) {
      next.remove(item.mangaId);
    } else {
      next[item.mangaId] = item;
    }
    state = Map.unmodifiable(next);
    return !sudahAda;
  }
}

final bookmarkRepositoryProvider =
    NotifierProvider<BookmarkRepository, Map<String, BookmarkedManga>>(
      () => BookmarkRepository(),
    );
