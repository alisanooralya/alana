import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Satu gambar halaman di reader vertikal (ber-cache).
///
/// - Full-width tanpa jarak (diatur list induk).
/// - Cache disk + memori: gambar yang sudah dibuka tidak diunduh ulang.
/// - Placeholder berukuran tetap selama memuat agar scroll tidak loncat.
/// - Gagal muat menampilkan tombol coba lagi per gambar.
/// - Zoom: cubit untuk memperbesar, satu jari untuk menggeser gambar yang
///   sudah membesar. Saat belum zoom, gestur satu jari diteruskan ke list
///   supaya halaman masih bisa di-scroll.
/// - [onLoaded] dipanggil sekali saat gambar berhasil tampil,
///   dipakai induk untuk preload gambar berikutnya.
class ReaderImage extends StatefulWidget {
  const ReaderImage({
    super.key,
    required this.imageUrl,
    required this.headers,
    this.localPath,
    this.onLoaded,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final String? localPath;
  final VoidCallback? onLoaded;

  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  final TransformationController _transform = TransformationController();
  int _attempt = 0;
  bool _notified = false;
  bool _zoomAktif = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoom = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoom != _zoomAktif) setState(() => _zoomAktif = zoom);
  }

  void _resetZoom() {
    if (!_zoomAktif) return;
    _transform.value = Matrix4.identity();
  }

  void _notifyLoaded() {
    if (_notified) return;
    _notified = true;
    final callback = widget.onLoaded;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  /// Lebar decode dalam piksel fisik: cukup untuk ukuran tampil di layar.
  ///
  /// Tanpa batas ini Flutter men-decode gambar pada ukuran aslinya. Strip
  /// webtoon dari API ini berukuran sekitar 800 x 9700, yaitu sekitar 30 MB
  /// per halaman sebagai bitmap ARGB8; sepuluh halaman sudah melampaui
  /// batas cache gambar Flutter sehingga terjadi thrashing terus-menerus.
  static int? _decodeWidth(BuildContext context) {
    final logical = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final px = (logical * dpr).round();
    return px > 0 ? px : null;
  }

  @override
  Widget build(BuildContext context) {
    // Estimasi tinggi placeholder: strip webtoon umumnya jauh lebih
    // tinggi daripada lebar layar.
    final placeholderHeight = MediaQuery.of(context).size.width * 1.5;
    final decodeWidth = _decodeWidth(context);

    final viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      // Pan hanya diizinkan saat sedang zoom. Dengan panEnabled selalu
      // false, gambar yang sudah diperbesar tidak bisa digeser sama sekali
      // sehingga tidak ada jalan keluar selain mencubit balik.
      panEnabled: _zoomAktif,
      child: widget.localPath != null && widget.localPath!.isNotEmpty
          ? Image.file(
              File(widget.localPath!),
              width: double.infinity,
              fit: BoxFit.fitWidth,
              cacheWidth: decodeWidth,
              errorBuilder: (context, error, stackTrace) => SizedBox(
                height: placeholderHeight,
                child: const Center(
                  child: Text('File gambar offline tidak tersedia.'),
                ),
              ),
            )
          : CachedNetworkImage(
              key: ValueKey('reader-$_attempt-${widget.imageUrl}'),
              imageUrl: widget.imageUrl,
              httpHeaders: widget.headers,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              fadeInDuration: const Duration(milliseconds: 200),
              imageBuilder: (context, imageProvider) {
                _notifyLoaded();
                return Image(
                  image: ResizeImage(imageProvider, width: decodeWidth),
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                );
              },
              placeholder: (context, url) => SizedBox(
                height: placeholderHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Memuat gambar…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              errorWidget: (context, url, error) => SizedBox(
                height: placeholderHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined, size: 48),
                      const SizedBox(height: 8),
                      const Text('Gagal memuat gambar.'),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _attempt++);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );

    // Ketuk ganda hanya dipasang saat sedang zoom supaya tidak mengganggu
    // ketuk tunggal yang mengatur visibilitas AppBar.
    if (!_zoomAktif) return viewer;
    return GestureDetector(onDoubleTap: _resetZoom, child: viewer);
  }
}
