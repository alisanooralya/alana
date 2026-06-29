import 'package:flutter/material.dart';
import '../widgets/app_header.dart';

/// Tab "Home" — dashboard utama saat app dibuka (highlight manga, update
/// terbaru, lanjutkan baca, dsb). Isi nanti sesuai kebutuhan kamu.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Lanjutkan Baca',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.menu_book),
              title: Text('Belum ada riwayat baca'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Update Terbaru',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.new_releases_outlined),
              title: Text('Belum ada update chapter baru'),
            ),
          ),
        ],
      ),
    );
  }
}
