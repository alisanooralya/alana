/// Satu baris tabel `notifications`.
class Notifikasi {
  const Notifikasi({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.mangaId = '',
    this.chapterId = '',
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String mangaId;
  final String chapterId;
  final bool isRead;
  final DateTime createdAt;

  factory Notifikasi.fromMap(Map<String, dynamic> map) {
    return Notifikasi(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'system',
      title: map['title']?.toString() ?? 'Notifikasi',
      body: map['body']?.toString() ?? '',
      mangaId: map['manga_id']?.toString() ?? '',
      chapterId: map['chapter_id']?.toString() ?? '',
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
