import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'package:alana/core/storage/app_storage.dart';

enum DownloadStatus { queued, downloading, completed, failed, paused }

extension DownloadStatusValue on DownloadStatus {
  String get value => name;

  static DownloadStatus fromValue(String? value) {
    for (final status in DownloadStatus.values) {
      if (status.name == value) return status;
    }
    return DownloadStatus.failed;
  }
}

class DownloadedChapter {
  const DownloadedChapter({
    required this.mangaId,
    required this.chapterId,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.coverLocalPath,
    required this.totalPages,
    required this.downloadedPages,
    required this.status,
    required this.fileSizeBytes,
    required this.createdAt,
    this.errorMessage = '',
  });

  final String mangaId;
  final String chapterId;
  final String mangaTitle;
  final String chapterTitle;
  final String coverLocalPath;
  final int totalPages;
  final int downloadedPages;
  final DownloadStatus status;
  final int fileSizeBytes;
  final DateTime createdAt;
  final String errorMessage;

  String get key => DownloadRepository.keyFor(mangaId, chapterId);

  double get progress {
    if (totalPages <= 0) return 0;
    return (downloadedPages / totalPages).clamp(0, 1).toDouble();
  }

  DownloadedChapter copyWith({
    String? mangaTitle,
    String? chapterTitle,
    String? coverLocalPath,
    int? totalPages,
    int? downloadedPages,
    DownloadStatus? status,
    int? fileSizeBytes,
    DateTime? createdAt,
    String? errorMessage,
  }) {
    return DownloadedChapter(
      mangaId: mangaId,
      chapterId: chapterId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      totalPages: totalPages ?? this.totalPages,
      downloadedPages: downloadedPages ?? this.downloadedPages,
      status: status ?? this.status,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'mangaTitle': mangaTitle,
      'chapterTitle': chapterTitle,
      'coverLocalPath': coverLocalPath,
      'totalPages': totalPages,
      'downloadedPages': downloadedPages,
      'status': status.value,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory DownloadedChapter.fromMap(Map<String, dynamic> map) {
    return DownloadedChapter(
      mangaId: map['mangaId']?.toString() ?? '',
      chapterId: map['chapterId']?.toString() ?? '',
      mangaTitle: map['mangaTitle']?.toString() ?? '',
      chapterTitle: map['chapterTitle']?.toString() ?? '',
      coverLocalPath: map['coverLocalPath']?.toString() ?? '',
      totalPages: _asInt(map['totalPages']),
      downloadedPages: _asInt(map['downloadedPages']),
      status: DownloadStatusValue.fromValue(map['status']?.toString()),
      fileSizeBytes: _asInt(map['fileSizeBytes']),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      errorMessage: map['errorMessage']?.toString() ?? '',
    );
  }
}

class DownloadRepository {
  const DownloadRepository();

  static const boxName = 'downloads';

  static String keyFor(String mangaId, String chapterId) =>
      '$mangaId::$chapterId';

  static String safeSegment(String value) {
    final result = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return result.isEmpty ? 'unknown' : result;
  }

  Box? get _box => AppStorage.downloadsBox;

  Future<Directory> downloadsRoot() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/downloads');
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> mangaDirectory(String mangaId) async {
    final root = await downloadsRoot();
    final directory = Directory('${root.path}/${safeSegment(mangaId)}');
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> chapterDirectory(String mangaId, String chapterId) async {
    final root = await mangaDirectory(mangaId);
    final directory = Directory('${root.path}/${safeSegment(chapterId)}');
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<File>> pageFiles(String mangaId, String chapterId) async {
    final directory = await chapterDirectory(mangaId, chapterId);
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jpg'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<DownloadedChapter>> all() async {
    final box = _box;
    if (box == null) return const [];
    final result = <DownloadedChapter>[];
    for (final value in box.values) {
      if (value is! Map) continue;
      final item = DownloadedChapter.fromMap(Map<String, dynamic>.from(value));
      if (item.mangaId.isNotEmpty && item.chapterId.isNotEmpty) {
        result.add(item);
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<DownloadedChapter?> find(String mangaId, String chapterId) async {
    final raw = _box?.get(keyFor(mangaId, chapterId));
    if (raw is! Map) return null;
    return DownloadedChapter.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> save(DownloadedChapter chapter) async {
    await _box?.put(chapter.key, chapter.toMap());
  }

  Future<void> remove(String mangaId, String chapterId) async {
    await _box?.delete(keyFor(mangaId, chapterId));
  }

  Future<DownloadedChapter> verify(DownloadedChapter chapter) async {
    if (chapter.status != DownloadStatus.downloading &&
        chapter.status != DownloadStatus.completed) {
      return chapter;
    }
    final files = await pageFiles(chapter.mangaId, chapter.chapterId);
    final lengkap =
        chapter.totalPages > 0 && files.length >= chapter.totalPages;
    final bytes = await _sizeOfFiles(files);
    return chapter.copyWith(
      downloadedPages: files.length,
      fileSizeBytes: bytes,
      status: lengkap ? DownloadStatus.completed : DownloadStatus.failed,
      errorMessage: lengkap
          ? ''
          : 'Download terhenti. File belum lengkap; coba lagi.',
    );
  }

  Future<List<DownloadedChapter>> verifyAll() async {
    final entries = await all();
    final verified = <DownloadedChapter>[];
    for (final entry in entries) {
      final item = await verify(entry);
      verified.add(item);
      if (item.status != entry.status ||
          item.downloadedPages != entry.downloadedPages ||
          item.fileSizeBytes != entry.fileSizeBytes) {
        await save(item);
      }
    }
    return verified;
  }

  Future<int> totalStorageBytes() async {
    final root = await downloadsRoot();
    if (!await root.exists()) return 0;
    return _sizeDirectory(root);
  }

  Future<void> deleteChapter(String mangaId, String chapterId) async {
    final directory = await chapterDirectory(mangaId, chapterId);
    if (await directory.exists()) await directory.delete(recursive: true);
    await remove(mangaId, chapterId);
  }

  Future<void> deleteManga(String mangaId) async {
    final directory = await mangaDirectory(mangaId);
    if (await directory.exists()) await directory.delete(recursive: true);
    final box = _box;
    if (box == null) return;
    final keys = box.keys.where((key) {
      final value = box.get(key);
      return value is Map && value['mangaId'] == mangaId;
    }).toList();
    await box.deleteAll(keys);
  }
}

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return const DownloadRepository();
});

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Future<int> _sizeOfFiles(List<File> files) async {
  var total = 0;
  for (final file in files) {
    try {
      total += await file.length();
    } catch (_) {}
  }
  return total;
}

Future<int> _sizeDirectory(Directory directory) async {
  var total = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File) continue;
    try {
      total += await entity.length();
    } catch (_) {}
  }
  return total;
}
