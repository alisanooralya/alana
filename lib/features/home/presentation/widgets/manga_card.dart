import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';

/// Kartu vertikal untuk satu judul (cover + judul + info singkat).
///
/// Dipakai di daftar horizontal Beranda dan grid Pencarian/Jelajah.
/// Ketuk kartu membuka halaman detail.
///
/// Area teks memakai [Expanded] + [Flexible] supaya kartu tidak pernah
/// overflow: tinggi cover mengikuti lebar (rasio 3:4), sedangkan tinggi
/// teks adalah sisa dari tinggi yang diberikan parent. Pendekatan lama
/// (tinggi kartu = hasil kali dua konstanta) meluber di grid 3 kolom dan
/// di baris horizontal Beranda, dan akan meluber lagi begitu pengguna
/// memperbesar font lewat setelan aksesibilitas.
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
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: CoverImage(
                  imageUrl: manga.thumbnail,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          manga.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          manga.status.isEmpty
                              ? 'Status tidak diketahui'
                              : manga.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
