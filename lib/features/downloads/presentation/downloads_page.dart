import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/loading_view.dart';

import '../data/download_manager.dart';
import '../data/download_repository.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadManagerProvider);
    final storage = ref.watch(downloadStorageBytesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Unduhan')),
      body: downloads.when(
        loading: () => const LoadingView(),
        error: (error, _) =>
            Center(child: Text('Gagal memuat unduhan. $error')),
        data: (state) {
          final groups = _groupByManga(state.entries.values);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Penyimpanan offline'),
                  subtitle: Text(
                    storage.when(
                      loading: () => 'Menghitung…',
                      error: (_, __) => 'Tidak dapat menghitung',
                      data: (bytes) => '${_formatBytes(bytes)} terpakai',
                    ),
                  ),
                ),
              ),
              if (state.waitingForWifi)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.wifi_off_outlined),
                    title: Text('Menunggu Wi-Fi'),
                    subtitle: Text(
                      'Antrean akan dilanjutkan saat Wi-Fi tersedia.',
                    ),
                  ),
                ),
              if (state.message != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(state.message!),
                  ),
                ),
              const SizedBox(height: 8),
              if (groups.isEmpty)
                const EmptyView(
                  judul: 'Belum ada unduhan',
                  deskripsi: 'Chapter yang diunduh akan tersimpan di sini.',
                  ikon: Icons.download_done,
                )
              else
                for (final group in groups) ...[
                  _MangaDownloadCard(group: group),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MangaDownloadCard extends ConsumerWidget {
  const _MangaDownloadCard({required this.group});

  final _DownloadGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = group.coverPath;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: cover != null && File(cover).existsSync()
            ? Image.file(File(cover), width: 48, height: 64, fit: BoxFit.cover)
            : const SizedBox(
                width: 48,
                height: 64,
                child: Icon(Icons.menu_book_outlined),
              ),
        title: Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${group.chapters.length} chapter'),
        trailing: IconButton(
          tooltip: 'Hapus semua unduhan manga ini',
          onPressed: () => _konfirmasiHapusManga(context, ref, group),
          icon: const Icon(Icons.delete_outline),
        ),
        children: [
          for (final chapter in group.chapters)
            _ChapterDownloadTile(chapter: chapter),
        ],
      ),
    );
  }
}

class _ChapterDownloadTile extends ConsumerWidget {
  const _ChapterDownloadTile({required this.chapter});

  final DownloadedChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadManagerProvider).valueOrNull;
    final liveProgress = state?.liveProgress[chapter.key];
    final progress = liveProgress ?? chapter.progress;
    final active = state?.activeKey == chapter.key;
    final queued = state?.queue.any((item) => item.key == chapter.key) == true;
    final subtitle = [
      _statusLabel(chapter),
      if (chapter.totalPages > 0)
        '${chapter.downloadedPages}/${chapter.totalPages} halaman',
      _formatBytes(chapter.fileSizeBytes),
      if (chapter.errorMessage.isNotEmpty) chapter.errorMessage,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              chapter.chapterTitle.isEmpty
                  ? chapter.chapterId
                  : chapter.chapterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(subtitle),
            trailing: _ChapterActions(
              chapter: chapter,
              active: active,
              queued: queued,
            ),
          ),
          if (active || queued)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(value: progress),
            ),
        ],
      ),
    );
  }
}

class _ChapterActions extends ConsumerWidget {
  const _ChapterActions({
    required this.chapter,
    required this.active,
    required this.queued,
  });

  final DownloadedChapter chapter;
  final bool active;
  final bool queued;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];
    if (active || queued) {
      actions.add(
        IconButton(
          tooltip: 'Batalkan',
          onPressed: () =>
              ref.read(downloadManagerProvider.notifier).cancel(chapter.key),
          icon: const Icon(Icons.stop_circle_outlined),
        ),
      );
    }
    if (chapter.status == DownloadStatus.failed ||
        chapter.status == DownloadStatus.paused) {
      actions.add(
        IconButton(
          tooltip: 'Coba lagi',
          onPressed: () =>
              ref.read(downloadManagerProvider.notifier).retry(chapter.key),
          icon: const Icon(Icons.refresh),
        ),
      );
    }
    actions.add(
      IconButton(
        tooltip: 'Hapus chapter',
        onPressed: () => _konfirmasiHapusChapter(context, ref, chapter),
        icon: const Icon(Icons.delete_outline),
      ),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}

Future<void> _konfirmasiHapusChapter(
  BuildContext context,
  WidgetRef ref,
  DownloadedChapter chapter,
) async {
  final hapus = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus chapter ini?'),
      content: const Text('File dan metadata unduhan akan dihapus.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (hapus == true) {
    await ref.read(downloadManagerProvider.notifier).deleteChapter(chapter.key);
  }
}

Future<void> _konfirmasiHapusManga(
  BuildContext context,
  WidgetRef ref,
  _DownloadGroup group,
) async {
  final hapus = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus semua unduhan?'),
      content: Text('Semua chapter dari ${group.title} akan dihapus.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (hapus == true) {
    await ref.read(downloadManagerProvider.notifier).deleteManga(group.mangaId);
  }
}

class _DownloadGroup {
  const _DownloadGroup({
    required this.mangaId,
    required this.title,
    required this.coverPath,
    required this.chapters,
  });

  final String mangaId;
  final String title;
  final String coverPath;
  final List<DownloadedChapter> chapters;
}

List<_DownloadGroup> _groupByManga(Iterable<DownloadedChapter> entries) {
  final groups = <String, List<DownloadedChapter>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.mangaId, () => []).add(entry);
  }
  final result = <_DownloadGroup>[];
  for (final item in groups.entries) {
    final chapters = item.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    result.add(
      _DownloadGroup(
        mangaId: item.key,
        title: chapters.first.mangaTitle.isEmpty
            ? item.key
            : chapters.first.mangaTitle,
        coverPath: chapters.first.coverLocalPath,
        chapters: chapters,
      ),
    );
  }
  result.sort((a, b) => a.title.compareTo(b.title));
  return result;
}

String _statusLabel(DownloadedChapter chapter) {
  return switch (chapter.status) {
    DownloadStatus.queued => 'Dalam antrean',
    DownloadStatus.downloading => 'Mengunduh',
    DownloadStatus.completed => 'Selesai',
    DownloadStatus.failed => 'Gagal',
    DownloadStatus.paused => 'Dijeda',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
