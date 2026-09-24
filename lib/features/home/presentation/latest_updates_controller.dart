import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/home/data/home_repository.dart';

import 'paginated_manga_state.dart';

/// Controller paginasi untuk daftar pembaruan terbaru.
///
/// Halaman pertama dimuat otomatis. [muatBerikutnya] menambah halaman
/// berikutnya tanpa menghapus daftar yang sudah tampil.
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

  /// Memuat ulang dari halaman pertama.
  Future<void> muatUlang() async {
    ref.invalidateSelf();
  }

  /// Memuat halaman berikutnya. Aman dipanggil berulang:
  /// diabaikan bila sedang memuat atau sudah habis.
  Future<void> muatBerikutnya() async {
    final saatIni = state.valueOrNull;
    if (saatIni == null || !saatIni.hasNext || saatIni.isLoadingMore) {
      return;
    }

    state = AsyncData(
      saatIni.copyWith(isLoadingMore: true, pesanErrorMore: () => null),
    );

    try {
      final repository = ref.read(homeRepositoryProvider);
      final response = await repository.getLatestUpdates(
        page: saatIni.page + 1,
      );
      state = AsyncData(
        saatIni.copyWith(
          items: [...saatIni.items, ...response.mangas],
          page: saatIni.page + 1,
          hasNext: response.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      state = AsyncData(
        saatIni.copyWith(
          isLoadingMore: false,
          pesanErrorMore: () => 'Gagal memuat halaman berikutnya: $error',
        ),
      );
    }
  }

  /// Menghapus pesan kesalahan halaman berikutnya setelah ditampilkan.
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
