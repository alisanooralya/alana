import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/core/widgets/offline_banner.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/home/data/jelajah_query.dart';
import 'package:alana/models/genre.dart';
import 'package:alana/services/manga_api_service.dart';

import 'jelajah_providers.dart';
import 'widgets/manga_card.dart';

class JelajahPage extends ConsumerStatefulWidget {
  const JelajahPage({super.key});

  @override
  ConsumerState<JelajahPage> createState() => _JelajahPageState();
}

class _JelajahPageState extends ConsumerState<JelajahPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      unawaited(ref.read(jelajahControllerProvider.notifier).muatBerikutnya());
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    if (_tabController.index == 0) {
      final query = ref.read(jelajahFilterProvider);
      if (query.genreSlugs.isNotEmpty) {
        ref.read(jelajahFilterProvider.notifier).state = query.copyWith(
          genreSlugs: const [],
        );
      }
    }
  }

  Future<void> _openFilters(JelajahQuery query, List<Genre> genres) async {
    final result = await showModalBottomSheet<JelajahQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(current: query, genres: genres),
    );
    if (!mounted || result == null) return;
    ref.read(jelajahFilterProvider.notifier).state = result;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(jelajahControllerProvider, (previous, next) {
      final pesan = next.valueOrNull?.pesanErrorMore;
      if (pesan != null && pesan.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(pesan)));
        ref.read(jelajahControllerProvider.notifier).hapusErrorMore();
      }
    });

    final query = ref.watch(jelajahFilterProvider);
    final genres = ref.watch(genreListProvider).valueOrNull ?? const <Genre>[];
    final selectedGenreNames = genres
        .where((genre) => query.genreSlugs.contains(genre.slug))
        .map((genre) => genre.name)
        .toList();
    final title = _tabController.index == 1 && selectedGenreNames.isNotEmpty
        ? 'Genre: ${selectedGenreNames.join(', ')}'
        : 'Jelajah';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Badge(
            isLabelVisible: query.activeFilterCount > 0,
            label: Text('${query.activeFilterCount}'),
            child: IconButton(
              tooltip: 'Filter dan sort',
              icon: const Icon(Icons.tune),
              onPressed: () => _openFilters(query, genres),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Genre'),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(jelajahControllerProvider.notifier).muatUlang();
              },
              child: _JelajahResults(
                scrollController: _scrollController,
                genreMode: _tabController.index == 1,
                genres: genres,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JelajahResults extends ConsumerWidget {
  const _JelajahResults({
    required this.scrollController,
    required this.genreMode,
    required this.genres,
  });

  final ScrollController scrollController;
  final bool genreMode;
  final List<Genre> genres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasil = ref.watch(jelajahControllerProvider);

    return hasil.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        pesan: pesanErrorRamah(error),
        onRetry: () => ref.read(jelajahControllerProvider.notifier).muatUlang(),
      ),
      data: (halaman) {
        if (halaman.items.isEmpty) {
          return const EmptyView(
            judul: 'Tidak ada hasil untuk filter ini',
            deskripsi: 'Coba ubah genre, status, atau urutan hasil.',
            ikon: Icons.search_off_outlined,
          );
        }

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            if (genreMode)
              SliverToBoxAdapter(child: _GenreSelector(genres: genres)),
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
                          .read(jelajahControllerProvider.notifier)
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

class _GenreSelector extends ConsumerWidget {
  const _GenreSelector({required this.genres});

  final List<Genre> genres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (genres.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('Genre belum tersedia.'),
      );
    }

    final selected = ref.watch(jelajahFilterProvider).genreSlugs;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          return ChoiceChip(
            label: Text(genre.name),
            selected: selected.contains(genre.slug),
            onSelected: (_) {
              final query = ref.read(jelajahFilterProvider);
              ref.read(jelajahFilterProvider.notifier).state = query.copyWith(
                genreSlugs: [genre.slug],
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.genres});

  final JelajahQuery current;
  final List<Genre> genres;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MangaStatusFilter _status;
  late MangaSort _sort;
  late Set<String> _genres;

  @override
  void initState() {
    super.initState();
    _status = widget.current.status;
    _sort = widget.current.sort;
    _genres = widget.current.genreSlugs.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (_status) {
      MangaStatusFilter.all => 'Semua',
      MangaStatusFilter.ongoing => 'Ongoing',
      MangaStatusFilter.completed => 'Completed',
    };

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filter dan urutan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text('Status', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in MangaStatusFilter.values)
                    ChoiceChip(
                      label: Text(switch (value) {
                        MangaStatusFilter.all => 'Semua',
                        MangaStatusFilter.ongoing => 'Ongoing',
                        MangaStatusFilter.completed => 'Completed',
                      }),
                      selected: _status == value,
                      onSelected: (_) => setState(() => _status = value),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Genre', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (widget.genres.isEmpty)
                const Text('Daftar genre belum tersedia.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final genre in widget.genres)
                      FilterChip(
                        label: Text(genre.name),
                        selected: _genres.contains(genre.slug),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _genres.add(genre.slug);
                            } else {
                              _genres.remove(genre.slug);
                            }
                          });
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              Text('Urutkan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final value in MangaSort.values)
                    ChoiceChip(
                      label: Text(switch (value) {
                        MangaSort.latest => 'Terbaru update',
                        MangaSort.popular => 'Terpopuler',
                        MangaSort.rating => 'Rating tertinggi',
                        MangaSort.title => 'A-Z',
                      }),
                      selected: _sort == value,
                      onSelected: (_) => setState(() => _sort = value),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _status = MangaStatusFilter.all;
                        _sort = MangaSort.latest;
                        _genres.clear();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        JelajahQuery(
                          genreSlugs: _genres,
                          status: _status,
                          sort: _sort,
                        ),
                      );
                    },
                    child: Text('Terapkan ($statusLabel)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
