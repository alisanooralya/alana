/// Progres baca satu judul.
///
/// Disimpan in-memory di Fase 3. Fase 5 mempersistkan tanpa
/// mengubah API ini. Fase 4 menambahkan posisi halaman terakhir.
class MangaReadingProgress {
  const MangaReadingProgress({
    required this.mangaId,
    this.lastChapterId = '',
    this.lastChapterName = '',
    this.readChapterIds = const {},
  });

  final String mangaId;

  /// Chapter terakhir yang dibuka.
  final String lastChapterId;
  final String lastChapterName;

  /// Semua ID chapter yang pernah ditandai dibaca.
  final Set<String> readChapterIds;

  MangaReadingProgress copyWith({
    String? lastChapterId,
    String? lastChapterName,
    Set<String>? readChapterIds,
  }) {
    return MangaReadingProgress(
      mangaId: mangaId,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterName: lastChapterName ?? this.lastChapterName,
      readChapterIds: readChapterIds ?? this.readChapterIds,
    );
  }
}
