import 'package:alana/models/models.dart';

import 'manga_api_client.dart';
import 'manga_api_exception.dart';
import 'manga_api_parsers.dart';

enum MangaStatusFilter { all, ongoing, completed }

extension MangaStatusFilterValue on MangaStatusFilter {
  int? get apiValue => switch (this) {
    MangaStatusFilter.all => null,
    MangaStatusFilter.ongoing => 1,
    MangaStatusFilter.completed => 2,
  };
}

enum MangaSort { latest, popular, rating }

extension MangaSortValue on MangaSort {
  String get apiValue => switch (this) {
    MangaSort.latest => 'latest',
    MangaSort.popular => 'popularity',
    MangaSort.rating => 'rating',
  };
}

class MangaApiService {
  MangaApiService({MangaApiClient? client})
    : _client = client ?? MangaApiClient();

  final MangaApiClient _client;

  Future<MangaListResponse> getPopularManga({int page = 1}) {
    return _guard('get popular manga', () async {
      final json = await _client.getJson(
        '/v1/manga/top',
        queryParameters: {'filter': 'daily', 'page': page, 'page_size': 10},
      );
      return MangaListResponse.fromJson(json);
    });
  }

  Future<MangaListResponse> getLatestUpdates({int page = 1}) {
    return _guard('get latest updates', () async {
      final json = await _client.getJson(
        '/v1/manga/list',
        queryParameters: {
          'type': 'project',
          'page': page,
          'page_size': 24,
          'is_update': true,
          'sort': 'latest',
          'sort_order': 'desc',
        },
      );
      return MangaListResponse.fromJson(json);
    });
  }

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

  Future<MangaListResponse> listManga({
    String query = '',
    int page = 1,
    Iterable<String> genreSlugs = const [],
    MangaStatusFilter status = MangaStatusFilter.all,
    MangaSort sort = MangaSort.latest,
  }) {
    return _guard('list manga', () async {
      final params = <String, dynamic>{
        'page': page,
        'page_size': 24,
        'genre_include_mode': 'or',
        'genre_exclude_mode': 'or',
        'sort': sort.apiValue,
        'sort_order': 'desc',
      };

      if (query.isNotEmpty) params['q'] = query;
      final genre = _normalizeMultiValue(genreSlugs);
      if (genre.isNotEmpty) params['genre_include'] = genre;
      if (status.apiValue != null) params['status'] = status.apiValue;

      final json = await _client.getJson(
        '/v1/manga/list',
        queryParameters: params,
      );
      return MangaListResponse.fromJson(json);
    });
  }

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

  static const int _chapterPageSize = 50;

  Future<ChapterPage> getChapterList(String mangaId, {int page = 1}) {
    return _guard('get chapter list', () async {
      final json = await _client.getJson(
        '/v1/chapter/$mangaId/list',
        queryParameters: {'page': page, 'page_size': _chapterPageSize},
      );
      final totalPage = _totalPage(json);
      return ChapterPage(
        chapters: parseChapterList(json, mangaId: mangaId),
        totalPage: totalPage != null && totalPage > 0 ? totalPage : 1,
      );
    });
  }

  static int? _totalPage(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map) return null;
    final value = meta['total_page'];
    if (value is int) return value > 0 ? value : null;
    if (value is num) return value.toInt() > 0 ? value.toInt() : null;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<List<Page>> getPageList(String chapterId) {
    return _guard('get page list', () async {
      final data = await _client.getData('/v1/chapter/detail/$chapterId');
      return parsePageList(data);
    });
  }

  Future<T> _guard<T>(String action, Future<T> Function() request) async {
    try {
      return await request();
    } catch (error) {
      throw MangaApiException.from(action, error);
    }
  }
}

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
