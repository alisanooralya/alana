import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/widgets/auth_widgets.dart';

/// Halaman Keamanan: ganti password untuk user identity email.
///
/// User yang hanya login Google melihat keterangan bahwa akunnya
/// masuk lewat Google (tanpa form).
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final punyaEmail = ref.watch(punyaEmailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: punyaEmail
          ? const _FormGantiPassword()
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Akun ini masuk lewat Google.\n'
                  'Password dikelola oleh Google, jadi tidak ada '
                  'yang perlu diubah di sini.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}

class _FormGantiPassword extends ConsumerStatefulWidget {
  const _FormGantiPassword();

  @override
  ConsumerState<_FormGantiPassword> createState() => _FormGantiPasswordState();
}

class _FormGantiPasswordState extends ConsumerState<_FormGantiPassword> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _memuat = false;
  String? _pesanError;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _memuat = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = repo.userAktif?.email ?? '';
      if (email.isEmpty) {
        setState(() => _pesanError = 'Sesi tidak valid. Masuk ulang.');
        return;
      }
      await repo.verifikasiPassword(email, _lama.text);
      await repo.gantiPassword(_baru.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Password berhasil diganti.')),
        );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordField(
              controller: _lama,
              label: 'Password saat ini',
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value.isEmpty ? 'Password wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _baru,
              label: 'Password baru',
              textInputAction: TextInputAction.next,
              validator: (value) {
                final pesan = validasiPassword(value);
                if (pesan != null) return pesan;
                if (value == _lama.text) {
                  return 'Password baru tidak boleh sama dengan yang lama.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _konfirmasi,
              label: 'Ulangi password baru',
              validator: (value) {
                if (value != _baru.text) {
                  return 'Konfirmasi tidak sama.';
                }
                return null;
              },
              onSubmitted: (_) => _simpan(),
            ),
            if (_pesanError != null) ...[
              const SizedBox(height: 12),
              AuthErrorText(pesan: _pesanError!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _memuat ? null : _simpan,
              child: _memuat
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan password'),
            ),
          ],
        ),
      ),
    );
  }
}
