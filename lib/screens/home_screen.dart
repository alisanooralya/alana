import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';
import 'package:alana/services/manga_api.dart';
import 'package:alana/widgets/top_manhwa_carousel.dart';
import 'package:alana/widgets/manhwa_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MangaApiService _service = MangaApiService();

  List<Manga> _topMangas = [];
  List<Manga> _recommendationMangas = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getPopularManga(),
        _service.getRecommendedManga(),
      ]);

      setState(() {
        _topMangas = results[0].mangas.take(10).toList();
        _recommendationMangas = results[1].mangas.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            if (_isLoading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SizedBox(
                height: 220,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Gagal memuat: $_errorMessage',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else if (_topMangas.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(child: Text('Belum ada data manhwa')),
              )
            else
              TopManhwaCarousel(
                mangas: _topMangas,
                autoScrollInterval: const Duration(seconds: 3),
                height: 220,
                onTap: (manga) {
                  // TODO: ganti dengan navigasi ke halaman detail manga kamu
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Tapped')));
                },
              ),

            const SizedBox(height: 24),

            if (!_isLoading && _errorMessage == null && _recommendationMangas.isNotEmpty)
              _RecommendationMangasSection(
                mangas: _recommendationMangas,
                onSeeAll: () {
                  // TODO: navigasi ke halaman "See All" new release
                },
                onCardTap: (manga) {
                  // TODO: navigasi ke halaman detail manga
                },
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RecommendationMangasSection extends StatelessWidget {
  final List<Manga> mangas;
  final VoidCallback? onSeeAll;
  final void Function(Manga manga)? onCardTap;

  const _RecommendationMangasSection({
    required this.mangas,
    this.onSeeAll,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(color: Colors.blue),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recommendations for you',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Daily',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: const Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            const sidePadding = 8.0;
            const peekFraction = 0.12;

            final cardWidth =
                (constraints.maxWidth - sidePadding * 2 - spacing * 2) /
                (3 + peekFraction);

            return SizedBox(
              height: cardWidth / (2 / 3) + 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                itemCount: mangas.length,
                separatorBuilder: (_, _) => const SizedBox(width: spacing),
                itemBuilder: (context, index) {
                  final manga = mangas[index];
                  return ManhwaCard(
                    manga: manga,
                    width: cardWidth,
                    onTap: () => onCardTap?.call(manga),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
