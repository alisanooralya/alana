import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
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

  Future<void> _hapusAkun(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);
    final punyaEmail = ref.read(punyaEmailProvider);
    final email = repo.userAktif?.email ?? '';

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus akun permanen?'),
        content: const Text(
          'Akun, profil, bookmark, dan riwayat bacamu akan terhapus '
          'permanen dari server dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (lanjut != true || !context.mounted) return;

    // Konfirmasi ulang: password (email) atau kata HAPUS (Google).
    final terkonfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogKonfirmasiHapus(
        lewatEmail: punyaEmail,
        onValidasi: (input) async {
          if (punyaEmail) {
            if (email.isEmpty) return 'Sesi tidak valid. Masuk ulang.';
            try {
              await repo.verifikasiPassword(email, input);
              return null;
            } catch (error) {
              return pesanAuthRamah(error);
            }
          }
          if (input.trim() != 'HAPUS') {
            return 'Ketik persis: HAPUS';
          }
          return null;
        },
      ),
    );
    if (terkonfirmasi != true || !context.mounted) return;

    try {
      await repo.hapusAkun();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanAuthRamah(error))));
      return;
    }

    // Bersihkan cache lokal: gambar + Hive (Hive user menyusul
    // lewat orkestrasi sync saat sesi hilang).
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Abaikan: bukan kritis.
    }
    ref.read(pendingUsernameSetupProvider.notifier).state = false;
    await repo.keluar();
    // Pindah ke /masuk ditangani redirect (sesi hilang).
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(profileProvider);
    final email = ref.watch(userEmailProvider);
    final punyaEmail = ref.watch(punyaEmailProvider);

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
                leading: const Icon(Icons.info_outline),
                title: const Text('Tentang Aplikasi'),
                subtitle: const Text('Versi, sumber data, dan lisensi'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('tentang-aplikasi'),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Unduhan'),
                subtitle: const Text('Chapter tersimpan untuk baca offline'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('unduhan'),
              ),
              if (punyaEmail)
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Keamanan'),
                  subtitle: const Text('Ganti password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('keamanan'),
                )
              else
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Akun ini masuk lewat Google'),
                  subtitle: Text('Password dikelola oleh Google.'),
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
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Hapus Akun',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Hapus permanen dari server'),
                onTap: () => _hapusAkun(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dialog konfirmasi ulang hapus akun.
///
/// [lewatEmail] true → minta password (divalidasi via [onValidasi]);
/// false → minta ketik kata HAPUS.
class _DialogKonfirmasiHapus extends StatefulWidget {
  const _DialogKonfirmasiHapus({
    required this.lewatEmail,
    required this.onValidasi,
  });

  final bool lewatEmail;
  final Future<String?> Function(String input) onValidasi;

  @override
  State<_DialogKonfirmasiHapus> createState() => _DialogKonfirmasiHapusState();
}

class _DialogKonfirmasiHapusState extends State<_DialogKonfirmasiHapus> {
  final _controller = TextEditingController();
  bool _sembunyi = true;
  bool _memuat = false;
  String? _pesanError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    setState(() {
      _pesanError = null;
      _memuat = true;
    });
    final pesan = await widget.onValidasi(_controller.text);
    if (!mounted) return;
    setState(() => _memuat = false);
    if (pesan != null) {
      setState(() => _pesanError = pesan);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi terakhir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.lewatEmail
                ? 'Ketik password kamu untuk memastikan.'
                : 'Ketik persis kata HAPUS untuk memastikan.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: widget.lewatEmail && _sembunyi,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _kirim(),
            decoration: InputDecoration(
              labelText: widget.lewatEmail ? 'Password' : 'Ketik HAPUS',
              border: const OutlineInputBorder(),
              errorText: _pesanError,
              suffixIcon: widget.lewatEmail
                  ? IconButton(
                      tooltip: _sembunyi
                          ? 'Lihat password'
                          : 'Sembunyikan password',
                      icon: Icon(
                        _sembunyi
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _sembunyi = !_sembunyi),
                    )
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _memuat ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _memuat ? null : _kirim,
          child: _memuat
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hapus permanen'),
        ),
      ],
    );
  }
}
