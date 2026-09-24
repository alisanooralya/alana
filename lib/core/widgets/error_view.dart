import 'package:flutter/material.dart';

/// Tampilan gagal memuat dengan tombol coba lagi.
///
/// Semua teks bawaan memakai Bahasa Indonesia.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.pesan = 'Terjadi kesalahan. Periksa koneksi internet kamu.',
    required this.onRetry,
    this.labelTombol = 'Coba lagi',
  });

  /// Pesan kesalahan yang ditampilkan ke pengguna.
  final String pesan;

  /// Dipanggil saat tombol coba lagi ditekan.
  final VoidCallback onRetry;

  /// Label tombol aksi.
  final String labelTombol;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(labelTombol),
            ),
          ],
        ),
      ),
    );
  }
}
