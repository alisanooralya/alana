import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';

import 'bookmarked_manga.dart';

/// Repository bookmark (Pustaka), reaktif + persisten (Hive).
class BookmarkRepository extends Notifier<Map<String, BookmarkedManga>> {
  @override
  Map<String, BookmarkedManga> build() {
    final box = AppStorage.bookmarksBox;
    final entries = <String, BookmarkedManga>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final item = BookmarkedManga.fromMap(Map<String, dynamic>.from(raw));
      if (item.mangaId.isNotEmpty) entries[item.mangaId] = item;
    }
    return Map.unmodifiable(entries);
  }

  bool isBookmarked(String mangaId) => state.containsKey(mangaId);

  /// Menandai bila belum ada, menghapus bila sudah ada.
  /// Mengembalikan status baru (`true` = ditandai).
  bool toggle(BookmarkedManga item) {
    final box = AppStorage.bookmarksBox;
    final next = Map<String, BookmarkedManga>.of(state);
    final sudahAda = next.containsKey(item.mangaId);
    if (sudahAda) {
      next.remove(item.mangaId);
      box.delete(item.mangaId);
    } else {
      next[item.mangaId] = item;
      box.put(item.mangaId, item.toMap());
    }
    state = Map.unmodifiable(next);
    return !sudahAda;
  }

  /// Menghapus bookmark. Aman bila ID tidak ada.
  void hapus(String mangaId) {
    if (!state.containsKey(mangaId)) return;
    final next = Map<String, BookmarkedManga>.of(state)..remove(mangaId);
    AppStorage.bookmarksBox.delete(mangaId);
    state = Map.unmodifiable(next);
  }
}

final bookmarkRepositoryProvider =
    NotifierProvider<BookmarkRepository, Map<String, BookmarkedManga>>(
      () => BookmarkRepository(),
    );
