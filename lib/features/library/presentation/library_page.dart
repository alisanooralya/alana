import 'package:flutter/material.dart';

import 'package:alana/core/widgets/empty_view.dart';

/// Halaman Pustaka (bookmark).
///
/// Fondasi Fase 1: placeholder kosong. Daftar bookmark
/// dan penyimpanan lokal menyusul di Fase 5.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pustaka')),
      body: const EmptyView(
        judul: 'Pustaka masih kosong',
        deskripsi: 'Judul yang kamu tandai akan tersimpan di sini.',
        ikon: Icons.bookmark_outline,
      ),
    );
  }
}
