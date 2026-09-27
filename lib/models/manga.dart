import 'package:alana/utils/json_utils.dart';
import 'package:alana/utils/manga_labels.dart';

/// Rujukan chapter yang baru rilis, untuk daftar pembaruan.
///
/// Berbeda dengan [Chapter] di `chapter.dart`, yang berisi judul dan URL
/// lengkap untuk halaman detail. Yang ini cuma nomor dan waktu rilis, jadi
/// nama-nya dibedakan agar keduanya tidak bentrok di `models/models.dart`.
class RecentChapter {
  final int number;

  /// ISO-8601 mentah, bukan label: label dihitung saat ditampilkan supaya
  /// "2 jam lalu" tidak kedaluwarsa selama feed masih di-cache.
  final String createdAt;

  const RecentChapter({required this.number, this.createdAt = ''});

  factory RecentChapter.fromJson(Map<String, dynamic> json) {
    return RecentChapter(
      number: asInt(json['chapter_number']),
      createdAt: asString(json['created_at']),
    );
  }
}

/// A manga/manhwa entry from list endpoints.
class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String status;

  /// ISO-8601 mentah, bukan label. Versi lama mem-bake label saat parsing,
  /// jadi chapter yang diupdate lima menit sebelum aplikasi dibuka tetap
  /// terbaca "5 menit lalu" berjam-jam selama feed masih di-cache.
  final String latestChapterTime;
  final int latestChapterNumber;
  final String country;
  final int viewCount;
  final num rating;
  final String description;

  /// Kode apa adanya (KR/CN/EN/JP), berbeda dari [country] yang sudah berupa
  /// nama panjang. Untuk bendera, karena "Korea" tidak bisa dikembalikan jadi
  /// emoji.
  final String countryCode;

  /// Chapter terbaru lebih dulu. Hanya endpoint daftar yang membawanya.
  final List<RecentChapter> chapters;

  const Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.status = '',
    this.latestChapterTime = '',
    this.latestChapterNumber = 0,
    this.country = '',
    this.countryCode = '',
    this.viewCount = 0,
    this.rating = 0,
    this.description = '',
    this.chapters = const [],
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final kodeNegara = asString(json['country_id']);

    return Manga(
      title: asString(json['title'], fallback: 'Unknown'),
      thumbnail: asString(
        json['cover_image_url'] ?? json['cover_portrait_url'],
      ),
      url: asString(json['manga_id']),
      status: mangaStatusLabel(json['status']),
      latestChapterTime: asString(json['latest_chapter_time']),
      latestChapterNumber: asInt(json['latest_chapter_number']),
      country: countryLabel(kodeNegara),
      countryCode: kodeNegara,
      viewCount: asInt(json['view_count']),
      rating: asNum(json['user_rate']),
      description: asString(json['description']),
      chapters: _parseChapters(json['chapters']),
    );
  }

  /// API bertipe longgar dan kadang mengirim null atau objek aneh. Nomor 0
  /// dibuang karena akan tampil sebagai "Chapter 0".
  static List<RecentChapter> _parseChapters(dynamic raw) {
    if (raw is! List) return const [];

    final hasil = <RecentChapter>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final chapter = RecentChapter.fromJson(Map<String, dynamic>.from(item));
      if (chapter.number > 0) hasil.add(chapter);
      if (hasil.length == 3) break;
    }
    return List.unmodifiable(hasil);
  }

  /// Chapter terbaru, maksimal [jumlah]. Kalau endpoint tidak mengirim
  /// `chapters`, chapter dirakit dari [latestChapterNumber] dan
  /// [latestChapterTime] supaya sel tidak kosong sama sekali.
  List<RecentChapter> recentChapterTerbaru({int jumlah = 2}) {
    if (chapters.isNotEmpty) {
      return jumlah >= chapters.length ? chapters : chapters.sublist(0, jumlah);
    }
    if (latestChapterNumber <= 0) return const [];
    return [
      RecentChapter(number: latestChapterNumber, createdAt: latestChapterTime),
    ];
  }
}
