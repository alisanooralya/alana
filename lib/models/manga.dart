import 'package:alana/utils/json_utils.dart';
import 'package:alana/utils/manga_labels.dart';

class RecentChapter {
  final String id;

  final int number;
  final String createdAt;

  const RecentChapter({
    this.id = '',
    required this.number,
    this.createdAt = '',
  });

  factory RecentChapter.fromJson(Map<String, dynamic> json) {
    return RecentChapter(
      id: asString(json['chapter_id']),
      number: asInt(json['chapter_number']),
      createdAt: asString(json['created_at']),
    );
  }
}

class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String status;

  final String latestChapterTime;
  final int latestChapterNumber;

  final String latestChapterId;
  final String country;
  final int viewCount;
  final num rating;
  final String description;
  final String countryCode;

  final List<RecentChapter> chapters;

  const Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.status = '',
    this.latestChapterTime = '',
    this.latestChapterNumber = 0,
    this.latestChapterId = '',
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
      latestChapterId: asString(json['latest_chapter_id']),
      country: countryLabel(kodeNegara),
      countryCode: kodeNegara,
      viewCount: asInt(json['view_count']),
      rating: asNum(json['user_rate']),
      description: asString(json['description']),
      chapters: _parseChapters(json['chapters']),
    );
  }

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

  List<RecentChapter> recentChapterTerbaru({int jumlah = 2}) {
    if (chapters.isNotEmpty) {
      return jumlah >= chapters.length ? chapters : chapters.sublist(0, jumlah);
    }
    if (latestChapterNumber <= 0) return const [];
    return [
      RecentChapter(
        id: latestChapterId,
        number: latestChapterNumber,
        createdAt: latestChapterTime,
      ),
    ];
  }
}
