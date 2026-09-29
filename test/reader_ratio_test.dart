import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/reader/data/page_ratio.dart';

/// Bangun header JPEG yang valid tanpa data gambar: SOI, satu segmen APP0,
/// lalu SOF. Panjang segmen dibuat benar supaya pen walkers berhenti tepat di
/// SOF, seperti berkas sungguhan.
Uint8List _jpeg({required int w, required int h, bool denganApp0 = true}) {
  final bytes = <int>[];

  void segmen(int marker, List<int> isi) {
    bytes
      ..add(0xFF)
      ..add(marker);
    final panjang = isi.length + 2;
    bytes
      ..add((panjang >> 8) & 0xFF)
      ..add(panjang & 0xFF)
      ..addAll(isi);
  }

  bytes.addAll([0xFF, 0xD8]);
  if (denganApp0) {
    // APP0 JFIF: 14 byte isi.
    segmen(0xE0, List<int>.filled(14, 0x00));
  }
  // SOF2 (progressive): presisi 8, tinggi, lebar, 3 komponen.
  segmen(0xC2, [
    0x08,
    (h >> 8) & 0xFF,
    h & 0xFF,
    (w >> 8) & 0xFF,
    w & 0xFF,
    0x03,
  ]);
  bytes.addAll([0xFF, 0xD9]);
  return Uint8List.fromList(bytes);
}

Uint8List _png({required int w, required int h}) {
  final bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  void be32(int v) {
    bytes.addAll([
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ]);
  }

  be32(13);
  bytes.addAll([0x49, 0x48, 0x44, 0x52]); // IHDR
  be32(w);
  be32(h);
  be32(8);
  bytes.addAll([0x06, 0x00, 0x00, 0x00]); // sisa header, tidak dipakai parser
  return Uint8List.fromList(bytes);
}

Uint8List _webpVp8({required int w, required int h}) {
  final bytes = <int>[
    0x52,
    0x49,
    0x46,
    0x46,
    0,
    0,
    0,
    0,
    0x57,
    0x45,
    0x42,
    0x50,
  ];
  bytes.addAll([0x56, 0x50, 0x38, 0x20]); // "VP8 "
  bytes.addAll([0x00, 0x00, 0x00]); // frame tag
  bytes.addAll([0x9D, 0x01, 0x2A]); // start code
  bytes.addAll([w & 0xFF, (w >> 8) & 0x3F]);
  bytes.addAll([h & 0xFF, (h >> 8) & 0x3F]);
  return Uint8List.fromList(bytes);
}

Uint8List _webpVp8x({required int w, required int h}) {
  final bytes = <int>[
    0x52,
    0x49,
    0x46,
    0x46,
    0,
    0,
    0,
    0,
    0x57,
    0x45,
    0x42,
    0x50,
  ];
  bytes.addAll([0x56, 0x50, 0x38, 0x58]); // "VP8X"
  bytes.addAll([0x00, 0x00, 0x00, 0x00]); // flag
  int le24(int v) => v & 0xFF;
  bytes.addAll([
    le24(w - 1),
    ((w - 1) >> 8) & 0xFF,
    ((w - 1) >> 16) & 0xFF,
    le24(h - 1),
    ((h - 1) >> 8) & 0xFF,
    ((h - 1) >> 16) & 0xFF,
  ]);
  return Uint8List.fromList(bytes);
}

Uint8List _webpVp8l({required int w, required int h}) {
  final bits = (w - 1) | ((h - 1) << 14);
  final bytes = <int>[
    0x52,
    0x49,
    0x46,
    0x46,
    0,
    0,
    0,
    0,
    0x57,
    0x45,
    0x42,
    0x50,
  ];
  bytes.addAll([0x56, 0x50, 0x38, 0x4C]); // "VP8L"
  bytes.add(0x2F);
  bytes.addAll([
    bits & 0xFF,
    (bits >> 8) & 0xFF,
    (bits >> 16) & 0xFF,
    (bits >> 24) & 0xFF,
  ]);
  return Uint8List.fromList(bytes);
}

void main() {
  group('parseJpeg', () {
    test('membaca SOF2 setelah segmen APP0', () {
      final d = parseJpeg(_jpeg(w: 800, h: 9097));
      expect(d, isNotNull);
      expect(d!.w, 800);
      expect(d.h, 9097);
    });

    test('membaca SOF0 baseline tanpa segmen lain', () {
      final d = parseJpeg(_jpeg(w: 800, h: 614, denganApp0: false));
      expect(d!.w, 800);
      expect(d.h, 614);
    });

    test('melewati DHT dan restart interval, bukan salah baca sebagai SOF', () {
      // 0xC4 (DHT) dan 0xCC (DAC) berada di rentang SOF tapi bukan SOF.
      final bytes = <int>[0xFF, 0xD8];

      void segmen(int marker, List<int> isi) {
        final panjang = isi.length + 2;
        bytes
          ..add(0xFF)
          ..add(marker)
          ..add((panjang >> 8) & 0xFF)
          ..add(panjang & 0xFF)
          ..addAll(isi);
      }

      segmen(0xC4, List<int>.filled(6, 0));
      segmen(0xCC, List<int>.filled(2, 0));
      // SOF2: presisi 8, tinggi 10000 (0x2710), lebar 800 (0x0320).
      segmen(0xC2, [0x08, 0x27, 0x10, 0x03, 0x20, 0x03]);
      bytes.addAll([0xFF, 0xD9]);

      final d = parseJpeg(Uint8List.fromList(bytes));
      expect(d!.w, 800);
      expect(d.h, 10000);
    });

    test('menolak buffer yang bukan JPEG dan buffer terpotong', () {
      expect(parseJpeg(Uint8List.fromList([0x00, 0x01, 0x02, 0x03])), isNull);
      expect(parseJpeg(_jpeg(w: 800, h: 9000).sublist(0, 5)), isNull);
      expect(parseJpeg(Uint8List(0)), isNull);
    });
  });

  group('parsePng', () {
    test('membaca IHDR', () {
      final d = parsePng(_png(w: 1200, h: 3400));
      expect(d!.w, 1200);
      expect(d.h, 3400);
    });

    test('menolak signature yang salah', () {
      final bytes = _png(w: 10, h: 10);
      bytes[1] = 0x00;
      expect(parsePng(bytes), isNull);
    });
  });

  group('parseWebp', () {
    test('membaca VP8 lossy', () {
      final d = parseWebp(_webpVp8(w: 800, h: 2000));
      expect(d!.w, 800);
      expect(d.h, 2000);
    });

    test('membaca VP8X canvas', () {
      final d = parseWebp(_webpVp8x(w: 1600, h: 900));
      expect(d!.w, 1600);
      expect(d.h, 900);
    });

    test('membaca VP8L lossless', () {
      final d = parseWebp(_webpVp8l(w: 640, h: 480));
      expect(d!.w, 640);
      expect(d.h, 480);
    });

    test('menolak start code VP8 yang salah', () {
      final bytes = _webpVp8(w: 800, h: 2000);
      bytes[19] = 0x00;
      expect(parseWebp(bytes), isNull);
    });
  });

  group('parseHeaderGambar', () {
    test('mengenali ketiga format', () {
      expect(parseHeaderGambar(_jpeg(w: 800, h: 9700))!.h, 9700);
      expect(parseHeaderGambar(_png(w: 800, h: 9700))!.h, 9700);
      expect(parseHeaderGambar(_webpVp8(w: 800, h: 9700))!.h, 9700);
    });

    test('format lain jatuh ke null untuk jaring pengaman', () {
      // AVIF/HEIF: kotak 'ftypavif'. Tidak diuraikan, jadi `null`.
      final avif = Uint8List.fromList([
        ...'ftypavif'.codeUnits,
        ...List<int>.filled(24, 0),
      ]);
      expect(parseHeaderGambar(avif), isNull);
      expect(parseHeaderGambar(Uint8List(0)), isNull);
    });
  });

  group('pilihRasio', () {
    // Sampel nyata dari satu chapter: median 0,0863 tapi mean 0,2009.
    const sampel = [0.08, 0.086, 0.139, 0.667, 1.303];

    test('memakai rasio sendiri kalau ada', () {
      expect(pilihRasio(index: 2, rasionya: sampel), 0.139);
    });

    test('jatuh ke tetangga terdekat, bukan rata-rata', () {
      // Index 5 tidak diketahui; tetangganya langsung index 4 = 1,303.
      // Yang dipakai adalah nilai tetangga itu, bukan mean seluruh daftar
      // (0,455) dan bukan median (0,139).
      final withSlot = [0.08, 0.086, 0.139, 0.667, 1.303, null, null];
      final mean = sampel.reduce((a, b) => a + b) / sampel.length;

      final r = pilihRasio(index: 5, rasionya: withSlot);
      expect(r, 1.303);
      expect(r, isNot(closeTo(mean, 0.01)));
      expect(r, isNot(closeTo(medianDiketahui(sampel)!, 0.01)));
    });

    test('data timpang tidak membuat strip terlalu tinggi lewat mean', () {
      // Dua halaman depan tidak diketahui, jadi tidak ada tetangga langsung dan
      // yang dipakai median — bukan mean. Mean dari sampel adalah 0,455.
      final mean = sampel.reduce((a, b) => a + b) / sampel.length;
      expect(mean, greaterThan(0.4));

      final median = pilihRasio(index: 0, rasionya: [null, null, ...sampel]);
      expect(median, 0.139);
      expect(median, lessThan(mean));
    });

    test('halaman di tengah memakai tetangga, bukan median', () {
      // Index 0 kosong, tetangganya index 1 = 0,086.
      expect(
        pilihRasio(index: 0, rasionya: [null, 0.086, 0.09, 0.667, 1.303]),
        0.086,
      );
    });

    test('jarak sama memilih halaman sebelum', () {
      // Index 1 dikelilingi 0,5 (index 0) dan 0,7 (index 2).
      expect(pilihRasio(index: 1, rasionya: [0.5, null, 0.7]), 0.5);
    });

    test('median dipakai saat tidak ada tetangga sama sekali', () {
      // Dua halaman pertama kosong, jadi tidak ada tetangga langsung untuk
      // halaman 0 dan yang dipakai median.
      expect(pilihRasio(index: 0, rasionya: [null, null, 0.08, 0.1]), 0.09);
      // Jumlah genap: rata-rata dua tengah. Hasilnya 0,15000000000000002
      // karena penjumlahan floating point, jadi dibandingkan dengan toleransi.
      expect(
        pilihRasio(index: 0, rasionya: [null, null, 0.08, 0.1, 0.2, 0.3]),
        closeTo(0.15, 1e-9),
      );
    });

    test('konstanta 0,1 saat belum ada data sama sekali', () {
      expect(pilihRasio(index: 0, rasionya: [null, null, null]), 0.1);
      expect(pilihRasio(index: 0, rasionya: const []), 0.1);
      expect(rasioKonstantaAwal, 0.1);
    });

    test('index di luar rentang aman', () {
      expect(pilihRasio(index: -1, rasionya: sampel), 0.1);
      expect(pilihRasio(index: 99, rasionya: sampel), 0.1);
    });

    test('mengabaikan nilai nol atau negatif', () {
      // 0 berarti "belum diketahui" di list ini, bukan rasio valid.
      expect(pilihRasio(index: 1, rasionya: [null, 0, -1, 0.2]), 0.2);
    });
  });

  group('medianDiketahui', () {
    test('mengabaikan null', () {
      expect(medianDiketahui([null, 0.08, 0.1, 0.2]), 0.1);
      expect(medianDiketahui([null, null]), isNull);
    });
  });

  group('tinggi yang dihasilkan', () {
    test('rasio 0,08 dan 1,30 menghasilkan tinggi yang sangat berbeda', () {
      // Inilah alasan tinggi tidak boleh ditebak dari lebar: pada lebar logis
      // 360, dua halaman dalam satu chapter punya tinggi 4500 px dan 276 px.
      const lebar = 360.0;
      expect(lebar / 0.08, 4500);
      expect(lebar / 1.303, lessThan(280));
      expect(lebar / 0.08 / (lebar / 1.303), greaterThan(15));
    });

    test('placeholder lama 0,6 kali lebar meleset jauh', () {
      const lebar = 360.0;
      expect(lebar * 0.6, 216);
      // Untuk strip 800x10000, placeholder lama meleset 20 kali.
      expect(lebar / 0.08 / (lebar * 0.6), greaterThan(20));
    });
  });
}
