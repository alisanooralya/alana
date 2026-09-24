import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/models/manga.dart';

/// Carousel populer harian: geser otomatis tiap 5 detik,
/// bisa digeser manual, lengkap dengan indikator titik.
///
/// Ketuk banner untuk membuka halaman detail.
class PopularCarousel extends StatefulWidget {
  const PopularCarousel({super.key, required this.mangas});

  final List<Manga> mangas;

  @override
  State<PopularCarousel> createState() => _PopularCarouselState();
}

class _PopularCarouselState extends State<PopularCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _halaman = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    if (widget.mangas.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final berikutnya = (_halaman + 1) % widget.mangas.length;
        _controller.animateToPage(
          berikutnya,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _buka(Manga manga) {
    if (manga.url.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('ID judul tidak tersedia.')),
        );
      return;
    }
    context.pushNamed('detail', pathParameters: {'mangaId': manga.url});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Populer Hari Ini',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.mangas.length,
            onPageChanged: (index) {
              setState(() => _halaman = index);
            },
            itemBuilder: (context, index) {
              final manga = widget.mangas[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _BannerPopuler(
                  manga: manga,
                  peringkat: index + 1,
                  onTap: () => _buka(manga),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.mangas.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _halaman ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _halaman
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerPopuler extends StatelessWidget {
  const _BannerPopuler({
    required this.manga,
    required this.peringkat,
    required this.onTap,
  });

  final Manga manga;
  final int peringkat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final meta = [
      if (manga.status.isNotEmpty) manga.status,
      if (manga.country.isNotEmpty) manga.country,
    ].join(' • ');

    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CoverImage(
                imageUrl: manga.thumbnail,
                width: 100,
                height: 140,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$peringkat Populer',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                    if (manga.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            manga.rating.toString(),
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
