import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/downloads/data/download_repository.dart';

const _userA = '11111111-1111-1111-1111-111111111111';

DownloadedChapter _lama({
  required String mangaId,
  required String chapterId,
  String coverLocalPath = '',
}) {
  return DownloadedChapter(
    userId: '',
    mangaId: mangaId,
    chapterId: chapterId,
    mangaTitle: 'Judul',
    chapterTitle: 'Chapter 1',
    coverLocalPath: coverLocalPath,
    totalPages: 2,
    downloadedPages: 2,
    status: DownloadStatus.completed,
    fileSizeBytes: 10,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// Membuat folder + berkas halaman berstruktur lama.
///
/// [rootUnduhan] sudah menunjuk ke folder `downloads`, jadi path di sini
/// tidak menambah `/downloads` lagi.
Future<String> buatFolderLama(
  Directory rootUnduhan,
  String mangaId,
  String chapterId,
) async {
  final mangaSeg = DownloadRepository.safeSegment(mangaId);
  final chapterSeg = DownloadRepository.safeSegment(chapterId);
  final dir = Directory('${rootUnduhan.path}/$mangaSeg/$chapterSeg')
    ..createSync(recursive: true);
  for (final n in ['001.jpg', '002.jpg']) {
    File('${dir.path}/$n').writeAsStringSync('x');
  }
  final cover = File('${rootUnduhan.path}/$mangaSeg/cover.jpg')
    ..writeAsStringSync('c');
  return cover.path;
}

Future<List<String>> isiFolder(Directory dir) async {
  if (!await dir.exists()) return const [];
  return dir
      .list()
      .where((e) => e is File)
      .map((e) => e.uri.pathSegments.last)
      .toList();
}

void main() {
  late Directory direktori;
  late Directory rootUnduhan;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    direktori = await Directory.systemTemp.createTemp('migrasi_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => direktori.path,
        );
    Hive.init(direktori.path);
    await AppStorage.init();
  });

  setUp(() async {
    DownloadRepository.resetMigrasiUntukTest();
    await AppStorage.downloadsBox!.clear();
    final sisa = Directory('${direktori.path}/downloads');
    if (sisa.existsSync()) await sisa.delete(recursive: true);
    rootUnduhan = Directory('${direktori.path}/downloads')
      ..createSync(recursive: true);
  });

  tearDownAll(() async {
    await Hive.close();
    if (direktori.existsSync()) await direktori.delete(recursive: true);
  });

  group('pindah ke folder per-akun', () {
    test('folder dan metadata pindah ke pemilik yang sedang login', () async {
      final cover = await buatFolderLama(rootUnduhan, 'manga-1', 'chapter-1');
      await AppStorage.downloadsBox!.put(
        'manga-1::chapter-1',
        _lama(
          mangaId: 'manga-1',
          chapterId: 'chapter-1',
          coverLocalPath: cover,
        ).toMap(),
      );

      final hasil = await DownloadRepository(userId: _userA)
          .migrasiStrukturLama();

      expect(hasil.dipindahkan, 1);
      expect(hasil.gagal, 0);

      final userSeg = DownloadRepository.safeSegment(_userA);
      final mangaSeg = DownloadRepository.safeSegment('manga-1');
      final chapSeg = DownloadRepository.safeSegment('chapter-1');
      final folderBaru = Directory(
        '${rootUnduhan.path}/$userSeg/$mangaSeg/$chapSeg',
      );
      expect(await isiFolder(folderBaru), ['001.jpg', '002.jpg']);

      // Folder lama benar-benar hilang, bukan disalin.
      final folderLama = Directory('${rootUnduhan.path}/$mangaSeg/$chapSeg');
      expect(await folderLama.exists(), isFalse);

      // Metadata pindah ke kunci berawalan user.
      final keys = AppStorage.downloadsBox!.keys.toList();
      expect(
        keys,
        contains(DownloadRepository.keyFor(_userA, 'manga-1', 'chapter-1')),
      );
      expect(keys, isNot(contains('manga-1::chapter-1')));
    });

    test('alamat cover absolut ditulis ulang', () async {
      final cover = await buatFolderLama(rootUnduhan, 'manga-1', 'chapter-1');
      await AppStorage.downloadsBox!.put(
        'manga-1::chapter-1',
        _lama(
          mangaId: 'manga-1',
          chapterId: 'chapter-1',
          coverLocalPath: cover,
        ).toMap(),
      );

      await DownloadRepository(userId: _userA).migrasiStrukturLama();

      final baru = AppStorage.downloadsBox!.get(
        DownloadRepository.keyFor(_userA, 'manga-1', 'chapter-1'),
      ) as Map;
      expect(baru['userId'], _userA);
      expect(
        baru['coverLocalPath'],
        '${rootUnduhan.path}/${DownloadRepository.safeSegment(_userA)}'
        '/${DownloadRepository.safeSegment('manga-1')}/cover.jpg',
      );
      expect(await File(baru['coverLocalPath'] as String).exists(), isTrue);
    });

    test('beberapa chapter dan manga dipindah semua', () async {
      for (final m in ['m1', 'm2']) {
        for (final c in ['c1', 'c2']) {
          await buatFolderLama(rootUnduhan, m, c);
          await AppStorage.downloadsBox!.put(
            '$m::$c',
            _lama(mangaId: m, chapterId: c).toMap(),
          );
        }
      }

      final hasil = await DownloadRepository(userId: _userA)
          .migrasiStrukturLama();

      expect(hasil.dipindahkan, 4);
      expect((await DownloadRepository(userId: _userA).all()).length, 4);
    });

    test('entri tanpa folder tetap dimigrasikan, bukan hilang', () async {
      // Metadata tanpa berkas: verifyAll() akan menandainya gagal dan user
      // bisa mengunduh ulang, asalkan tetap muncul di daftar.
      await AppStorage.downloadsBox!.put(
        'manga-9::chapter-9',
        _lama(mangaId: 'manga-9', chapterId: 'chapter-9').toMap(),
      );

      final hasil = await DownloadRepository(userId: _userA)
          .migrasiStrukturLama();

      expect(hasil.dipindahkan, 1);
      final daftar = await DownloadRepository(userId: _userA).all();
      expect(daftar.single.userId, _userA);
      expect(daftar.single.mangaId, 'manga-9');
    });
  });

  group('kondisi khusus', () {
    test('tidak jalan tanpa user pemilik', () async {
      await buatFolderLama(rootUnduhan, 'm1', 'c1');
      await AppStorage.downloadsBox!.put(
        'm1::c1',
        _lama(mangaId: 'm1', chapterId: 'c1').toMap(),
      );

      final hasil = await DownloadRepository(userId: '').migrasiStrukturLama();

      expect(hasil.dipindahkan, 0);
      // Folder lama harus tetap ada, tidak dipindah ke folder tanpa pemilik.
      final folderLama = Directory(
        '${rootUnduhan.path}/${DownloadRepository.safeSegment('m1')}'
        '/${DownloadRepository.safeSegment('c1')}',
      );
      expect(await folderLama.exists(), isTrue);
      expect(AppStorage.downloadsBox!.keys.toList(), ['m1::c1']);
    });

    test('hanya jalan sekali per aplikasi', () async {
      await buatFolderLama(rootUnduhan, 'm1', 'c1');
      await AppStorage.downloadsBox!.put(
        'm1::c1',
        _lama(mangaId: 'm1', chapterId: 'c1').toMap(),
      );
      final repo = DownloadRepository(userId: _userA);

      final pertama = await repo.migrasiStrukturLama();
      final kedua = await repo.migrasiStrukturLama();

      expect(pertama.dipindahkan, 1);
      // Panggilan kedua tidak boleh mengulang atau merusak hasil yang sudah
      // benar.
      expect(kedua.dipindahkan, 0);
      expect(kedua.dilewati, 0);
      expect(AppStorage.downloadsBox!.keys.toList(), [
        DownloadRepository.keyFor(_userA, 'm1', 'c1'),
      ]);
    });

    test('folder baru yang sudah ada dianggap duplikat', () async {
      // Migrasi yang sempat jalan lalu gagal sebelum menghapus metadata.
      await buatFolderLama(rootUnduhan, 'm1', 'c1');
      final userSeg = DownloadRepository.safeSegment(_userA);
      final mangaSeg = DownloadRepository.safeSegment('m1');
      final chapSeg = DownloadRepository.safeSegment('c1');
      final sudahAda = Directory(
        '${rootUnduhan.path}/$userSeg/$mangaSeg/$chapSeg',
      )..createSync(recursive: true);
      File('${sudahAda.path}/001.jpg').writeAsStringSync('y');
      await AppStorage.downloadsBox!.put(
        'm1::c1',
        _lama(mangaId: 'm1', chapterId: 'c1').toMap(),
      );

      final hasil = await DownloadRepository(userId: _userA)
          .migrasiStrukturLama();

      expect(hasil.dilewati, 1);
      expect(hasil.dipindahkan, 0);
      // Metadata lama dibuang, yang di folder baru dipertahankan.
      expect(AppStorage.downloadsBox!.keys.toList(), [
        DownloadRepository.keyFor(_userA, 'm1', 'c1'),
      ]);
    });

    test('entri milik akun lain tidak disentuh', () async {
      const userB = '22222222-2222-2222-2222-222222222222';
      await AppStorage.downloadsBox!.put(
        DownloadRepository.keyFor(userB, 'm1', 'c1'),
        _lama(mangaId: 'm1', chapterId: 'c1').copyWith(userId: userB).toMap(),
      );

      final hasil = await DownloadRepository(userId: _userA)
          .migrasiStrukturLama();

      expect(hasil.dipindahkan, 0);
      expect(AppStorage.downloadsBox!.keys.toList(), [
        DownloadRepository.keyFor(userB, 'm1', 'c1'),
      ]);
    });

    test('nilai cover yang bukan di folder unduhan dibiarkan', () async {
      // Menebak lokasi untuk string yang tidak dikenal lebih berisiko
      // merusak daripada membiarkan apa adanya.
      await AppStorage.downloadsBox!.put(
        'm1::c1',
        _lama(
          mangaId: 'm1',
          chapterId: 'c1',
          coverLocalPath: '/storage/emulated/0/DCIM/lain.jpg',
        ).toMap(),
      );

      await DownloadRepository(userId: _userA).migrasiStrukturLama();

      final baru = AppStorage.downloadsBox!.get(
        DownloadRepository.keyFor(_userA, 'm1', 'c1'),
      ) as Map;
      expect(baru['coverLocalPath'], '/storage/emulated/0/DCIM/lain.jpg');
    });
  });
}
