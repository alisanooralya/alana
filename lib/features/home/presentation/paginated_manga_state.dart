import 'package:alana/models/manga.dart';

/// Status daftar paginasi untuk Beranda dan Pencarian.
///
/// dipakai oleh controller berbasis [AsyncNotifier] agar UI bisa
/// menampilkan daftar yang sudah ada sambil memuat halaman berikutnya.
class PaginatedMangaState {
  const PaginatedMangaState({
    this.items = const [],
    this.page = 0,
    this.hasNext = true,
    this.isLoadingMore = false,
    this.pesanErrorMore,
  });

  /// Item yang sudah terkumpul dari halaman 1..[page].
  final List<Manga> items;

  /// Halaman terakhir yang berhasil dimuat (0 = belum ada).
  final int page;

  /// `false` bila API menyatakan tidak ada halaman berikutnya.
  final bool hasNext;

  /// `true` saat halaman berikutnya sedang dimuat.
  final bool isLoadingMore;

  /// Pesan kesalahan pemuatan halaman berikutnya, bila ada.
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
