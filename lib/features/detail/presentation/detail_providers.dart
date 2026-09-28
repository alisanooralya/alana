import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import '../data/detail_repository.dart';

class ChapterPageRequest {
  const ChapterPageRequest({required this.mangaId, required this.page});

  final String mangaId;
  final int page;

  @override
  bool operator ==(Object other) {
    return other is ChapterPageRequest &&
        other.mangaId == mangaId &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(mangaId, page);
}

final mangaDetailsProvider = FutureProvider.autoDispose
    .family<MangaDetails, String>((ref, mangaId) {
      return ref.watch(detailRepositoryProvider).getDetails(mangaId);
    });

final chapterListProvider = FutureProvider.autoDispose
    .family<ChapterPage, ChapterPageRequest>((ref, request) {
      return ref
          .watch(detailRepositoryProvider)
          .getChapters(request.mangaId, page: request.page);
    });
