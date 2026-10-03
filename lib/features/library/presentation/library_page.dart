import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/widgets/cover_image.dart';
import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/features/downloads/data/download_manager.dart';
import 'package:alana/features/downloads/data/download_repository.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/sync/data/sync_service.dart';
import 'package:alana/features/sync/presentation/widgets/pending_bar.dart';
import 'package:alana/utils/relative_time.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pustaka'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bookmark', icon: Icon(Icons.bookmark_outline)),
              Tab(text: 'Riwayat', icon: Icon(Icons.history_outlined)),
              Tab(text: 'Unduhan', icon: Icon(Icons.download_outlined)),
            ],
          ),
        ),
        body: const Column(
          children: [
            PendingBar(),
            Expanded(
              child: TabBarView(
                children: [_TabBookmark(), _TabRiwayat(), _TabUnduhan()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBookmark extends ConsumerWidget {
  const _TabBookmark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmark = ref.watch(bookmarkRepositoryProvider);
    final daftar = bookmark.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(syncServiceProvider).pullSegar(),
      child: daftar.isEmpty
          ? const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: EmptyView(
                    judul: 'Pustaka masih kosong',
                    deskripsi: 'Ketuk ikon bookmark di halaman detail untuk menyimpan judul.',
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
    );
  }
}

class _TabRiwayat extends ConsumerWidget {
  const _TabRiwayat();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayat = ref.watch(historyRepositoryProvider);
    final daftar = riwayat.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(syncServiceProvider).pullSegar(),
      child: daftar.isEmpty
          ? const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: EmptyView(
                    judul: 'Riwayat masih kosong',
                    deskripsi: 'Chapter yang kamu baca akan tercatat di sini.',
                    ikon: Icons.history_outlined,
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
                    leading: CoverImage(imageUrl: item.mangaThumbnail),
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

String _relatif(MangaReadingProgress item) {
  final label = formatRelativeTime(item.updatedAt.toIso8601String());
  return label;
}

class _TabUnduhan extends ConsumerWidget {
  const _TabUnduhan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unduhan = ref.watch(downloadManagerProvider);

    return unduhan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: EmptyView(
              judul: 'Gagal memuat unduhan',
              deskripsi: 'Tarik untuk mencoba lagi.',
              ikon: Icons.download_outlined,
            ),
          ),
        ],
      ),
      data: (state) {
        final groups = _kelompokUnduhan(state.entries.values);
        if (groups.isEmpty) {
          return const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: EmptyView(
                  judul: 'Belum ada unduhan',
                  deskripsi:
                      'Manhwa dengan chapter terunduh akan muncul di sini.',
                  ikon: Icons.download_outlined,
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(downloadManagerProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Kelola unduhan'),
                    subtitle: const Text(
                      'Lihat progres, jeda, atau hapus chapter',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed('unduhan'),
                  ),
                );
              }
              final group = groups[index - 1];
              final cover = group.sampul;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: cover.isNotEmpty && File(cover).existsSync()
                      ? Image.file(
                          File(cover),
                          width: 48,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox(
                          width: 48,
                          height: 64,
                          child: Icon(Icons.menu_book_outlined),
                        ),
                  title: Text(
                    group.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${group.jumlah} chapter terunduh'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (group.mangaId.isEmpty) return;
                    context.pushNamed(
                      'detail',
                      pathParameters: {'mangaId': group.mangaId},
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _KelompokUnduhan {
  const _KelompokUnduhan({
    required this.mangaId,
    required this.judul,
    required this.sampul,
    required this.jumlah,
  });

  final String mangaId;
  final String judul;
  final String sampul;
  final int jumlah;
}

List<_KelompokUnduhan> _kelompokUnduhan(Iterable<DownloadedChapter> entries) {
  final perManga = <String, List<DownloadedChapter>>{};
  for (final entry in entries) {
    perManga.putIfAbsent(entry.mangaId, () => []).add(entry);
  }
  final result = <_KelompokUnduhan>[];
  for (final item in perManga.entries) {
    final pertama = item.value.first;
    result.add(
      _KelompokUnduhan(
        mangaId: item.key,
        judul: pertama.mangaTitle.isEmpty ? item.key : pertama.mangaTitle,
        sampul: pertama.coverLocalPath,
        jumlah: item.value.length,
      ),
    );
  }
  result.sort((a, b) => a.judul.compareTo(b.judul));
  return result;
}
