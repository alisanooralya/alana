import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/widgets/auth_widgets.dart';

import '../data/profile_repository.dart';
import 'profile_providers.dart';
import 'widgets/profile_avatar.dart';

/// Halaman Edit Profil: foto, nama tampilan, username.
///
/// [baru] true bila dibuka perdana untuk user Google baru
/// (menampilkan pesan ajakan memilih username sendiri).
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
  bool _mengunggah = false;
  String? _pesanError;
  String? _avatarBaru;

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

  Future<void> _gantiFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (sumber == null || !mounted) return;

    final diambil = await ImagePicker().pickImage(
      source: sumber,
      imageQuality: 90,
    );
    if (diambil == null || !mounted) return;

    final potong = await ImageCropper().cropImage(
      sourcePath: diambil.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Potong foto', lockAspectRatio: true),
      ],
    );
    if (potong == null || !mounted) return;

    final uid = ref.read(userIdProvider);
    if (uid == null || uid.isEmpty) {
      setState(() => _pesanError = 'Sesi tidak valid. Masuk ulang.');
      return;
    }
    setState(() {
      _mengunggah = true;
      _pesanError = null;
    });
    try {
      final url = await ref
          .read(profileRepositoryProvider)
          .unggahAvatar(uid, File(potong.path));
      if (!mounted) return;
      setState(() => _avatarBaru = url);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Foto profil diperbarui.')),
        );
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _mengunggah = false);
    }
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profil disimpan.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
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
    final profilAsync = ref.watch(profileProvider);
    final uid = ref.watch(userIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: profilAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Gagal memuat profil. $error')),
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
          }
          final avatar = _avatarBaru ?? profil.avatarUrl;
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
                Center(
                  child: Stack(
                    children: [
                      ProfileAvatar(
                        avatarUrl: avatar,
                        inisial: profil.inisial,
                        radius: 56,
                      ),
                      if (_mengunggah)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _mengunggah ? null : _gantiFoto,
                          child: const Icon(Icons.camera_alt, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  TextButton(
                    onPressed: _mengunggah ? null : _gantiFoto,
                    child: Text(_mengunggah ? 'Mengunggah…' : 'Ganti foto'),
                  ),
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
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
                          labelText: 'Nama tampilan',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _simpan(uid, profil.username),
                        validator: (value) => validasiUsername(value ?? ''),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixText: '@',
                          helperText: statusUsername,
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: const OutlineInputBorder(),
                        ),
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
                  onPressed: (_menyimpan || _mengunggah)
                      ? null
                      : () => _simpan(uid, profil.username),
                  child: _menyimpan
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
