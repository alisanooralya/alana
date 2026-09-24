/// Satu judul yang ditandai di Pustaka.
///
/// Disimpan in-memory di Fase 3. Fase 5 mengganti penyimpanan
/// dengan shared_preferences/hive tanpa mengubah API ini.
class BookmarkedManga {
  const BookmarkedManga({
    required this.mangaId,
    required this.title,
    this.thumbnail = '',
    required this.savedAt,
  });

  final String mangaId;
  final String title;
  final String thumbnail;

  /// Kapan judul ditandai.
  final DateTime savedAt;
}
