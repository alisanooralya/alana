import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/home/data/home_repository.dart';
import 'package:alana/models/manga_list_response.dart';

/// Daftar populer harian (halaman pertama).
///
/// Pagination penuh dan pencarian dikerjakan di Fase 2.
final popularMangaProvider = FutureProvider<MangaListResponse>((ref) {
  return ref.watch(homeRepositoryProvider).getPopular();
});

/// Daftar pembaruan terbaru (halaman pertama).
final latestUpdatesProvider = FutureProvider<MangaListResponse>((ref) {
  return ref.watch(homeRepositoryProvider).getLatestUpdates();
});

/// Daftar rekomendasi (halaman pertama).
final recommendedMangaProvider = FutureProvider<MangaListResponse>((ref) {
  return ref.watch(homeRepositoryProvider).getRecommended();
});
