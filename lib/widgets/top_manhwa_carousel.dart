import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';

class TopManhwaCarousel extends StatefulWidget {
  final List<Manga> mangas;
  final Duration autoScrollInterval;
  final double height;
  final void Function(Manga manga)? onTap;

  const TopManhwaCarousel({
    super.key,
    required this.mangas,
    this.autoScrollInterval = const Duration(seconds: 4),
    this.height = 200,
    this.onTap,
  });

  @override
  State<TopManhwaCarousel> createState() => _TopManhwaCarouselState();
}

class _TopManhwaCarouselState extends State<TopManhwaCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.mangas.length <= 1) return;

    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!_controller.hasClients) return;

      final nextPage = (_currentPage + 1) % widget.mangas.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetAutoScroll() {
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mangas.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _resetAutoScroll();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.mangas.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final manga = widget.mangas[index];
                  return _CarouselSlide(
                    manga: manga,
                    onTap: () => widget.onTap?.call(manga),
                  );
                },
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: _DotsIndicator(
                count: widget.mangas.length,
                currentIndex: _currentPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselSlide extends StatelessWidget {
  final Manga manga;
  final VoidCallback? onTap;

  const _CarouselSlide({required this.manga, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            manga.thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade800,
              child: const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 40,
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              manga.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _DotsIndicator({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isActive ? Colors.blue : Colors.white.withValues(alpha: 0.6),
          ),
        );
      }),
    );
  }
}
