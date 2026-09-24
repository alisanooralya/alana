import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'widgets/auth_widgets.dart';

/// Halaman daftar: username + email + password atau Google.
///
/// Bila konfirmasi email aktif (tidak ada sesi setelah daftar),
/// user diarahkan ke layar verifikasi email.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _konfirmasi = TextEditingController();
  Timer? _debounce;
  bool? _usernameTersedia;
  bool _cekUsername = false;
  bool _memuat = false;
  bool _memuatGoogle = false;
  String? _pesanError;

  @override
  void initState() {
    super.initState();
    _username.addListener(_jadwalCekUsername);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _username
      ..removeListener(_jadwalCekUsername)
      ..dispose();
    _email.dispose();
    _password.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  void _jadwalCekUsername() {
    _debounce?.cancel();
    final teks = _username.text.trim();
    if (validasiUsername(teks) != null) {
      setState(() {
        _usernameTersedia = null;
        _cekUsername = false;
      });
      return;
    }
    setState(() => _cekUsername = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final dipakai = await ref
          .read(authRepositoryProvider)
          .usernameDipakai(teks);
      if (!mounted) return;
      setState(() {
        _cekUsername = false;
        _usernameTersedia = dipakai == null ? null : !dipakai;
      });
    });
  }

  Future<void> _daftar() async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_usernameTersedia == false) {
      setState(() => _pesanError = 'Username sudah dipakai.');
      return;
    }
    setState(() => _memuat = true);
    try {
      final hasil = await ref
          .read(authRepositoryProvider)
          .daftar(
            username: _username.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      if (hasil.session == null) {
        // Konfirmasi email aktif → minta verifikasi dulu.
        context.pushNamed(
          'verifikasi-email',
          queryParameters: {'email': _email.text.trim()},
        );
      }
      // Bila ada sesi, redirect otomatis ke Beranda.
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
      ref.read(pendingUsernameSetupProvider.notifier).state = akunBaruDariIso(
        hasil.user?.createdAt,
      );
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuatGoogle = false);
    }
  }

  String? _statusUsername() {
    if (_cekUsername) return 'Memeriksa ketersediaan…';
    if (_usernameTersedia == true) return 'Username tersedia.';
    if (_usernameTersedia == false) return 'Username sudah dipakai.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final terkonfigurasi = SupabaseSetup.siap;
    final statusUsername = _statusUsername();

    return AuthScaffold(
      judul: 'Buat akun baru',
      subjudul: 'Satu akun untuk semua bacaanmu.',
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
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  validator: (value) => validasiUsername(value ?? ''),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    helperText: statusUsername,
                    helperStyle: TextStyle(
                      color: _usernameTersedia == false
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                  textInputAction: TextInputAction.next,
                  validator: validasiPassword,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _konfirmasi,
                  label: 'Ulangi password',
                  validator: (value) {
                    if (value != _password.text) {
                      return 'Konfirmasi tidak sama.';
                    }
                    return null;
                  },
                  onSubmitted: (_) => _daftar(),
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
            onPressed: (_memuat || !terkonfigurasi) ? null : _daftar,
            child: _memuat
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Daftar'),
          ),
          const SizedBox(height: 12),
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
              const Text('Sudah punya akun?'),
              TextButton(
                onPressed: () => context.pushNamed('masuk'),
                child: const Text('Masuk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
