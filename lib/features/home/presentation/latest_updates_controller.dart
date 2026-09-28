import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/home/data/home_repository.dart';

import 'paginated_manga_state.dart';

class LatestUpdatesController extends AsyncNotifier<PaginatedMangaState> {
  @override
  Future<PaginatedMangaState> build() async {
    final repository = ref.watch(homeRepositoryProvider);
    final response = await repository.getLatestUpdates(page: 1);
    return PaginatedMangaState(
      items: response.mangas,
      page: 1,
      totalPage: response.totalPage,
      hasNext: response.hasNextPage,
    );
  }

  Future<void> muatUlang() async {
    ref.invalidateSelf();
  }

  Future<void> pindahHalaman(int halaman) async {
    final saatIni = state.valueOrNull;
    if (saatIni == null || halaman < 1) return;
    if (halaman == saatIni.page) return;
    if (halaman > saatIni.totalPage) return;
    if (saatIni.isLoadingMore) return;

    state = AsyncData(
      saatIni.copyWith(isLoadingMore: true, pesanErrorMore: () => null),
    );

    try {
      final response = await ref
          .read(homeRepositoryProvider)
          .getLatestUpdates(page: halaman);
      if (state.valueOrNull?.page != saatIni.page) return;
      state = AsyncData(
        saatIni.copyWith(
          items: response.mangas,
          page: halaman,
          totalPage: response.totalPage,
          hasNext: response.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (state.valueOrNull?.page != saatIni.page) return;
      state = AsyncData(
        saatIni.copyWith(
          isLoadingMore: false,
          pesanErrorMore: () =>
              'Gagal memuat halaman $halaman. ${pesanErrorRamah(error)}',
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

final latestUpdatesControllerProvider =
    AsyncNotifierProvider<LatestUpdatesController, PaginatedMangaState>(() {
      return LatestUpdatesController();
    });
