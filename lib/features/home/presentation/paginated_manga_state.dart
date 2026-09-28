import 'package:alana/models/manga.dart';

class PaginatedMangaState {
  const PaginatedMangaState({
    this.items = const [],
    this.page = 0,
    this.totalPage = 1,
    this.hasNext = true,
    this.isLoadingMore = false,
    this.pesanErrorMore,
  });

  final List<Manga> items;

  final int page;

  final int totalPage;

  final bool hasNext;
  final bool isLoadingMore;

  final String? pesanErrorMore;

  PaginatedMangaState copyWith({
    List<Manga>? items,
    int? page,
    int? totalPage,
    bool? hasNext,
    bool? isLoadingMore,
    String? Function()? pesanErrorMore,
  }) {
    return PaginatedMangaState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPage: totalPage ?? this.totalPage,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pesanErrorMore: pesanErrorMore != null
          ? pesanErrorMore()
          : this.pesanErrorMore,
    );
  }
}
