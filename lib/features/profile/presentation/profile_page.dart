import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'profile_providers.dart';
import 'widgets/avatar_picker.dart';
import 'widgets/profile_avatar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _scroll = ScrollController();
  final _kategoriKey = GlobalKey();
  bool _mengunggah = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollKeKategori() {
    final ctx = _kategoriKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
      return;
    }
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pasangFoto() async {
    if (_mengunggah) return;
    setState(() => _mengunggah = true);
    try {
      await pilihDanUnggahAvatar(context, ref);
    } finally {
      if (mounted) setState(() => _mengunggah = false);
    }
  }

  Future<void> _keluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Kamu harus masuk lagi untuk membaca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    ref.read(pendingUsernameSetupProvider.notifier).state = false;
    await ref.read(authRepositoryProvider).keluar();
  }

  @override
  Widget build(BuildContext context) {
    final profilAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profilAsync.when(
        loading: () => const LoadingSpinner(),
        error: (error, _) => ErrorView(
          pesan: 'Gagal memuat profil. ${pesanErrorRamah(error)}',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profil) {
          if (profil == null) {
            return EmptyView(
              judul: 'Profil belum tersedia',
              deskripsi: 'Tunggu sebentar atau muat ulang.',
              labelAksi: 'Muat ulang',
              onAksi: () => ref.invalidate(profileProvider),
            );
          }
          final nama = profil.displayName.isNotEmpty
              ? profil.displayName
              : profil.username.isNotEmpty
              ? profil.username
              : 'Tanpa nama';
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(
                        avatarUrl: profil.avatarUrl,
                        inisial: profil.inisial,
                        radius: 64,
                      ),
                      if (_mengunggah)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nama,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  if (profil.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${profil.username}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TombolAksi(
                    ikon: Icons.camera_alt_outlined,
                    label: _mengunggah ? 'Mengunggah…' : 'Pasang Foto',
                    onTap: _mengunggah ? null : _pasangFoto,
                  ),
                  const SizedBox(width: 10),
                  _TombolAksi(
                    ikon: Icons.edit_outlined,
                    label: 'Ubah Info',
                    onTap: () => context.pushNamed('ubah-profil'),
                  ),
                  const SizedBox(width: 10),
                  _TombolAksi(
                    ikon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    onTap: _scrollKeKategori,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(key: _kategoriKey),
              _ItemKategori(
                ikon: Icons.key_outlined,
                label: 'Akun',
                onTap: () => context.pushNamed('akun'),
              ),
              _ItemKategori(
                ikon: Icons.palette_outlined,
                label: 'Tampilan',
                onTap: () => context.pushNamed('tampilan'),
              ),
              _ItemKategori(
                ikon: Icons.notifications_none,
                label: 'Notifikasi',
                onTap: () => context.pushNamed('pengaturan-notifikasi'),
              ),
              _ItemKategori(
                ikon: Icons.cached_outlined,
                label: 'Penyimpanan & Data',
                onTap: () => context.pushNamed('penyimpanan-data'),
              ),
              _ItemKategori(
                ikon: Icons.help_outline,
                label: 'Tentang Aplikasi',
                onTap: () => context.pushNamed('tentang-aplikasi'),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('Keluar', style: TextStyle(color: scheme.error)),
                onTap: _keluar,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TombolAksi extends StatelessWidget {
  const _TombolAksi({
    required this.ikon,
    required this.label,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(ikon, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemKategori extends StatelessWidget {
  const _ItemKategori({
    required this.ikon,
    required this.label,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      leading: Icon(ikon, color: scheme.onSurfaceVariant, size: 26),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}
