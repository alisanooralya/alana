import 'package:flutter/material.dart';

/// Satu gambar halaman di reader vertikal.
///
/// - Full-width tanpa jarak (diatur list induk).
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
    this.onLoaded,
  });

  final String imageUrl;
  final Map<String, String> headers;
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

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      // Geser satu jari tetap milik ListView; cubit dua jari untuk zoom.
      panEnabled: false,
      child: Image.network(
        widget.imageUrl,
        key: ValueKey('reader-$_attempt-${widget.imageUrl}'),
        headers: widget.headers,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            _notifyLoaded();
            return child;
          }
          return SizedBox(
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
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
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
          );
        },
      ),
    );
  }
}
