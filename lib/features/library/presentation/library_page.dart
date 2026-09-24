import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';

/// Halaman Pustaka (bookmark). Reaktif: otomatis memperbarui
/// saat bookmark ditambah/dihapus dari halaman detail.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmark = ref.watch(bookmarkRepositoryProvider);
    final daftar = bookmark.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Pustaka')),
      body: daftar.isEmpty
          ? const EmptyView(
              judul: 'Pustaka masih kosong',
              deskripsi: 'Ketuk ikon bookmark di halaman detail untuk menyimpan judul.',
              ikon: Icons.bookmark_outline,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: daftar.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = daftar[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: item.thumbnail.isEmpty
                        ? const Icon(
                            Icons.image_not_supported_outlined,
                            size: 48,
                          )
                        : Image.network(
                            item.thumbnail,
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
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Disimpan ${_formatTanggal(item.savedAt)}'),
                    trailing: IconButton(
                      tooltip: 'Hapus dari Pustaka',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref
                            .read(bookmarkRepositoryProvider.notifier)
                            .hapus(item.mangaId);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Dihapus dari Pustaka.'),
                            ),
                          );
                      },
                    ),
                    onTap: () {
                      if (item.mangaId.isEmpty) return;
                      context.pushNamed(
                        'detail',
                        pathParameters: {'mangaId': item.mangaId},
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

String _formatTanggal(DateTime tanggal) {
  const bulan = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${tanggal.day} ${bulan[tanggal.month]} ${tanggal.year}';
}
