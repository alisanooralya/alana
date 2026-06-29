import 'package:flutter/material.dart';
import '../widgets/app_header.dart';

/// Tab "History" — riwayat chapter yang sudah dibaca user.
/// Isi nanti dengan data dari local storage (misalnya Hive/SharedPreferences/SQLite),
/// urut dari yang paling baru dibaca.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
      body: const Center(
        child: Text('Belum ada riwayat baca.'),
      ),
    );
  }
}
