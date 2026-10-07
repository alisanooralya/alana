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
    final scheme = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final modes = AppThemeMode.values;

    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Tema',
                    style: (teks.titleSmall ?? const TextStyle()).copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                RadioGroup<AppThemeMode>(
                  groupValue: pengaturan.themeMode,
                  onChanged: (value) {
                    if (value != null) repo.aturTema(value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < modes.length; i++) ...[
                        RadioListTile<AppThemeMode>(
                          title: Text(modes[i].label),
                          value: modes[i],
                        ),
                        if (i < modes.length - 1)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: scheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              title: const Text('Layar tetap menyala'),
              subtitle: const Text(
                'Mencegah layar mati sendiri selama membaca.',
              ),
              value: pengaturan.keepScreenOn,
              onChanged: repo.aturKeepScreenOn,
            ),
          ),
        ],
      ),
    );
  }
}
