import 'package:alana/utils/json_utils.dart';
import 'package:alana/utils/manga_labels.dart';
import 'package:alana/utils/relative_time.dart';

/// A manga/manhwa entry from list endpoints.
class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String status;
  final String latestChapterDate;
  final int latestChapterNumber;
  final String country;
  final int viewCount;
  final num rating;
  final String description;
  final List<Map<String, dynamic>>? chapters;

  const Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.status = '',
    this.latestChapterDate = '',
    this.latestChapterNumber = 0,
    this.country = '',
    this.viewCount = 0,
    this.rating = 0,
    this.description = '',
    this.chapters,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      title: asString(json['title'], fallback: 'Unknown'),
      thumbnail: asString(
        json['cover_image_url'] ?? json['cover_portrait_url'],
      ),
      url: asString(json['manga_id']),
      status: mangaStatusLabel(json['status']),
      latestChapterDate: formatRelativeTime(
        asString(json['latest_chapter_time']),
      ),
      latestChapterNumber: asInt(json['latest_chapter_number']),
      country: countryLabel(asString(json['country_id'])),
      viewCount: asInt(json['view_count']),
      rating: asNum(json['user_rate']),
      description: asString(json['description']),
      chapters: _chaptersFromJson(json['chapters']),
    );
  }

  Manga copyWith({
    String? title,
    String? thumbnail,
    String? url,
    String? status,
    String? latestChapterDate,
    int? latestChapterNumber,
    String? country,
    int? viewCount,
    num? rating,
    String? description,
    List<Map<String, dynamic>>? chapters,
  }) {
    return Manga(
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      url: url ?? this.url,
      status: status ?? this.status,
      latestChapterDate: latestChapterDate ?? this.latestChapterDate,
      latestChapterNumber: latestChapterNumber ?? this.latestChapterNumber,
      country: country ?? this.country,
      viewCount: viewCount ?? this.viewCount,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      chapters: chapters ?? this.chapters,
    );
  }
}

/// Extracts the light chapter summaries embedded in list responses.
/// Returns `null` when the payload carries no chapter list.
List<Map<String, dynamic>>? _chaptersFromJson(dynamic rawChapters) {
  if (rawChapters is! List) return null;

  return rawChapters.whereType<Map<String, dynamic>>().map((chapter) {
    return <String, dynamic>{
      'chapter_id': asString(chapter['chapter_id']),
      'chapter_number': chapter['chapter_number'] ?? 0,
      'created_at': formatRelativeTime(asString(chapter['created_at'])),
    };
  }).toList();
}
