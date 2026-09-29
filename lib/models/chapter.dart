class Chapter {
  final String name;

  final int number;

  final int dateUpload;
  final String url;
  final String chapterUrl;

  const Chapter({
    required this.name,
    this.number = 0,
    required this.dateUpload,
    required this.url,
    required this.chapterUrl,
  });
}

class ChapterPage {
  final List<Chapter> chapters;
  final int totalPage;

  const ChapterPage({required this.chapters, this.totalPage = 1});
}
