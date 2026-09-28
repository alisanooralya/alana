import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/core/widgets/nomor_halaman.dart';
import 'package:alana/core/widgets/offline_banner.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/core/utils/share_content.dart';
import 'package:alana/features/downloads/data/download_manager.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/downloads/data/download_repository.dart';
import 'package:alana/features/detail/data/detail_repository.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/library/data/bookmarked_manga.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/manga_details.dart';

import 'detail_providers.dart';

class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, required this.mangaId});

  final String mangaId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  bool _sinopsisPenuh = false;
  bool _terbaruDulu = true;
  int _halamanChapter = 1;

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

  Future<void> _konfirmasiDownloadSemua(
    BuildContext context,
    WidgetRef ref,
    String mangaId,
    MangaDetails info,
    List<Chapter> chapters,
  ) async {
    if (chapters.isEmpty) return;
    final hasil = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Download semua chapter?'),
        content: Text(
          '${chapters.length} chapter akan masuk ke antrean unduhan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Masuk antrean'),
          ),
        ],
      ),
    );
    if (hasil != true || !context.mounted) return;
    await ref
        .read(downloadManagerProvider.notifier)
        .enqueueAll(
          chapters
              .map(
                (chapter) => DownloadRequest(
                  userId: ref.read(userIdProvider) ?? '',
                  mangaId: mangaId,
                  chapterId: chapter.url,
                  mangaTitle: info.title,
                  chapterTitle: chapter.name,
                  coverUrl: info.thumbnail,
                ),
              )
              .toList(),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${chapters.length} chapter masuk antrean.')),
      );
  }

  static int _nomorDariNama(String name) {
    final cocok = RegExp(r'Chapter\s+([\d.]+)').firstMatch(name);
    if (cocok == null) return 0;
    return double.tryParse(cocok.group(1)!)?.round() ?? 0;
  }

  Future<void> _bukaLanjutBaca(
    MangaDetails info,
    MangaReadingProgress? progres,
  ) async {
    final lastId = progres?.lastChapterId ?? '';
    final nomor = _nomorDariNama(progres?.lastChapterName ?? '');
    if (lastId.isEmpty || nomor <= 0) {
      await _bukaChapterTerbaru(info);
      return;
    }

    final repository = ref.read(detailRepositoryProvider);
    try {
      final probe = await repository.getChapters(widget.mangaId, page: 1);
      final total = probe.totalPage;
      final halaman = total <= 1
          ? 1
          : await _halamanBerisiNomor(repository, widget.mangaId, total, nomor);
      if (halaman == null) {
        await _bukaChapterTerbaru(info);
        return;
      }
      final result = halaman == 1
          ? probe
          : await repository.getChapters(widget.mangaId, page: halaman);
      if (!mounted) return;
      if (halaman != _halamanChapter) setState(() => _halamanChapter = halaman);
      await _bukaSetelah(info, result.chapters, lastId, nomor, halaman, total);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Gagal mencari chapter. ${pesanErrorRamah(error)}'),
          ),
        );
    }
  }

  Future<int?> _halamanBerisiNomor(
    DetailRepository repository,
    String mangaId,
    int totalPage,
    int nomor,
  ) async {
    var bawah = 1;
    var atas = totalPage;
    while (bawah <= atas) {
      final tengah = (bawah + atas) ~/ 2;
      final result = await repository.getChapters(mangaId, page: tengah);
      if (result.chapters.isEmpty) return null;
      final pertama = result.chapters.first.number;
      if (pertama == 0) return tengah;
      if (pertama > nomor) {
        bawah = tengah + 1;
      } else {
        atas = tengah - 1;
      }
    }
    return bawah <= totalPage ? bawah : null;
  }

  Future<void> _bukaSetelah(
    MangaDetails info,
    List<Chapter> chapters,
    String lastId,
    int nomor,
    int halaman,
    int totalPage,
  ) async {
    if (chapters.isEmpty) return;
    var indeks = chapters.indexWhere((c) => c.url == lastId);
    if (indeks == -1) {
      indeks = chapters.indexWhere((c) => c.number == nomor);
    }
    if (indeks == -1) {
      _bukaChapter(info, chapters.first);
      return;
    }
    if (indeks + 1 < chapters.length) {
      _bukaChapter(info, chapters[indeks + 1]);
      return;
    }
    if (halaman < totalPage) {
      try {
        final berikut = await ref
            .read(detailRepositoryProvider)
            .getChapters(widget.mangaId, page: halaman + 1);
        if (!mounted || berikut.chapters.isEmpty) return;
        _bukaChapter(info, berikut.chapters.first);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Gagal membuka chapter. ${pesanErrorRamah(error)}'),
            ),
          );
      }
      return;
    }
    _bukaChapter(info, chapters[indeks]);
  }

  Future<void> _bukaChapterTerbaru(MangaDetails info) async {
    final repository = ref.read(detailRepositoryProvider);
    try {
      final pertama = await repository.getChapters(widget.mangaId, page: 1);
      var daftar = pertama.chapters;
      if (daftar.isEmpty && pertama.totalPage > 1) {
        daftar = (await repository.getChapters(
          widget.mangaId,
          page: pertama.totalPage,
        )).chapters;
      }
      if (!mounted) return;
      if (daftar.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Judul ini belum punya chapter.')),
          );
        return;
      }
      _bukaChapter(info, daftar.first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Gagal membuka chapter. ${pesanErrorRamah(error)}'),
          ),
        );
    }
  }

  void _bukaChapter(MangaDetails info, Chapter chapter) {
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
    final downloads = ref.watch(downloadManagerProvider).valueOrNull;
    final chapterRequest = ChapterPageRequest(
      mangaId: widget.mangaId,
      page: _halamanChapter,
    );
    final chaptersAsync = ref.watch(chapterListProvider(chapterRequest));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: detail.when(
        loading: () => const LoadingSpinner(),
        error: (error, _) => ErrorView(
          pesan: pesanErrorRamah(error),
          onRetry: () => ref.invalidate(mangaDetailsProvider(widget.mangaId)),
        ),
        data: (info) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mangaDetailsProvider(widget.mangaId));
            ref.invalidate(chapterListProvider(chapterRequest));
            await ref.read(mangaDetailsProvider(widget.mangaId).future);
            await ref.read(chapterListProvider(chapterRequest).future);
          },
          child: _IsiDetail(
            mangaId: widget.mangaId,
            info: info,
            halaman: _halamanChapter,
            sinopsisPenuh: _sinopsisPenuh,
            terbaruDulu: _terbaruDulu,
            onToggleSinopsis: () {
              setState(() => _sinopsisPenuh = !_sinopsisPenuh);
            },
            onToggleUrut: () {
              setState(() => _terbaruDulu = !_terbaruDulu);
            },
            onToggleBookmark: () => _toggleBookmark(info),
            onBukaChapter: (chapter) => _bukaChapter(info, chapter),
            onBaca: () => _bukaLanjutBaca(
              info,
              ref.read(historyRepositoryProvider)[widget.mangaId],
            ),
            downloads: downloads,
            onPilihHalaman: (halaman) {
              setState(() => _halamanChapter = halaman);
            },
            onDownloadAll: () => _konfirmasiDownloadSemua(
              context,
              ref,
              widget.mangaId,
              info,
              chaptersAsync.valueOrNull?.chapters ?? const [],
            ),
            onDownloadChapter: (chapter) => ref
                .read(downloadManagerProvider.notifier)
                .enqueue(
                  DownloadRequest(
                    userId: ref.read(userIdProvider) ?? '',
                    mangaId: widget.mangaId,
                    chapterId: chapter.url,
                    mangaTitle: info.title,
                    chapterTitle: chapter.name,
                    coverUrl: info.thumbnail,
                  ),
                ),
            onJeda: (key) =>
                ref.read(downloadManagerProvider.notifier).pause(key),
            onLanjut: (key) =>
                ref.read(downloadManagerProvider.notifier).retry(key),
            onBatal: (key) =>
                ref.read(downloadManagerProvider.notifier).cancel(key),
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
    required this.halaman,
    required this.sinopsisPenuh,
    required this.terbaruDulu,
    required this.onToggleSinopsis,
    required this.onToggleUrut,
    required this.onToggleBookmark,
    required this.onBukaChapter,
    required this.onBaca,
    required this.downloads,
    required this.onPilihHalaman,
    required this.onDownloadAll,
    required this.onDownloadChapter,
    required this.onJeda,
    required this.onLanjut,
    required this.onBatal,
  });

  final String mangaId;
  final MangaDetails info;
  final int halaman;
  final bool sinopsisPenuh;
  final bool terbaruDulu;
  final VoidCallback onToggleSinopsis;
  final VoidCallback onToggleUrut;
  final VoidCallback onToggleBookmark;
  final void Function(Chapter chapter) onBukaChapter;
  final VoidCallback onBaca;
  final DownloadState? downloads;
  final ValueChanged<int> onPilihHalaman;
  final VoidCallback onDownloadAll;
  final void Function(Chapter chapter) onDownloadChapter;
  final void Function(String key) onJeda;
  final void Function(String key) onLanjut;
  final void Function(String key) onBatal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ditandai = ref.watch(bookmarkRepositoryProvider).containsKey(mangaId);
    final progres = ref.watch(historyRepositoryProvider)[mangaId];
    final dibaca = progres?.readChapterIds ?? const <String>{};
    final chaptersAsync = ref.watch(
      chapterListProvider(ChapterPageRequest(mangaId: mangaId, page: halaman)),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: OfflineBanner()),
        SliverToBoxAdapter(
          child: _HeaderDetail(
            info: info,
            ditandai: ditandai,
            labelTombolBaca: (progres?.lastChapterId ?? '').isEmpty
                ? 'Mulai Baca'
                : 'Lanjut Baca',
            onToggleBookmark: onToggleBookmark,
            onShare: (shareContext) =>
                shareManga(shareContext, info.title, mangaId),
            onBaca: onBaca,
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
            jumlah: chaptersAsync.valueOrNull?.chapters.length,
            terbaruDulu: terbaruDulu,
            onToggleUrut: onToggleUrut,
            onDownloadAll: onDownloadAll,
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
                  Expanded(
                    child: Text(
                      'Gagal memuat chapter. ${pesanErrorRamah(error)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      chapterListProvider(
                        ChapterPageRequest(mangaId: mangaId, page: halaman),
                      ),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (result) {
            final chapters = result.chapters;
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
            return SliverMainAxisGroup(
              slivers: [
                SliverList.separated(
                  itemCount: tampil.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final chapter = tampil[index];
                    final sudah = dibaca.contains(chapter.url);
                    final download = downloads?.entryFor(
                      DownloadRepository.keyFor(
                        ref.watch(userIdProvider) ?? '',
                        mangaId,
                        chapter.url,
                      ),
                    );
                    final statusUnduhan = download?.status;
                    final selesaiUnduh =
                        statusUnduhan == DownloadStatus.completed;
                    final sedangBerjalan =
                        statusUnduhan == DownloadStatus.downloading ||
                        statusUnduhan == DownloadStatus.queued;
                    final statusLabel = switch (statusUnduhan) {
                      DownloadStatus.queued => 'Dalam antrean',
                      DownloadStatus.downloading =>
                        'Mengunduh ${((download?.progress ?? 0) * 100).round()}%',

                      DownloadStatus.completed => 'Tersimpan',
                      DownloadStatus.failed => 'Gagal',
                      DownloadStatus.paused => 'Dijeda',
                      null => null,
                    };
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
                      subtitle: Text(
                        [
                          _formatTanggalChapter(chapter.dateUpload),
                          ?statusLabel,
                        ].join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selesaiUnduh)
                            const Icon(Icons.offline_pin, size: 18),
                          if (statusUnduhan == DownloadStatus.downloading)
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                value: download?.progress ?? 0,
                                strokeWidth: 2,
                              ),
                            )
                          else if (!selesaiUnduh)
                            IconButton(
                              tooltip: selesaiUnduh
                                  ? 'Chapter sudah tersimpan'
                                  : 'Unduh chapter',
                              onPressed: selesaiUnduh
                                  ? null
                                  : () => onDownloadChapter(chapter),
                              icon: Icon(
                                selesaiUnduh
                                    ? Icons.download_done
                                    : Icons.download_outlined,
                              ),
                            ),
                          if (sedangBerjalan)
                            _TombolAksi(
                              tooltip: 'Jeda unduhan',
                              ikon: Icons.pause,
                              onTap: () => onJeda(download!.key),
                            )
                          else if (statusUnduhan == DownloadStatus.paused ||
                              statusUnduhan == DownloadStatus.failed)
                            _TombolAksi(
                              tooltip: 'Lanjutkan unduhan',
                              ikon: Icons.play_arrow,
                              onTap: () => onLanjut(download!.key),
                            ),
                          if (download != null && !selesaiUnduh)
                            _TombolAksi(
                              tooltip: 'Batalkan unduhan',
                              ikon: Icons.stop,
                              onTap: () => onBatal(download.key),
                            )
                          else if (sudah)
                            const Text('Dibaca')
                          else if (!selesaiUnduh)
                            const Icon(Icons.chevron_right),
                        ],
                      ),

                      onTap: () => onBukaChapter(chapter),
                    );
                  },
                ),
                if (result.totalPage > 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: NomorHalaman(
                        halaman: halaman,
                        totalHalaman: result.totalPage,
                        onPilih: onPilihHalaman,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _TombolAksi extends StatelessWidget {
  const _TombolAksi({
    required this.tooltip,
    required this.ikon,
    required this.onTap,
  });

  final String tooltip;
  final IconData ikon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(ikon),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: EdgeInsets.zero,
    );
  }
}

class _HeaderDetail extends StatelessWidget {
  const _HeaderDetail({
    required this.info,
    required this.ditandai,
    required this.labelTombolBaca,
    required this.onToggleBookmark,
    required this.onShare,
    required this.onBaca,
  });

  final MangaDetails info;
  final bool ditandai;
  final String labelTombolBaca;
  final VoidCallback onToggleBookmark;
  final void Function(BuildContext) onShare;
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
                  onPressed: onBaca,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(labelTombolBaca),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (shareContext) => IconButton.outlined(
                  tooltip: 'Bagikan judul',
                  onPressed: () => onShare(shareContext),
                  icon: const Icon(Icons.share_outlined),
                ),
              ),
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
    required this.onDownloadAll,
  });

  final int? jumlah;
  final bool terbaruDulu;
  final VoidCallback onToggleUrut;
  final VoidCallback onDownloadAll;

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
          IconButton(
            tooltip: 'Download semua chapter',
            onPressed: jumlah == null || jumlah == 0 ? null : onDownloadAll,

            icon: const Icon(Icons.download_outlined),
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

List<Chapter> _urutkan(List<Chapter> daftar, bool terbaruDulu) {
  final denganTanggal = daftar.where((c) => c.dateUpload > 0).toList();
  if (denganTanggal.isEmpty) return [...daftar];
  final tanpaTanggal = daftar.where((c) => c.dateUpload <= 0).toList();
  denganTanggal.sort((a, b) {
    final urut = terbaruDulu
        ? b.dateUpload.compareTo(a.dateUpload)
        : a.dateUpload.compareTo(b.dateUpload);
    return urut != 0 ? urut : a.name.compareTo(b.name);
  });
  return [...denganTanggal, ...tanpaTanggal];
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
