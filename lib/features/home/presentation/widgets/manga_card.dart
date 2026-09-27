import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';

/// Kartu vertikal untuk satu judul. Dipakai di daftar horizontal Beranda dan
/// grid Pencarian/Jelajah.
///
/// [Expanded] + [Stack] supaya tidak pernah overflow: tinggi cover mengikuti
/// lebar (3:4), sisa tinggi dipakai teks. Versi lama menjumlahkan tinggi dari
/// dua konstanta dan meluber di grid 3 kolom maupun saat font diperbesar.
///
/// Status dipatok ke dasar dengan [Positioned] supaya tidak ikut naik-turun
/// mengikuti jumlah baris judul, dan [Padding] bawah judul mencegah baris
/// terakhirnya menabrak status.
class MangaCard extends StatelessWidget {
  const MangaCard({super.key, required this.manga, this.width = 130});

  final Manga manga;

  /// Lebar kartu. Tinggi cover mengikuti rasio 3:4.
  final double width;

  /// Ruang untuk baris status di bawah judul.
  static const double _ruangStatus = 17;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Status kosong dibiarkan netral: diberi warna status, ketiadaan data
    // terlihat seperti data yang valid.
    final status = manga.status;
    final adaStatus = status.isNotEmpty;

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
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: _ruangStatus),
                        child: Text(
                          manga.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Text(
                          adaStatus ? status : 'Tanpa status',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: adaStatus
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
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
