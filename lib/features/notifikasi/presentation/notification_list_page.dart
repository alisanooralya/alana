import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/utils/relative_time.dart';

import '../data/notification_repository.dart';
import 'notifikasi_providers.dart';

/// Halaman daftar notifikasi.
///
/// Tap item → tandai dibaca → buka Detail/Reader bila ada
/// manga_id/chapter_id.
class NotificationListPage extends ConsumerWidget {
  const NotificationListPage({super.key});

  Future<void> _buka(
    BuildContext context,
    WidgetRef ref,
    String id,
    String mangaId,
    String chapterId,
  ) async {
    try {
      await ref.read(notificationRepositoryProvider).tandaiDibaca(id);
    } catch (_) {
      // Tetap navigasi walau penandaan gagal.
    }
    ref.invalidate(daftarNotifikasiProvider);
    ref.invalidate(belumDibacaProvider);
    if (!context.mounted) return;
    if (mangaId.isEmpty) return;
    if (chapterId.isEmpty) {
      context.pushNamed('detail', pathParameters: {'mangaId': mangaId});
    } else {
      context.pushNamed(
        'reader',
        pathParameters: {'mangaId': mangaId, 'chapterId': chapterId},
      );
    }
  }

  IconData _ikon(String type) {
    switch (type) {
      case 'reading_reminder':
        return Icons.menu_book_outlined;
      case 'chapter_update':
        return Icons.new_releases_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftarAsync = ref.watch(daftarNotifikasiProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(daftarNotifikasiProvider);
          ref.invalidate(belumDibacaProvider);
        },
        child: daftarAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            pesan: 'Gagal memuat notifikasi. $error',
            onRetry: () {
              ref.invalidate(daftarNotifikasiProvider);
              ref.invalidate(belumDibacaProvider);
            },
          ),
          data: (daftar) {
            if (daftar.isEmpty) {
              return const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: EmptyView(
                      judul: 'Belum ada notifikasi',
                      deskripsi:
                          'Notifikasi update dan pengingat muncul di sini.',
                      ikon: Icons.notifications_none_outlined,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: daftar.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = daftar[index];
                final label = formatRelativeTime(
                  item.createdAt.toIso8601String(),
                );
                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: item.isRead ? null : scheme.primaryContainer,
                  child: ListTile(
                    leading: Stack(
                      children: [
                        Icon(
                          _ikon(item.type),
                          size: 32,
                          color: item.isRead
                              ? scheme.outline
                              : scheme.onPrimaryContainer,
                        ),
                        if (!item.isRead)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.body.isNotEmpty)
                          Text(
                            item.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (label.isNotEmpty)
                          Text(
                            '$label lalu',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    onTap: () => _buka(
                      context,
                      ref,
                      item.id,
                      item.mangaId,
                      item.chapterId,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
