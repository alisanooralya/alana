import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/features/downloads/data/download_manager.dart';
import 'package:alana/features/downloads/data/download_repository.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/features/detail/presentation/detail_providers.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/settings/data/settings_repository.dart';
import 'package:alana/features/sync/data/sync_service.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/page.dart' as manga;

import '../data/reader_repository.dart';
import 'chapter_report_sheet.dart';
import 'reader_providers.dart';
import 'widgets/reader_image.dart';

/// Halaman baca vertikal ala webtoon.
///
/// - Daftar gambar full-width tanpa jarak.
/// - Ketuk layar menampilkan/menyembunyikan AppBar + tombol pindah chapter.
/// - Mode immersive: status bar sistem disembunyikan selama membaca.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.chapterName = '',
    this.mangaTitle = '',
    this.mangaThumbnail = '',
  });

  final String mangaId;
  final String chapterId;

  /// Nama chapter untuk judul AppBar (dikirim lewat route `extra`).
  final String chapterName;
  final String mangaTitle;
  final String mangaThumbnail;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  bool _chromeTerlihat = true;
  bool _sudahRestore = false;
  final _scrollController = ScrollController();
  Timer? _saveTimer;
  String? _uid;
  int _jumlahHalamanTerakhir = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (ref.read(settingsRepositoryProvider).keepScreenOn) {
      WakelockPlus.enable();
    }
    _scrollController.addListener(_onScroll);
    // Selaraskan flag pending dengan box (dorong statis menulis box langsung).
    ref.invalidate(historyRepositoryProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _simpanPosisi();
    // Tanpa ref di dispose: dorong statis langsung dari box.
    unawaited(SyncService.dorongSekarang(_uid, mangaId: widget.mangaId));
    _scrollController.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Aplikasi background: kirim progres yang pending (best-effort).
    if (state == AppLifecycleState.paused) {
      unawaited(ref.read(syncServiceProvider).flushTertunda());
    }
  }

  /// Menyimpan posisi scroll (debounce 1 detik selama scroll).
  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _simpanPosisi);
  }

  void _simpanPosisi() {
    if (!_scrollController.hasClients) return;
    ref
        .read(historyRepositoryProvider.notifier)
        .simpanPosisi(
          mangaId: widget.mangaId,
          mangaTitle: widget.mangaTitle,
          mangaThumbnail: widget.mangaThumbnail,
          chapterId: widget.chapterId,
          chapterName: widget.chapterName,
          scrollOffset: _scrollController.offset,
          pageCount: _jumlahHalamanTerakhir,
        );
  }

  void _restorePosisi(double offset) {
    if (_sudahRestore) return;
    _sudahRestore = true;
    if (offset <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      _scrollController.jumpTo(offset.clamp(0.0, max).toDouble());
    });
  }

  void _preloadBerikutnya(
    int index,
    List<manga.Page> pages, {
    bool offline = false,
  }) {
    if (offline) return;
    for (var i = index + 1; i <= index + 2 && i < pages.length; i++) {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            pages[i].imageUrl,
            headers: readerImageHeaders,
          ),
          context,
        ).then((_) {}, onError: (_) {}),
      );
    }
  }

  void _pindahChapter(Chapter target) {
    // Dorong progres chapter ini sebelum pindah (tanpa menunggu).
    unawaited(ref.read(syncServiceProvider).flushTertunda());
    context.pushReplacementNamed(
      'reader',
      pathParameters: {'mangaId': widget.mangaId, 'chapterId': target.url},
      extra: {
        'chapterName': target.name,
        'mangaTitle': widget.mangaTitle,
        'mangaThumbnail': widget.mangaThumbnail,
      },
    );
  }

  Future<void> _bukaLaporan() async {
    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sesi login tidak tersedia.')),
        );
      return;
    }

    final hasil = await showModalBottomSheet<ReportSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChapterReportSheet(chapterId: widget.chapterId),
    );
    if (!mounted || hasil == null) return;
    final pesan = switch (hasil) {
      ReportSheetResult.submitted => 'Laporan terkirim, terima kasih.',
      ReportSheetResult.alreadyReported =>
        'Kamu sudah melaporkan chapter ini, tim akan meninjau.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    final downloadAsync = ref.watch(downloadManagerProvider);
    final downloadState = downloadAsync.valueOrNull;
    final downloaded = downloadState?.entryFor(
      DownloadRepository.keyFor(widget.mangaId, widget.chapterId),
    );
    final offline =
        downloadAsync.hasValue &&
        downloaded?.status == DownloadStatus.completed;
    final pagesAsync = downloadAsync.isLoading
        ? const AsyncLoading()
        : offline
        ? ref.watch(offlinePageListProvider(widget.chapterId))
        : ref.watch(pageListProvider(widget.chapterId));
    final chaptersAsync = downloadAsync.isLoading || offline
        ? const AsyncData<List<Chapter>>(<Chapter>[])
        : ref.watch(chapterListProvider(widget.mangaId));
    _uid = ref.watch(userIdProvider);

    void tandaiDibaca(AsyncValue<List<manga.Page>> next) {
      final pages = next.valueOrNull;
      if (pages == null || pages.isEmpty) return;
      ref
          .read(historyRepositoryProvider.notifier)
          .tandaiDibaca(
            mangaId: widget.mangaId,
            mangaTitle: widget.mangaTitle,
            mangaThumbnail: widget.mangaThumbnail,
            chapterId: widget.chapterId,
            chapterName: widget.chapterName.isEmpty
                ? widget.chapterId
                : widget.chapterName,
          );
    }

    if (!downloadAsync.isLoading) {
      if (offline) {
        ref.listen(offlinePageListProvider(widget.chapterId), (previous, next) {
          tandaiDibaca(next);
        });
      } else {
        ref.listen(pageListProvider(widget.chapterId), (previous, next) {
          tandaiDibaca(next);
        });
      }
    }

    final chapters = chaptersAsync.valueOrNull;
    final terlamaDulu = chapters == null ? null : _urutTerlamaDulu(chapters);
    final posisi = terlamaDulu?.indexWhere(
      (chapter) => chapter.url == widget.chapterId,
    );
    final sebelumnya = (terlamaDulu != null && posisi != null && posisi > 0)
        ? terlamaDulu[posisi - 1]
        : null;
    final berikutnya =
        (terlamaDulu != null &&
            posisi != null &&
            posisi >= 0 &&
            posisi < terlamaDulu.length - 1)
        ? terlamaDulu[posisi + 1]
        : null;

    String judul = widget.chapterName;
    if (judul.isEmpty && terlamaDulu != null && posisi != null && posisi >= 0) {
      judul = terlamaDulu[posisi].name;
    }
    if (judul.isEmpty) judul = 'Membaca';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chromeTerlihat
          ? AppBar(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (offline)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.offline_pin, size: 18),
                    ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Menu chapter',
                  onSelected: (value) {
                    if (value == 'laporan') unawaited(_bukaLaporan());
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'laporan',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.report_problem_outlined),
                        title: Text('Laporkan Masalah'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      bottomNavigationBar: _chromeTerlihat
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sebelumnya == null
                            ? null
                            : () => _pindahChapter(sebelumnya),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Sebelumnya'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: berikutnya == null
                            ? null
                            : () => _pindahChapter(berikutnya),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Berikutnya'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() => _chromeTerlihat = !_chromeTerlihat);
        },
        child: pagesAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            pesan: pesanErrorRamah(error),
            onRetry: () {
              if (offline) {
                ref.invalidate(offlinePageListProvider(widget.chapterId));
              } else {
                ref.invalidate(pageListProvider(widget.chapterId));
              }
            },
          ),
          data: (pages) {
            if (pages.isEmpty) {
              return const EmptyView(
                judul: 'Belum ada gambar',
                deskripsi: 'Chapter ini belum memiliki gambar.',
                ikon: Icons.image_not_supported_outlined,
              );
            }
            _jumlahHalamanTerakhir = pages.length;
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: pages.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Kembalikan posisi terakhir hanya bila chapter-nya sama.
                  final tersimpan = ref.read(
                    historyRepositoryProvider,
                  )[widget.mangaId];
                  final offset = tersimpan?.lastChapterId == widget.chapterId
                      ? tersimpan?.scrollOffset ?? 0.0
                      : 0.0;
                  _restorePosisi(offset);
                }
                return ReaderImage(
                  imageUrl: pages[index].imageUrl,
                  localPath: offline ? pages[index].imageUrl : null,
                  headers: readerImageHeaders,
                  onLoaded: () =>
                      _preloadBerikutnya(index, pages, offline: offline),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Urutan baca: chapter terlama lebih dulu (fallback: urutan API).
List<Chapter> _urutTerlamaDulu(List<Chapter> daftar) {
  final tersusun = [...daftar];
  if (tersusun.any((chapter) => chapter.dateUpload > 0)) {
    tersusun.sort((a, b) => a.dateUpload.compareTo(b.dateUpload));
  }
  return tersusun;
}
