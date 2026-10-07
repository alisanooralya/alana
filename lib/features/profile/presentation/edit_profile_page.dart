import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/widgets/auth_widgets.dart';

import '../data/profile_repository.dart';
import 'profile_providers.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, this.baru = false});

  final bool baru;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _username = TextEditingController();
  Timer? _debounce;
  bool _dimuat = false;
  bool _cekUsername = false;
  bool? _usernameTersedia;
  bool _menyimpan = false;
  String? _pesanError;
  String? _uidSimpan;
  String? _usernameSimpan;

  @override
  void initState() {
    super.initState();
    _username.addListener(_jadwalCekUsername);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _username.removeListener(_jadwalCekUsername);
    _username.dispose();
    _nama.dispose();
    super.dispose();
  }

  void _jadwalCekUsername() {
    _debounce?.cancel();
    final uid = ref.read(userIdProvider);
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
          .read(profileRepositoryProvider)
          .usernameDipakai(teks, kecualiUid: uid);
      if (!mounted) return;
      setState(() {
        _cekUsername = false;
        _usernameTersedia = dipakai == null ? null : !dipakai;
      });
    });
  }

  Future<void> _simpan(String uidAwal, String usernameAwal) async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final usernameBaru = _username.text.trim();
    if (usernameBaru != usernameAwal && _usernameTersedia == false) {
      setState(() => _pesanError = 'Username sudah dipakai.');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .ubah(uidAwal, displayName: _nama.text, username: usernameBaru);
      ref.read(pendingUsernameSetupProvider.notifier).state = false;
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profil disimpan.')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profil');
      }
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  // Kartu input ala desain: label cyan + field tanpa border.
  Widget _kartu({required String judul, required Widget anak}) {
    final scheme = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: (teks.titleSmall ?? const TextStyle()).copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          anak,
        ],
      ),
    );
  }

  Widget _tombolBawah() {
    final uid = _uidSimpan;
    final usernameAwal = _usernameSimpan;
    if (uid == null || usernameAwal == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _menyimpan ? null : () => _simpan(uid, usernameAwal),
              child: _menyimpan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
            if (widget.baru)
              TextButton(
                onPressed: () {
                  ref.read(pendingUsernameSetupProvider.notifier).state = false;
                  context.go('/profil');
                },
                child: const Text('Nanti saja, ubah nanti'),
              ),
          ],
        ),
      ),
    );
  }

  String? _statusUsername() {
    if (_cekUsername) return 'Memeriksa ketersediaan…';
    if (_usernameTersedia == true) return 'Username tersedia.';
    if (_usernameTersedia == false) return 'Username sudah dipakai.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profilAsync = ref.watch(profileProvider);
    final uid = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Info')),
      bottomNavigationBar: _tombolBawah(),
      body: profilAsync.when(
        loading: () => const LoadingSpinner(),
        error: (error, _) => Center(
          child: Text('Gagal memuat profil. ${pesanErrorRamah(error)}'),
        ),
        data: (profil) {
          if (profil == null || uid == null || uid.isEmpty) {
            return const Center(
              child: Text('Profil belum tersedia. Coba lagi nanti.'),
            );
          }
          if (!_dimuat) {
            _dimuat = true;
            _nama.text = profil.displayName;
            _username.text = profil.username;
            _uidSimpan = uid;
            _usernameSimpan = profil.username;
          }
          final statusUsername = _statusUsername();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.baru)
                  const AuthInfoText(
                    pesan: 'Kamu masuk dengan Google. Pilih username sendiri agar mudah dikenali.',
                  ),
                if (widget.baru) const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _kartu(
                        judul: 'Nama kamu',
                        anak: TextFormField(
                          controller: _nama,
                          textInputAction: TextInputAction.next,
                          maxLength: 50,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Nama tampilan wajib diisi.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Nama tampilan',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _kartu(
                        judul: 'Username kamu',
                        anak: TextFormField(
                          controller: _username,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              _simpan(uid, profil.username),
                          validator: (value) => validasiUsername(value ?? ''),
                          decoration: InputDecoration(
                            hintText: 'username',
                            prefixText: '@',
                            helperText: statusUsername,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pesanError != null) ...[
                  const SizedBox(height: 12),
                  AuthErrorText(pesan: _pesanError!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
