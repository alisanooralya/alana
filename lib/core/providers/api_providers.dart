import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/services/manga_api_client.dart';
import 'package:alana/services/manga_api_service.dart';

final mangaApiClientProvider = Provider<MangaApiClient>((ref) {
  return MangaApiClient();
});

final mangaApiServiceProvider = Provider<MangaApiService>((ref) {
  return MangaApiService(client: ref.watch(mangaApiClientProvider));
});
