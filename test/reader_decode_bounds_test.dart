import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/reader/presentation/widgets/reader_image.dart';

/// Menghitung dimensi hasil decode seperti yang dilakukan Flutter untuk
/// `ResizeImagePolicy.fit`: skala agar muat dalam batas, rasio aspek
/// terjaga, dan tidak pernah membesar.
///
/// Menyalin algoritma dari `image_provider.dart` supaya bisa diuji tanpa
/// engine gambar.
({int w, int h}) decodeFit({
  required int lebarSumber,
  required int tinggiSumber,
  required int? maksLebar,
  required int? maksTinggi,
}) {
  final rasio = lebarSumber / tinggiSumber;
  var lebar = lebarSumber;
  var tinggi = tinggiSumber;
  final batasLebar = maksLebar ?? lebarSumber;
  final batasTinggi = maksTinggi ?? tinggiSumber;
  if (lebar > batasLebar) {
    lebar = batasLebar;
    tinggi = lebar ~/ rasio;
  }
  if (tinggi > batasTinggi) {
    tinggi = batasTinggi;
    lebar = (tinggi * rasio).floor();
  }
  return (w: lebar, h: tinggi);
}

/// Memori bitmap ARGB8 dalam MiB.
double memoriMiB(int lebar, int tinggi) => lebar * tinggi * 4 / (1024 * 1024);

void main() {
  // Strip webtoon yang disebut di komentar kode: 800 x 9700.
  const lebarSumber = 800;
  const tinggiSumber = 9700;

  // Ponsel umum: 400 x 800 logical, dpr 3.
  final batas = batasDecode(lebarLogis: 400, tinggiLogis: 800, dpr: 3);

  group('batasDecode', () {
    test('lebar mengikuti lebar layar dikali dpr', () {
      expect(batas.width, 1200);
    });

    test('tinggi adalah dua kali tinggi layar dikali dpr', () {
      // 800 x 3 x 2 = 4800
      expect(batas.height, 4800);
    });

    test('ukuran tidak sah menghasilkan null, bukan nol', () {
      // cacheWidth atau cacheHeight bernilai nol akan dipakai apa adanya
      // dan merusak perhitungan, jadi dikembalikan null agar Flutter
      // menentukan sendiri.
      final cacak = batasDecode(lebarLogis: 0, tinggiLogis: 0, dpr: 1);
      expect(cacak.width, isNull);
      expect(cacak.height, isNull);
    });

    test('faktor tinggi bisa disesuaikan', () {
      final satu = batasDecode(
        lebarLogis: 400,
        tinggiLogis: 800,
        dpr: 1,
        faktorTinggi: 1,
      );
      expect(satu.height, 800);
    });
  });

  group('dampak memori pada strip webtoon 800x9700', () {
    test('tanpa batas decode, satu halaman sekitar 30 MB', () {
      final polos = decodeFit(
        lebarSumber: lebarSumber,
        tinggiSumber: tinggiSumber,
        maksLebar: null,
        maksTinggi: null,
      );
      expect(memoriMiB(polos.w, polos.h), greaterThan(28));
    });

    test('batas lebar tidak berefek saat sumber lebih sempit dari layar', () {
      // Lebar fisikal 1200 px tapi sumber cuma 800 px, dan Flutter tidak
      // pernah memperbesar. Batas lebar karena itu tidak mengubah apa pun.
      final hanyaLebar = decodeFit(
        lebarSumber: lebarSumber,
        tinggiSumber: tinggiSumber,
        maksLebar: batas.width,
        maksTinggi: null,
      );
      expect(hanyaLebar.w, lebarSumber);
      expect(hanyaLebar.h, tinggiSumber);
      expect(memoriMiB(hanyaLebar.w, hanyaLebar.h), greaterThan(28));
    });

    test('batas tinggi yang menahan memori ke bawah 8 MB', () {
      final keduanya = decodeFit(
        lebarSumber: lebarSumber,
        tinggiSumber: tinggiSumber,
        maksLebar: batas.width,
        maksTinggi: batas.height,
      );
      expect(memoriMiB(keduanya.w, keduanya.h), lessThan(8));

      // Rasio aspek harus tetap terjaga, kalau tidak gambar akan gepeng.
      final rasioSumber = lebarSumber / tinggiSumber;
      final rasioHasil = keduanya.w / keduanya.h;
      expect(rasioHasil, closeTo(rasioSumber, 0.01));
    });

    test('beberapa halaman yang hidup bersamaan muat di bawah 32 MB', () {
      // Empat halaman adalah wajar untuk viewport reader vertikal.
      final perHalaman = decodeFit(
        lebarSumber: lebarSumber,
        tinggiSumber: tinggiSumber,
        maksLebar: batas.width,
        maksTinggi: batas.height,
      );
      final total = memoriMiB(perHalaman.w, perHalaman.h) * 4;
      // Tanpa batas: 800 x 9700 = 29,6 MB per halaman, 118 MB untuk empat.
      expect(total, lessThan(32));
      expect(memoriMiB(perHalaman.w, perHalaman.h), lessThan(8));
    });
  });

  group('gambar biasa tidak dirugikan', () {
    test('halaman normal 800x1200 tetap full-width', () {
      final normal = decodeFit(
        lebarSumber: 800,
        tinggiSumber: 1200,
        maksLebar: batas.width,
        maksTinggi: batas.height,
      );
      // Batas lebar dan tinggi keduanya lebih besar dari ukuran sumber,
      // jadi tidak ada yang diperkecil.
      expect(normal.w, 800);
      expect(normal.h, 1200);
    });

    test('gambar kecil tidak diperbesar', () {
      final kecil = decodeFit(
        lebarSumber: 300,
        tinggiSumber: 400,
        maksLebar: batas.width,
        maksTinggi: batas.height,
      );
      expect(kecil.w, 300);
      expect(kecil.h, 400);
    });

    test('halaman tinggi yang wajar tetap dikecilkan hanya seperlunya', () {
      // 800 x 3000 masih wajar untuk satu halaman, tidak ekstrem seperti
      // 9700. Batasnya tidak boleh memotongnya jadi terlalu kecil.
      final wajar = decodeFit(
        lebarSumber: 800,
        tinggiSumber: 3000,
        maksLebar: 400,
        maksTinggi: 4800,
      );
      // Lebar dibatasi ke 400, tinggi mengikuti rasio: 3000 * 400 / 800.
      expect(wajar.w, 400);
      expect(wajar.h, 1500);
    });
  });
}
