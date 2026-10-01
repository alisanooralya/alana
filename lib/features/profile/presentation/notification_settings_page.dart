import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/notifikasi/push_fcm.dart';
import 'package:alana/features/notifikasi/data/device_token_repository.dart';
import 'package:alana/features/notifikasi/data/pengingat_repository.dart';
import 'package:alana/features/notifikasi/presentation/notification_permission_provider.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: ListView(
        children: [
          const _TilePengingat(),
          const _TilePushBab(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Kirim notifikasi uji'),
            subtitle: const Text(
              'Tampilkan satu notifikasi sekarang untuk mencoba.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final permission = await ref.read(
                notificationPermissionProvider.future,
              );
              if (!context.mounted) return;
              if (!permission.granted) {
                if (permission.blocked) {
                  await ref
                      .read(notificationPermissionProvider.notifier)
                      .openSettings();
                  return;
                }
                final lanjut = await showNotificationPermissionDialog(
                  context,
                  title: 'Aktifkan notifikasi',
                );
                if (lanjut != true ||
                    !await ref
                        .read(notificationPermissionProvider.notifier)
                        .request()) {
                  return;
                }
              }
              await ref.read(pengingatRepositoryProvider).kirimUji();
            },
          ),
        ],
      ),
    );
  }
}

class _TilePushBab extends ConsumerWidget {
  const _TilePushBab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(pushAktifProvider);
    final permission = ref.watch(notificationPermissionProvider).valueOrNull;
    final granted = permission?.granted ?? false;
    final blocked = permission?.blocked ?? false;

    return SwitchListTile(
      title: const Text('Notifikasi chapter baru'),
      subtitle: _NotifikasiSubtitle(
        description: 'Kirim kabar saat bookmark mendapat chapter baru.',
        blocked: blocked,
        onOpenSettings: () =>
            ref.read(notificationPermissionProvider.notifier).openSettings(),
      ),
      value: aktif && granted,
      isThreeLine: blocked,
      onChanged: blocked
          ? null
          : (nilai) async {
              if (nilai) {
                final current = await ref.read(
                  notificationPermissionProvider.future,
                );
                if (!context.mounted) return;
                if (!current.granted) {
                  if (current.blocked) return;
                  final lanjut = await showNotificationPermissionDialog(
                    context,
                  );
                  if (lanjut != true ||
                      !await ref
                          .read(notificationPermissionProvider.notifier)
                          .request()) {
                    await ref.read(pushAktifProvider.notifier).atur(false);
                    await ref.read(pushServiceProvider).hapusTokenTersimpan();
                    return;
                  }
                }
              }
              await ref.read(pushAktifProvider.notifier).atur(nilai);
              final push = ref.read(pushServiceProvider);
              if (nilai) {
                await push.sinkronToken(ref.read(userIdProvider));
              } else {
                await push.hapusTokenTersimpan();
              }
            },
    );
  }
}

class _TilePengingat extends ConsumerWidget {
  const _TilePengingat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = ref.watch(pengingatAktifProvider);
    final permission = ref.watch(notificationPermissionProvider).valueOrNull;
    final granted = permission?.granted ?? false;
    final blocked = permission?.blocked ?? false;

    return SwitchListTile(
      title: const Text('Pengingat baca'),
      subtitle: _NotifikasiSubtitle(
        description: 'Ingatkan bacaan yang 2+ hari tidak dilanjutkan.',
        blocked: blocked,
        onOpenSettings: () =>
            ref.read(notificationPermissionProvider.notifier).openSettings(),
      ),
      value: aktif && granted,
      isThreeLine: blocked,
      onChanged: blocked
          ? null
          : (nilai) async {
              if (nilai) {
                final current = await ref.read(
                  notificationPermissionProvider.future,
                );
                if (!context.mounted) return;
                if (!current.granted) {
                  if (current.blocked) return;
                  final lanjut = await showNotificationPermissionDialog(
                    context,
                  );
                  if (lanjut != true ||
                      !await ref
                          .read(notificationPermissionProvider.notifier)
                          .request()) {
                    await ref.read(pengingatAktifProvider.notifier).atur(false);
                    return;
                  }
                }
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

class _NotifikasiSubtitle extends StatelessWidget {
  const _NotifikasiSubtitle({
    required this.description,
    required this.blocked,
    required this.onOpenSettings,
  });

  final String description;
  final bool blocked;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        if (blocked) ...[
          const SizedBox(height: 4),
          Text(
            'Izin notifikasi dimatikan di pengaturan sistem',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Buka Pengaturan'),
            ),
          ),
        ],
      ],
    );
  }
}

Future<bool?> showNotificationPermissionDialog(
  BuildContext context, {
  String title = 'Aktifkan notifikasi',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: const Text(
        'Aktifkan notifikasi supaya tahu saat chapter baru terbit '
        'dan menerima pengingat baca.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Nanti dulu'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Lanjutkan'),
        ),
      ],
    ),
  );
}
