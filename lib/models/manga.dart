class Manga {
  final String id;
  final String title;
  final String coverUrl;
  final bool isFavorite;
  final double? unreadCount;

  const Manga({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.isFavorite = false,
    this.unreadCount,
  });
}
