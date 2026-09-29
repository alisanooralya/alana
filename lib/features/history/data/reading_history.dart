class MangaReadingProgress {
  const MangaReadingProgress({
    required this.mangaId,
    this.mangaTitle = '',
    this.mangaThumbnail = '',
    this.lastChapterId = '',
    this.lastChapterName = '',
    this.readChapterIds = const {},
    this.scrollIndex = 0,
    this.scrollLeading = 0,
    this.scrollOffset = 0,
    this.pageCount = 0,
    required this.updatedAt,
    this.pending = false,
  });

  final String mangaId;
  final String mangaTitle;
  final String mangaThumbnail;
  final String lastChapterId;
  final String lastChapterName;

  final Set<String> readChapterIds;

  /// Halaman yang paling atas terlihat. Ini yang dipakai untuk restore.
  final int scrollIndex;

  /// Tepi depan halaman itu relatif terhadap atas viewport, dinormalisasi
  /// terhadap tinggi viewport. Bisa negatif kalau halaman itu sudah sebagian
  /// terlewat ke atas.
  final double scrollLeading;

  /// Piksel absolut dari versi lama.
  ///
  /// Tidak lagi dipakai untuk restore dan **tidak dikonversi** ke
  /// [scrollIndex]: tinggi item pernah berubah-ubah (placeholder 0,6 kali
  /// lebar lalu rasio asli), jadi piksel lama tidak punya indeks yang bisa
  /// dipercaya. Kolomnya masih ikut ditulis supaya versi aplikasi lama tidak
  /// kehilangan datanya.
  final double scrollOffset;
  final int pageCount;
  final DateTime updatedAt;
  final bool pending;

  MangaReadingProgress copyWith({
    String? mangaTitle,
    String? mangaThumbnail,
    String? lastChapterId,
    String? lastChapterName,
    Set<String>? readChapterIds,
    int? scrollIndex,
    double? scrollLeading,
    double? scrollOffset,
    int? pageCount,
    DateTime? updatedAt,
    bool? pending,
  }) {
    return MangaReadingProgress(
      mangaId: mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      mangaThumbnail: mangaThumbnail ?? this.mangaThumbnail,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterName: lastChapterName ?? this.lastChapterName,
      readChapterIds: readChapterIds ?? this.readChapterIds,
      scrollIndex: scrollIndex ?? this.scrollIndex,
      scrollLeading: scrollLeading ?? this.scrollLeading,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      pageCount: pageCount ?? this.pageCount,
      updatedAt: updatedAt ?? this.updatedAt,
      pending: pending ?? this.pending,
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
      'scrollIndex': scrollIndex,
      'scrollLeading': scrollLeading,
      'scrollOffset': scrollOffset,
      'pageCount': pageCount,
      'updatedAt': updatedAt.toIso8601String(),
      'pending': pending,
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
      scrollIndex: int.tryParse(map['scrollIndex']?.toString() ?? '') ?? 0,
      scrollLeading:
          double.tryParse(map['scrollLeading']?.toString() ?? '') ?? 0,
      scrollOffset: double.tryParse(map['scrollOffset']?.toString() ?? '') ?? 0,
      pageCount: int.tryParse(map['pageCount']?.toString() ?? '') ?? 0,
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pending: map['pending'] == true,
    );
  }
}
