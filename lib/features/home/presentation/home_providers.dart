import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/home/data/home_repository.dart';
import 'package:alana/models/manga_list_response.dart';

final popularMangaProvider = FutureProvider.autoDispose<MangaListResponse>((
  ref,
) {
  return ref.watch(homeRepositoryProvider).getPopular();
});

final recommendedMangaProvider = FutureProvider.autoDispose<MangaListResponse>((
  ref,
) {
  return ref.watch(homeRepositoryProvider).getRecommended();
});
