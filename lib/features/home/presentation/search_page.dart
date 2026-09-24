import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/core/widgets/offline_banner.dart';
import 'package:alana/core/utils/pesan_error.dart';

import 'paginated_manga_state.dart';
import 'search_controller.dart';
import 'widgets/manga_card.dart';

/// Halaman pencarian judul.
///
/// Fase 2: pencarian teks dengan debounce 500ms + infinite scroll.
/// Filter genre/format/status menyusul setelah Fase 3.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = _textController.text
          .trim();
    });
    setState(() {});
  }

  void _bersihkan() {
    _debounce?.cancel();
    _textController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(searchResultsControllerProvider.notifier).muatBerikutnya();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final hasil = ref.watch(searchResultsControllerProvider);

    ref.listen(searchResultsControllerProvider, (previous, next) {
      final pesan = next.valueOrNull?.pesanErrorMore;
      if (pesan != null && pesan.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(pesan)));
        ref.read(searchResultsControllerProvider.notifier).hapusErrorMore();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Cari Judul')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              controller: _textController,
              hintText: 'Ketik judul manhwa…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_textController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Bersihkan',
                    icon: const Icon(Icons.clear),
                    onPressed: _bersihkan,
                  ),
              ],
            ),
          ),
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(searchResultsControllerProvider);
              },
              child: _HasilPencarian(
                query: query,
                hasil: hasil,
                scrollController: _scrollController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HasilPencarian extends ConsumerWidget {
  const _HasilPencarian({
    required this.query,
    required this.hasil,
    required this.scrollController,
  });

  final String query;
  final AsyncValue<PaginatedMangaState> hasil;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const EmptyView(
        judul: 'Cari judul favoritmu',
        deskripsi: 'Ketik minimal satu kata untuk mulai mencari.',
        ikon: Icons.search_outlined,
      );
    }

    return hasil.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        pesan: pesanErrorRamah(error),
        onRetry: () => ref.invalidate(searchResultsControllerProvider),
      ),
      data: (halaman) {
        if (halaman.items.isEmpty) {
          return EmptyView(
            judul: 'Tidak ditemukan',
            deskripsi: 'Coba kata kunci lain untuk "$query".',
          );
        }
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.52,
                ),
                itemCount: halaman.items.length,
                itemBuilder: (context, index) {
                  return MangaCard(
                    manga: halaman.items[index],
                    width: double.infinity,
                  );
                },
              ),
            ),
            if (halaman.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (halaman.hasNext)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(searchResultsControllerProvider.notifier)
                          .muatBerikutnya(),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Muat lebih banyak'),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Semua hasil sudah ditampilkan.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
