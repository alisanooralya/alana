import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/home/data/home_repository.dart';
import 'package:alana/features/home/data/jelajah_query.dart';
import 'package:alana/features/home/presentation/paginated_manga_state.dart';
import 'package:alana/models/genre.dart';
import 'package:alana/models/manga_list_response.dart';

final genreListProvider = FutureProvider<List<Genre>>((ref) {
  return ref.watch(homeRepositoryProvider).getGenres();
});

final jelajahFilterProvider = StateProvider<JelajahQuery>(
  (ref) => JelajahQuery.defaultQuery,
);

final jelajahPageProvider =
    FutureProvider.family<MangaListResponse, JelajahPageRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(homeRepositoryProvider)
          .explore(query: request.query, page: request.page);
    });

class JelajahController extends AsyncNotifier<PaginatedMangaState> {
  late JelajahQuery _queryAktif;

  @override
  Future<PaginatedMangaState> build() async {
    final query = ref.watch(jelajahFilterProvider);
    _queryAktif = query;
    final response = await ref.watch(
      jelajahPageProvider(JelajahPageRequest(query: query, page: 1)).future,
    );
    return PaginatedMangaState(
      items: response.mangas,
      page: 1,
      hasNext: response.hasNextPage,
    );
  }

  void muatUlang() {
    final query = ref.read(jelajahFilterProvider);
    ref.invalidate(
      jelajahPageProvider(JelajahPageRequest(query: query, page: 1)),
    );
    ref.invalidateSelf();
  }

  Future<void> muatBerikutnya() async {
    final saatIni = state.valueOrNull;
    if (saatIni == null || !saatIni.hasNext || saatIni.isLoadingMore) {
      return;
    }

    final query = _queryAktif;
    final halamanBerikutnya = JelajahPageRequest(
      query: query,
      page: saatIni.page + 1,
    );
    state = AsyncData(
      saatIni.copyWith(isLoadingMore: true, pesanErrorMore: () => null),
    );

    try {
      final response = await ref.read(
        jelajahPageProvider(halamanBerikutnya).future,
      );
      if (ref.read(jelajahFilterProvider) != query) return;
      state = AsyncData(
        saatIni.copyWith(
          items: [...saatIni.items, ...response.mangas],
          page: saatIni.page + 1,
          hasNext: response.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (ref.read(jelajahFilterProvider) != query) return;
      state = AsyncData(
        saatIni.copyWith(
          isLoadingMore: false,
          pesanErrorMore: () =>
              'Gagal memuat halaman berikutnya. ${pesanErrorRamah(error)}',
        ),
      );
    }
  }

  void hapusErrorMore() {
    final saatIni = state.valueOrNull;
    if (saatIni?.pesanErrorMore == null) return;
    state = AsyncData(saatIni!.copyWith(pesanErrorMore: () => null));
  }
}

final jelajahControllerProvider =
    AsyncNotifierProvider<JelajahController, PaginatedMangaState>(() {
      return JelajahController();
    });
