import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/api_providers.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';
import 'package:alana/services/manga_api_service.dart';

/// Repository halaman detail. Membungkus [MangaApiService]
/// yang sudah ada; widget tidak memanggil service langsung.
class DetailRepository {
  const DetailRepository({required this.service});

  final MangaApiService service;

  Future<MangaDetails> getDetails(String mangaId) {
    return service.getMangaDetails(mangaId);
  }

  Future<List<Chapter>> getChapters(String mangaId) {
    return service.getChapterList(mangaId);
  }
}

final detailRepositoryProvider = Provider<DetailRepository>((ref) {
  return DetailRepository(service: ref.watch(mangaApiServiceProvider));
});
