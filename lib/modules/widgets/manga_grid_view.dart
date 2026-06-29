// Diadaptasi & disederhanakan dari mangayomi (https://github.com/kodjodevf/mangayomi)
// Lisensi asal: Apache-2.0 — Copyright 2023 Moustapha Kodjo Amadou

import 'package:flutter/material.dart';
import '../models/manga.dart';
import 'manga_card_widget.dart';

/// Grid sederhana untuk menampilkan daftar manga (mirip tampilan Library
/// di mangayomi). Atur jumlah kolom lewat [crossAxisCount].
class MangaGridView extends StatelessWidget {
  final List<Manga> mangaList;
  final int crossAxisCount;
  final MangaCardStyle style;
  final void Function(Manga manga) onTapManga;
  final void Function(Manga manga)? onLongPressManga;

  const MangaGridView({
    super.key,
    required this.mangaList,
    required this.onTapManga,
    this.crossAxisCount = 3,
    this.style = MangaCardStyle.compact,
    this.onLongPressManga,
  });

  @override
  Widget build(BuildContext context) {
    if (mangaList.isEmpty) {
      return const Center(child: Text('Belum ada manga di library'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65, // rasio poster manga (potrait)
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: mangaList.length,
      itemBuilder: (context, index) {
        final manga = mangaList[index];
        return MangaCardWidget(
          manga: manga,
          style: style,
          onTap: () => onTapManga(manga),
          onLongPress: onLongPressManga == null
              ? null
              : () => onLongPressManga!(manga),
        );
      },
    );
  }
}
