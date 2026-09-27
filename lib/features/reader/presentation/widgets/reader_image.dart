import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Berapa kali tinggi viewport dipakai sebagai batas tinggi decode.
///
/// Strip webtoon dari API ini umumnya 800 x 9700. Karena Flutter tidak pernah
/// memperbesar, batas lebar sama sekali tidak berefek kalau gambar sumber
/// lebih sempit daripada layar fisikal - di ponsel 400 x 800 dpr 3, lebar
/// fisikanya 1200 px sedangkan sumbernya cuma 800 px. Yang membatasi hanya
/// tinggi.
///
/// Dua kali tinggi viewport berarti satu gambar decode menutup dua layar
/// penuh, cukup untuk menggeser tanpa bagian yang belum terlihat ikut terpotong
/// kasar. Strip 800 x 9700 di perangkat itu jadi 395 x 4800, turun dari
/// sekitar 30 MB ke sekitar 7,6 MB. Empat halaman yang hidup bersamaan jadi
/// di bawah 32 MB, sebelumnya lebih dari 110 MB.
///
/// Menaikkan nilai ini tidak menambah ketajaman: gambar sumber 800 px tetap
/// akan diperbesar saat digambar di layar dpr 3; yang kita atur hanya berapa
/// tinggi yang didecode.
const faktorTinggiDecode = 2;

/// Batas dimensi decode dalam piksel fisik.
///
/// Dipisah dari widget supaya bisa diuji tanpa `MediaQuery`. Nilai `null`
/// berarti biarkan Flutter yang menentukan.
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

/// [ReaderImage] menampilkan satu gambar halaman di reader vertikal
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

  /// Batas dimensi decode: lebar mengikuti lebar layar, tinggi dibatasi
  /// beberapa kali tinggi layar.
  ///
  /// Tanpa batas tinggi, gambar yang sangat panjang hanya dilebihkan lebar,
  /// sehingga tinggi decode-nya tetap mengikuti aslinya. Strip webtoon
  /// 800 x 9700 jadi sekitar 800 x 9700, yaitu hampir 30 MB per halaman.
  ///
  /// Rasio aspek tetap terjaga karena kedua batas dipakai dengan
  /// [ResizeImagePolicy.fit], yang hanya memperkecil dan tidak pernah
  /// membesar.
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
    // Estimasi tinggi placeholder: strip webtoon umumnya jauh lebih
    // tinggi daripada lebar layar.
    final placeholderHeight = MediaQuery.of(context).size.width * 1.5;
    final batas = _batasDecode(context);

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
                    // fit: skala agar muat dalam batas dengan rasio aspek
                    // terjaga. Tanpa ini ResizeImage memakai policy exact dan
                    // meregangkan gambar yang tidak sesuai rasio.
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

    // Ketuk ganda hanya dipasang saat sedang zoom supaya tidak mengganggu
    // ketuk tunggal yang mengatur visibilitas AppBar.
    if (!_zoomAktif) return viewer;
    return GestureDetector(onDoubleTap: _resetZoom, child: viewer);
  }
}
