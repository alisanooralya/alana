import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/providers/api_providers.dart';
import 'package:alana/models/page.dart' as manga;
import 'package:alana/services/manga_api_client.dart';
import 'package:alana/services/manga_api_service.dart';

/// Header HTTP untuk mengunduh gambar halaman dari CDN.
///
/// CDN (`storage.shngm.id`) memeriksa `Referer` seperti browser.
/// Disalurkan ke `CachedNetworkImage(httpHeaders: ...)` dan `precacheImage`.
const readerImageHeaders = <String, String>{
  'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  'Referer': '${MangaApiClient.webBaseUrl}/',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
};

/// Repository halaman reader. Membungkus [MangaApiService]
/// yang sudah ada; widget tidak memanggil service langsung.
class ReaderRepository {
  const ReaderRepository({required this.service});

  final MangaApiService service;

  Future<List<manga.Page>> getPages(String chapterId) {
    return service.getPageList(chapterId);
  }
}

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ReaderRepository(service: ref.watch(mangaApiServiceProvider));
});
