import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/core/utils/share_content.dart';
import 'package:alana/features/downloads/data/download_manager.dart';
import 'package:alana/features/downloads/data/download_repository.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/settings/data/settings_repository.dart';
import 'package:alana/features/sync/data/sync_service.dart';
import 'package:alana/models/page.dart' as manga;

import '../data/reader_repository.dart';
import 'chapter_report_sheet.dart';
import 'reader_providers.dart';
import 'widgets/reader_image.dart';

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

  double? _targetOffset;

  bool _restoreTercapai = false;

  ({String mangaId, String chapterId}) get _kunciOffline =>
      (mangaId: widget.mangaId, chapterId: widget.chapterId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      _ImmersiveSession.aktif(
        ref.read(settingsRepositoryProvider).keepScreenOn,
      ),
    );
    _scrollController.addListener(_onScroll);
    ref.invalidate(historyRepositoryProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _simpanPosisi();
    unawaited(SyncService.dorongSekarang(_uid, mangaId: widget.mangaId));
    _scrollController.dispose();
    unawaited(_ImmersiveSession.lepas());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTimer?.cancel();
      _simpanPosisi();
      unawaited(ref.read(syncServiceProvider).flushTertunda());
    }
  }

  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _simpanPosisi);
  }

  bool _onUserScroll(UserScrollNotification notifikasi) {
    if (notifikasi.direction != ScrollDirection.idle) {
      _targetOffset = null;
      _restoreTercapai = true;
    }
    return false;
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
    _targetOffset = offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cobaRestore();
    });
  }

  void _cobaRestore() {
    final target = _targetOffset;
    if (target == null || _restoreTercapai) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final sampai = target.clamp(0.0, max).toDouble();
    _scrollController.jumpTo(sampai);
    _restoreTercapai = sampai >= target - 1;
  }

  void _preloadBerikutnya(
    int index,
    List<manga.Page> pages, {
    bool offline = false,
  }) {
    _cobaRestore();
    if (offline) return;
    final decodeWidth = _lebarDecode(context);
    for (var i = index + 1; i <= index + 2 && i < pages.length; i++) {
      unawaited(
        precacheImage(
          ResizeImage(
            CachedNetworkImageProvider(
              pages[i].imageUrl,
              headers: readerImageHeaders,
            ),
            width: decodeWidth,
          ),
          context,
        ).then((_) {}, onError: (_) {}),
      );
    }
  }

  static int? _lebarDecode(BuildContext context) {
    final logical = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final px = (logical * dpr).round();
    return px > 0 ? px : null;
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
      builder: (_) => ChapterReportSheet(
        mangaId: widget.mangaId,
        mangaTitle: widget.mangaTitle,
        chapterId: widget.chapterId,
      ),
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
    final uid = ref.watch(userIdProvider) ?? '';
    final downloadAsync = ref.watch(downloadManagerProvider);
    final downloadState = downloadAsync.valueOrNull;
    final downloaded = downloadState?.entryFor(
      DownloadRepository.keyFor(uid, widget.mangaId, widget.chapterId),
    );
    final offline = downloaded?.status == DownloadStatus.completed;
    final AsyncValue<List<manga.Page>> pagesAsync = offline
        ? ref.watch(offlinePageListProvider(_kunciOffline))
        : ref.watch(pageListProvider(widget.chapterId));
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
        ref.listen(offlinePageListProvider(_kunciOffline), (previous, next) {
          tandaiDibaca(next);
        });
      } else {
        ref.listen(pageListProvider(widget.chapterId), (previous, next) {
          tandaiDibaca(next);
        });
      }
    }

    String judul = widget.chapterName;
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
                    if (value == 'laporan') {
                      unawaited(_bukaLaporan());
                    } else if (value == 'bagikan') {
                      unawaited(
                        shareChapter(
                          context,
                          mangaTitle: widget.mangaTitle.isEmpty
                              ? widget.mangaId
                              : widget.mangaTitle,
                          chapterTitle: judul,
                          mangaId: widget.mangaId,
                          chapterId: widget.chapterId,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'bagikan',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.share_outlined),
                        title: Text('Bagikan chapter'),
                      ),
                    ),
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
      body: GestureDetector(
        onTap: () {
          setState(() => _chromeTerlihat = !_chromeTerlihat);
        },
        child: pagesAsync.when(
          loading: () => const LoadingSpinner(),
          error: (error, _) => ErrorView(
            pesan: pesanErrorRamah(error),
            onRetry: () {
              if (offline) {
                ref.invalidate(offlinePageListProvider(_kunciOffline));
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
            return NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImmersiveSession {
  const _ImmersiveSession._();

  static int _peminat = 0;

  static Future<void> aktif(bool keepScreenOn) async {
    _peminat++;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (keepScreenOn) await WakelockPlus.enable();
  }

  static Future<void> lepas() async {
    if (_peminat > 0) _peminat--;
    if (_peminat > 0) return;
    await WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
