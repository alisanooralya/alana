import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/page_ratio.dart';
import '../../data/reader_net.dart';

const int batasMemoriReader = 48 << 20;
const int batasPikselReader = batasMemoriReader ~/ 4;

({int? width, int? height}) batasDecode({
  required double lebarLogis,
  required double dpr,
  int batasPiksel = batasPikselReader,
}) {
  final px = (lebarLogis * dpr).round();
  if (px <= 0) return (width: null, height: null);
  return (width: px, height: batasPiksel ~/ px);
}

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

  final BaseCacheManager? cacheManager;
  final ValueListenable<double?> rasio;
  final VoidCallback? onLoaded;

  final void Function(int width, int height)? onDimensi;
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
        widget.onDimensi?.call(info.image.width, info.image.height);
      },
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
    final konten = _offline ? _gambarOffline() : _gambarOnline();

    if (_zoomAktif) {
      return InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _resetZoom,
          child: konten,
        ),
      );
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        ZoomMulaiGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ZoomMulaiGestureRecognizer>(
              () => ZoomMulaiGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onMulai = _mulaiZoom,
            ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _mulaiZoom,
        child: konten,
      ),
    );
  }

  void _mulaiZoom() {
    if (_zoomAktif) return;
    setState(() => _zoomAktif = true);
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

class ZoomMulaiGestureRecognizer extends OneSequenceGestureRecognizer {
  ZoomMulaiGestureRecognizer({super.debugOwner});

  VoidCallback? onMulai;

  final Set<int> _jaris = <int>{};
  bool _sudahMulai = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) => true;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_jaris.isNotEmpty && !_sudahMulai) {
      _sudahMulai = true;
      onMulai?.call();
    }
    _jaris.add(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _jaris.remove(event.pointer);
    }
    if (_jaris.length < 2) _sudahMulai = false;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _jaris.clear();
    _sudahMulai = false;
  }

  @override
  String get debugDescription => 'zoom dua jari';

  @override
  void dispose() {
    _jaris.clear();
    super.dispose();
  }
}
