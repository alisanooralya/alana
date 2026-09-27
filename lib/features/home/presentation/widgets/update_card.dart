import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

/// Jarak tepi dan antar kolom sengaja sama, lalu dipecah dua kolom.
const double paddingHorizontalUpdate = 10;
const double jarakAntarSelUpdate = 10;

/// Lebar cover dibagi tinggi cover. Dipakai [LoadingGrid] juga.
const double rasioCoverUpdate = 0.69;

const double _tinggiJudul = 38;

const double tinggiChip = 23;
const double jarakAntarChip = 6;

const int _chapterPerSel = 2;

double hitungLebarSel(double lebarLayar) {
  return (lebarLayar - paddingHorizontalUpdate * 2 - jarakAntarSelUpdate) / 2;
}

/// Dipakai `mainAxisExtent`, bukan `childAspectRatio`, supaya semua sel sama
/// tinggi dan chip pasti muat.
double hitungTinggiSel(double lebarLayar) {
  return hitungLebarSel(lebarLayar) / rasioCoverUpdate +
      8 + // jarak cover ke judul
      _tinggiJudul +
      _chapterPerSel * tinggiChip +
      (_chapterPerSel - 1) * jarakAntarChip;
}

/// Satu sel daftar "Pembaruan Terbaru": cover, judul, chip chapter bertumpuk.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chapters = manga.recentChapterTerbaru(jumlah: _chapterPerSel);

    return InkWell(
      onTap: () => bukaDetailManga(context, manga),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: rasioCoverUpdate,
                child: CoverImage(
                  imageUrl: manga.thumbnail,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 12,
                ),
              ),
              if (manga.countryCode.isNotEmpty)
                Positioned(right: 6, bottom: 6, child: _BenderaNegara(manga)),
            ],
          ),
          // Di tengah ruang sisa: judul satu baris kalau menempel ke cover
          // akan terlihat melayang jauh di atas chip-nya.
          Expanded(
            child: Center(
              child: Text(
                manga.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ),
          for (var i = 0; i < chapters.length; i++) ...[
            if (i > 0) const SizedBox(height: jarakAntarChip),
            ChipChapter(chapter: chapters[i]),
          ],
        ],
      ),
    );
  }
}

/// Emoji regional indicator, bukan gambar yang diunduh. Di perangkat tanpa
/// glyph bendera, yang tampil jadi huruf kode negara yang tetap terbaca.
class _BenderaNegara extends StatelessWidget {
  const _BenderaNegara(this.manga);

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 26,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        _emojiBendera(manga.countryCode),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// Kode di luar dua huruf dikembalikan apa adanya agar tidak menjadi
/// regional indicator yang salah arti.
String _emojiBendera(String kode) {
  final bersih = kode.trim().toUpperCase();
  if (bersih.length != 2) return bersih;
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(bersih)) return bersih;

  const awal = 0x1F1E6; // regional indicator A
  return String.fromCharCodes([
    awal + bersih.codeUnitAt(0) - 0x41,
    awal + bersih.codeUnitAt(1) - 0x41,
  ]);
}

/// "Chapter 39" di kiri, waktu rilis di kanan, dalam satu pil.
class ChipChapter extends StatelessWidget {
  const ChipChapter({super.key, required this.chapter});

  final RecentChapter chapter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waktu = formatRelativeTimePendek(chapter.createdAt);

    return Container(
      height: tinggiChip,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              'Chapter ${chapter.number}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (waktu.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              waktu,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void bukaDetailManga(BuildContext context, Manga manga) {
  if (manga.url.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('ID judul tidak tersedia.')));
    return;
  }
  context.pushNamed('detail', pathParameters: {'mangaId': manga.url});
}
