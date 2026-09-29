import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/features/history/data/reading_history.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.item, this.width = 96});

  final MangaReadingProgress item;

  final double width;

  static const double _ruangSubjudul = 15;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final judul = item.mangaTitle.isEmpty ? item.mangaId : item.mangaTitle;
    final subjudul = item.lastChapterName;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (item.lastChapterId.isEmpty) {
              if (item.mangaId.isEmpty) return;
              context.pushNamed(
                'detail',
                pathParameters: {'mangaId': item.mangaId},
              );
              return;
            }
            context.pushNamed(
              'reader',
              pathParameters: {
                'mangaId': item.mangaId,
                'chapterId': item.lastChapterId,
              },
              extra: {
                'chapterName': item.lastChapterName,
                'mangaTitle': item.mangaTitle,
                'mangaThumbnail': item.mangaThumbnail,
              },
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: CoverImage(
                  imageUrl: item.mangaThumbnail,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: _ruangSubjudul),
                        child: Text(
                          judul,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
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
                          subjudul.isEmpty ? 'Tanpa chapter' : subjudul,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: subjudul.isEmpty
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
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
