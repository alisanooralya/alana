import 'package:alana/models/manga.dart';
import 'package:alana/utils/json_utils.dart';

class MangaListResponse {
  final List<Manga> mangas;
  final bool hasNextPage;

  final int totalPage;

  const MangaListResponse({
    required this.mangas,
    required this.hasNextPage,
    this.totalPage = 1,
  });

  factory MangaListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! List) {
      throw const FormatException('Invalid response from API: data is missing');
    }

    final mangas = rawData
        .whereType<Map<String, dynamic>>()
        .map(Manga.fromJson)
        .toList();

    final meta = json['meta'];
    final currentPage = meta is Map ? asIntOrNull(meta['page']) : null;
    final totalPage = meta is Map ? asIntOrNull(meta['total_page']) : null;
    final hasNextPage =
        currentPage != null && totalPage != null && currentPage < totalPage;

    return MangaListResponse(
      mangas: mangas,
      hasNextPage: hasNextPage,
      totalPage: totalPage != null && totalPage > 0 ? totalPage : 1,
    );
  }
}
