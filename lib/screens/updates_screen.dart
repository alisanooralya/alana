import 'package:flutter/material.dart';

/// Tab "Updates" — daftar chapter baru dari manga yang diikuti.
/// Isi nanti dengan list hasil fetch dari API kamu (chapter terbaru + waktu rilis).
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: const Center(
        child: Text('Belum ada update chapter baru.'),
      ),
    );
  }
}
