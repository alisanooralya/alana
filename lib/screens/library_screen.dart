import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../widgets/manga_grid_view.dart';
import '../widgets/app_header.dart';

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
          'https://upload.wikimedia.org/wikipedia/en/9/9b/One_Piece%2C_Volume_61_Cover_%28Japanese%29.jpg',
      isFavorite: true,
      unreadCount: 12,
    ),
    Manga(
      id: '2',
      title: 'Jujutsu Kaisen',
      coverUrl:
          'https://upload.wikimedia.org/wikipedia/en/6/64/Jujutsu_Kaisen_volume_1_cover.jpg',
      unreadCount: 3,
    ),
    Manga(
      id: '3',
      title: 'Chainsaw Man',
      coverUrl:
          'https://upload.wikimedia.org/wikipedia/en/0/0d/Chainsaw_Man_vol_1_cover.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        onSearchTap: () {
          // TODO: arahkan ke halaman search.
        },
        onNotificationTap: () {
          // TODO: arahkan ke halaman notifikasi.
        },
      ),
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
