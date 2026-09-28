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
      hasNext: response.hasNextPage,
    );
  }

  Future<void> muatUlang() async {
    ref.invalidateSelf();
  }

  Future<void> muatBerikutnya() async {
    final saatIni = state.valueOrNull;
    if (saatIni == null || !saatIni.hasNext || saatIni.isLoadingMore) {
      return;
    }

    state = AsyncData(
      saatIni.copyWith(isLoadingMore: true, pesanErrorMore: () => null),
    );

    final halamanBerikutnya = saatIni.page + 1;
    try {
      final repository = ref.read(homeRepositoryProvider);
      final response = await repository.getLatestUpdates(
        page: halamanBerikutnya,
      );
      if (state.valueOrNull?.page != saatIni.page) return;
      state = AsyncData(
        saatIni.copyWith(
          items: [...saatIni.items, ...response.mangas],
          page: halamanBerikutnya,
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

final latestUpdatesControllerProvider =
    AsyncNotifierProvider<LatestUpdatesController, PaginatedMangaState>(() {
      return LatestUpdatesController();
    });
