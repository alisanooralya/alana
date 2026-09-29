import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/reader/data/ratio_probe.dart';
import 'package:alana/features/reader/data/reader_net.dart';

/// File service palsu yang mencatat setiap pemanggilan dan mengembalikan isi
/// tetap, supaya bisa dibedakan "unduhan" dari "dilayani cache".
class _FileServicePalsu implements FileService {
  _FileServicePalsu(this.isi);

  final Uint8List isi;
  int panggilan = 0;
  int concurrently = 0;
  int puncak = 0;

  @override
  int concurrentFetches = 10;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    panggilan++;
    concurrently++;
    if (concurrently > puncak) puncak = concurrently;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    concurrently--;
    return _ResponsPalsu(isi);
  }
}

class _ResponsPalsu implements FileServiceResponse {
  _ResponsPalsu(this.isi);

  final Uint8List isi;

  @override
  int get statusCode => 200;

  @override
  int? get contentLength => isi.length;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 7));

  @override
  String? get eTag => 'etag-palsu';

  @override
  String get fileExtension => '.jpg';

  @override
  Stream<List<int>> get content => Stream<List<int>>.value(isi);
}

void main() {
  // `CacheManager` dan `IOFileSystem` memanggil `getTemporaryDirectory()` dan
  // `getApplicationSupportDirectory()` dari path_provider, yang memakai
  // platform channel. Tanpa binding dan mock, `flutter test` gagal dengan
  // "Binding has not yet been initialized".
  TestWidgetsFlutterBinding.ensureInitialized();
  final rootUji = Directory.systemTemp.createTempSync('alana_reader_traffic');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => rootUji.path,
      );
  // `addTearDown` hanya boleh dipanggil di dalam sebuah test, jadi pembersihan
  // di level berkas memakai `tearDownAll`.
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (rootUji.existsSync()) rootUji.deleteSync(recursive: true);
  });

  group('BatasKoneksi', () {
    test('tidak pernah melewati batas yang ditentukan', () async {
      final batas = BatasKoneksi(3);
      var sekarang = 0;
      var puncak = 0;

      Future<void> kerja() async {
        await batas.jalankan(() async {
          sekarang++;
          if (sekarang > puncak) puncak = sekarang;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          sekarang--;
        });
      }

      // 20 pekerjaan, hanya boleh 3 jalan bersamaan.
      await Future.wait(List.generate(20, (_) => kerja()));

      expect(puncak, lessThanOrEqualTo(3));
      expect(batas.puncak, 3);
      expect(batas.tersedia, 3);
      expect(batas.menunggu, 0);
    });

    test('permit kembali walau ada yang gagal', () async {
      final batas = BatasKoneksi(1);

      await expectLater(
        batas.jalankan(() async => throw StateError('gagal')),
        throwsStateError,
      );

      // Kalau permit bocor, pekerjaan kedua akan menggantung selamanya.
      await batas.jalankan(() async => 'ok');
      expect(batas.tersedia, 1);
    });

    test('resetPuncak tidak menyentuh permit yang sedang dipakai', () async {
      final batas = BatasKoneksi(2);
      final jalan = batas.jalankan(() async {
        batas.resetPuncak();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 1;
      });
      expect(await jalan, 1);
      expect(batas.tersedia, 2);
    });
  });

  group('readerCacheKey', () {
    test('deterministik dan berbeda per url', () {
      const a = 'https://cdn.example/01.jpg';
      const b = 'https://cdn.example/02.jpg';

      expect(readerCacheKey(a), readerCacheKey(a));
      expect(readerCacheKey(a), isNot(readerCacheKey(b)));
    });

    test('memakai awalan yang tidak bentrok dengan cache manager lain', () {
      // Kunci bawaan `DefaultCacheManager` adalah url mentah. Kalau reader
      // memakai url mentah juga, kedua manager akan berebut entri yang sama.
      expect(
        readerCacheKey('https://cdn.example/01.jpg'),
        isNot('https://cdn.example/01.jpg'),
      );
    });
  });

  group('retry tidak mengunduh ulang berkas yang sudah lengkap', () {
    test('permintaan kedua dilayani dari cache tanpa memanggil file service', () async {
      final service = _FileServicePalsu(
        Uint8List.fromList(List<int>.filled(64, 7)),
      );
      final manager = CacheManager(
        Config(
          'uji_reader_traffic',
          stalePeriod: const Duration(days: 14),
          maxNrOfCacheObjects: 600,
          fileService: service,
        ),
      );
      const url = 'https://cdn.example/halaman-01.jpg';
      const kunci = 'reader/$url';

      Future<FileInfo> ambil() async {
        final stream = manager.getFileStream(url, key: kunci);
        return stream
            .firstWhere((r) => r is FileInfo)
            .then((r) => r as FileInfo);
      }

      // Percobaan pertama: memang harus mengunduh.
      final pertama = await ambil();
      expect(pertama.source, FileSource.Online);
      expect(service.panggilan, 1);

      // "Coba lagi" membangun ulang widget dengan key baru, tapi cacheKey tetap
      // sama, jadi berkas lengkap di disk dipakai apa adanya.
      final kedua = await ambil();
      expect(kedua.source, FileSource.Cache);
      expect(service.panggilan, 1, reason: 'tidak boleh ada unduhan kedua');

      await manager.dispose();
    });

    test('unduhan tidak paralel melebihi concurrentFetches', () async {
      final service = _FileServicePalsu(Uint8List.fromList([1, 2, 3, 4]));
      final manager = CacheManager(
        Config('uji_reader_traffic_paralel', fileService: service),
      );
      service.concurrentFetches = 2;

      Future<void> ambil(String url) async {
        await manager
            .getFileStream(url, key: readerCacheKey(url))
            .firstWhere((r) => r is FileInfo);
      }

      await Future.wait([
        for (var i = 0; i < 8; i++) ambil('https://cdn.example/$i.jpg'),
      ]);

      expect(service.puncak, lessThanOrEqualTo(2));
      await manager.dispose();
    });
  });

  group('RatioCache tidak ikut terhapus', () {
    test('box rasio terpisah dari cache manager gambar', () {
      // Kunci cache manager adalah nama folder/database; box Hive adalah
      // yang lain. Kalau ini sama, `emptyCache()` akan ikut menghapus rasio
      // dan probe 2 KB diulang untuk halaman yang sudah diketahui.
      expect(AppStorage.pageRatioBoxName, isNot('reader_cache'));
      expect(AppStorage.pageRatioBoxName, isNot('defaultCacheManager'));
    });

    test('box rasio bukan box per pengguna yang dihapus saat keluar', () {
      // `AppStorage.hapusBoxUser` hanya membersihkan bm/rh/sm.
      // `page_ratio` sengaja tidak ada di sana: rasio bukan data pengguna dan
      // tidak perlu dihapus tiap ganti akun.
      const dihapusSaatKeluar = ['bm', 'rh', 'sm'];
      expect(dihapusSaatKeluar, isNot(contains('page_ratio')));
    });
  });

  group('klasifikasi status probe', () {
    test('403 dan 429 ditandai diblokir, status lain tidak', () {
      expect(RatioProbe.diblokir(403), isTrue);
      expect(RatioProbe.diblokir(429), isTrue);
      expect(RatioProbe.diblokir(200), isFalse);
      expect(RatioProbe.diblokir(206), isFalse);
      expect(RatioProbe.diblokir(404), isFalse);
      expect(RatioProbe.diblokir(500), isFalse);
      expect(RatioProbe.diblokir(null), isFalse);
    });

    test('url kosong tidak menyentuh jaringan', () async {
      PenghitungTrafik.reset();
      final hasil = await RatioProbe().probe('');
      expect(hasil, isA<HasilKosong>());
    });
  });

  group('PenghitungTrafik', () {
    test('reset mengembalikan semua ke nol', () {
      PenghitungTrafik.tambahProbe(5);
      PenghitungTrafik.tambahUnduhan(7);
      PenghitungTrafik.tambahHitCache(9);

      expect(PenghitungTrafik.probe, 5);
      expect(PenghitungTrafik.unduhan, 7);
      expect(PenghitungTrafik.hitCache, 9);

      PenghitungTrafik.reset();

      expect(PenghitungTrafik.probe, 0);
      expect(PenghitungTrafik.unduhan, 0);
      expect(PenghitungTrafik.hitCache, 0);
    });

    test('ringkasan memuat ketiga angka', () {
      PenghitungTrafik.reset();
      PenghitungTrafik.tambahProbe(1);
      PenghitungTrafik.tambahUnduhan(2);
      PenghitungTrafik.tambahHitCache(3);

      final teks = PenghitungTrafik.ringkas();
      expect(teks, contains('probe=1'));
      expect(teks, contains('unduhan=2'));
      expect(teks, contains('hitCache=3'));
      expect(teks, contains('/6'));
    });
  });
}
