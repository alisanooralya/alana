import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:alana/models/manga_types.dart';

class MangaApiService {
  final String baseUrl = 'https://app.shinigami.asia';
  final String apiUrl = 'https://api.shngm.io';
  final String cdnUrl = 'https://storage.shngm.id';

  late final Dio _client;

  MangaApiService() {
    _client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: _getApiHeaders(),
      ),
    );
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  Map<String, String> _getApiHeaders() {
    final rnd = Random();
    return {
      'Accept': 'application/json',
      'DNT': '1',
      'Origin': baseUrl,
      'Sec-GPC': '1',
      'X-Requested-With': _randomString(rnd.nextInt(20) + 1),
    };
  }

  Map<String, String> _getImageHeaders() {
    final rnd = Random();
    return {
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'DNT': '1',
      'Referer': '$baseUrl/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-GPC': '1',
      'X-Requested-With': _randomString(rnd.nextInt(20) + 1),
    };
  }

  String _toStatus(int statusCode) {
    if (statusCode == 1) return 'Ongoing';
    if (statusCode == 2) return 'Completed';
    return 'Unknown';
  }

  Exception _buildError(String action, dynamic error) {
    if (error is DioException && error.response != null) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      String message = error.message ?? '';
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }
      return Exception('Failed to $action: $status - $message');
    }
    return Exception('Failed to $action: ${error.toString()}');
  }

  String _mapCountry(String? countryId) {
    switch ((countryId ?? '').toUpperCase()) {
      case 'KR':
        return 'Korea';
      case 'CN':
        return 'China';
      case 'EN':
        return 'English';
      case 'JP':
        return 'Japan';
      default:
        return countryId ?? '';
    }
  }

  String _formatChapterDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
  
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
  
      final minutes = diff.inMinutes;
      final hours = diff.inHours;
      final days = diff.inDays;
  
      if (minutes < 1) {
        return 'Now';
      } else if (hours < 1) {
        return '${minutes}M';
      } else if (days < 1) {
        return '${hours}H';
      } else if (days < 7) {
        return '${days}D';
      } else if (days < 30) {
        final weeks = (days / 7).floor();
        return '${weeks}W';
      } else if (days < 365) {
        final months = (days / 30).floor();
        return '${months}M';
      } else {
        final years = (days / 365).floor();
        return '${years}Y';
      }
    } catch (_) {
      return '';
    }
  }

  List<Manga> _mapMangaList(List<dynamic> data) {
    return data.map((item) {
      final map = item as Map<String, dynamic>;
      final mangaId = map['manga_id'] ?? '';
      return Manga(
        title: map['title'] ?? 'Unknown',
        thumbnail: map['cover_image_url'] ?? map['cover_portrait_url'] ?? '',
        url: mangaId,
        latestChapterDate: _formatChapterDate(map['latest_chapter_time']),
        country: _mapCountry(map['country_id']),
      );
    }).toList();
  }

  Future<MangaListResponse> getPopularManga({int page = 1}) async {
    try {
      final response = await _client.get(
        '$apiUrl/v1/manga/top',
        queryParameters: {'filter': 'daily', 'page': page, 'page_size': 10},
      );

      final body = response.data;
      if (body == null || body['data'] == null) {
        throw Exception('Invalid response from API');
      }

      final mangas = _mapMangaList(body['data'] as List<dynamic>);

      final meta = body['meta'];
      final currentPage = meta?['page'];
      final totalPage = meta?['total_page'];
      final hasNextPage = (currentPage != null && totalPage != null)
          ? currentPage < totalPage
          : false;

      return MangaListResponse(mangas: mangas, hasNextPage: hasNextPage);
    } catch (error) {
      throw _buildError('get popular manga', error);
    }
  }

  Future<MangaListResponse> getLatestUpdates({int page = 1}) async {
    try {
      final response = await _client.get(
        '$apiUrl/v1/manga/list',
        queryParameters: {'page': page, 'page_size': 30, 'sort': 'latest'},
      );

      final body = response.data;
      if (body == null || body['data'] == null) {
        throw Exception('Invalid response from API');
      }

      final mangas = _mapMangaList(body['data'] as List<dynamic>);

      final meta = body['meta'];
      final currentPage = meta?['page'];
      final totalPage = meta?['total_page'];
      final hasNextPage = (currentPage != null && totalPage != null)
          ? currentPage < totalPage
          : false;

      return MangaListResponse(mangas: mangas, hasNextPage: hasNextPage);
    } catch (error) {
      throw _buildError('get latest updates', error);
    }
  }
  
  Future<MangaListResponse> getRecommendedManga({int page = 1}) async {
    try {
      final response = await _client.get(
        '$apiUrl/v1/manga/list',
        queryParameters: {
          'format': 'manhwa',
          'page': page,
          'page_size': 10,
          'is_recommended': true,
          'sort': 'latest',
          'sort_order': 'desc',
        },
      );
  
      final body = response.data;
      if (body == null || body['data'] == null) {
        throw Exception('Invalid response from API');
      }
  
      final mangas = _mapMangaList(body['data'] as List<dynamic>);
  
      final meta = body['meta'];
      final currentPage = meta?['page'];
      final totalPage = meta?['total_page'];
      final hasNextPage = (currentPage != null && totalPage != null)
          ? currentPage < totalPage
          : false;
  
      return MangaListResponse(mangas: mangas, hasNextPage: hasNextPage);
    } catch (error) {
      throw _buildError('get recommended manga', error);
    }
  }

  Future<MangaListResponse> searchManga(String query, {int page = 1}) async {
    try {
      final params = <String, dynamic>{'page': page, 'page_size': 30};

      if (query.isNotEmpty) {
        params['q'] = query;
      }

      final response = await _client.get(
        '$apiUrl/v1/manga/list',
        queryParameters: params,
      );

      final body = response.data;
      if (body == null || body['data'] == null) {
        throw Exception('Invalid response from API');
      }

      final mangas = _mapMangaList(body['data'] as List<dynamic>);

      final meta = body['meta'];
      final currentPage = meta?['page'];
      final totalPage = meta?['total_page'];
      final hasNextPage = (currentPage != null && totalPage != null)
          ? currentPage < totalPage
          : false;

      return MangaListResponse(mangas: mangas, hasNextPage: hasNextPage);
    } catch (error) {
      throw _buildError('search manga', error);
    }
  }

  Future<MangaDetails> getMangaDetails(String mangaId) async {
    try {
      final response = await _client.get('$apiUrl/v1/manga/detail/$mangaId');

      final body = response.data;
      if (body == null || body['data'] == null) {
        throw Exception('Invalid response from API');
      }

      final data = body['data'] as Map<String, dynamic>;
      final taxonomy = (data['taxonomy'] as Map<String, dynamic>?) ?? {};

      String getNames(dynamic items) {
        if (items == null || items is! List) return '';
        return items
            .map((item) => (item as Map<String, dynamic>)['name'] ?? '')
            .where((n) => n.toString().isNotEmpty)
            .join(', ');
      }

      final authors = getNames(taxonomy['Author']);
      final artists = getNames(taxonomy['Artist']);
      final genres = getNames(taxonomy['Genre']);
      final format = getNames(taxonomy['Format']);

      final tags = [genres, format].where((t) => t.isNotEmpty).join(', ');

      return MangaDetails(
        title: data['title'] ?? 'Unknown',
        author: authors.isNotEmpty ? authors : 'Unknown',
        artist: artists.isNotEmpty ? artists : 'Unknown',
        status: _toStatus(data['status'] ?? 0),
        description: data['description'] ?? '',
        genre: tags,
        thumbnail: data['cover_image_url'] ?? data['cover_portrait_url'] ?? '',
      );
    } catch (error) {
      throw _buildError('get manga details', error);
    }
  }

  Future<List<Chapter>> getChapterList(String mangaId) async {
    try {
      final response = await _client.get(
        '$apiUrl/v1/chapter/$mangaId/list',
        queryParameters: {'page_size': 3000},
      );

      List<dynamic> chapterList = [];
      final data = response.data;

      if (data is List) {
        chapterList = data;
      } else if (data is Map && data['chapter_list'] is List) {
        chapterList = data['chapter_list'] as List<dynamic>;
      } else if (data is Map && data['data'] is List) {
        chapterList = data['data'] as List<dynamic>;
      }

      if (chapterList.isEmpty) {
        return [];
      }

      return chapterList.map((raw) {
        final item = raw as Map<String, dynamic>;

        int dateUpload = 0;
        final dateStr =
            item['release_date'] ?? item['date'] ?? item['created_at'];
        if (dateStr != null) {
          try {
            dateUpload = DateTime.parse(
              dateStr.toString(),
            ).millisecondsSinceEpoch;
          } catch (_) {
            // Ignore parse errors
          }
        }

        final chapterNum =
            (item['chapter_number'] ?? item['name'] ?? item['number'] ?? '')
                .toString()
                .replaceAll('.0', '');

        final chapterTitle = (item['chapter_title'] ?? item['title'] ?? '')
            .toString();
        final name = chapterTitle.isNotEmpty
            ? 'Chapter $chapterNum - $chapterTitle'
            : 'Chapter $chapterNum';

        final chapterId = item['chapter_id'] ?? item['id'] ?? '';

        return Chapter(
          name: name.trim(),
          dateUpload: dateUpload,
          url: chapterId.toString(),
          chapterUrl: '$baseUrl/series/$mangaId/$chapterId',
        );
      }).toList();
    } catch (error) {
      throw _buildError('get chapter list', error);
    }
  }

  Future<List<Page>> getPageList(String chapterId) async {
    try {
      final response = await _client.get(
        '$apiUrl/v1/chapter/detail/$chapterId',
      );

      final data = response.data;

      List<dynamic> pages = [];
      String base = '';
      String path = '';

      if (data is Map &&
          data['data'] != null &&
          data['data']['chapter'] != null) {
        final chapterData = data['data'] as Map<String, dynamic>;
        base = chapterData['base_url'] ?? chapterData['base_url_low'] ?? '';
        path = chapterData['chapter']['path'] ?? '';
        pages = chapterData['chapter']['data'] ?? [];
      } else if (data is Map &&
          data['page_list'] != null &&
          data['page_list']['chapter_page'] != null) {
        final pageList =
            data['page_list']['chapter_page'] as Map<String, dynamic>;
        base = cdnUrl;
        path = pageList['path'] ?? '';
        pages = pageList['pages'] ?? [];
      } else if (data is Map && data['pages'] != null) {
        pages = data['pages'] as List<dynamic>;
        base = data['base_url'] ?? cdnUrl;
        path = data['path'] ?? '';
      } else if (data is List) {
        final list = data;
        return List<Page>.generate(list.length, (index) {
          final page = list[index];
          String imageUrl;
          if (page is Map) {
            imageUrl = page['image_url'] ?? page['url'] ?? '';
          } else {
            imageUrl = page.toString();
          }
          return Page(index: index, imageUrl: imageUrl);
        });
      }

      if (pages.isEmpty) {
        throw Exception('Invalid response from API - pages not found or empty');
      }

      return List<Page>.generate(pages.length, (index) {
        final page = pages[index].toString();
        return Page(index: index, imageUrl: '$base$path$page');
      });
    } catch (error) {
      throw _buildError('get page list', error);
    }
  }

  Future<Uint8List> downloadImage(String imageUrl) async {
    final response = await Dio().get<List<int>>(
      imageUrl,
      options: Options(
        headers: _getImageHeaders(),
        responseType: ResponseType.bytes,
      ),
    );

    return Uint8List.fromList(response.data ?? []);
  }
}
