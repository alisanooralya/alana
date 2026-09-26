import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/home/data/home_repository.dart';

import 'paginated_manga_state.dart';

/// Kata kunci pencarian saat ini. Kosong = belum mencari.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Controller hasil pencarian dengan paginasi.
///
/// Otomatis memuat ulang setiap [searchQueryProvider] berubah.
/// Query kosong tidak memanggil API dan langsung mengembalikan
/// daftar kosong.
class SearchResultsController extends AsyncNotifier<PaginatedMangaState> {
  @override
  Future<PaginatedMangaState> build() async {
    final query = ref.watch(searchQueryProvider);
    if (query.isEmpty) {
      return const PaginatedMangaState(hasNext: false);
    }

    final repository = ref.watch(homeRepositoryProvider);
    final response = await repository.search(query, page: 1);
    return PaginatedMangaState(
      items: response.mangas,
      page: 1,
      hasNext: response.hasNextPage,
    );
  }

  Future<void> muatBerikutnya() async {
    final saatIni = state.valueOrNull;
    if (saatIni == null || !saatIni.hasNext || saatIni.isLoadingMore) {
      return;
    }

    // Query harus dibaca SEBELUM await dan dicek ulang sesudahnya. Kalau
    // dibaca sesudah await, permintaan page-2 memakai query yang sudah
    // diganti dan hasilnya ditumpuk ke daftar query lama.
    final query = ref.read(searchQueryProvider);
    final halamanBerikutnya = saatIni.page + 1;
    state = AsyncData(
      saatIni.copyWith(isLoadingMore: true, pesanErrorMore: () => null),
    );

    try {
      final repository = ref.read(homeRepositoryProvider);
      final response = await repository.search(query, page: halamanBerikutnya);
      if (ref.read(searchQueryProvider) != query) return;
      state = AsyncData(
        saatIni.copyWith(
          items: [...saatIni.items, ...response.mangas],
          page: halamanBerikutnya,
          hasNext: response.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (ref.read(searchQueryProvider) != query) return;
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

final searchResultsControllerProvider =
    AsyncNotifierProvider<SearchResultsController, PaginatedMangaState>(() {
      return SearchResultsController();
    });
