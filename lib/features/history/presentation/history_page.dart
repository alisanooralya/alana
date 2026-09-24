import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/utils/relative_time.dart';

/// Halaman Riwayat baca. Reaktif: otomatis memperbarui
/// setiap reader menyimpan progres. Ketuk entri untuk
/// lanjut membaca dari chapter terakhir.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayat = ref.watch(historyRepositoryProvider);
    final daftar = riwayat.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: daftar.isEmpty
          ? const EmptyView(
              judul: 'Riwayat masih kosong',
              deskripsi: 'Chapter yang kamu baca akan tercatat di sini.',
              ikon: Icons.history_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: daftar.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = daftar[index];
                final judul = item.mangaTitle.isEmpty
                    ? item.mangaId
                    : item.mangaTitle;
                final sub = [
                  if (item.lastChapterName.isNotEmpty) item.lastChapterName,
                  _relatif(item),
                ].where((bagian) => bagian.isNotEmpty).join(' • ');

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: item.mangaThumbnail.isEmpty
                        ? const Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                          )
                        : Image.network(
                            item.mangaThumbnail,
                            width: 56,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                              );
                            },
                          ),
                    title: Text(
                      judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      sub.isEmpty ? 'Belum ada progres.' : sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Hapus dari Riwayat',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref
                            .read(historyRepositoryProvider.notifier)
                            .hapus(item.mangaId);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Dihapus dari Riwayat.'),
                            ),
                          );
                      },
                    ),
                    onTap: () {
                      if (item.lastChapterId.isEmpty) {
                        if (item.mangaId.isEmpty) return;
                        context.pushNamed(
                          'detail',
                          pathParameters: {'mangaId': item.mangaId},
                        );
                        return;
                      }
                      context.pushNamed(
                        'reader',
                        pathParameters: {
                          'mangaId': item.mangaId,
                          'chapterId': item.lastChapterId,
                        },
                        extra: {
                          'chapterName': item.lastChapterName,
                          'mangaTitle': item.mangaTitle,
                          'mangaThumbnail': item.mangaThumbnail,
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

String _relatif(MangaReadingProgress item) {
  final label = formatRelativeTime(item.updatedAt.toIso8601String());
  return label.isEmpty ? '' : '$label lalu';
}
