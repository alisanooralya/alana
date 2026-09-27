import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/downloads/data/download_repository.dart';

const _userA = '11111111-1111-1111-1111-111111111111';
const _userB = '22222222-2222-2222-2222-222222222222';

DownloadedChapter _bab({
  required String userId,
  String mangaId = 'manga-1',
  String chapterId = 'chapter-1',
  DownloadStatus status = DownloadStatus.completed,
}) {
  return DownloadedChapter(
    userId: userId,
    mangaId: mangaId,
    chapterId: chapterId,
    mangaTitle: 'Judul',
    chapterTitle: 'Chapter 1',
    coverLocalPath: '',
    totalPages: 10,
    downloadedPages: 10,
    status: status,
    fileSizeBytes: 1024,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late Directory direktori;

  // path_provider memakai platform channel yang tidak ada di unit test, dan
  // folder unduhan adalah bagian dari yang sedang diuji, jadi channel-nya
  // diarahkan ke folder sementara.
  //
  // Hive dan AppStorage hanya diinisialisasi sekali untuk seluruh berkas:
  // AppStorage.init() punya penanda statis, jadi memanggilnya lagi setelah
  // Hive.close() tidak melakukan apa-apa dan box tidak pernah terbuka lagi.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    direktori = await Directory.systemTemp.createTemp('unduhan_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => direktori.path,
        );
    Hive.init(direktori.path);
    await AppStorage.init();
  });

  setUp(() async {
    await AppStorage.downloadsBox!.clear();
    final sisa = Directory('${direktori.path}/downloads');
    if (sisa.existsSync()) await sisa.delete(recursive: true);
  });

  tearDownAll(() async {
    await Hive.close();
    if (direktori.existsSync()) await direktori.delete(recursive: true);
  });

  group('kunci unduhan', () {
    test('memuat userId sehingga dua akun tidak bertabrakan', () {
      final a = DownloadRepository.keyFor(_userA, 'manga-1', 'chapter-1');
      final b = DownloadRepository.keyFor(_userB, 'manga-1', 'chapter-1');
      expect(a, isNot(b));
    });

    test('masih unik untuk manga dan chapter berbeda', () {
      final keys = {
        DownloadRepository.keyFor(_userA, 'm', 'c1'),
        DownloadRepository.keyFor(_userA, 'm', 'c2'),
        DownloadRepository.keyFor(_userA, 'm2', 'c1'),
        DownloadRepository.keyFor(_userB, 'm', 'c1'),
      };
      expect(keys, hasLength(4));
    });
  });

  group('isolasi daftar unduhan', () {
    test('akun B tidak melihat unduhan akun A', () async {
      final a = DownloadRepository(userId: _userA);
      final b = DownloadRepository(userId: _userB);

      await a.save(_bab(userId: _userA));

      expect((await a.all()).map((e) => e.chapterId), ['chapter-1']);
      expect(await b.all(), isEmpty);
      expect(await b.find('manga-1', 'chapter-1'), isNull);
    });

    test('kunci lama tanpa userId tidak terlihat oleh akun mana pun', () async {
      // Entri peninggalan sebelum ada isolasi akun. Harus tetap tak terlihat
      // supaya tidak pernah tampil untuk akun yang salah.
      await AppStorage.downloadsBox!.put(
        'manga-1::chapter-1',
        _bab(userId: '').toMap(),
      );

      expect(await DownloadRepository(userId: _userA).all(), isEmpty);
      expect(await DownloadRepository(userId: _userB).all(), isEmpty);
    });

    test('manga sama milik dua akun terpisah penuh', () async {
      final a = DownloadRepository(userId: _userA);
      final b = DownloadRepository(userId: _userB);

      await a.save(_bab(userId: _userA, chapterId: 'c-a1'));
      await a.save(_bab(userId: _userA, chapterId: 'c-a2'));
      await b.save(_bab(userId: _userB, chapterId: 'c-b1'));

      final daftarA = await a.all();
      final daftarB = await b.all();
      expect(daftarA.map((e) => e.chapterId), containsAll(['c-a1', 'c-a2']));
      expect(daftarB.map((e) => e.chapterId), ['c-b1']);
      for (final item in daftarA) {
        expect(item.userId, _userA);
      }
    });

    test('save menolak entri milik akun lain', () async {
      // Penjaga terakhir kalau ada pemanggil yang salah mengirim chapter.
      final a = DownloadRepository(userId: _userA);
      await a.save(_bab(userId: _userB));
      expect(await a.all(), isEmpty);
    });

    test('repository tanpa userId tidak menyimpan apa pun', () async {
      final kosong = DownloadRepository(userId: '');
      await kosong.save(_bab(userId: ''));
      expect(await kosong.all(), isEmpty);
      expect(await kosong.find('manga-1', 'chapter-1'), isNull);
    });

    test('hapus chapter hanya menyentuh folder milik akun itu', () async {
      final a = DownloadRepository(userId: _userA);
      final b = DownloadRepository(userId: _userB);
      await a.save(_bab(userId: _userA));
      await b.save(_bab(userId: _userB, chapterId: 'chapter-1'));

      await b.deleteChapter('manga-1', 'chapter-1');

      expect(await b.all(), isEmpty);
      // Unduhan akun A harus utuh meski chapter-nya sama persis.
      expect((await a.all()).map((e) => e.chapterId), ['chapter-1']);
    });

    test('hapus manga hanya menghapus entri akun itu', () async {
      final a = DownloadRepository(userId: _userA);
      final b = DownloadRepository(userId: _userB);
      await a.save(_bab(userId: _userA, chapterId: 'c1'));
      await a.save(_bab(userId: _userA, chapterId: 'c2'));
      await b.save(_bab(userId: _userB, chapterId: 'c1'));

      await a.deleteManga('manga-1');

      expect(await a.all(), isEmpty);
      expect((await b.all()).map((e) => e.chapterId), ['c1']);
    });
  });

  group('serialisasi entri', () {
    test('userId ikut tersimpan dan terbaca kembali', () {
      final bab = _bab(userId: _userA);
      final kembali = DownloadedChapter.fromMap(bab.toMap());
      expect(kembali.userId, _userA);
      expect(kembali.key, bab.key);
    });

    test('entri lama tanpa userId dibaca sebagai userId kosong', () {
      final lama = _bab(userId: _userA).toMap()..remove('userId');
      expect(DownloadedChapter.fromMap(lama).userId, '');
    });
  });

  group('safeSegment', () {
    test('tetap satu-ke-satu untuk id yang mirip', () {
      // Regression: a/b dan a?b dulu jadi folder sama dan saling menimpa.
      expect(
        DownloadRepository.safeSegment('a/b'),
        isNot(DownloadRepository.safeSegment('a?b')),
      );
    });
  });
}
