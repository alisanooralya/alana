class Manga {
  final String title;
  final String thumbnail;
  final String url;
  final String latestChapterDate;
  final String latestChapterNumber;
  final String country;
  final int viewCount;
  final num rating;
  final List<Map<String, dynamic>>? chapters;

  Manga({
    required this.title,
    required this.thumbnail,
    required this.url,
    this.latestChapterDate = '',
    this.latestChapterNumber = 0,
    this.country = '',
    this.viewCount = 0,
    this.rating = 0,
    this.chapters,
  });

  Manga copyWith({
    String? title,
    String? thumbnail,
    String? url,
    String? latestChapterDate,
    int? latestChapterNumber,
    String? country,
    int? viewCount,
    num? rating,
    List<Map<String, dynamic>>? chapters,
  }) {
    return Manga(
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      url: url ?? this.url,
      latestChapterDate: latestChapterDate ?? this.latestChapterDate,
      latestChapterNumber: latestChapterNumber ?? this.latestChapterNumber,
      country: country ?? this.country,
      viewCount: viewCount ?? this.viewCount,
      rating: rating ?? this.rating,
      chapters: chapters ?? this.chapters,
    );
  }
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
