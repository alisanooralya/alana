import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/home/data/home_repository.dart';
import 'package:alana/models/manga_list_response.dart';

/// Daftar populer harian (halaman pertama).
///
/// autoDispose: tanpa itu nilai ini tertahan selama proses dan "Populer
/// Hari Ini" selalu menampilkan apa yang server kirim saat aplikasi dibuka,
/// berapa pun jam aplikasi sudah berjalan.
final popularMangaProvider = FutureProvider.autoDispose<MangaListResponse>((
  ref,
) {
  return ref.watch(homeRepositoryProvider).getPopular();
});

/// Daftar rekomendasi (halaman pertama).
final recommendedMangaProvider = FutureProvider.autoDispose<MangaListResponse>((
  ref,
) {
  return ref.watch(homeRepositoryProvider).getRecommended();
});
