import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Batas memori per gambar yang sudah di-decode (RGBA, 4 byte per piksel).
///
/// Dinyatakan dalam byte, bukan piksel, supaya tidak salah baca: 8 juta piksel
/// itu 32 MB, bukan 8 MB.
///
/// Trade-off yang disengaja: makin kecil batasnya, makin banyak strip yang muat
/// di `imageCache` sehingga lebih sedikit yang terevict, tapi strip yang lebih
/// tinggi dari batas ikut jadi kecil dan harus diperbesar saat ditampilkan.
/// Di 48 MB, Goblin Inc (800x10228) dan Infinite Mage (800x12777) sama-sama
/// cuma di-upscale 1,5x. Turunkan ke 32 MB untuk tambah muat di cache, tapi
/// Infinite Mage jadi 2,2x dan terasa lembut.
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

class ReaderImage extends StatefulWidget {
  const ReaderImage({
    super.key,
    required this.imageUrl,
    required this.headers,
    this.localPath,
    this.onLoaded,
    this.sedangGeser = false,
    this.onTerlihat,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final String? localPath;
  final VoidCallback? onLoaded;

  /// True selama pengguna sedang menggeser daftar.
  ///
  /// Saat true dan gambar ini belum pernah tampil, widget hanya drew
  /// placeholder tanpa memulai decode. Tanpa gerbang ini, `ListView.builder`
  /// membangun item jauh lebih cepat daripada decode selesai saat di-fling, dan
  /// tiap strip webtoon 37 MB langsung masuk antrean. Akibatnya `imageCache`
  /// penuh, evict, lalu gambar yang sudah dibaca hilang.
  final bool sedangGeser;

  /// Dipanggil sekali saat item ini menjadi yang teratas di layar.
  ///
  /// Ini yang memberi tahu halamanZTiap reader halaman berapa yang sedang dibaca,
  /// untuk evict halaman lain di luar jendela. Widget memeriksa sendiri
  /// posisinya lewat post-frame callback, jadi halaman reader tidak perlu
  /// menghitung offset tiap item.
  final VoidCallback? onTerlihat;

  @override
  State<ReaderImage> createState() => _ReaderImageState();
}

class _ReaderImageState extends State<ReaderImage> {
  final TransformationController _transform = TransformationController();
  int _attempt = 0;
  bool _sudahTampil = false;
  bool _zoomAktif = false;
  bool _sudahMelapor = false;

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

  void _periksaPosisi() {
    if (_sudahMelapor || widget.onTerlihat == null) return;

    final context = this.context;
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;

    final posisi = box.localToGlobal(Offset.zero).dy;
    final tinggiLayar = MediaQuery.sizeOf(context).height;

    // Item dianggap "teratas" kalau puncaknya sudah melewati atau menyentuh
    // tepi atas layar, tapi masih jauh dari bawah. Hanya satu item yang bisa
    // memenuhi ini pada satu waktu, jadi tidak perlu rebutan antar widget.
    if (posisi > 24 || posisi < -tinggiLayar * 0.75) return;

    _sudahMelapor = true;
    widget.onTerlihat!.call();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      widget.onLoaded?.call();
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

    // Gambar yang sudah pernah tampil tidak pernah dikembalikan jadi
    // placeholder, jadi tidak ada kedip saat pengguna menggeser.
    if (widget.sedangGeser && !_sudahTampil) {
      return SizedBox(
        height: placeholderHeight,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

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
              // Tanpa frameBuilder ini jalur offline tidak pernah menandai
              // gambar sebagai tampil, jadi gerbang `sedangGeser` akan
              // menaruhnya balik jadi spinner setiap kali digeser.
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (frame != null) _tandaiTampil();
                return child;
              },
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
                _tandaiTampil();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _periksaPosisi();
    });

    if (!_zoomAktif) return viewer;
    return GestureDetector(onDoubleTap: _resetZoom, child: viewer);
  }
}
