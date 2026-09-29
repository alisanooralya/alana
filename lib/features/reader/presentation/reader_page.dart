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

import '../data/reader_net.dart';
import '../data/reader_repository.dart';
import 'chapter_report_sheet.dart';
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
  /// Chrome digerakkan `ValueNotifier`, bukan `setState`.
  ///
  /// Sebelumnya`_chromeTerlihat` adalah kondisi `setState` yang memunculkan dan
  /// menghilangkan `AppBar`, jadi tinggi `Scaffold` berubah dan seluruh isi list
  /// bergeser — yang ikut menggeser offset baca. Sekarang hanya opasitas dan
  /// posisinya yang berubah; tinggi list tidak pernah tersentuh.
  final ValueNotifier<bool> _chromeTerlihat = ValueNotifier<bool>(true);

  /// Halaman yang paling atas viewport. Mengatur urutan probe dan menentukan
  /// rasio mana yang perlu ditunggu sebelum list pertama tampil.
  final ValueNotifier<int> _indeksAktif = ValueNotifier<int>(0);

  final _scrollController = ScrollController();
  final _listKey = GlobalKey();

  Timer? _saveTimer;
  String? _uid;
  int _jumlahHalamanTerakhir = 0;
  bool _offlineAktif = false;
  bool _sudahRestore = false;

  ReaderRatioController? _rasio;
  String? _rasioUntuk;

  double? _targetOffset;
  bool _restoreTercapai = false;

  /// Hanya menahan preload, bukan decode. Dulu flag ini memakai `setState` dan
  /// ikut menekan decode sampai pengguna berhenti, yang membuat gambar yang
  /// sedang dibaca hilang; sekarang tinggi item sudah pasti, jadi cukup
  /// menahan permintaan pratinjau.
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
    _scrollController.addListener(_onScroll);
    ref.invalidate(historyRepositoryProvider);
    // Angka trafik hanya berlaku untuk satu sesi baca, jadi penghitung dimulai
    // dari nol setiap reader dibuka.
    PenghitungTrafik.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _simpanPosisi();
    unawaited(SyncService.dorongSekarang(_uid, mangaId: widget.mangaId));
    _scrollController.dispose();
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
      _simpanPosisi();
      unawaited(ref.read(syncServiceProvider).flushTertunda());
    }
  }

  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _simpanPosisi);
  }

  bool _onScrollNotification(ScrollNotification notifikasi) {
    if (notifikasi is ScrollStartNotification) {
      // Hanya flag; tidak ada `setState`, jadi list tidak dibangun ulang.
      _sedangGeres = true;
    } else if (notifikasi is ScrollEndNotification) {
      _sedangGeres = false;
      _perbaruiIndeksAktif();
      // Jendela probe mengikuti halaman yang sedang tampil, bukan seluruh
      // chapter. Chapter yang hanya dibaca seperempat cukup mengirim probe
      // seperempat saja.
      _rasio?.aturJendela(_indeksAktif.value);
      _preload();
    }

    if (notifikasi is UserScrollNotification &&
        notifikasi.direction != ScrollDirection.idle) {
      _targetOffset = null;
      _restoreTercapai = true;
    }
    return false;
  }

  /// Cari halaman teratas yang masih terlihat.
  ///
  /// Dipanggil hanya saat scroll selesai, bukan per frame. Tinggi item dihitung
  /// dari rasio, jadi hasilnya sama dengan tinggi yang benar-benar dipakai
  /// `AspectRatio`.
  void _perbaruiIndeksAktif() {
    final controller = _rasio;
    if (controller == null) return;
    if (!_scrollController.hasClients) return;
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final lebar = box.size.width;
    final atas = _scrollController.offset;
    var kumulatif = 0.0;
    var ditemukan = 0;
    for (var i = 0; i < controller.pages.length; i++) {
      final rasio = controller.rasioEfektif(i);
      final tinggi = rasio > 0 ? lebar / rasio : lebar;
      if (kumulatif + tinggi > atas + 1) {
        ditemukan = i;
        break;
      }
      kumulatif += tinggi;
    }
    if (_indeksAktif.value != ditemukan) _indeksAktif.value = ditemukan;
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

  void _siapkanRasio(List<manga.Page> pages, {required bool offline}) {
    final kunci = '${offline}_${widget.chapterId}_${pages.length}';
    if (_rasio != null && _rasioUntuk == kunci) return;
    // Bukan `dispose()`: notifier lama masih didengarkan item yang belum
    // rebuilt.
    _rasio?.hentikan();
    _rasioUntuk = kunci;

    final controller = ReaderRatioController(pages: pages, online: !offline);
    _rasio = controller;
    _offlineAktif = offline;

    final tersimpan = ref.read(historyRepositoryProvider)[widget.mangaId];
    final awal = tersimpan?.lastChapterId == widget.chapterId
        ? _perkiraanIndeksAwal(tersimpan?.scrollOffset ?? 0, controller)
        : 0;
    _indeksAktif.value = awal;

    unawaited(
      controller.tungguAwal(awal).then((_) {
        // Rasio untuk halaman yang terlihat sudah ada; list tampil dengan
        // fallback sisanya. `setState` satu kali agar tinggi yang terkunci
        // ikut terpasang, lalu posisi baca dicoba lagi karena `maxScrollExtent`
        // yang dipakai frame pertama masih memakai rasio estimasi.
        if (!mounted) return;
        setState(() {});
        _cobaRestore();
      }),
    );
  }

  /// Tebakan halaman awal hanya untuk mengurutkan probe dan menentukan rasio
  /// mana yang ditunggu. Menebak seperti ini tidak pernah menggeser scroll.
  int _perkiraanIndeksAwal(double offset, ReaderRatioController controller) {
    if (offset <= 0) return 0;
    final lebar = MediaQuery.sizeOf(context).width;
    var kumulatif = 0.0;
    for (var i = 0; i < controller.pages.length; i++) {
      final rasio = controller.rasioEfektif(i);
      kumulatif += rasio > 0 ? lebar / rasio : lebar;
      if (kumulatif > offset) return i;
    }
    return controller.pages.length - 1;
  }

  /// Jaring pengaman: rasio asli dari `ImageInfo`, dipakai hanya kalau probe
  /// header gagal. Nilai yang sudah cocok dilewati supaya tidak menulis Hive
  /// berulang.
  void _adopsiDimensi(int index, int width, int height) {
    final controller = _rasio;
    if (controller == null || width <= 0 || height <= 0) return;
    controller.tetapkan(index, width / height);
  }

  /// Rasio masuk setelah halaman tampil, jadi tinggi item berubah. Kalau item
  /// itu berada di atas layar, geser scroll sebesar perubahan tinggi supaya
  /// konten yang sedang dibaca tidak loncat.
  void _kompensasiTinggi(double top, double deltaTinggi) {
    if (deltaTinggi.abs() < 0.5) return;
    if (top >= 0) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final dari = _scrollController.offset;
    final sampai = (dari + deltaTinggi).clamp(0.0, position.maxScrollExtent);
    if ((sampai - dari).abs() < 0.5) return;
    _scrollController.jumpTo(sampai);
  }

  /// Dua halaman ke depan dari halaman yang sedang tampil.
  ///
  /// Cache manager, kunci cache, dan batas decode semuanya identik dengan
  /// yang diminta `ReaderImage`. Kalau salah satu beda, `ResizeImage` dan
  /// `CachedNetworkImageProvider` menghasilkan kunci `ImageCache` yang lain,
  /// hasil preload tidak akan dipakai, dan satu url terunduh dua kali.
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
      body: Stack(
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
          // Chrome menumpuk di atas list, jadi menampilkan atau
          // menyembunyikannya tidak pernah mengubah tinggi konten.
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
      child: ListView.builder(
        key: _listKey,
        controller: _scrollController,
        padding: EdgeInsets.zero,
        // 1,5 kali tinggi layar. `ScrollCacheExtent.viewport` menyatakan
        // angka sebagai pengali sumbu utama viewport, jadi nilainya ikut
        // menyesuaikan orientasi dan tinggi layar tanpa perlu membaca
        // MediaQuery di sini.
        // Cukup untuk scroll kontinu tanpa decode berhenti, tanpa menahan
        // terlalu banyak bitmap besar sekaligus.
        scrollCacheExtent: const ScrollCacheExtent.viewport(1.5),
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
