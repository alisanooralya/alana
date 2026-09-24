import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/home/data/home_repository.dart';
import 'package:alana/models/manga_list_response.dart';

/// Daftar populer harian (halaman pertama).
final popularMangaProvider = FutureProvider<MangaListResponse>((ref) {
  return ref.watch(homeRepositoryProvider).getPopular();
});

/// Daftar rekomendasi (halaman pertama).
final recommendedMangaProvider = FutureProvider<MangaListResponse>((ref) {
  return ref.watch(homeRepositoryProvider).getRecommended();
});
