import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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

import '../data/reader_net.dart';
import '../data/reader_repository.dart';
import 'chapter_report_sheet.dart';
import 'reader_anchor.dart';
import 'reader_providers.dart';
import 'reader_ratio_controller.dart';
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
  final ValueNotifier<bool> _chromeTerlihat = ValueNotifier<bool>(true);

  final ValueNotifier<int> _indeksAktif = ValueNotifier<int>(0);

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositions = ItemPositionsListener.create();

  Timer? _saveTimer;
  String? _uid;
  int _jumlahHalamanTerakhir = 0;
  bool _offlineAktif = false;
  bool _sudahRestore = false;
  bool _bolehSimpan = false;

  AnchorBaca? _anchorTersimpan;

  ReaderRatioController? _rasio;
  String? _rasioUntuk;
  bool _riwayatSudahDisegarkan = false;
  bool _sedangGeres = false;

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
    PenghitungTrafik.reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_riwayatSudahDisegarkan) return;
    _riwayatSudahDisegarkan = true;
    ref.invalidate(historyRepositoryProvider);
  }

  @override
  void deactivate() {
    _saveTimer?.cancel();
    _simpanPosisi();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _rasio?.dispose();
    _chromeTerlihat.dispose();
    _indeksAktif.dispose();
    if (PenghitungTrafik.aktif) {
      debugPrint('${PenghitungTrafik.ringkas()} chapter=${widget.chapterName}');
    }
    unawaited(_ImmersiveSession.lepas());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTimer?.cancel();
      _simpanPosisiDanDorong();
    }
  }

  void _jadwalSimpan() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _simpanPosisi);
  }

  bool _onScrollNotification(ScrollNotification notifikasi) {
    if (notifikasi is ScrollUpdateNotification) {
      _jadwalSimpan();
    } else if (notifikasi is ScrollStartNotification) {
      _sedangGeres = true;
    } else if (notifikasi is ScrollEndNotification) {
      _sedangGeres = false;
      _sinkronIndeksAktif();
      _rasio?.aturJendela(_indeksAktif.value);
      _preload();
    }

    if (notifikasi is UserScrollNotification &&
        notifikasi.direction != ScrollDirection.idle) {
      _bolehSimpan = true;
    }
    return false;
  }

  void _simpanPosisiDanDorong() {
    _simpanPosisi();
    unawaited(SyncService.dorongSekarang(_uid, mangaId: widget.mangaId));
  }

  AnchorBaca? get _anchorSekarang {
    final anchor = anchorDariPosisi(_itemPositions.itemPositions.value);
    if (anchor == null) return null;
    if (_indeksAktif.value != anchor.scrollIndex) {
      _indeksAktif.value = anchor.scrollIndex;
    }
    return anchor;
  }

  void _sinkronIndeksAktif() {
    _anchorSekarang;
  }

  void _simpanPosisi() {
    if (!_bolehSimpan) return;
    final anchor = _anchorSekarang;
    if (anchor == null) return;
    ref
        .read(historyRepositoryProvider.notifier)
        .simpanPosisi(
          mangaId: widget.mangaId,
          mangaTitle: widget.mangaTitle,
          mangaThumbnail: widget.mangaThumbnail,
          chapterId: widget.chapterId,
          chapterName: widget.chapterName,
          scrollIndex: anchor.scrollIndex,
          scrollLeading: anchor.scrollLeading,
          pageCount: _jumlahHalamanTerakhir,
        );
  }

  void _restoreAnchor(AnchorBaca? anchor) {
    if (_sudahRestore) return;
    _sudahRestore = true;
    if (anchor == null) return;
    if (anchor.scrollIndex <= 0) return;
    _anchorTersimpan = anchor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_itemScrollController.isAttached) return;
      _itemScrollController.jumpTo(
        index: anchor.scrollIndex,
        alignment: anchor.scrollLeading,
      );
    });
  }

  void _kompensasiTinggi(double top, double deltaTinggi) {
    if (deltaTinggi.abs() < 0.5) return;
    if (top >= 0) return;
    if (!_itemScrollController.isAttached) return;
    final anchor = _anchorSekarang ?? _anchorTersimpan;
    if (anchor == null) return;
    final tinggi = MediaQuery.sizeOf(context).height;
    if (tinggi <= 0) return;

    final depan = koreksiLeading(
      scrollLeading: anchor.scrollLeading,
      deltaTinggi: deltaTinggi,
      tinggiViewport: tinggi,
    );
    if ((depan - anchor.scrollLeading).abs() < 0.0005) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      _itemScrollController.jumpTo(index: anchor.scrollIndex, alignment: depan);
    });
  }

  void _siapkanRasio(List<manga.Page> pages, {required bool offline}) {
    final kunci = '${offline}_${widget.chapterId}_${pages.length}';
    if (_rasio != null && _rasioUntuk == kunci) return;
    _rasio?.hentikan();
    _rasioUntuk = kunci;

    final controller = ReaderRatioController(pages: pages, online: !offline);
    _rasio = controller;
    _offlineAktif = offline;

    final tersimpan = ref.read(historyRepositoryProvider)[widget.mangaId];
    final milikChapterIni = tersimpan?.lastChapterId == widget.chapterId;
    final awal = milikChapterIni ? (tersimpan?.scrollIndex ?? 0) : 0;
    _indeksAktif.value = awal;
    _restoreAnchor(
      milikChapterIni
          ? (scrollIndex: awal, scrollLeading: tersimpan?.scrollLeading ?? 0)
          : null,
    );

    unawaited(
      controller.tungguAwal(awal).then((_) {
        if (!mounted) return;
        setState(() {});
      }),
    );
  }

  void _adopsiDimensi(int index, int width, int height) {
    final controller = _rasio;
    if (controller == null || width <= 0 || height <= 0) return;
    controller.tetapkan(index, width / height);
  }

  void _preload() {
    final controller = _rasio;
    if (controller == null) return;
    if (_offlineAktif) return;
    if (_sedangGeres) return;

    final batas = batasDecode(
      lebarLogis: MediaQuery.sizeOf(context).width,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
    final mulai = _indeksAktif.value;
    for (
      var i = mulai + 1;
      i <= mulai + 2 && i < controller.pages.length;
      i++
    ) {
      final url = controller.pages[i].imageUrl;
      unawaited(
        precacheImage(
          ResizeImage(
            CachedNetworkImageProvider(
              url,
              headers: readerImageHeaders,
              cacheManager: readerCacheManager,
              cacheKey: readerCacheKey(url),
            ),
            width: batas.width,
            height: batas.height,
            policy: ResizeImagePolicy.fit,
          ),
          context,
        ).then((_) {}, onError: (_) {}),
      );
    }
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
      if (next.valueOrNull == null || next.value!.isEmpty) return;
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
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _simpanPosisiDanDorong();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _chromeTerlihat.value = !_chromeTerlihat.value;
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
                    _siapkanRasio(pages, offline: offline);
                    return _bangunList(pages, offline: offline);
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _chromeTerlihat,
                builder: (context, terlihat, _) {
                  return AnimatedSlide(
                    offset: terlihat ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedOpacity(
                      opacity: terlihat ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !terlihat,
                        child: _bangunAppBar(judul, offline: offline),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _bangunAppBar(String judul, {required bool offline}) {
    return AppBar(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Expanded(
            child: Text(judul, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    );
  }

  Widget _bangunList(List<manga.Page> pages, {required bool offline}) {
    final controller = _rasio;
    if (controller == null) return const LoadingSpinner();

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ScrollablePositionedList.builder(
        itemCount: pages.length,
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositions,
        padding: EdgeInsets.zero,
        minCacheExtent: MediaQuery.sizeOf(context).height * 1.5,
        itemBuilder: (context, index) {
          return ReaderImage(
            imageUrl: pages[index].imageUrl,
            localPath: offline ? pages[index].imageUrl : null,
            headers: readerImageHeaders,
            cacheManager: readerCacheManager,
            rasio: controller.notifier[index],
            onLoaded: _preload,
            onDimensi: (w, h) => _adopsiDimensi(index, w, h),
            onTinggiBerubah: _kompensasiTinggi,
          );
        },
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
