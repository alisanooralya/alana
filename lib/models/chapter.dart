class Chapter {
  final String name;

  /// Nomor chapter hasil parsing `chapter_number`. 0 kalau tidak berupa angka
  /// (misalnya "Extra"). Dipakai untuk mencari di halaman mana sebuah chapter
  /// berada tanpa harus memuat seluruh daftar.
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
