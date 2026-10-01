import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/settings/data/app_settings.dart';
import 'package:alana/features/settings/data/settings_repository.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengaturan = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tema',
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
          SwitchListTile(
            title: const Text('Layar tetap menyala'),
            subtitle: const Text('Mencegah layar mati sendiri selama membaca.'),
            value: pengaturan.keepScreenOn,
            onChanged: repo.aturKeepScreenOn,
          ),
        ],
      ),
    );
  }
}
