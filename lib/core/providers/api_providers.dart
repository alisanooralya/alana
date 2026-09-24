import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/services/manga_api_client.dart';
import 'package:alana/services/manga_api_service.dart';

/// Instance HTTP dasar. Satu instance dipakai ulang oleh [mangaApiServiceProvider].
final mangaApiClientProvider = Provider<MangaApiClient>((ref) {
  return MangaApiClient();
});

/// Akses tingkat tinggi ke REST API. Repository di tiap fitur
/// membungkus provider ini, bukan memanggil Dio langsung.
final mangaApiServiceProvider = Provider<MangaApiService>((ref) {
  return MangaApiService(client: ref.watch(mangaApiClientProvider));
});
