import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/api_providers.dart';
import 'package:alana/models/genre.dart';
import 'package:alana/models/manga_list_response.dart';
import 'package:alana/services/manga_api_service.dart';

import 'jelajah_query.dart';

/// Repository Beranda. Membungkus [MangaApiService] yang sudah ada
/// agar widget tidak memanggil service secara langsung.
class HomeRepository {
  const HomeRepository({required this.service});

  final MangaApiService service;

  Future<MangaListResponse> getPopular({int page = 1}) {
    return service.getPopularManga(page: page);
  }

  Future<MangaListResponse> getLatestUpdates({int page = 1}) {
    return service.getLatestUpdates(page: page);
  }

  Future<MangaListResponse> getRecommended({int page = 1}) {
    return service.getRecommendedManga(page: page);
  }

  Future<MangaListResponse> search(String query, {int page = 1}) {
    return service.searchManga(query, page: page);
  }

  Future<List<Genre>> getGenres() {
    return service.getGenreList();
  }

  Future<MangaListResponse> explore({
    required JelajahQuery query,
    int page = 1,
  }) {
    return service.listManga(
      page: page,
      genreSlugs: query.genreSlugs,
      status: query.status,
      sort: query.sort,
    );
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(service: ref.watch(mangaApiServiceProvider));
});
