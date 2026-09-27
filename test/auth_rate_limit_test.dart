import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/auth/data/auth_validators.dart';

void main() {
  group('pesanBatasPercobaan', () {
    test('di bawah satu menit disebut dalam detik', () {
      expect(
        pesanBatasPercobaan(45),
        'Terlalu banyak percobaan. Coba lagi dalam 45 detik.',
      );
    });

    test('satu menit penuh tidak jadi 0 menit', () {
      expect(
        pesanBatasPercobaan(60),
        'Terlalu banyak percobaan. Coba lagi dalam 1 menit.',
      );
      expect(
        pesanBatasPercobaan(119),
        'Terlalu banyak percobaan. Coba lagi dalam 2 menit.',
      );
    });

    test('dua menit ke atas dibulatkan ke atas', () {
      expect(
        pesanBatasPercobaan(120),
        'Terlalu banyak percobaan. Coba lagi dalam 2 menit.',
      );
      // 121 detik harus 3 menit, bukan 2: membulatkan ke bawah akan
      // menjanjikan waktu yang belum tiba.
      expect(
        pesanBatasPercobaan(121),
        'Terlalu banyak percobaan. Coba lagi dalam 3 menit.',
      );
      expect(
        pesanBatasPercobaan(900),
        'Terlalu banyak percobaan. Coba lagi dalam 15 menit.',
      );
    });

    test('nilai nonsense tidak jadi 0 detik atau minus', () {
      expect(pesanBatasPercobaan(0), contains('1 detik'));
      expect(pesanBatasPercobaan(-5), contains('1 detik'));
    });

    test('tidak menyebut jatah percobaan yang tersisa', () {
      // Batas per email 5 dan per IP 30 tidak boleh terlihat. Yang
      // ditampilkan hanya waktu tunggu, karena itulah satu-satunya
      // informasi yang pengguna butuh untuk memutuskan kapan mencoba lagi.
      for (final detik in [1, 30, 45, 60, 119, 120, 300, 900]) {
        final pesan = pesanBatasPercobaan(detik).toLowerCase();
        expect(pesan, isNot(contains('sisa')));
        expect(pesan, isNot(contains('maks')));
        expect(pesan, isNot(contains('jatah')));
        expect(pesan, isNot(contains('dari 5')));
        expect(pesan, isNot(contains('dari 30')));
      }
    });

    test('tidak pernah menjanjikan waktu lebih singkat dari kenyataan', () {
      // Kalau pesan lebih pendek dari waktu asli, user mencoba lagi terlalu
      // awal lalu mendapat 429 lagi tanpa tahu kenapa.
      for (final detik in [
        1,
        5,
        59,
        60,
        61,
        119,
        120,
        121,
        300,
        599,
        600,
        900,
      ]) {
        final pesan = pesanBatasPercobaan(detik);
        if (pesan.contains('detik')) {
          final shown = int.parse(
            RegExp(r'dalam (\d+) detik').firstMatch(pesan)!.group(1)!,
          );
          expect(shown, greaterThanOrEqualTo(detik));
        } else {
          final shown = int.parse(
            RegExp(r'dalam (\d+) menit').firstMatch(pesan)!.group(1)!,
          );
          expect(shown * 60, greaterThanOrEqualTo(detik));
        }
      }
    });
  });

  group('pesanAuthRamah', () {
    test('PercobaanLoginDibatasi memakai pesan waktu tunggu', () {
      expect(
        pesanAuthRamah(const PercobaanLoginDibatasi(300)),
        'Terlalu banyak percobaan. Coba lagi dalam 5 menit.',
      );
    });

    test('tidak membaca angka dari teks error lain', () {
      // Pastikan penambahan tipe baru tidak menggeser perilaku pesan lama.
      expect(
        pesanAuthRamah('invalid login credentials'),
        'Email atau password salah.',
      );
    });
  });
}
