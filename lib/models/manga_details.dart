import 'package:alana/utils/json_utils.dart';
import 'package:alana/utils/manga_labels.dart';

/// Full details of a single manga.
class MangaDetails {
  final String title;
  final String description;
  final String alternativeTitle;
  final String releaseYear;
  final String status;
  final String thumbnail;
  final int viewCount;
  final double userRate;
  final String country;
  final int bookmarkCount;
  final int rank;

  final List<String> authors;
  final List<String> artists;
  final List<String> genres;
  final List<String> formats;
  final List<String> types;

  const MangaDetails({
    required this.title,
    required this.description,
    this.alternativeTitle = '',
    this.releaseYear = '',
    this.status = '',
    this.thumbnail = '',
    this.viewCount = 0,
    this.userRate = 0,
    this.country = '',
    this.bookmarkCount = 0,
    this.rank = 0,
    this.authors = const [],
    this.artists = const [],
    this.genres = const [],
    this.formats = const [],
    this.types = const [],
  });

  factory MangaDetails.fromJson(Map<String, dynamic> json) {
    final rawTaxonomy = json['taxonomy'];
    final taxonomy = rawTaxonomy is Map
        ? Map<String, dynamic>.from(rawTaxonomy)
        : const <String, dynamic>{};

    return MangaDetails(
      title: asString(json['title'], fallback: 'Unknown'),
      description: asString(json['description']),
      alternativeTitle: asString(json['alternative_title']),
      releaseYear: asString(json['release_year']),
      status: mangaStatusLabel(json['status']),
      thumbnail: asString(
        json['cover_image_url'] ?? json['cover_portrait_url'],
      ),
      viewCount: asInt(json['view_count']),
      userRate: asDouble(json['user_rate']),
      country: countryLabel(asString(json['country_id'])),
      bookmarkCount: asInt(json['bookmark_count']),
      rank: asInt(json['rank']),
      authors: _namesOf(taxonomy['Author']),
      artists: _namesOf(taxonomy['Artist']),
      genres: _namesOf(taxonomy['Genre']),
      formats: _namesOf(taxonomy['Format']),
      types: _namesOf(taxonomy['Type']),
    );
  }
}

/// Extracts the `name` values of a taxonomy group (Author, Genre, ...).
List<String> _namesOf(dynamic items) {
  if (items is! List) return const [];

  return items
      .whereType<Map>()
      .map((item) => asString(item['name']))
      .where((name) => name.isNotEmpty)
      .toList();
}
