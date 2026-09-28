import 'package:alana/models/manga.dart';

class PaginatedMangaState {
  const PaginatedMangaState({
    this.items = const [],
    this.page = 0,
    this.hasNext = true,
    this.isLoadingMore = false,
    this.pesanErrorMore,
  });

  final List<Manga> items;

  final int page;

  final bool hasNext;
  final bool isLoadingMore;

  final String? pesanErrorMore;

  PaginatedMangaState copyWith({
    List<Manga>? items,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
    String? Function()? pesanErrorMore,
  }) {
    return PaginatedMangaState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pesanErrorMore: pesanErrorMore != null
          ? pesanErrorMore()
          : this.pesanErrorMore,
    );
  }
}
