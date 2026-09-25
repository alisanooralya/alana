import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/notifikasi/data/pengingat_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/settings/data/app_settings.dart';
import 'package:alana/features/settings/data/settings_repository.dart';

/// Halaman Pengaturan: tema tampilan dan layar tetap menyala.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengaturan = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tampilan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<AppThemeMode>(
            groupValue: pengaturan.themeMode,
            onChanged: (value) {
              if (value != null) repo.aturTema(value);
            },
            child: Column(
              children: [
                for (final mode in AppThemeMode.values)
                  RadioListTile<AppThemeMode>(
                    title: Text(mode.label),
                    value: mode,
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Membaca',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text('Layar tetap menyala'),
            subtitle: const Text('Mencegah layar mati sendiri selama membaca.'),
            value: pengaturan.keepScreenOn,
            onChanged: repo.aturKeepScreenOn,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Notifikasi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const _TilePengingat(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Kirim notifikasi uji'),
            subtitle: const Text(
              'Tampilkan satu notifikasi sekarang untuk mencoba.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(pengingatRepositoryProvider).kirimUji(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Perangkat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Penyimpanan lokal'),
            subtitle: Text(
              AppStorage.siap
                  ? 'OK — bookmark dan riwayat tersimpan di HP.'
                  : 'Tidak tersedia'
                        '${AppStorage.lastError == null ? '' : ': ${AppStorage.lastError}'}'
                        ' — data hanya tersimpan sementara.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Log error perangkat'),
            subtitle: const Text('Lihat dan salin laporan error.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('diagnostik'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pengaturan tersimpan otomatis di perangkat.'),
          ),
        ],
      ),
    );
  }
}

/// Toggle pengingat baca: minta izin + jadwalkan saat dinyalakan.
class _TilePengingat extends ConsumerWidget {
  const _TilePengingat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(pengingatAktifProvider);

    return SwitchListTile(
      title: const Text('Pengingat baca'),
      subtitle: const Text('Ingatkan bacaan yang 2+ hari tidak dilanjutkan.'),
      value: aktif,
      onChanged: (nilai) async {
        if (nilai) {
          await LayananNotifikasi.mintaIzin();
        }
        await ref.read(pengingatAktifProvider.notifier).atur(nilai);
        if (nilai) {
          final uid = ref.read(userIdProvider);
          await ref.read(pengingatRepositoryProvider).jadwalkanUlang(uid);
        }
      },
    );
  }
}
