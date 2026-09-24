import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/features/detail/presentation/detail_providers.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/models/chapter.dart';
import 'package:alana/models/page.dart' as manga;

import '../data/reader_repository.dart';
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

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool _chromeTerlihat = true;
  bool _sudahRestore = false;
  final _scrollController = ScrollController();
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _simpanPosisi();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Menyimpan posisi scroll (debounce 1 detik selama scroll).
  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _simpanPosisi);
  }

  void _simpanPosisi() {
    if (!_scrollController.hasClients) return;
    final pages = ref.read(pageListProvider(widget.chapterId)).valueOrNull;
    ref
        .read(historyRepositoryProvider.notifier)
        .simpanPosisi(
          mangaId: widget.mangaId,
          mangaTitle: widget.mangaTitle,
          mangaThumbnail: widget.mangaThumbnail,
          chapterId: widget.chapterId,
          chapterName: widget.chapterName,
          scrollOffset: _scrollController.offset,
          pageCount: pages?.length ?? 0,
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
      _scrollController.jumpTo(offset.clamp(0, max));
    });
  }

  void _preloadBerikutnya(int index, List<manga.Page> pages) {
    for (var i = index + 1; i <= index + 2 && i < pages.length; i++) {
      unawaited(
        precacheImage(
          NetworkImage(pages[i].imageUrl, headers: readerImageHeaders),
          context,
        ).then((_) {}, onError: (_) {}),
      );
    }
  }

  void _pindahChapter(Chapter target) {
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

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(pageListProvider(widget.chapterId));
    final chaptersAsync = ref.watch(chapterListProvider(widget.mangaId));

    // Tandai chapter sedang dibaca begitu daftar gambar termuat.
    ref.listen(pageListProvider(widget.chapterId), (previous, next) {
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
    });

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
              title: Text(judul, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            pesan: 'Gagal memuat gambar. $error',
            onRetry: () => ref.invalidate(pageListProvider(widget.chapterId)),
          ),
          data: (pages) {
            if (pages.isEmpty) {
              return const EmptyView(
                judul: 'Belum ada gambar',
                deskripsi: 'Chapter ini belum memiliki gambar.',
                ikon: Icons.image_not_supported_outlined,
              );
            }
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              cacheExtent: MediaQuery.of(context).size.height,
              itemCount: pages.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Kembalikan posisi terakhir hanya bila chapter-nya sama.
                  final tersimpan = ref.read(
                    historyRepositoryProvider,
                  )[widget.mangaId];
                  final offset = tersimpan?.lastChapterId == widget.chapterId
                      ? tersimpan?.scrollOffset ?? 0
                      : 0;
                  _restorePosisi(offset);
                }
                return ReaderImage(
                  imageUrl: pages[index].imageUrl,
                  headers: readerImageHeaders,
                  onLoaded: () => _preloadBerikutnya(index, pages),
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
