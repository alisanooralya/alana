import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import '../data/detail_repository.dart';

/// Info lengkap satu judul berdasarkan ID-nya.
///
/// autoDispose: tanpa itu setiap judul yang pernah dibuka beserta daftar
/// chapter penuhnya (sampai ribuan objek Chapter) tetap hidup sampai proses
/// ditutup.
final mangaDetailsProvider =
    FutureProvider.autoDispose.family<MangaDetails, String>((ref, mangaId) {
      return ref.watch(detailRepositoryProvider).getDetails(mangaId);
    });

/// Daftar chapter satu judul berdasarkan ID-nya.
final chapterListProvider =
    FutureProvider.autoDispose.family<List<Chapter>, String>((ref, mangaId) {
      return ref.watch(detailRepositoryProvider).getChapters(mangaId);
    });
