import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/api_providers.dart';
import 'package:alana/models/manga_list_response.dart';
import 'package:alana/services/manga_api_service.dart';

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
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(service: ref.watch(mangaApiServiceProvider));
});
