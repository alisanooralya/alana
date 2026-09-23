import 'package:alana/models/models.dart';
import 'package:alana/utils/json_utils.dart';

import 'manga_api_client.dart';

/// Parses the many response shapes of the chapter list endpoint into
/// [Chapter] models.
List<Chapter> parseChapterList(dynamic data, {required String mangaId}) {
  final List<dynamic> rawChapters;
  if (data is List) {
    rawChapters = data;
  } else if (data is Map && data['chapter_list'] is List) {
    rawChapters = data['chapter_list'] as List<dynamic>;
  } else if (data is Map && data['data'] is List) {
    rawChapters = data['data'] as List<dynamic>;
  } else {
    return const [];
  }

  return rawChapters.whereType<Map<String, dynamic>>().map((item) {
    var dateUpload = 0;
    final dateValue =
        item['release_date'] ?? item['date'] ?? item['created_at'];
    if (dateValue != null) {
      try {
        dateUpload = DateTime.parse(dateValue.toString())
            .millisecondsSinceEpoch;
      } on FormatException {
        // Keep the default upload date when the value cannot be parsed.
      }
    }

    final chapterNumber = asString(
      item['chapter_number'] ?? item['name'] ?? item['number'],
    ).replaceAll('.0', '');
    final chapterTitle = asString(item['chapter_title'] ?? item['title']);
    final chapterId = asString(item['chapter_id'] ?? item['id']);

    final name = chapterTitle.isNotEmpty
        ? 'Chapter $chapterNumber - $chapterTitle'
        : 'Chapter $chapterNumber';

    return Chapter(
      name: name.trim(),
      dateUpload: dateUpload,
      url: chapterId,
      chapterUrl: '${MangaApiClient.webBaseUrl}/series/$mangaId/$chapterId',
    );
  }).toList();
}

/// Parses the many response shapes of the chapter detail endpoint into
/// [Page] models.
List<Page> parsePageList(dynamic data) {
  if (data is List) {
    return [
      for (var index = 0; index < data.length; index++)
        Page(index: index, imageUrl: _pageImageUrl(data[index])),
    ];
  }

  if (data is! Map) {
    throw const FormatException(
      'Invalid response from API - pages not found or empty',
    );
  }

  // Shape 1: {"data": {"base_url": ..., "chapter": {"path": ..., "data": [...]}}}
  final chapterData = data['data'];
  if (chapterData is Map && chapterData['chapter'] is Map) {
    final chapter = chapterData['chapter'] as Map<String, dynamic>;
    final pages = chapter['data'];
    if (pages is List && pages.isNotEmpty) {
      final base = asString(
        chapterData['base_url'] ?? chapterData['base_url_low'],
      );
      return _buildPages(base, asString(chapter['path']), pages);
    }
  }

  // Shape 2: {"page_list": {"chapter_page": {"path": ..., "pages": [...]}}}
  final pageList = data['page_list'];
  if (pageList is Map && pageList['chapter_page'] is Map) {
    final chapterPage = pageList['chapter_page'] as Map<String, dynamic>;
    final pages = chapterPage['pages'];
    if (pages is List && pages.isNotEmpty) {
      return _buildPages(
        MangaApiClient.cdnBaseUrl,
        asString(chapterPage['path']),
        pages,
      );
    }
  }

  // Shape 3: {"pages": [...], "base_url": ..., "path": ...}
  final pages = data['pages'];
  if (pages is List && pages.isNotEmpty) {
    final base = asString(
      data['base_url'],
      fallback: MangaApiClient.cdnBaseUrl,
    );
    return _buildPages(base, asString(data['path']), pages);
  }

  throw const FormatException(
    'Invalid response from API - pages not found or empty',
  );
}

List<Page> _buildPages(String base, String path, List<dynamic> pages) {
  return [
    for (var index = 0; index < pages.length; index++)
      Page(index: index, imageUrl: '$base$path${pages[index]}'),
  ];
}

String _pageImageUrl(dynamic page) {
  if (page is Map) {
    return asString(page['image_url'] ?? page['url']);
  }
  return page.toString();
}
