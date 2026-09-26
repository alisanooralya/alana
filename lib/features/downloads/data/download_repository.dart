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

  /// Nama folder aman untuk sebuah id.
  ///
  /// Sebelumnya semua karakter di luar [A-Za-z0-9._-] diganti garis bawah,
  /// jadi dua id berbeda bisa jadi folder sama - misalnya `a/b` dan `a?b` sama-sama
  /// menjadi `a_b`. Unduhan kedua lalu menimpa file `001.jpg` milik yang
  /// pertama dan verify() tetap menghitungnya lengkap, sehingga user membaca
  /// chapter yang salah saat offline. Sekarang sufiks hash ditambahkan dari
  /// id asli supaya pemetaannya selalu satu-ke-satu.
  static String safeSegment(String value) {
    final bersih = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dasar = bersih.isEmpty ? 'unknown' : bersih;
    if (value.isEmpty) return dasar;
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return '$dasar-$hash';
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
    final directory = await _chapterPath(mangaId, chapterId);
    await directory.create(recursive: true);
    return directory;
  }

  /// Lokasi folder chapter TANPA membuatnya.
  ///
  /// Dipakai jalur baca dan hapus. Sebelumnya chapterDirectory() selalu
  /// membuat folder, sehingga `deleteChapter` membuat folder yang akan
  /// segera ia hapus, `pageFiles() membuat folder kosong untuk chapter
  /// yang hilang, dan verifyAll() membuat folder kosong
  /// untuk setiap entri yang rusak. Akibatnya chapter yang file-nya hilang
  /// terlihat seperti "belum memiliki gambar" alih-alih unduhan rusak.
  Future<Directory> _chapterPath(String mangaId, String chapterId) async {
    final root = await downloadsRoot();
    return Directory(
      '${root.path}/${safeSegment(mangaId)}/${safeSegment(chapterId)}',
    );
  }

  Future<List<File>> pageFiles(String mangaId, String chapterId) async {
    final directory = await _chapterPath(mangaId, chapterId);
    if (!await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jpg'))
        .cast<File>()
        .toList();
    // Urut berdasarkan nomor halaman, bukan string path. Nama file di-pad ke
    // tiga digit, jadi perbandingan string menempatkan 1000.jpg sebelum
    // 999.jpg dan chapter dengan lebih dari 999 halaman dibaca terbalik.
    files.sort((a, b) => _nomorHalaman(a).compareTo(_nomorHalaman(b)));
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
    final bytes = await _sizeOfFiles(files);
    // Nomor halaman harus lengkap dan berurutan tanpa celah: file yang hilang
    // di tengah tidak bisa digantikan hanya dengan menghitung jumlah file.
    final lengkap = chapter.totalPages > 0 &&
        files.length == chapter.totalPages &&
        _nomorBerurutan(files, chapter.totalPages);
    return chapter.copyWith(
      downloadedPages: files.length,
      fileSizeBytes: bytes,
      status: lengkap ? DownloadStatus.completed : DownloadStatus.failed,
      errorMessage: lengkap
          ? ''
          : files.isEmpty
          ? 'Folder halaman tidak ditemukan. Unduh ulang chapter ini.'
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
    final directory = await _chapterPath(mangaId, chapterId);
    if (await directory.exists()) await directory.delete(recursive: true);
    await remove(mangaId, chapterId);
  }

  Future<void> deleteManga(String mangaId) async {
    final root = await downloadsRoot();
    final directory = Directory('${root.path}/${safeSegment(mangaId)}');
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

/// Nomor halaman dari nama file `001.jpg`.
int _nomorHalaman(File file) {
  final nama = file.uri.pathSegments.isEmpty ? '' : file.uri.pathSegments.last;
  final titik = nama.lastIndexOf('.');
  final dasar = titik > 0 ? nama.substring(0, titik) : nama;
  return int.tryParse(dasar) ?? 0;
}

/// `true` bila file halaman bernomor 1..total lengkap semua.
bool _nomorBerurutan(List<File> files, int total) {
  if (files.length != total) return false;
  for (var i = 0; i < files.length; i++) {
    if (_nomorHalaman(files[i]) != i + 1) return false;
  }
  return true;
}

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
