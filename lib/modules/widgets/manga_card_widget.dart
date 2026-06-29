import 'package:flutter/material.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/modules/widgets/cover_view_widget.dart';
import 'package:alana/modules/widgets/bottom_text_widget.dart';

enum MangaCardStyle {
  compact,
  comfortable,
}

class MangaCardWidget extends StatelessWidget {
  final Manga manga;
  final MangaCardStyle style;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MangaCardWidget({
    super.key,
    required this.manga,
    required this.onTap,
    this.style = MangaCardStyle.compact,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isComfortable = style == MangaCardStyle.comfortable;

    return CoverViewWidget(
      isComfortableGrid: isComfortable,
      onTap: onTap,
      onLongPress: onLongPress,
      image: manga.coverUrl.isNotEmpty
          ? NetworkImage(manga.coverUrl)
          : null,
      bottomTextWidget: BottomTextWidget(
        text: manga.title,
        isComfortableGrid: isComfortable,
      ),
      children: [
        if (manga.unreadCount != null && manga.unreadCount! > 0)
          Positioned(
            top: 4,
            right: 4,
            child: _UnreadBadge(count: manga.unreadCount!.toInt()),
          ),
        if (manga.isFavorite)
          const Positioned(
            top: 4,
            left: 4,
            child: Icon(Icons.favorite, color: Colors.redAccent, size: 18),
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
