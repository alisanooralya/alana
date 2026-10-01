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

    return Scaffold(
      appBar: AppBar(title: const Text('Penyimpanan & Data')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Unduhan'),
            subtitle: const Text('Chapter tersimpan untuk baca offline'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('unduhan'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Unduh hanya via Wi-Fi'),
            subtitle: const Text(
              'Tunggu koneksi Wi-Fi sebelum memulai setiap chapter baru.',
            ),
            value: pengaturan.wifiOnlyDownloads,
            onChanged: repo.aturWifiOnlyDownloads,
          ),
          const Divider(),
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
        ],
      ),
    );
  }
}
