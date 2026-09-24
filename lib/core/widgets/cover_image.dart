import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Header HTTP untuk cover (beberapa host CDN memeriksa `Referer`).
const coverImageHeaders = <String, String>{
  'Accept': 'image/*,*/*;q=0.8',
  'Referer': 'https://app.shinigami.asia/',
};

/// Gambar cover ber-cache untuk thumbnail daftar.
///
/// Menghemat internet: gambar yang sudah dibuka tidak diunduh ulang.
/// Menangani sendiri status memuat (spinner) dan gagal (ikon).
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.imageUrl,
    this.width = 56,
    this.height = 76,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.image_not_supported_outlined, size: 40),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        httpHeaders: coverImageHeaders,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined, size: 40),
        ),
      ),
    );
  }
}
