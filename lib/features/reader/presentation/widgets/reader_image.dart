import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Satu gambar halaman di reader vertikal (ber-cache).
///
/// - Full-width tanpa jarak (diatur list induk).
/// - Cache disk + memori: gambar yang sudah dibuka tidak diunduh ulang.
/// - Placeholder berukuran tetap selama memuat agar scroll tidak loncat.
/// - Gagal muat menampilkan tombol coba lagi per gambar.
/// - Cubit untuk zoom via [InteractiveViewer] (`panEnabled: false`
///   agar gestur scroll vertikal tetap diteruskan ke list).
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
  int _attempt = 0;
  bool _notified = false;

  void _notifyLoaded() {
    if (_notified) return;
    _notified = true;
    final callback = widget.onLoaded;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Estimasi tinggi placeholder: strip webtoon umumnya jauh lebih
    // tinggi daripada lebar layar.
    final placeholderHeight = MediaQuery.of(context).size.width * 1.5;

    if (widget.localPath != null && widget.localPath!.isNotEmpty) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        panEnabled: false,
        child: Image.file(
          File(widget.localPath!),
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            height: placeholderHeight,
            child: const Center(
              child: Text('File gambar offline tidak tersedia.'),
            ),
          ),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      // Geser satu jari tetap milik ListView; cubit dua jari untuk zoom.
      panEnabled: false,
      child: CachedNetworkImage(
        key: ValueKey('reader-$_attempt-${widget.imageUrl}'),
        imageUrl: widget.imageUrl,
        httpHeaders: widget.headers,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        fadeInDuration: const Duration(milliseconds: 200),
        imageBuilder: (context, imageProvider) {
          _notifyLoaded();
          return Image(
            image: imageProvider,
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
  }
}
