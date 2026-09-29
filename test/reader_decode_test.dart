import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/reader/presentation/widgets/reader_image.dart';

({int w, int h}) decodeFit({
  required int w,
  required int h,
  int? maxWidth,
  int? maxHeight,
}) {
  final ar = w / h;
  final batasW = maxWidth ?? w;
  final batasH = maxHeight ?? h;
  var tw = w;
  var th = h;
  if (tw > batasW) {
    tw = batasW;
    th = tw ~/ ar;
  }
  if (th > batasH) {
    th = batasH;
    tw = (th * ar).floor();
  }
  return (w: tw, h: th);
}

({int? w, int? h}) decodeExact({
  required int w,
  required int h,
  int? maxWidth,
  int? maxHeight,
}) {
  var tw = maxWidth;
  var th = maxHeight;
  if (tw != null && tw > w) tw = w;
  if (th != null && th > h) th = h;
  return (w: tw, h: th);
}

/// Dimensi asli dari API, bukan angka tebakan. Strip webtoon 800x12777 dan
/// 800x10228 adalah milik Infinite Mage ch 187 dan Goblin Inc ch 15, dua
/// judul yang dilaporkan buram dan gepeng.
const _sampul = (w: 800, h: 614);
const _infiniteMage = (w: 800, h: 12777);
const _goblinInc = (w: 800, h: 10228);

void main() {
  group('batasDecode', () {
    test('height adalah plafon piksel, bukan tinggi gambar', () {
      final batas = batasDecode(lebarLogis: 360, dpr: 3);

      expect(batas.width, 1080);
      expect(batas.height, batasPikselReader ~/ 1080);
      expect(batas.height, greaterThan(10000));
    });

    test('tinggi gambar tidak lagi memengaruhi batas', () {
      final kecil = batasDecode(lebarLogis: 360, dpr: 3);
      final besar = batasDecode(lebarLogis: 360, dpr: 3, batasPiksel: 4 << 20);

      // Batas lama memakai tinggiLayar x dpr x 2, jadi layar yang lebih tinggi
      // memberi bitmap lebih besar. Sekarang tidak ada dependensi ke layar.
      expect(kecil.width, besar.width);
      expect(besar.height, lessThan(kecil.height!));
    });

    test('layar sangat kecil atau dpr nol tidak menghasilkan ukuran', () {
      expect(batasDecode(lebarLogis: 0, dpr: 3).width, isNull);
      expect(batasDecode(lebarLogis: 360, dpr: 0).width, isNull);
    });
  });

  group('jalur online, ResizeImagePolicy.fit', () {
    test('batas memori sekarang memberi upscale yang terkontrol', () {
      // Angka hasil nyata untuk batas sekarang, bukan perkiraan. Kalau
      // `batasMemoriReader` diubah, test ini yang memberi tahu konsekuensinya.
      const layarPx = 1080;
      final batas = batasDecode(lebarLogis: 360, dpr: 3);

      // Halaman pendek dan Goblin Inc (800x10228) masih di bawah plafon
      // 11650 px, jadi ter-decode pada lebar penuh sumber.
      for (final sumber in [_sampul, _goblinInc]) {
        final out = decodeFit(
          w: sumber.w,
          h: sumber.h,
          maxWidth: batas.width,
          maxHeight: batas.height,
        );
        expect(out.w, sumber.w);
        expect(out.h, sumber.h);
      }

      // Infinite Mage (800x12777) melewati plafon, jadi hanya dikecilkan
      // sampai upscale 1,5x. Inilah batasAbu-abu yang harus dijaga: kalau
      // batas memori diturunkan lagi, angka ini naik dan gambar jadi lembut.
      final panjang = decodeFit(
        w: _infiniteMage.w,
        h: _infiniteMage.h,
        maxWidth: batas.width,
        maxHeight: batas.height,
      );
      expect(panjang.w, 729);
      expect(panjang.h, 11650);
      expect(layarPx / panjang.w, lessThan(1.6));
      expect(panjang.w * panjang.h, lessThanOrEqualTo(batasPikselReader));
    });

    test('rasio aspek tetap terjaga', () {
      final batas = batasDecode(lebarLogis: 360, dpr: 3);

      for (final sumber in [_sampul, _infiniteMage, _goblinInc]) {
        final out = decodeFit(
          w: sumber.w,
          h: sumber.h,
          maxWidth: batas.width,
          maxHeight: batas.height,
        );
        final sebelum = sumber.w / sumber.h;
        final sesudah = out.w / out.h;
        expect((sesudah - sebelum).abs() / sebelum, lessThan(0.005));
      }
    });

    test('tidak pernah melebihi batas piksel', () {
      final batas = batasDecode(lebarLogis: 360, dpr: 3);
      final out = decodeFit(
        w: 2000,
        h: 30000,
        maxWidth: batas.width,
        maxHeight: batas.height,
      );

      expect(out.w * out.h, lessThanOrEqualTo(batasPikselReader));
      // Lebar sumber 2000 dijepit ke 1080, jadi upscale-nya kecil.
      expect(1080 / out.w, lessThan(1.6));
    });
  });

  group('jalur offline lama, ResizeImagePolicy.exact', () {
    test('memakai cacheWidth dan cacheHeight merusak rasio aspek', () {
      // `Image.file(cacheWidth:, cacheHeight:)` melewati
      // `ResizeImage.resizeIfNeeded` yang tidak menyertakan `policy`, sehingga
      // memakai default `ResizeImagePolicy.exact`. Inilah asal "gepeng".
      const batasLama = 4800;
      final out = decodeExact(
        w: _infiniteMage.w,
        h: _infiniteMage.h,
        maxWidth: 1080,
        maxHeight: batasLama,
      );

      expect(out.w, 800);
      expect(out.h, batasLama);
      expect(
        out.w! / out.h!,
        isNot(closeTo(_infiniteMage.w / _infiniteMage.h, 0.01)),
      );
    });

    test('halaman pendek tidak terpengaruh, makanya hanya sebagian', () {
      final out = decodeExact(
        w: _sampul.w,
        h: _sampul.h,
        maxWidth: 1080,
        maxHeight: 4800,
      );

      expect(out.w, _sampul.w);
      expect(out.h, _sampul.h);
    });
  });

  group('widget ReaderImage', () {
    /// Test di atas hanya menguji aritmetika `batasDecode`; ia tidak tahu
    /// policy apa yang benar-benar dipakai widget. Tanpa test ini, `Image.file`
    /// dengan `cacheWidth`/`cacheHeight` bisa saja dikembalikan tanpa test
    /// mana pun yang gagal.
    Future<void> pumpReader(
      WidgetTester tester, {
      required String localPath,
      double rasio = 0.08,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderImage(
              imageUrl: 'https://contoh.invalid/01.jpg',
              localPath: localPath,
              headers: const {'Referer': 'https://app.shinigami.asia/'},
              rasio: ValueNotifier<double?>(rasio),
            ),
          ),
        ),
      );
    }

    testWidgets('jalur offline memakai ResizeImage dengan policy fit', (
      tester,
    ) async {
      await pumpReader(tester, localPath: '/tidak/ada/gambar.jpg');

      final provider = tester.widget<Image>(find.byType(Image)).image;
      expect(provider, isA<ResizeImage>());

      final resize = provider as ResizeImage;
      expect(resize.policy, ResizeImagePolicy.fit);
      expect(resize.width, 1080);
      expect(resize.height, batasPikselReader ~/ 1080);
    });

    testWidgets('batas decode tidak memakai tinggi layar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1080, 6000)),
            child: Scaffold(
              body: ReaderImage(
                imageUrl: 'https://contoh.invalid/01.jpg',
                localPath: '/tidak/ada/gambar.jpg',
                headers: const {'Referer': 'https://app.shinigami.asia/'},
                rasio: ValueNotifier<double?>(0.08),
              ),
            ),
          ),
        ),
      );

      final resize =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      // Batas lama adalah tinggiLayar * dpr * 2. Kalau masih memakainya,
      // tinggi 6000 logical akan menghasilkan batas yang jauh lebih besar.
      expect(resize.height, batasPikselReader ~/ 1080);
    });
  });

  group('tinggi item terkunci', () {
    /// Tinggi item pernah mengikuti `lebar * 0.6` sampai gambar termuat, lalu
    /// melompat mengikuti rasio asli. Pada satu chapter terukur tinggi antar
    /// halaman ranging dari 276 px sampai 4500 px, jadi lompatan itu sendiri
    /// menggagalkan pemulihan posisi baca.
    ///
    /// Widget harus berada di dalam `ListView`, bukan langsung di `Scaffold`
    /// body. Di `Scaffold` body tinggi sudah dibatasi viewport, jadi
    /// `AspectRatio` akan memakai tinggi layar (800), bukan `lebar / rasio` —
    /// dan itu bukan kondisi nyata reader.
    Future<double> tinggiDalamList(
      WidgetTester tester, {
      required double? rasio,
      String? localPath,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ReaderImage(
                  imageUrl: 'https://contoh.invalid/01.jpg',
                  localPath: localPath,
                  headers: const {},
                  rasio: ValueNotifier<double?>(rasio),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(ReaderImage)).height;
    }

    testWidgets('placeholder, gambar, dan error semua punya tinggi sama', (
      tester,
    ) async {
      // Lebar logis 360 pada 1080/3.
      final denganRasio = await tinggiDalamList(tester, rasio: 0.08);
      expect(denganRasio, closeTo(360 / 0.08, 1));

      // Tanpa rasio, konstanta 0,1 yang dipakai — bukan 0,6 kali lebar.
      final tanpaRasio = await tinggiDalamList(tester, rasio: null);
      expect(tanpaRasio, closeTo(360 / 0.1, 1));
      expect(tanpaRasio, isNot(closeTo(360 * 0.6, 1)));
    });

    testWidgets('tinggi tidak bergantung pada gambar yang termuat', (
      tester,
    ) async {
      // Berkas tidak ada, jadi `Image` tidak akan pernah selesai decode dan
      // tidak bisa mengubah tinggi. Mesmo setelah error, tinggi harus tetap
      // mengikuti `AspectRatio`.
      final tinggi = await tinggiDalamList(
        tester,
        rasio: 0.086,
        localPath: '/tidak/ada/gambar.jpg',
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(tinggi, closeTo(360 / 0.086, 1));
      expect(
        tester.getSize(find.byType(ReaderImage)).height,
        closeTo(360 / 0.086, 1),
      );
    });
  });
}
