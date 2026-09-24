import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          for (final mode in AppThemeMode.values)
            RadioListTile<AppThemeMode>(
              title: Text(mode.label),
              value: mode,
              groupValue: pengaturan.themeMode,
              onChanged: (value) {
                if (value != null) repo.aturTema(value);
              },
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pengaturan tersimpan otomatis di perangkat.'),
          ),
        ],
      ),
    );
  }
}
