import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../widgets/manga_grid_view.dart';

/// Tab "Browse" — katalog/popular/search dari API kamu (1 sumber permanen,
/// jadi tidak butuh pemilihan "source" seperti mangayomi).
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
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
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Cari manga...',
            border: InputBorder.none,
          ),
          onSubmitted: (query) {
            // TODO: panggil API search dengan `query`.
          },
        ),
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
