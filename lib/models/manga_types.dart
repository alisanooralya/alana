class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String latestChapterDate;
  final String country;

  Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.latestChapterDate = '',
    this.country = '',
  });
}

class MangaListResponse {
  final List<Manga> mangas;
  final bool hasNextPage;

  MangaListResponse({
    required this.mangas,
    required this.hasNextPage,
  });
}

class MangaDetails {
  final String title;
  final String author;
  final String artist;
  final String status;
  final String description;
  final String genre;
  final String thumbnail;

  MangaDetails({
    required this.title,
    required this.author,
    required this.artist,
    required this.status,
    required this.description,
    required this.genre,
    required this.thumbnail,
  });
}

class Chapter {
  final String name;
  final int dateUpload;
  final String url;
  final String chapterUrl;

  Chapter({
    required this.name,
    required this.dateUpload,
    required this.url,
    required this.chapterUrl,
  });
}

class Page {
  final int index;
  final String imageUrl;

  Page({
    required this.index,
    required this.imageUrl,
  });
}
