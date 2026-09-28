import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Batas piksel per gambar (RGBA, 4 byte per piksel).
///
/// 16 Mpx = 64 MB. Dulu pembatasnya tinggi gambar (`tinggiLayar * dpr * 2`),
/// dan itu membuat strip webtoon 800x12777 ter-decode jadi 403x4800: karena
/// `fit` memakai skala min, tinggi yang lebih dulu membatasi, padahal yang
/// perlu tajam itu lebarnya.
const int batasPikselReader = 16 * 1024 * 1024;

/// Batas decode dalam piksel.
///
/// [height] di sini bukan tinggi gambar, melainkan plafon jumlah piksel:
/// `batasPiksel / width`. Dipakai bareng `ResizeImagePolicy.fit` supaya
/// rasio aspek tetap terjaga dan tidak pernah di-upscale melebihi lebar sumber.
({int? width, int? height}) batasDecode({
  required double lebarLogis,
  required double dpr,
  int batasPiksel = batasPikselReader,
}) {
  final px = (lebarLogis * dpr).round();
  if (px <= 0) return (width: null, height: null);
  return (width: px, height: batasPiksel ~/ px);
}

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

  ({int? width, int? height}) _batasDecode(BuildContext context) {
    return batasDecode(
      lebarLogis: MediaQuery.sizeOf(context).width,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholderHeight = MediaQuery.of(context).size.width * 0.6;
    final batas = _batasDecode(context);

    final viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomAktif,
      child: widget.localPath != null && widget.localPath!.isNotEmpty
          ? Image(
              // Bukan `Image.file(cacheWidth:, cacheHeight:)`. `cacheWidth`
              // dan `cacheHeight` melewati `ResizeImage.resizeIfNeeded` yang
              // tidak menyertakan `policy`, sehingga default-nya
              // `ResizeImagePolicy.exact`: lebarnya dijepit ke lebar sumber
              // karena `allowUpscaling` false, sementara tingginya dipaksa
              // turun sesuai batas.
              // Strip 800x12777 jadi 800x4800 dan rasio aspeknya meleset
              // 2,66 kali. Path offline wajib memakai policy eksplisit supaya
              // sama dengan path online.
              image: ResizeImage(
                FileImage(File(widget.localPath!)),
                width: batas.width,
                height: batas.height,
                policy: ResizeImagePolicy.fit,
              ),
              width: double.infinity,
              fit: BoxFit.fitWidth,
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
                  image: ResizeImage(
                    imageProvider,
                    width: batas.width,
                    height: batas.height,
                    policy: ResizeImagePolicy.fit,
                  ),
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

    if (!_zoomAktif) return viewer;
    return GestureDetector(onDoubleTap: _resetZoom, child: viewer);
  }
}
