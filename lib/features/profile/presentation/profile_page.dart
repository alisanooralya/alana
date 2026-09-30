import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/utils/pesan_error.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_spinner.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'profile_providers.dart';
import 'widgets/profile_avatar.dart';

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

    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Abaikan: bukan kritis.
    }
    ref.read(pendingUsernameSetupProvider.notifier).state = false;
    await repo.keluar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilAsync = ref.watch(profileProvider);
    final punyaEmail = ref.watch(punyaEmailProvider);

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(
                      avatarUrl: profil.avatarUrl,
                      inisial: profil.inisial,
                      radius: 56,
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
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TombolAksi(
                    ikon: Icons.camera_alt_outlined,
                    label: 'Pasang Foto',
                    onTap: () => context.pushNamed('ubah-profil'),
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
                    onTap: () => context.pushNamed('pengaturan'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              _ItemMenu(
                ikon: Icons.person_outline,
                label: 'Edit Profil',
                deskripsi: 'Foto, nama, dan username',
                onTap: () => context.pushNamed('ubah-profil'),
              ),
              _ItemMenu(
                ikon: Icons.settings_outlined,
                label: 'Pengaturan',
                deskripsi: 'Tema, layar, dan diagnostik',
                onTap: () => context.pushNamed('pengaturan'),
              ),
              _ItemMenu(
                ikon: Icons.download_outlined,
                label: 'Unduhan',
                deskripsi: 'Chapter tersimpan untuk baca offline',
                onTap: () => context.pushNamed('unduhan'),
              ),
              if (punyaEmail)
                _ItemMenu(
                  ikon: Icons.lock_outline,
                  label: 'Keamanan',
                  deskripsi: 'Ganti password',
                  onTap: () => context.pushNamed('keamanan'),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.info_outline,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: const Text('Akun ini masuk lewat Google'),
                  subtitle: const Text('Password dikelola oleh Google.'),
                ),
              _ItemMenu(
                ikon: Icons.info_outline,
                label: 'Tentang Aplikasi',
                deskripsi: 'Versi, sumber data, dan lisensi',
                onTap: () => context.pushNamed('tentang-aplikasi'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('Keluar', style: TextStyle(color: scheme.error)),
                onTap: () => _keluar(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(
                  'Hapus Akun',
                  style: TextStyle(color: scheme.error),
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

class _TombolAksi extends StatelessWidget {
  const _TombolAksi({
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

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.ikon,
    required this.label,
    required this.deskripsi,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final String deskripsi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ikon, color: scheme.onSurfaceVariant),
      title: Text(label),
      subtitle: Text(deskripsi),
      onTap: onTap,
    );
  }
}

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
