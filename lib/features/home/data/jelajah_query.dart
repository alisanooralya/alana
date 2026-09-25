import 'package:alana/services/manga_api_service.dart';

class JelajahQuery {
  JelajahQuery({
    Iterable<String> genreSlugs = const [],
    this.status = MangaStatusFilter.all,
    this.sort = MangaSort.latest,
  }) : genreSlugs = List.unmodifiable(genreSlugs.toSet().toList()..sort());

  const JelajahQuery._()
    : genreSlugs = const [],
      status = MangaStatusFilter.all,
      sort = MangaSort.latest;

  static const defaultQuery = JelajahQuery._();

  final List<String> genreSlugs;
  final MangaStatusFilter status;
  final MangaSort sort;

  bool get hasFilters =>
      genreSlugs.isNotEmpty ||
      status != MangaStatusFilter.all ||
      sort != MangaSort.latest;

  int get activeFilterCount =>
      genreSlugs.length +
      (status == MangaStatusFilter.all ? 0 : 1) +
      (sort == MangaSort.latest ? 0 : 1);

  JelajahQuery copyWith({
    Iterable<String>? genreSlugs,
    MangaStatusFilter? status,
    MangaSort? sort,
  }) {
    return JelajahQuery(
      genreSlugs: genreSlugs ?? this.genreSlugs,
      status: status ?? this.status,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JelajahQuery &&
        other.status == status &&
        other.sort == sort &&
        _sameList(other.genreSlugs, genreSlugs);
  }

  @override
  int get hashCode => Object.hash(status, sort, Object.hashAll(genreSlugs));
}

class JelajahPageRequest {
  JelajahPageRequest({required this.query, required this.page});

  final JelajahQuery query;
  final int page;

  @override
  bool operator ==(Object other) {
    return other is JelajahPageRequest &&
        other.query == query &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(query, page);
}

bool _sameList(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
