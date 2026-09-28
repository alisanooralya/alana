import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

const double paddingHorizontalUpdate = 10;
const double jarakAntarSelUpdate = 10;

const double _rasioCover = 0.69;

const double _tinggiJudul = 38;

const double _tinggiChip = 27;
const double _jarakAntarChip = 7;

const int _chapterPerSel = 2;

double _hitungLebarSel(double lebarLayar) {
  return (lebarLayar - paddingHorizontalUpdate * 2 - jarakAntarSelUpdate) / 2;
}

double hitungTinggiSel(double lebarLayar) {
  return _hitungLebarSel(lebarLayar) / _rasioCover +
      8 +
      _tinggiJudul +
      _chapterPerSel * _tinggiChip +
      (_chapterPerSel - 1) * _jarakAntarChip;
}

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chapters = manga.recentChapterTerbaru(jumlah: _chapterPerSel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => bukaDetailManga(context, manga),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: _rasioCover,
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
        ),
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
          if (i > 0) const SizedBox(height: _jarakAntarChip),
          ChipChapter(
            chapter: chapters[i],
            onTap: () => bacaChapter(context, manga, chapters[i]),
          ),
        ],
      ],
    );
  }
}

class _BenderaNegara extends StatelessWidget {
  const _BenderaNegara(this.manga);

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 34,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        _emojiBendera(manga.countryCode),
        style: const TextStyle(fontSize: 17),
      ),
    );
  }
}

String _emojiBendera(String kode) {
  final bersih = kode.trim().toUpperCase();
  if (bersih.length != 2) return bersih;
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(bersih)) return bersih;

  const awal = 0x1F1E6;
  return String.fromCharCodes([
    awal + bersih.codeUnitAt(0) - 0x41,
    awal + bersih.codeUnitAt(1) - 0x41,
  ]);
}

class ChipChapter extends StatelessWidget {
  const ChipChapter({super.key, required this.chapter, required this.onTap});

  final RecentChapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waktu = formatRelativeTimePendek(chapter.createdAt);

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _tinggiChip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Chapter ${chapter.number}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (waktu.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    waktu,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void bacaChapter(BuildContext context, Manga manga, RecentChapter chapter) {
  if (manga.url.isEmpty || chapter.id.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Chapter ini belum bisa dibuka.')),
      );
    return;
  }
  context.pushNamed(
    'reader',
    pathParameters: {'mangaId': manga.url, 'chapterId': chapter.id},
    extra: {
      'chapterName': 'Chapter ${chapter.number}',
      'mangaTitle': manga.title,
      'mangaThumbnail': manga.thumbnail,
    },
  );
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
