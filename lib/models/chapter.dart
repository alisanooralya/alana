/// A chapter entry of a manga.
class Chapter {
  final String name;
  final int dateUpload;
  final String url;
  final String chapterUrl;

  const Chapter({
    required this.name,
    required this.dateUpload,
    required this.url,
    required this.chapterUrl,
  });
}
