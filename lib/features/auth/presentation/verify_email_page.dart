import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/auth_widgets.dart';

/// Layar setelah daftar bila konfirmasi email aktif (tanpa sesi).
///
/// Meminta user membuka tautan verifikasi di emailnya,
/// lalu kembali masuk.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key, this.email = ''});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      judul: 'Cek email kamu',
      subjudul: email.isEmpty
          ? 'Tautan verifikasi sudah dikirim.'
          : 'Tautan verifikasi dikirim ke $email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 72),
          const SizedBox(height: 16),
          const Text(
            'Buka email lalu ketuk tautan verifikasi. '
            'Setelah itu kembali ke sini dan masuk.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.goNamed('masuk'),
            child: const Text('Saya sudah verifikasi — Masuk'),
          ),
        ],
      ),
    );
  }
}
