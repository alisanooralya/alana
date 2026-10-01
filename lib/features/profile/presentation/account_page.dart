import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/data/auth_validators.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/widgets/auth_widgets.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

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
    final punyaEmail = ref.watch(punyaEmailProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Keamanan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (punyaEmail)
            const _FormGantiPassword()
          else
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: scheme.onSurfaceVariant,
                ),
                title: const Text('Akun ini masuk lewat Google'),
                subtitle: const Text('Password dikelola oleh Google.'),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Zona sensitif',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: 8),
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
              title: Text('Hapus Akun', style: TextStyle(color: scheme.error)),
              subtitle: const Text('Hapus permanen dari server'),
              onTap: () => _hapusAkun(context, ref),
            ),
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
