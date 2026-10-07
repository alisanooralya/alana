import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/settings/data/settings_repository.dart';

class StorageDataPage extends ConsumerWidget {
  const StorageDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengaturan = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);

    final scheme = Theme.of(context).colorScheme;

    Widget pemisah() => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: scheme.outlineVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Penyimpanan & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Unduhan'),
                  subtitle: const Text('Chapter tersimpan untuk baca offline'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('unduhan'),
                ),
                pemisah(),
                SwitchListTile(
                  title: const Text('Unduh hanya via Wi-Fi'),
                  subtitle: const Text(
                    'Tunggu koneksi Wi-Fi sebelum memulai setiap chapter baru.',
                  ),
                  value: pengaturan.wifiOnlyDownloads,
                  onChanged: repo.aturWifiOnlyDownloads,
                ),
                pemisah(),
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
                pemisah(),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Log error perangkat'),
                  subtitle: const Text('Lihat dan salin laporan error.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('diagnostik'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
