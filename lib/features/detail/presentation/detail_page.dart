import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/core/widgets/offline_banner.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/library/data/bookmarked_manga.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import 'detail_providers.dart';

/// Halaman detail satu judul.
///
/// Menampilkan cover besar, sinopsis expandable, genre sebagai chip,
/// status/rating, tombol baca + bookmark, dan daftar chapter yang
/// bisa diurutkan terbaru/terlama.
class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, required this.mangaId});

  /// ID judul (nilai `Manga.url` dari daftar).
  final String mangaId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  bool _sinopsisPenuh = false;
  bool _terbaruDulu = true;

  void _toggleBookmark(MangaDetails detail) {
    final ditandai = ref
        .read(bookmarkRepositoryProvider.notifier)
        .toggle(
          BookmarkedManga(
            mangaId: widget.mangaId,
            title: detail.title,
            thumbnail: detail.thumbnail,
            savedAt: DateTime.now(),
          ),
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ditandai ? 'Ditambahkan ke Pustaka.' : 'Dihapus dari Pustaka.',
          ),
        ),
      );
  }

  void _bukaChapter(BuildContext context, MangaDetails info, Chapter chapter) {
    context.pushNamed(
      'reader',
      pathParameters: {'mangaId': widget.mangaId, 'chapterId': chapter.url},
      extra: {
        'chapterName': chapter.name,
        'mangaTitle': info.title,
        'mangaThumbnail': info.thumbnail,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mangaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: ErrorView(
          pesan: 'ID judul tidak valid.',
          onRetry: () => Navigator.of(context).pop(),
        ),
      );
    }

    final detail = ref.watch(mangaDetailsProvider(widget.mangaId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          pesan: pesanErrorRamah(error),
          onRetry: () => ref.invalidate(mangaDetailsProvider(widget.mangaId)),
        ),
        data: (info) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(mangaDetailsProvider(widget.mangaId))
              ..invalidate(chapterListProvider(widget.mangaId));
          },
          child: _IsiDetail(
            mangaId: widget.mangaId,
            info: info,
            sinopsisPenuh: _sinopsisPenuh,
            terbaruDulu: _terbaruDulu,
            onToggleSinopsis: () {
              setState(() => _sinopsisPenuh = !_sinopsisPenuh);
            },
            onToggleUrut: () {
              setState(() => _terbaruDulu = !_terbaruDulu);
            },
            onToggleBookmark: () => _toggleBookmark(info),
            onBukaChapter: (chapter) => _bukaChapter(context, info, chapter),
          ),
        ),
      ),
    );
  }
}

class _IsiDetail extends ConsumerWidget {
  const _IsiDetail({
    required this.mangaId,
    required this.info,
    required this.sinopsisPenuh,
    required this.terbaruDulu,
    required this.onToggleSinopsis,
    required this.onToggleUrut,
    required this.onToggleBookmark,
    required this.onBukaChapter,
  });

  final String mangaId;
  final MangaDetails info;
  final bool sinopsisPenuh;
  final bool terbaruDulu;
  final VoidCallback onToggleSinopsis;
  final VoidCallback onToggleUrut;
  final VoidCallback onToggleBookmark;
  final void Function(Chapter chapter) onBukaChapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ditandai = ref.watch(bookmarkRepositoryProvider).containsKey(mangaId);
    final progres = ref.watch(historyRepositoryProvider)[mangaId];
    final dibaca = progres?.readChapterIds ?? const <String>{};
    final chaptersAsync = ref.watch(chapterListProvider(mangaId));

    return CustomScrollView(
      // Selalu bisa ditarik-refresh walau konten pendek.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: OfflineBanner()),
        SliverToBoxAdapter(
          child: _HeaderDetail(
            info: info,
            ditandai: ditandai,
            labelTombolBaca: _labelTombolBaca(
              chaptersAsync.valueOrNull,
              dibaca,
              progres?.lastChapterId,
            ),
            targetBaca: _targetBaca(
              chaptersAsync.valueOrNull,
              dibaca,
              progres?.lastChapterId,
            ),
            onToggleBookmark: onToggleBookmark,
            onBaca: () {
              final target = _targetBaca(
                chaptersAsync.valueOrNull,
                dibaca,
                progres?.lastChapterId,
              );
              if (target != null) onBukaChapter(target);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _Sinopsis(
            teks: info.description,
            penuh: sinopsisPenuh,
            onToggle: onToggleSinopsis,
          ),
        ),
        SliverToBoxAdapter(child: _InfoGenres(genres: info.genres)),
        SliverToBoxAdapter(child: _InfoTambahan(info: info)),
        SliverToBoxAdapter(
          child: _HeaderChapter(
            jumlah: chaptersAsync.valueOrNull?.length,
            terbaruDulu: terbaruDulu,
            onToggleUrut: onToggleUrut,
          ),
        ),
        chaptersAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('Gagal memuat chapter. $error')),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(chapterListProvider(mangaId)),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (chapters) {
            if (chapters.isEmpty) {
              return const SliverToBoxAdapter(
                child: EmptyView(
                  judul: 'Belum ada chapter',
                  deskripsi: 'Judul ini belum memiliki chapter.',
                  ikon: Icons.menu_book_outlined,
                ),
              );
            }
            final tampil = _urutkan(chapters, terbaruDulu);
            return SliverList.separated(
              itemCount: tampil.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final chapter = tampil[index];
                final sudah = dibaca.contains(chapter.url);
                return ListTile(
                  leading: Icon(
                    sudah ? Icons.check_circle : Icons.check_circle_outline,
                    color: sudah
                        ? Colors.green
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(
                    chapter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sudah
                        ? TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          )
                        : null,
                  ),
                  subtitle: Text(_formatTanggalChapter(chapter.dateUpload)),
                  trailing: sudah
                      ? const Text('Dibaca')
                      : const Icon(Icons.chevron_right),
                  onTap: () => onBukaChapter(chapter),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _HeaderDetail extends StatelessWidget {
  const _HeaderDetail({
    required this.info,
    required this.ditandai,
    required this.labelTombolBaca,
    required this.targetBaca,
    required this.onToggleBookmark,
    required this.onBaca,
  });

  final MangaDetails info;
  final bool ditandai;
  final String labelTombolBaca;
  final Chapter? targetBaca;
  final VoidCallback onToggleBookmark;
  final VoidCallback onBaca;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final meta = [
      if (info.status.isNotEmpty) info.status,
      if (info.country.isNotEmpty) info.country,
      if (info.releaseYear.isNotEmpty) info.releaseYear,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(
                imageUrl: info.thumbnail,
                width: 120,
                height: 160,
                borderRadius: 12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.title, style: textTheme.titleLarge),
                    if (info.alternativeTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        info.alternativeTitle,
                        style: textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(meta, style: textTheme.bodyMedium),
                    ],
                    if (info.userRate > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            info.userRate.toStringAsFixed(1),
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    if (info.viewCount > 0 || info.bookmarkCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _ringkasStatistik(info.viewCount, info.bookmarkCount),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: targetBaca == null ? null : onBaca,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(labelTombolBaca),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: ditandai ? 'Hapus dari Pustaka' : 'Simpan ke Pustaka',
                isSelected: ditandai,
                selectedIcon: const Icon(Icons.bookmark),
                icon: const Icon(Icons.bookmark_outline),
                onPressed: onToggleBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sinopsis extends StatelessWidget {
  const _Sinopsis({
    required this.teks,
    required this.penuh,
    required this.onToggle,
  });

  final String teks;
  final bool penuh;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sinopsis', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                teks.isEmpty ? 'Sinopsis belum tersedia.' : teks,
                maxLines: penuh ? null : 4,
                overflow: penuh ? null : TextOverflow.ellipsis,
              ),
              if (teks.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onToggle,
                    child: Text(penuh ? 'Lebih sedikit' : 'Selengkapnya'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoGenres extends StatelessWidget {
  const _InfoGenres({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Genre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (genres.isEmpty)
            const Text('Genre tidak tersedia.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final genre in genres) Chip(label: Text(genre))],
            ),
        ],
      ),
    );
  }
}

class _InfoTambahan extends StatelessWidget {
  const _InfoTambahan({required this.info});

  final MangaDetails info;

  @override
  Widget build(BuildContext context) {
    final baris = <String, String>{
      if (info.authors.isNotEmpty) 'Penulis': info.authors.join(', '),
      if (info.artists.isNotEmpty) 'Artis': info.artists.join(', '),
      if (info.formats.isNotEmpty) 'Format': info.formats.join(', '),
      if (info.types.isNotEmpty) 'Tipe': info.types.join(', '),
      if (info.rank > 0) 'Peringkat': '#${info.rank}',
    };
    if (baris.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final entry in baris.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(child: Text(entry.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChapter extends StatelessWidget {
  const _HeaderChapter({
    required this.jumlah,
    required this.terbaruDulu,
    required this.onToggleUrut,
  });

  final int? jumlah;
  final bool terbaruDulu;
  final VoidCallback onToggleUrut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              jumlah == null ? 'Daftar Chapter' : 'Daftar Chapter ($jumlah)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: onToggleUrut,
            icon: Icon(terbaruDulu ? Icons.arrow_downward : Icons.arrow_upward),
            label: Text(terbaruDulu ? 'Terbaru' : 'Terlama'),
          ),
        ],
      ),
    );
  }
}

/// Mengurutkan chapter; terbaru = `dateUpload` terbesar lebih dulu.
/// Bila tidak ada tanggal, urutan API dianggap sudah terbaru.
List<Chapter> _urutkan(List<Chapter> daftar, bool terbaruDulu) {
  final tersusun = [...daftar];
  if (tersusun.any((chapter) => chapter.dateUpload > 0)) {
    tersusun.sort((a, b) => b.dateUpload.compareTo(a.dateUpload));
  }
  return terbaruDulu ? tersusun : tersusun.reversed.toList();
}

String _formatTanggalChapter(int millis) {
  if (millis <= 0) return 'Tanggal tidak diketahui';
  const bulan = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final tanggal = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${tanggal.day} ${bulan[tanggal.month]} ${tanggal.year}';
}

String _ringkasStatistik(int views, int bookmarks) {
  String ringkas(int nilai) {
    if (nilai >= 1000000) {
      return '${(nilai / 1000000).toStringAsFixed(1)} jt';
    }
    if (nilai >= 1000) return '${(nilai / 1000).toStringAsFixed(1)} rb';
    return '$nilai';
  }

  final bagian = <String>[
    if (views > 0) '${ringkas(views)} dibaca',
    if (bookmarks > 0) '${ringkas(bookmarks)} bookmark',
  ];
  return bagian.join(' • ');
}

/// Label tombol baca berdasarkan riwayat.
String _labelTombolBaca(
  List<Chapter>? chapters,
  Set<String> dibaca,
  String? lastChapterId,
) {
  final target = _targetBaca(chapters, dibaca, lastChapterId);
  if (target == null) return 'Mulai Baca';
  if (lastChapterId == null || lastChapterId.isEmpty) return 'Mulai Baca';
  return 'Lanjut Baca';
}

/// Chapter tujuan tombol baca: chapter terlama yang belum dibaca,
/// atau posisi terakhir bila semua sudah dibaca.
Chapter? _targetBaca(
  List<Chapter>? chapters,
  Set<String> dibaca,
  String? lastChapterId,
) {
  if (chapters == null || chapters.isEmpty) return null;
  final terlamaDulu = _urutkan(chapters, false);
  if (lastChapterId == null || lastChapterId.isEmpty) {
    return terlamaDulu.first;
  }
  final posisi = terlamaDulu.indexWhere(
    (chapter) => chapter.url == lastChapterId,
  );
  if (posisi == -1) {
    for (final chapter in terlamaDulu) {
      if (!dibaca.contains(chapter.url)) return chapter;
    }
    return terlamaDulu.first;
  }
  for (var i = posisi + 1; i < terlamaDulu.length; i++) {
    if (!dibaca.contains(terlamaDulu[i].url)) return terlamaDulu[i];
  }
  return terlamaDulu[posisi];
}
