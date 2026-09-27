import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';

/// Kartu vertikal untuk satu judul (cover + judul + info singkat).
///
/// Dipakai di daftar horizontal Beranda dan grid Pencarian/Jelajah.
/// Ketuk kartu membuka halaman detail.
///
/// Area teks memakai [Expanded] + [Stack] supaya kartu tidak pernah overflow:
/// tinggi cover mengikuti lebar (rasio 3:4), sedangkan tinggi teks adalah sisa
/// dari tinggi yang diberikan parent. Pendekatan lama (tinggi kartu = hasil kali
/// dua konstanta) meluber di grid 3 kolom dan di baris horizontal Beranda, dan
/// akan meluber lagi begitu pengguna memperbesar font lewat setelan
/// aksesibilitas.
///
/// Baris status dipatok ke dasar kartu dengan [Positioned], bukan menyatu di
/// bawah judul. Kalau ikut mengalir, judul satu baris membuat status naik
/// sedangkan judul dua baris menurunkannya, jadi deretan kartu terlihat
/// bergerigi. [Padding] bawah pada judul juga mencegah baris terakhirnya menabrak
/// baris status.
class MangaCard extends StatelessWidget {
  const MangaCard({super.key, required this.manga, this.width = 130});

  final Manga manga;

  /// Lebar kartu. Tinggi cover mengikuti rasio 3:4.
  final double width;

  /// Ruang yang harus disisakan di bawah judul untuk baris status.
  static const double _ruangStatus = 17;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Status yang tidak diketahui dibiarkan netral. Mewarnainya seperti status
    // sungguhan membuat "Status tidak diketahui" terlihat seperti data yang
    // valid, padahal itu sekadar ketiadaan nilai dari server.
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
