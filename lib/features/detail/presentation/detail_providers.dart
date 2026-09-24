import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import '../data/detail_repository.dart';

/// Info lengkap satu judul berdasarkan ID-nya.
final mangaDetailsProvider = FutureProvider.family<MangaDetails, String>((
  ref,
  mangaId,
) {
  return ref.watch(detailRepositoryProvider).getDetails(mangaId);
});

/// Daftar chapter satu judul berdasarkan ID-nya.
final chapterListProvider = FutureProvider.family<List<Chapter>, String>((
  ref,
  mangaId,
) {
  return ref.watch(detailRepositoryProvider).getChapters(mangaId);
});
