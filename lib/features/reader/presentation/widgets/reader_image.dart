import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/page_ratio.dart';
import '../../data/reader_net.dart';

/// Batas memori per gambar yang sudah di-decode (RGBA, 4 byte per piksel).
///
/// Dinyatakan dalam byte, bukan piksel, supaya tidak salah baca: 8 juta piksel
/// itu 32 MB, bukan 8 MB.
///
/// Strip 800x12777 yang ter-decode penuh menjadi 729x11650 = 34 MB, jadi
/// beberapa strip muat bersama di `imageCache` tanpa saling menyingkirkan.
const int batasMemoriReader = 48 << 20;

/// Turunan piksel dari [batasMemoriReader]. Harus `const` karena dipakai sebagai
/// nilai bawaan parameter.
const int batasPikselReader = batasMemoriReader ~/ 4;

/// Batas decode dalam piksel.
///
/// [height] di sini bukan tinggi gambar, melainkan plafon jumlah piksel:
/// `batasPiksel / width`. Dipakai bareng `ResizeImagePolicy.fit` supaya rasio
/// aspek tetap terjaga dan tidak pernah di-upscale melebihi lebar sumber.
({int? width, int? height}) batasDecode({
  required double lebarLogis,
  required double dpr,
  int batasPiksel = batasPikselReader,
}) {
  final px = (lebarLogis * dpr).round();
  if (px <= 0) return (width: null, height: null);
  return (width: px, height: batasPiksel ~/ px);
}

/// Warna latar panel yang menggantikan gambar. Hitungan instance bisa
/// melewati batas cache GPU kalau memakai warna terang, jadi gelap.
const Color _warnaPanel = Color(0xFF141414);

class ReaderImage extends StatefulWidget {
  const ReaderImage({
    super.key,
    required this.imageUrl,
    required this.headers,
    this.cacheManager,
    required this.rasio,
    this.localPath,
    this.onLoaded,
    this.onDimensi,
    this.onTinggiBerubah,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final String? localPath;

  /// Cache manager khusus reader. Wajib sama dengan yang dipakai
  /// `precacheImage`, dan `cacheKey` wajib sama juga, supaya hasil preload
  /// benar-benar dipakai dan tidak ada unduhan ganda untuk satu url.
  ///
  /// `null` berarti pakai [readerCacheManager]. Defaultnya ada supaya widget
  /// bisa diuji tanpa membangun cache manager sungguhan; halaman reader tetap
  /// mengirimnya secara eksplisit.
  final BaseCacheManager? cacheManager;

  /// Rasio efektif halaman ini, sudah di-resolve oleh
  /// `ReaderRatioController` memakai urutan: rasio sendiri, tetangga terdekat,
  /// median, lalu konstanta.
  ///
  /// Tinggi item **tidak pernah** memakai tebakan lebar. Pada satu chapter
  /// terukur tinggi antarhalaman ranging dari 276 px sampai 4500 px, jadi
  /// placeholder berbasis lebar salah sampai 20 kali dan itulah penyebab
  /// posisi baca meloncat.
  final ValueListenable<double?> rasio;

  /// Dipanggil sekali setelah gambar benar-benar tampil.
  ///
  /// Tidak pernah dipanggil lebih dulu karena tinggi item sudah pasti dari
  /// `AspectRatio`, jadi pemanggil bebas melakukan kerja berat di sini.
  final VoidCallback? onLoaded;

  /// Jaring pengaman: dimensi asli dari `ImageInfo` setelah decode.
  ///
  /// Dipanggil hanya kalau probe header gagal, dan hanya saat nilainya beda
  /// dari yang sudah dipakai. `ResizeImagePolicy.fit` menjaga rasio, jadi
  /// `width / height` di sini sama dengan rasio sumber.
  final void Function(int width, int height)? onDimensi;

  /// Rasio berubah setelah halaman ini sudah tampil, jadi tinggi item
  /// berubah dan isi viewport ikut bergeser.
  ///
  /// [top] adalah posisi item **sebelum** perubahan (jarak tepi atas item ke
  /// tepi atas layar). Kalau [top] negatif, item berada di atas layar dan
  /// pemanggil harus menggeser scroll sebesar [deltaTinggi] supaya konten
  /// yang sedang dibaca tidak loncat.
  final void Function(double top, double deltaTinggi)? onTinggiBerubah;

  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  final TransformationController _transform = TransformationController();

  int _attempt = 0;
  bool _sudahTampil = false;
  bool _sudahLaporDimensi = false;
  bool _zoomAktif = false;

  double? _topSebelum;
  double _tinggiSebelum = 0;
  ImageStream? _streamDimensi;
  ImageStreamListener? _pendengarDimensi;

  bool get _offline => widget.localPath != null && widget.localPath!.isNotEmpty;

  /// Sama persis dengan yang dipakai `precacheImage`, sehingga kunci cache
  /// yang dihasilkan identik dan tidak ada unduhan ganda.
  BaseCacheManager get _cacheManager =>
      widget.cacheManager ?? readerCacheManager;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    widget.rasio.addListener(_onRasioBerubah);
  }

  @override
  void didUpdateWidget(ReaderImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.rasio, widget.rasio)) {
      old.rasio.removeListener(_onRasioBerubah);
      widget.rasio.addListener(_onRasioBerubah);
    }
  }

  @override
  void dispose() {
    widget.rasio.removeListener(_onRasioBerubah);
    _transform.removeListener(_onTransform);
    _transform.dispose();
    final stream = _streamDimensi;
    final pendengar = _pendengarDimensi;
    if (stream != null && pendengar != null) {
      stream.removeListener(pendengar);
    }
    _streamDimensi = null;
    _pendengarDimensi = null;
    super.dispose();
  }

  /// Rasio baru masuk sementara item ini sudah punya tinggi. Catat posisi
  /// sekarang — sebelum layout baru dihitung — lalu ukur ulang setelah frame
  /// untuk memperkirakan berapa banyak konten yang harus dikompensasi.
  void _onRasioBerubah() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      _topSebelum = null;
      return;
    }
    _topSebelum = box.localToGlobal(Offset.zero).dy;
    _tinggiSebelum = box.size.height;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final top = _topSebelum;
      _topSebelum = null;
      if (top == null) return;
      final after = context.findRenderObject() as RenderBox?;
      if (after == null || !after.hasSize) return;
      final delta = after.size.height - _tinggiSebelum;
      if (delta.abs() < 0.5) return;
      widget.onTinggiBerubah?.call(top, delta);
    });
  }

  void _onTransform() {
    final zoom = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoom != _zoomAktif) setState(() => _zoomAktif = zoom);
  }

  void _resetZoom() {
    if (!_zoomAktif) return;
    _transform.value = Matrix4.identity();
  }

  void _tandaiTampil() {
    if (_sudahTampil) return;
    _sudahTampil = true;
    _laporkanDimensi();
    widget.onLoaded?.call();
  }

  /// Ambil dimensi dari `ImageInfo` provider yang sama persis dengan yang
  /// dirender, lalu lepas listener supaya tidak menahan cache entry.
  void _laporkanDimensi() {
    if (_sudahLaporDimensi) return;
    _sudahLaporDimensi = true;

    final stream = _providerGambar().resolve(
      createLocalImageConfiguration(context),
    );
    _streamDimensi = stream;
    late final ImageStreamListener pendengar;
    void lepas() {
      stream.removeListener(pendengar);
      if (identical(_pendengarDimensi, pendengar)) _pendengarDimensi = null;
      if (identical(_streamDimensi, stream)) _streamDimensi = null;
    }

    pendengar = ImageStreamListener(
      (info, _) {
        lepas();
        // `info.image` milik `imageCache`; jangan di-`dispose` di sini.
        widget.onDimensi?.call(info.image.width, info.image.height);
      },
      // Tanpa ini, gambar yang gagal resolve membuat listener menggantung dan
      // State widget tertahan sampai list dibuang.
      onError: (error, _) => lepas(),
    );
    _pendengarDimensi = pendengar;
    stream.addListener(pendengar);
  }

  ResizeImage _providerGambar() {
    final batas = batasDecode(
      lebarLogis: MediaQuery.sizeOf(context).width,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
    return ResizeImage(
      _offline
          ? FileImage(File(widget.localPath!))
          : CachedNetworkImageProvider(
              widget.imageUrl,
              headers: widget.headers,
              cacheManager: _cacheManager,
              // Derived dari url, bukan dari state widget, jadi provider di
              // dalam `precacheImage` menghasilkan kunci yang sama tanpa perlu
              // berbagi objek apa pun.
              cacheKey: readerCacheKey(widget.imageUrl),
            ),
      width: batas.width,
      height: batas.height,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: widget.rasio,
      builder: (context, rasio, _) {
        return AspectRatio(
          aspectRatio: rasio ?? rasioKonstantaAwal,
          child: _bangunGambar(),
        );
      },
    );
  }

  Widget _bangunGambar() {
    final viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomAktif,
      child: _offline ? _gambarOffline() : _gambarOnline(),
    );
    // Ketuk dua kali mengembalikan zoom. Tanpa ini satu item yang ter-zoom
    // menangkap gesture pan dan list tidak bisa digulir lagi.
    if (!_zoomAktif) return viewer;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _resetZoom,
      child: viewer,
    );
  }

  Widget _gambarOffline() {
    return Image(
      key: ValueKey('offline-$_attempt-${widget.imageUrl}'),
      image: _providerGambar(),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (frame != null) _tandaiTampil();
        return child;
      },
      errorBuilder: (context, error, stackTrace) => _panelError(
        pesan: 'File gambar offline tidak tersedia.',
        kunci: 'err-offline-$_attempt',
        onCobaLagi: () => setState(() => _attempt++),
      ),
    );
  }

  Widget _gambarOnline() {
    // Satu pembacaan MediaQuery per build, bukan dua di dalam `imageBuilder`
    // yang dipanggil sekali per frame decode.
    final batas = batasDecode(
      lebarLogis: MediaQuery.sizeOf(context).width,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
    return CachedNetworkImage(
      key: ValueKey('reader-$_attempt-${widget.imageUrl}'),
      imageUrl: widget.imageUrl,
      httpHeaders: widget.headers,
      cacheManager: _cacheManager,
      cacheKey: readerCacheKey(widget.imageUrl),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      fadeInDuration: Duration.zero,
      imageBuilder: (context, imageProvider) {
        return Image(
          image: ResizeImage(
            imageProvider,
            width: batas.width,
            height: batas.height,
            policy: ResizeImagePolicy.fit,
          ),
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSyncLoaded) {
            if (frame != null) _tandaiTampil();
            return child;
          },
        );
      },
      placeholder: (context, url) => const _Panel(),
      errorWidget: (context, url, error) => _panelError(
        pesan: 'Gagal memuat gambar.',
        kunci: 'err-online-$_attempt',
        onCobaLagi: () => setState(() => _attempt++),
      ),
    );
  }

  Widget _panelError({
    required String pesan,
    required String kunci,
    required VoidCallback onCobaLagi,
  }) {
    return _Panel(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 48),
          const SizedBox(height: 8),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          TextButton.icon(
            key: ValueKey(kunci),
            onPressed: onCobaLagi,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel([this.child]);

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _warnaPanel,
      child: Center(
        child:
            child ??
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
      ),
    );
  }
}
