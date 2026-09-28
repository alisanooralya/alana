import 'package:alana/models/models.dart';
import 'package:alana/utils/json_utils.dart';

import 'manga_api_client.dart';

String _nomorChapter(String mentah) {
  final nilai = mentah.trim();
  if (nilai.isEmpty) return '';
  final parsed = num.tryParse(nilai);
  if (parsed == null) return nilai;
  if (parsed is int) return parsed.toString();
  return nilai.endsWith('.0') ? nilai.substring(0, nilai.length - 2) : nilai;
}

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

    final chapterNumber = _nomorChapter(
      asString(item['chapter_number'] ?? item['name'] ?? item['number']),
    );
    final chapterTitle = asString(item['chapter_title'] ?? item['title']);
    final chapterId = asString(item['chapter_id'] ?? item['id']);

    final name = chapterTitle.isNotEmpty
        ? 'Chapter $chapterNumber - $chapterTitle'
        : 'Chapter $chapterNumber';

    return Chapter(
      name: name.trim(),
      number: double.tryParse(chapterNumber)?.round() ?? 0,
      dateUpload: dateUpload,
      url: chapterId,
      chapterUrl: '${MangaApiClient.webBaseUrl}/series/$mangaId/$chapterId',
    );
  }).toList();
}

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

  final chapterData = data['data'];
  if (chapterData is Map && chapterData['chapter'] is Map) {
    final chapter = chapterData['chapter'] as Map<String, dynamic>;
    final pages = chapter['data'];
    if (pages is List && pages.isNotEmpty) {
      final base = asString(
        chapterData['base_url'] ?? chapterData['base_url_low'],
        fallback: MangaApiClient.cdnBaseUrl,
      );
      return _buildPages(base, asString(chapter['path']), pages);
    }
  }

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
      Page(
        index: index,
        imageUrl: _gabungUrl(base, path, _pageImageUrl(pages[index])),
      ),
  ];
}

String _gabungUrl(String base, String path, String file) {
  if (file.isEmpty) return '';
  if (file.startsWith('http://') || file.startsWith('https://')) return file;
  if (base.isEmpty) return '';
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path : '/$path';
  return '$b$p$file';
}

String _pageImageUrl(dynamic page) {
  if (page is Map) {
    return asString(page['image_url'] ?? page['url']);
  }
  return page.toString();
}
