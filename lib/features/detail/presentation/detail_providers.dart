import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import '../data/detail_repository.dart';

final mangaDetailsProvider = FutureProvider.autoDispose
    .family<MangaDetails, String>((ref, mangaId) {
      return ref.watch(detailRepositoryProvider).getDetails(mangaId);
    });

final chapterListProvider = FutureProvider.autoDispose
    .family<List<Chapter>, String>((ref, mangaId) {
      return ref.watch(detailRepositoryProvider).getChapters(mangaId);
    });
