import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:alana/features/downloads/data/download_repository.dart';
import 'package:alana/features/reader/data/reader_net.dart';

import 'profile_providers.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _bukaSandi = false;
  bool _bukaEmail = false;

  Future<void> _hapusAkun() async {
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
    if (lanjut != true || !mounted) return;

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
    if (terkonfirmasi != true || !mounted) return;

    final uid = repo.userAktif?.id ?? '';

    try {
      await repo.hapusAkun();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanAuthRamah(error))));
      return;
    }

    await _bersihkanLokal(uid);

    ref.read(pendingUsernameSetupProvider.notifier).state = false;
    await repo.keluar();
  }

  Future<void> _bersihkanLokal(String uid) async {
    if (uid.isEmpty) return;

    await AppStorage.hapusBoxUser(uid);
    await kosongkanCacheGambarReader();

    try {
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${root.path}/downloads/${DownloadRepository.safeSegment(uid)}',
      );
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (_) {
      // Abaikan: data server sudah terhapus, sisa lokal tidak kritis.
    }

    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {
      // Abaikan.
    }
  }

  Future<void> _keluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu harus masuk lagi untuk sinkronisasi.'),
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
    await ref.read(authRepositoryProvider).keluar();
    if (mounted) context.go('/masuk');
  }

  Widget _baris({
    required IconData ikon,
    required String judul,
    required bool buka,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(ikon, color: scheme.onSurfaceVariant),
      title: Text(judul),
      trailing: AnimatedRotation(
        turns: buka ? 0.25 : 0,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }

  Widget _kartuMerah({
    required IconData ikon,
    required String judul,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(ikon, color: scheme.error),
        title: Text(judul, style: TextStyle(color: scheme.error)),
        onTap: onTap,
      ),
    );
  }

  Widget _bukaan({required bool tampil, required Widget anak}) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: anak,
      ),
      crossFadeState: tampil
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final punyaEmail = ref.watch(punyaEmailProvider);
    final email = ref.watch(userEmailProvider) ?? '';
    final scheme = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Keamanan',
                    style: (teks.titleSmall ?? const TextStyle()).copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _baris(
                  ikon: Icons.lock_outline,
                  judul: 'Kata Sandi',
                  buka: _bukaSandi,
                  onTap: () => setState(() => _bukaSandi = !_bukaSandi),
                ),
                _bukaan(
                  tampil: _bukaSandi,
                  anak: punyaEmail
                      ? const _FormGantiPassword()
                      : Text(
                          'Akun ini masuk lewat Google. '
                          'Password dikelola oleh Google.',
                          style: teks.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: scheme.outlineVariant,
                ),
                _baris(
                  ikon: Icons.mail_outline,
                  judul: 'Email',
                  buka: _bukaEmail,
                  onTap: () => setState(() => _bukaEmail = !_bukaEmail),
                ),
                _bukaan(
                  tampil: _bukaEmail,
                  anak: Text(
                    email.isEmpty ? '-' : email,
                    style: teks.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _kartuMerah(
            ikon: Icons.logout,
            judul: 'Keluar dari Akun',
            onTap: _keluar,
          ),
          const SizedBox(height: 12),
          _kartuMerah(
            ikon: Icons.delete_outline,
            judul: 'Hapus Akun secara Permanen',
            onTap: _hapusAkun,
          ),
        ],
      ),
    );
  }
}

class _FormGantiPassword extends ConsumerStatefulWidget {
  const _FormGantiPassword();

  @override
  ConsumerState<_FormGantiPassword> createState() => _FormGantiPasswordState();
}

class _FormGantiPasswordState extends ConsumerState<_FormGantiPassword> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _memuat = false;
  String? _pesanError;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    setState(() => _pesanError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _memuat = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = repo.userAktif?.email ?? '';
      if (email.isEmpty) {
        setState(() => _pesanError = 'Sesi tidak valid. Masuk ulang.');
        return;
      }
      await repo.verifikasiPassword(email, _lama.text);
      await repo.gantiPassword(_baru.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Password berhasil diganti.')),
        );
      _lama.clear();
      _baru.clear();
      _konfirmasi.clear();
    } catch (error) {
      if (mounted) setState(() => _pesanError = pesanAuthRamah(error));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            controller: _lama,
            label: 'Password saat ini',
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value.isEmpty ? 'Password wajib diisi.' : null,
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _baru,
            label: 'Password baru',
            textInputAction: TextInputAction.next,
            validator: (value) {
              final pesan = validasiPassword(value);
              if (pesan != null) return pesan;
              if (value == _lama.text) {
                return 'Password baru tidak boleh sama dengan yang lama.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          PasswordField(
            controller: _konfirmasi,
            label: 'Ulangi password baru',
            validator: (value) {
              if (value != _baru.text) {
                return 'Konfirmasi tidak sama.';
              }
              return null;
            },
            onSubmitted: (_) => _simpan(),
          ),
          if (_pesanError != null) ...[
            const SizedBox(height: 12),
            AuthErrorText(pesan: _pesanError!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _memuat ? null : _simpan,
            child: _memuat
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan password'),
          ),
        ],
      ),
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
