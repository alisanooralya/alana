import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../widgets/manga_grid_view.dart';

/// Tab "Library" — daftar manga yang sudah disimpan/diikuti user.
/// Nanti ganti `_dummyManga` dengan data dari API/local storage kamu.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<Manga> _dummyManga = const [
    Manga(
      id: '1',
      title: 'One Piece',
      coverUrl:
          'https://cors.caliph.my.id/https://x5.sokuja.uk/uploads/2026/06/marriagetoxin-episode-11-subtitle-indonesia-1781620507423.webp',
      isFavorite: true,
      unreadCount: 12,
    ),
    Manga(
      id: '2',
      title: 'Jujutsu Kaisen',
      coverUrl:
          'https://cors.caliph.my.id/https://x5.sokuja.uk/uploads/2026/06/marriagetoxin-episode-11-subtitle-indonesia-1781620507423.webp',
      unreadCount: 3,
    ),
    Manga(
      id: '3',
      title: 'Chainsaw Man',
      coverUrl:
          'https://cors.caliph.my.id/https://x5.sokuja.uk/uploads/2026/06/marriagetoxin-episode-11-subtitle-indonesia-1781620507423.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: MangaGridView(
        mangaList: _dummyManga,
        onTapManga: (manga) {
          // TODO: navigasi ke halaman detail manga.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Buka detail: ${manga.title}')),
          );
        },
      ),
    );
  }
}
