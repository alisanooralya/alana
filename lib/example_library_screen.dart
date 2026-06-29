// Contoh pemakaian MangaGridView + MangaCardWidget.
// Tempel widget ini di main.dart kamu untuk preview cepat, atau jadikan
// referensi cara pakai di LibraryScreen aslimu.

import 'package:flutter/material.dart';
import 'models/manga.dart';
import 'widgets/manga_card_widget.dart';
import 'widgets/manga_grid_view.dart';

class ExampleLibraryScreen extends StatefulWidget {
  const ExampleLibraryScreen({super.key});

  @override
  State<ExampleLibraryScreen> createState() => _ExampleLibraryScreenState();
}

class _ExampleLibraryScreenState extends State<ExampleLibraryScreen> {
  // Ganti dengan data asli (dari API/database) nantinya.
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

  MangaCardStyle _style = MangaCardStyle.compact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: Icon(
              _style == MangaCardStyle.compact
                  ? Icons.view_comfy
                  : Icons.view_compact,
            ),
            onPressed: () {
              setState(() {
                _style = _style == MangaCardStyle.compact
                    ? MangaCardStyle.comfortable
                    : MangaCardStyle.compact;
              });
            },
          ),
        ],
      ),
      body: MangaGridView(
        mangaList: _dummyManga,
        style: _style,
        onTapManga: (manga) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tap: ${manga.title}')),
          );
        },
        onLongPressManga: (manga) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Long press: ${manga.title}')),
          );
        },
      ),
    );
  }
}
