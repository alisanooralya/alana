import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';

class TopManhwaCarousel extends StatefulWidget {
  final List<Manga> mangas;
  final Duration autoScrollInterval;
  final Duration fadeDuration;
  final double height;

  final void Function(Manga manga)? onTap;

  const TopManhwaCarousel({
    super.key,
    required this.mangas,
    this.autoScrollInterval = const Duration(seconds: 5),
    this.fadeDuration = const Duration(milliseconds: 750),
    this.height = 220,
    this.onTap,
  });

  @override
  State<TopManhwaCarousel> createState() => _TopManhwaCarouselState();
}

class _TopManhwaCarouselState extends State<TopManhwaCarousel> {
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.mangas.length <= 1) return;

    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      _goToIndex((_currentIndex + 1) % widget.mangas.length);
    });
  }

  void _goToIndex(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mangas.isEmpty) {
      return const SizedBox.shrink();
    }

    final manga = widget.mangas[_currentIndex];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: widget.fadeDuration,
                child: Image.network(
                  manga.thumbnail,
                  key: ValueKey('${manga.url}-bg'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const SizedBox.expand(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () => widget.onTap?.call(manga),
                child: AnimatedSwitcher(
                  duration: widget.fadeDuration,
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: _CarouselContent(
                    key: ValueKey(manga.url),
                    manga: manga,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselContent extends StatelessWidget {
  final Manga manga;

  const _CarouselContent({
    super.key,
    required this.manga,
  });

  String _formatTimeAgoLabel(String shortFormat) {
  if (shortFormat.isEmpty) return "-";

  final match = RegExp(r'^(\d+)([a-zA-Z])$').firstMatch(shortFormat.trim());
  if (match == null) return shortFormat;

  final value = int.tryParse(match.group(1) ?? '') ?? 0;
  final unit = match.group(2) ?? '';

  String unitLabel;
    switch (unit) {
      case 'm':
        unitLabel = 'minute';
        break;
      case 'H':
        unitLabel = 'hour';
        break;
      case 'D':
        unitLabel = 'day';
        break;
      case 'W':
        unitLabel = 'week';
        break;
      case 'M':
        unitLabel = 'month';
        break;
      case 'Y':
        unitLabel = 'year';
        break;
      default:
        return shortFormat;
    }

    return '$value $unitLabel${value > 1 ? 's' : ''} ago';
  }

  String _formatCount(int value) {
    if (value < 1000) return '$value';

    if (value < 1000000) {
      final k = value / 1000;
      final formatted = k == k.roundToDouble()
          ? k.toStringAsFixed(0)
          : k.toStringAsFixed(1);
      return '${formatted}k';
    }

    final m = value / 1000000;
    final formatted = m == m.roundToDouble()
        ? m.toStringAsFixed(0)
        : m.toStringAsFixed(1);
    return '${formatted}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4.2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  manga.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade800,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoLine(label: 'Title', value: manga.title),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'Latest update',
                value: manga.latestChapterDate.isNotEmpty
                    ? _formatTimeAgoLabel(manga.latestChapterDate)
                    : '-',
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'Country',
                value: manga.country.isNotEmpty ? manga.country : '-',
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'View count',
                value: manga.viewCount > 0
                    ? _formatCount(manga.viewCount)
                    : '-',
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'Rating',
                value: manga.rating > 0 ? manga.rating.toStringAsFixed(1) : '-',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.white),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
