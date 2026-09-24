/// Progres baca satu judul, disimpan di Hive sebagai `Map`.
///
/// Menyimpan judul, chapter terakhir, posisi scroll chapter tersebut,
/// dan daftar chapter yang sudah dibaca. Fase berikutnya bisa
/// menambahkan posisi halaman terakhir tanpa mengubah bentuk dasar.
class MangaReadingProgress {
  const MangaReadingProgress({
    required this.mangaId,
    this.mangaTitle = '',
    this.mangaThumbnail = '',
    this.lastChapterId = '',
    this.lastChapterName = '',
    this.readChapterIds = const {},
    this.scrollOffset = 0,
    this.pageCount = 0,
    required this.updatedAt,
  });

  final String mangaId;
  final String mangaTitle;
  final String mangaThumbnail;

  /// Chapter terakhir yang dibuka.
  final String lastChapterId;
  final String lastChapterName;

  /// Semua ID chapter yang pernah ditandai dibaca.
  final Set<String> readChapterIds;

  /// Posisi scroll (piksel) terakhir di chapter terakhir.
  final double scrollOffset;

  /// Jumlah gambar saat posisi disimpan (validasi saat restore).
  final int pageCount;

  /// Terakhir diperbarui. Menentukan urutan di tab Riwayat.
  final DateTime updatedAt;

  MangaReadingProgress copyWith({
    String? mangaTitle,
    String? mangaThumbnail,
    String? lastChapterId,
    String? lastChapterName,
    Set<String>? readChapterIds,
    double? scrollOffset,
    int? pageCount,
    DateTime? updatedAt,
  }) {
    return MangaReadingProgress(
      mangaId: mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      mangaThumbnail: mangaThumbnail ?? this.mangaThumbnail,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterName: lastChapterName ?? this.lastChapterName,
      readChapterIds: readChapterIds ?? this.readChapterIds,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      pageCount: pageCount ?? this.pageCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'mangaTitle': mangaTitle,
      'mangaThumbnail': mangaThumbnail,
      'lastChapterId': lastChapterId,
      'lastChapterName': lastChapterName,
      'readChapterIds': readChapterIds.toList(),
      'scrollOffset': scrollOffset,
      'pageCount': pageCount,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MangaReadingProgress.fromMap(Map<String, dynamic> map) {
    final rawIds = map['readChapterIds'];
    return MangaReadingProgress(
      mangaId: map['mangaId']?.toString() ?? '',
      mangaTitle: map['mangaTitle']?.toString() ?? '',
      mangaThumbnail: map['mangaThumbnail']?.toString() ?? '',
      lastChapterId: map['lastChapterId']?.toString() ?? '',
      lastChapterName: map['lastChapterName']?.toString() ?? '',
      readChapterIds: rawIds is List
          ? {for (final id in rawIds) id.toString()}
          : const {},
      scrollOffset: double.tryParse(map['scrollOffset']?.toString() ?? '') ?? 0,
      pageCount: int.tryParse(map['pageCount']?.toString() ?? '') ?? 0,
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
