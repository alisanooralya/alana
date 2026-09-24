/// Satu judul yang ditandai di Pustaka.
///
/// Disimpan di Hive sebagai `Map` (lihat [toMap]/[fromMap]).
class BookmarkedManga {
  const BookmarkedManga({
    required this.mangaId,
    required this.title,
    this.thumbnail = '',
    required this.savedAt,
    DateTime? updatedAt,
    this.pending = false,
  }) : updatedAt = updatedAt ?? savedAt;

  final String mangaId;
  final String title;
  final String thumbnail;

  /// Kapan judul ditandai.
  final DateTime savedAt;

  /// Perubahan terakhir (untuk last-write-wins lintas perangkat).
  final DateTime updatedAt;

  /// `true` bila belum terkirim ke Supabase.
  final bool pending;

  BookmarkedManga copyWith({
    String? title,
    String? thumbnail,
    DateTime? updatedAt,
    bool? pending,
  }) {
    return BookmarkedManga(
      mangaId: mangaId,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      savedAt: savedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pending: pending ?? this.pending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'title': title,
      'thumbnail': thumbnail,
      'savedAt': savedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pending': pending,
    };
  }

  factory BookmarkedManga.fromMap(Map<String, dynamic> map) {
    final disimpan =
        DateTime.tryParse(map['savedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return BookmarkedManga(
      mangaId: map['mangaId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Tanpa judul',
      thumbnail: map['thumbnail']?.toString() ?? '',
      savedAt: disimpan,
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? disimpan,
      pending: map['pending'] == true,
    );
  }
}
