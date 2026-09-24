import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/storage/app_storage.dart';
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
