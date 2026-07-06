import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:alana/models/manga_types.dart';

class RecommendationCard extends StatelessWidget {
  final Manga manga;
  final double width;
  final double aspectRatio;

  final VoidCallback? onTap;

  const RecommendationCard({
    super.key,
    required this.manga,
    this.width = 130,
    this.aspectRatio = 2 / 3,
    this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                          color: Colors.white54,
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildCountryIcon(manga.country),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
