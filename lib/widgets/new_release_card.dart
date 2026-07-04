import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:alana/models/manga_types.dart';

class NewReleaseCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback? onTap;

  const NewReleaseCard({required this.manga, this.onTap});

  @override
  Widget _buildCountryIcon(String country) {
    switch (country.toLowerCase()) {
      case 'korea':
        return Image.asset(
          'assets/icons/korea.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      case 'china':
        return Image.asset(
          'assets/icons/china.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      case 'english':
        return Image.asset(
          'assets/icons/english.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      case 'japan':
      case 'jepang':
        return Image.asset(
          'assets/icons/japan.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<_DummyChapter> get _dummyChapters => const [
        _DummyChapter(name: 'Chapter 11', time: '10 mnt'),
        _DummyChapter(name: 'Chapter 10', time: '6 hari'),
      ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: manga.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildCountryIcon(manga.country)
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: Colors.black
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._dummyChapters.map(
            (chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ChapterRow(chapter: chapter),
            ),
          ),
        ],
      ),
    );
  }
}

class _DummyChapter {
  final String name;
  final String time;

  const _DummyChapter({required this.name, required this.time});
}

class _ChapterRow extends StatelessWidget {
  final _DummyChapter chapter;

  const _ChapterRow({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            chapter.name,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            chapter.time,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
