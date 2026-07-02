import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';
import 'package:alana/services/manga_api.dart';
import 'package:alana/widgets/top_manhwa_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MangaApiService _service = MangaApiService();

  List<Manga> _topMangas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTopManga();
  }

  Future<void> _loadTopManga() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getPopularManga();
      setState(() {
        _topMangas = result.mangas.take(10).toList();
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
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: _loadTopManga,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Top Manhwa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),

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
                autoScrollInterval: const Duration(seconds: 4),
                height: 220,
                onTap: (manga) {
                  // TODO: ganti dengan navigasi ke halaman detail manga kamu
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Tapped')));
                },
              ),

            const SizedBox(height: 24),
            // TODO: tambahkan section lain di sini, misal "Latest Updates"
          ],
        ),
      ),
    );
  }
}
