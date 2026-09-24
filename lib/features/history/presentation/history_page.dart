import 'package:flutter/material.dart';

import 'package:alana/core/widgets/empty_view.dart';

/// Halaman Riwayat baca.
///
/// Fondasi Fase 1: placeholder kosong. Daftar riwayat
/// dan progres baca menyusul di Fase 4-5.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: const EmptyView(
        judul: 'Riwayat masih kosong',
        deskripsi: 'Chapter yang kamu baca akan tercatat di sini.',
        ikon: Icons.history_outlined,
      ),
    );
  }
}
