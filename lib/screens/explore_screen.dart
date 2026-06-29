import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../widgets/manga_grid_view.dart';
import '../widgets/app_header.dart';

/// Tab "Explore" — katalog/popular/search dari API kamu (1 sumber permanen,
/// jadi tidak butuh pemilihan "source" seperti mangayomi).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  // TODO: ganti dengan hasil fetch dari API (mis. endpoint /popular atau /search).
  final List<Manga> _results = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        onSearchTap: () {
          // TODO: buka search bar / halaman search untuk cari manga.
        },
        onNotificationTap: () {
          // TODO: arahkan ke halaman notifikasi.
        },
      ),
      body: _results.isEmpty
          ? const Center(child: Text('Belum ada hasil. Coba cari manga.'))
          : MangaGridView(
              mangaList: _results,
              onTapManga: (manga) {
                // TODO: navigasi ke halaman detail manga.
              },
            ),
    );
  }
}
