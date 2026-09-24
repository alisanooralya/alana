import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/sync/data/sync_service.dart';
import 'package:alana/features/sync/presentation/widgets/pending_bar.dart';

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
      body: Column(
        children: [
          const PendingBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(syncServiceProvider).pullSegar(),
              child: daftar.isEmpty
                  ? const CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          child: EmptyView(
                            judul: 'Pustaka masih kosong',
                            deskripsi:
                                'Ketuk ikon bookmark di halaman detail untuk menyimpan judul.',
                            ikon: Icons.bookmark_outline,
                          ),
                        ),
                      ],
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
                    leading: CoverImage(imageUrl: item.thumbnail),
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
          ),
        ),
        ],
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
