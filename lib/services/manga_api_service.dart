import 'dart:typed_data';

import 'package:alana/models/models.dart';

import 'manga_api_client.dart';
import 'manga_api_exception.dart';
import 'manga_api_parsers.dart';

/// High-level access to the Shinigami (shngm) manga API.
class MangaApiService {
  MangaApiService({MangaApiClient? client})
    : _client = client ?? MangaApiClient();

  final MangaApiClient _client;

  /// Fetches the daily popular manga list.
  Future<MangaListResponse> getPopularManga({int page = 1}) {
    return _guard('get popular manga', () async {
      final json = await _client.getJson(
        '/v1/manga/top',
        queryParameters: {'filter': 'daily', 'page': page, 'page_size': 10},
      );
      return MangaListResponse.fromJson(json);
    });
  }

  /// Fetches the latest updated manga list.
  Future<MangaListResponse> getLatestUpdates({int page = 1}) {
    return _guard('get latest updates', () async {
      final json = await _client.getJson(
        '/v1/manga/list',
        queryParameters: {
          'type': 'project',
          'page': page,
          'page_size': 20,
          'is_update': true,
          'sort': 'latest',
          'sort_order': 'desc',
        },
      );
      return MangaListResponse.fromJson(json);
    });
  }

  /// Fetches recommended manga.
  Future<MangaListResponse> getRecommendedManga({int page = 1}) {
    return _guard('get recommended manga', () async {
      final json = await _client.getJson(
        '/v1/manga/list',
        queryParameters: {
          'format': 'manhwa',
          'page': page,
          'page_size': 10,
          'is_recommended': true,
          'sort': 'latest',
          'sort_order': 'desc',
        },
      );
      return MangaListResponse.fromJson(json);
    });
  }

  /// Searches manga by [query], optionally filtered by genre, format or status.
  ///
  /// [genreInclude], [format] and [status] each accept either a single value
  /// or a list of values.
  Future<MangaListResponse> searchManga(
    String query, {
    int page = 1,
    dynamic genreInclude = '',
    dynamic format = '',
    dynamic status = '',
  }) {
    return _guard('search manga', () async {
      final params = <String, dynamic>{
        'page': page,
        'page_size': 24,
        'genre_include_mode': 'or',
        'genre_exclude_mode': 'or',
        'sort': 'latest',
        'sort_order': 'desc',
      };

      if (query.isNotEmpty) params['q'] = query;

      final genre = _normalizeMultiValue(genreInclude);
      if (genre.isNotEmpty) params['genre_include'] = genre;

      final formatValue = _normalizeMultiValue(format);
      if (formatValue.isNotEmpty) params['format'] = formatValue;

      final statusValue = _normalizeMultiValue(status);
      if (statusValue.isNotEmpty) params['status'] = statusValue;

      final json = await _client.getJson(
        '/v1/manga/list',
        queryParameters: params,
      );
      return MangaListResponse.fromJson(json);
    });
  }

  /// Fetches the list of available genres.
  Future<List<Genre>> getGenreList() {
    return _guard('get genre list', () async {
      final body = await _client.getData('/v1/genre/list');

      final rawData = body is Map ? (body['data'] ?? body) : body;
      if (rawData is! List) {
        throw const FormatException('Invalid response structure from API');
      }

      return rawData
          .whereType<Map<String, dynamic>>()
          .map(Genre.fromJson)
          .toList();
    });
  }

  /// Fetches details of the manga with the given [mangaId].
  Future<MangaDetails> getMangaDetails(String mangaId) {
    return _guard('get manga details', () async {
      final json = await _client.getJson('/v1/manga/detail/$mangaId');

      final data = json['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response from API');
      }

      return MangaDetails.fromJson(data);
    });
  }

  /// Fetches all chapters of the manga with the given [mangaId].
  Future<List<Chapter>> getChapterList(String mangaId) {
    return _guard('get chapter list', () async {
      final data = await _client.getData(
        '/v1/chapter/$mangaId/list',
        queryParameters: {'page_size': 3000},
      );
      return parseChapterList(data, mangaId: mangaId);
    });
  }

  /// Fetches the pages (images) of the chapter with the given [chapterId].
  Future<List<Page>> getPageList(String chapterId) {
    return _guard('get page list', () async {
      final data = await _client.getData('/v1/chapter/detail/$chapterId');
      return parsePageList(data);
    });
  }

  /// Downloads the raw bytes of an image.
  Future<Uint8List> downloadImage(String imageUrl) {
    return _client.downloadImage(imageUrl);
  }

  Future<T> _guard<T>(String action, Future<T> Function() request) async {
    try {
      return await request();
    } catch (error) {
      throw MangaApiException.from(action, error);
    }
  }
}

/// Normalizes a search filter into a comma separated value.
///
/// Accepts a single value, a comma separated string or an iterable of values.
String _normalizeMultiValue(dynamic value) {
  if (value == null) return '';

  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join(',');
  }

  return value
      .toString()
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .join(',');
}
