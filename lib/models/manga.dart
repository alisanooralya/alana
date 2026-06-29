/// Model data sederhana untuk satu judul manga.
///
/// Ini adalah pengganti ringan dari model `Manga` milik mangayomi yang
/// aslinya berbasis Isar (database lokal). Silakan sesuaikan / tambah
/// field sesuai kebutuhan (misalnya genre, status, sumber, dsb).
class Manga {
  final String id;
  final String title;
  final String coverUrl;
  final bool isFavorite;
  final double? unreadCount; // null jika tidak ingin ditampilkan badge

  const Manga({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.isFavorite = false,
    this.unreadCount,
  });
}
