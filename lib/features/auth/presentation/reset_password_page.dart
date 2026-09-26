import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/utils/pesan_error.dart';

import '../data/auth_repository.dart';
import '../data/auth_validators.dart';
import 'auth_providers.dart';
import 'widgets/auth_widgets.dart';

/// Halaman set password baru, dibuka dari tautan recovery di email.
///
/// Halaman ini hanya punya arti kalau [passwordRecoveryProvider] true, yaitu
/// sesi sudah ditukar dari kode PKCE di tautan. Tanpa itu, user yang salah
/// menekan tautan akan melihat penjelasan dan tombol kembali.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _memuat = false;
  String? _pesanError;

  @override
  void dispose() {
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_baru.text != _konfirmasi.text) {
      setState(() => _pesanError = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _memuat = true);
    try {
      await ref.read(authRepositoryProvider).gantiPassword(_baru.text);
      if (!mounted) return;
      // Sesi recovery sudah habis gunanya: lepaskan kunci router lalu putuskan
      // sesi supaya user masuk lagi dengan password barunya.
      ref.read(passwordRecoveryProvider.notifier).state = false;
      await ref.read(authRepositoryProvider).keluar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Password diperbarui. Silakan masuk lagi.'),
          ),
        );
      context.go('/masuk');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _pesanError = pesanErrorRamah(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = ref.watch(passwordRecoveryProvider);
    if (!recovery) {
      return AuthScaffold(
        judul: 'Tautan tidak berlaku',
        subjudul: 'Buka lagi email reset password untuk melanjutkan.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthErrorText(
              pesan:
                  'Sesi reset password sudah berakhir atau tautannya sudah '
                  'dipakai. Minta tautan baru dari halaman lupa password.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/lupa-password'),
              child: const Text('Minta tautan baru'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      judul: 'Password baru',
      subjudul: 'Pilih password baru untuk akunmu.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordField(
              controller: _baru,
              label: 'Password baru',
              textInputAction: TextInputAction.next,
              validator: validasiPassword,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _konfirmasi,
              label: 'Ulangi password',
              textInputAction: TextInputAction.done,
              validator: validasiPassword,
              onSubmitted: (_) => _simpan(),
            ),
            if (_pesanError != null) ...[
              const SizedBox(height: 16),
              AuthErrorText(pesan: _pesanError!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _memuat ? null : _simpan,
              child: _memuat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
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
