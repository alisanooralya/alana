import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const faktorTinggiDecode = 2;

({int? width, int? height}) batasDecode({
  required double lebarLogis,
  required double tinggiLogis,
  required double dpr,
  int faktorTinggi = faktorTinggiDecode,
}) {
  final px = (lebarLogis * dpr).round();
  final py = (tinggiLogis * dpr * faktorTinggi).round();
  return (width: px > 0 ? px : null, height: py > 0 ? py : null);
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
    final ukuran = MediaQuery.sizeOf(context);
    return batasDecode(
      lebarLogis: ukuran.width,
      tinggiLogis: ukuran.height,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholderHeight = MediaQuery.of(context).size.width * 1.5;
    final batas = _batasDecode(context);

    final viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomAktif,
      child: widget.localPath != null && widget.localPath!.isNotEmpty
          ? Image.file(
              File(widget.localPath!),
              width: double.infinity,
              fit: BoxFit.fitWidth,
              cacheWidth: batas.width,
              cacheHeight: batas.height,
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
