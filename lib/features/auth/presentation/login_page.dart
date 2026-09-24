import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

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
  bool _sukses = false;
  String? _pesanError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pesanError = null;
      _sukses = false;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _memuat = true);
    try {
      final identitas = _email.text.trim();
      final repo = ref.read(authRepositoryProvider);
      if (identitas.contains('@')) {
        await repo.masuk(email: identitas, password: _password.text);
      } else {
        await repo.masukDenganUsername(
          username: identitas,
          password: _password.text,
        );
      }
      // Tampilkan centang singkat; pindah halaman ikut redirect sesi.
      if (mounted) setState(() => _sukses = true);
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
      final hasil = await ref.read(authRepositoryProvider).masukDenganGoogle();
      if (!mounted) return;
      // User Google baru (akun dibuat barusan) wajib pilih username.
      ref.read(pendingUsernameSetupProvider.notifier).state = akunBaruDariIso(
        hasil.user?.createdAt,
      );
    } catch (error, stack) {
      ErrorLog.catat(error, stack);
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
      animasiMasuk: true,
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
                  validator: (value) {
                    final teks = (value ?? '').trim();
                    if (teks.isEmpty) {
                      return 'Email atau username wajib diisi.';
                    }
                    if (teks.contains('@')) {
                      return validasiEmail(teks);
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email atau username',
                    hintText: 'nama@email.com atau username_kamu',
                    prefixIcon: Icon(Icons.person_outline),
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
            onPressed: (_memuat || _sukses || !terkonfigurasi) ? null : _masuk,
            child: _sukses
                ? const Icon(Icons.check, size: 20)
                : _memuat
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
