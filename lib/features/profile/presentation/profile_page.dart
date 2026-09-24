import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'profile_providers.dart';
import 'widgets/profile_avatar.dart';

/// Halaman Profil: avatar, nama, username, email, dan menu.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _keluar(BuildContext context, WidgetRef ref) async {
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
    // Pindah ke /masuk ditangani redirect (sesi hilang).
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(profileProvider);
    final email = ref.watch(userEmailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profilAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          pesan: 'Gagal memuat profil. $error',
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(
                      avatarUrl: profil.avatarUrl,
                      inisial: profil.inisial,
                      radius: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nama,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (profil.username.isNotEmpty)
                      Text(
                        '@${profil.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    if (email != null && email.isNotEmpty)
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Profil'),
                subtitle: const Text('Foto, nama, username'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('ubah-profil'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Pengaturan'),
                subtitle: const Text('Tema, layar, diagnostik'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('pengaturan'),
              ),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Keluar',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _keluar(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}
