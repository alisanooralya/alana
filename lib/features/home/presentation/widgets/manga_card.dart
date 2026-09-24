import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/models/manga.dart';

/// Kartu vertikal untuk satu judul (cover + judul + info singkat).
///
/// Dipakai di daftar horizontal Beranda dan grid Pencarian.
/// Ketuk kartu membuka halaman detail.
class MangaCard extends StatelessWidget {
  const MangaCard({super.key, required this.manga, this.width = 130});

  final Manga manga;

  /// Lebar kartu. Tinggi cover mengikuti rasio 3:4.
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (manga.url.isEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('ID judul tidak tersedia.')),
                );
              return;
            }
            context.pushNamed('detail', pathParameters: {'mangaId': manga.url});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: manga.thumbnail.isEmpty
                    ? const Icon(Icons.image_not_supported_outlined, size: 40)
                    : Image.network(
                        manga.thumbnail,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      manga.status.isEmpty
                          ? 'Status tidak diketahui'
                          : manga.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
