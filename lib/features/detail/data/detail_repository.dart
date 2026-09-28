import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/api_providers.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';
import 'package:alana/services/manga_api_service.dart';

class DetailRepository {
  const DetailRepository({required this.service});

  final MangaApiService service;

  Future<MangaDetails> getDetails(String mangaId) {
    return service.getMangaDetails(mangaId);
  }

  Future<ChapterPage> getChapters(String mangaId, {int page = 1}) {
    return service.getChapterList(mangaId, page: page);
  }
}

final detailRepositoryProvider = Provider<DetailRepository>((ref) {
  return DetailRepository(service: ref.watch(mangaApiServiceProvider));
});
