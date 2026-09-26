import 'package:alana/utils/json_utils.dart';
import 'package:alana/utils/manga_labels.dart';

/// A manga/manhwa entry from list endpoints.
class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String status;
  /// Waktu chapter terbaru dalam ISO-8601 mentah.
  /// Disimpan mentah, bukan sebagai label, supaya label selalu dihitung
  /// saat ditampilkan. Versi lama mem-bake label saat parsing, dan karena
  /// feed di-cache selama proses berjalan, chapter yang diupdate lima
  /// menit sebelum aplikasi dibuka tetap terbaca "5 menit lalu" berjam-jam.
  final String latestChapterTime;
  final int latestChapterNumber;
  final String country;
  final int viewCount;
  final num rating;
  final String description;

  const Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.status = '',
    this.latestChapterTime = '',
    this.latestChapterNumber = 0,
    this.country = '',
    this.viewCount = 0,
    this.rating = 0,
    this.description = '',
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      title: asString(json['title'], fallback: 'Unknown'),
      thumbnail: asString(
        json['cover_image_url'] ?? json['cover_portrait_url'],
      ),
      url: asString(json['manga_id']),
      status: mangaStatusLabel(json['status']),
      latestChapterTime: asString(json['latest_chapter_time']),
      latestChapterNumber: asInt(json['latest_chapter_number']),
      country: countryLabel(asString(json['country_id'])),
      viewCount: asInt(json['view_count']),
      rating: asNum(json['user_rate']),
      description: asString(json['description']),
    );
  }
