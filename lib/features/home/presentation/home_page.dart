import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/core/widgets/nomor_halaman.dart';
import 'package:alana/core/widgets/offline_banner.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/notifikasi/presentation/notifikasi_providers.dart';

import 'home_providers.dart';
import 'latest_updates_controller.dart';
import 'widgets/home_section.dart';
import 'widgets/manga_card.dart';
import 'widgets/popular_carousel.dart';
import 'widgets/riwayat_section.dart';
import 'widgets/update_card.dart';

const int _jumlahRekomendasi = 6;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _muatUlangSemua() async {
    ref
      ..invalidate(popularMangaProvider)
      ..invalidate(recommendedMangaProvider)
      ..invalidate(latestUpdatesControllerProvider);
    await Future.wait([
      ref.read(popularMangaProvider.future),
      ref.read(recommendedMangaProvider.future),
      ref.read(latestUpdatesControllerProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(latestUpdatesControllerProvider, (previous, next) {
      final pesan = next.valueOrNull?.pesanErrorMore;
      if (pesan != null && pesan.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(pesan)));
        ref.read(latestUpdatesControllerProvider.notifier).hapusErrorMore();
      }
    });

    final populer = ref.watch(popularMangaProvider);
    final rekomendasi = ref.watch(recommendedMangaProvider);
    final terbaru = ref.watch(latestUpdatesControllerProvider);
    final belumDibaca = ref.watch(belumDibacaProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Beranda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Jelajahi genre',
            icon: const Icon(Icons.explore_outlined),
            onPressed: () => context.pushNamed('jelajah'),
          ),
          IconButton(
            tooltip: 'Cari judul',
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed('pencarian'),
          ),
          IconButton(
            tooltip: 'Notifikasi',
            icon: Badge(
              isLabelVisible: belumDibaca > 0,
              label: Text(belumDibaca > 99 ? '99+' : '$belumDibaca'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              context.pushNamed('notifikasi');
              ref.invalidate(belumDibacaProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muatUlangSemua,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: populer.when(
                      loading: () =>
                          const _SectionMemuat(judul: 'Populer Hari Ini'),
                      error: (error, _) => _SectionGagal(
                        judul: 'Populer Hari Ini',
                        pesan: pesanErrorRamah(error),
                        onRetry: () => ref.invalidate(popularMangaProvider),
                      ),
                      data: (response) {
                        if (response.mangas.isEmpty) {
                          return const _SectionKosong(
                            judul: 'Populer Hari Ini',
                          );
                        }
                        return PopularCarousel(
                          mangas: response.mangas,
                          judul: 'Populer Hari Ini',
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: RiwayatSection()),
                  const SliverToBoxAdapter(
                    child: KepalaSection(judul: 'Pembaruan Terbaru'),
                  ),
                  terbaru.when(
                    loading: () =>
                        const SliverToBoxAdapter(child: LoadingSpinner()),
                    error: (error, _) => SliverToBoxAdapter(
                      child: ErrorView(
                        pesan: pesanErrorRamah(error),
                        onRetry: () =>
                            ref.invalidate(latestUpdatesControllerProvider),
                      ),
                    ),
                    data: (halaman) {
                      if (halaman.items.isEmpty) {
                        return SliverToBoxAdapter(
                          child: EmptyView(
                            judul: 'Belum ada pembaruan',
                            deskripsi: 'Coba lagi nanti atau tarik untuk memuat ulang.',
                            labelAksi: 'Muat ulang',
                            onAksi: () =>
                                ref.invalidate(latestUpdatesControllerProvider),
                          ),
                        );
                      }

                      final tinggi = hitungTinggiSel(
                        MediaQuery.sizeOf(context).width,
                      );

                      return SliverMainAxisGroup(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: paddingHorizontalUpdate,
                            ),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 18,
                                    crossAxisSpacing: jarakAntarSelUpdate,
                                    mainAxisExtent: tinggi,
                                  ),
                              itemCount: halaman.items.length,
                              itemBuilder: (context, index) =>
                                  UpdateCard(manga: halaman.items[index]),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                              child: NomorHalaman(
                                halaman: halaman.page,
                                totalHalaman: halaman.totalPage,
                                sedangMemuat: halaman.isLoadingMore,
                                onPilih: ref
                                    .read(
                                      latestUpdatesControllerProvider.notifier,
                                    )
                                    .pindahHalaman,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: rekomendasi.when(
                      loading: () => const _SectionMemuat(judul: 'Rekomendasi'),
                      error: (error, _) => _SectionGagal(
                        judul: 'Rekomendasi',
                        pesan: pesanErrorRamah(error),
                        onRetry: () => ref.invalidate(recommendedMangaProvider),
                      ),
                      data: (response) {
                        if (response.mangas.isEmpty) {
                          return const _SectionKosong(judul: 'Rekomendasi');
                        }
                        return HomeSection(
                          judul: 'Rekomendasi',
                          children: [
                            for (final manga in response.mangas.take(
                              _jumlahRekomendasi,
                            ))
                              MangaCard(manga: manga),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionMemuat extends StatelessWidget {
  const _SectionMemuat({required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KepalaSection(judul: judul),
        const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _SectionGagal extends StatelessWidget {
  const _SectionGagal({
    required this.judul,
    required this.pesan,
    required this.onRetry,
  });

  final String judul;
  final String pesan;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KepalaSection(judul: judul),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(child: Text(pesan)),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionKosong extends StatelessWidget {
  const _SectionKosong({required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KepalaSection(judul: judul),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Belum ada data.'),
        ),
      ],
    );
  }
}
