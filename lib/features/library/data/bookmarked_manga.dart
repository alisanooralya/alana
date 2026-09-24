/// Satu judul yang ditandai di Pustaka.
///
/// Disimpan di Hive sebagai `Map` (lihat [toMap]/[fromMap]).
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

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'title': title,
      'thumbnail': thumbnail,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory BookmarkedManga.fromMap(Map<String, dynamic> map) {
    return BookmarkedManga(
      mangaId: map['mangaId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Tanpa judul',
      thumbnail: map['thumbnail']?.toString() ?? '',
      savedAt:
          DateTime.tryParse(map['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
