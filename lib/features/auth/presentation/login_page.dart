import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';

import 'widgets/auth_widgets.dart';

/// Halaman masuk: email + password atau Google.
///
/// Setelah sesi terbentuk, redirect router otomatis ke Beranda.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _memuat = false;
  bool _memuatGoogle = false;
  String? _pesanError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _memuat = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .masuk(email: _email.text, password: _password.text);
      // Pindah halaman ditangani redirect (sesi berubah).
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _masukGoogle() async {
    setState(() {
      _pesanError = null;
      _memuatGoogle = true;
    });
    try {
      await ref.read(authRepositoryProvider).masukDenganGoogle();
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuatGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terkonfigurasi = SupabaseSetup.siap;

    return AuthScaffold(
      judul: 'Selamat datang kembali',
      subjudul: 'Masuk untuk lanjut membaca.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!terkonfigurasi)
            AuthErrorText(
              pesan:
                  SupabaseSetup.lastError ??
                  'Supabase belum dikonfigurasi (lihat README).',
            ),
          if (!terkonfigurasi) const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) => validasiEmail(value ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  validator: (value) =>
                      value.isEmpty ? 'Password wajib diisi.' : null,
                  onSubmitted: (_) => _masuk(),
                ),
              ],
            ),
          ),
          if (_pesanError != null) ...[
            const SizedBox(height: 12),
            AuthErrorText(pesan: _pesanError!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_memuat || !terkonfigurasi) ? null : _masuk,
            child: _memuat
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Masuk'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.pushNamed('lupa-password'),
              child: const Text('Lupa password?'),
            ),
          ),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          GoogleButton(
            memuat: _memuatGoogle,
            onPressed: !terkonfigurasi ? null : _masukGoogle,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Belum punya akun?'),
              TextButton(
                onPressed: () => context.pushNamed('daftar'),
                child: const Text('Daftar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
