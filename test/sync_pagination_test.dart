import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/sync/data/sync_remote.dart';

/// Sumber tiruan: `total` baris, `halaman` baris tiap halaman, seperti PostgREST.
Future<List<int>> Function(int dari, int sampai) _sumber(
  int total,
  int halaman,
) {
  return (int dari, int sampai) async {
    return [for (var i = dari; i <= sampai && i < total; i++) i];
  };
}

void main() {
  group('tarikBerpaginasi', () {
    test('mengambil semua baris pada jumlah di bawah satu halaman', () async {
      var panggilan = 0;
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: (dari, sampai) {
          panggilan++;
          return _sumber(3, SyncRemote.ukuranHalaman)(dari, sampai);
        },
      );

      expect(hasil, [0, 1, 2]);
      expect(panggilan, 1);
    });

    test('halaman penuh selalu meminta halaman berikutnya', () async {
      // 1000 baris persis satu halaman. Dengan 1001 baris atau lebih, baris
      // ke-1001 akan terpotong diam-diam kalau loop berhenti begitu halaman
      // pertama penuh. Jadi halaman penuh harus selalu ditanyakan lagi.
      var panggilan = 0;
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: (dari, sampai) async {
          panggilan++;
          return _sumber(1000, SyncRemote.ukuranHalaman)(dari, sampai);
        },
      );

      expect(hasil, hasLength(1000));
      expect(hasil.first, 0);
      expect(hasil.last, 999);
      expect(
        panggilan,
        2,
        reason: 'range(0,999) yang sudah penuh tidak menjamin itu habis',
      );
    });

    test('1001 baris tetap terambil semua', () async {
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: _sumber(1001, SyncRemote.ukuranHalaman),
      );

      expect(hasil, hasLength(1001));
      expect(hasil.last, 1000);
    });

    test('melewati 1000 baris tanpa kehilangan atau duplikasi', () async {
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: _sumber(2500, SyncRemote.ukuranHalaman),
      );

      expect(hasil, hasLength(2500));
      expect(hasil.first, 0);
      expect(hasil.last, 2499);
      // Berurutan penuh tanpa lompatan dan tanpa pengulangan.
      for (var i = 0; i < hasil.length; i++) {
        expect(hasil[i], i);
      }
    });

    test('rentang yang diminta benar-benar bergerak maju', () async {
      final rentang = <String>[];
      await SyncRemote.tarikBerpaginasi<int>(
        ambil: (dari, sampai) async {
          rentang.add('$dari-$sampai');
          return _sumber(2500, SyncRemote.ukuranHalaman)(dari, sampai);
        },
      );

      // range() PostgREST inklusif di kedua ujung.
      expect(rentang, ['0-999', '1000-1999', '2000-2999']);
    });

    test('halaman kosong langsung berhenti', () async {
      var panggilan = 0;
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: (dari, sampai) async {
          panggilan++;
          return const [];
        },
      );

      expect(hasil, isEmpty);
      expect(panggilan, 1);
    });

    test('berhenti di batas pengaman kalau halaman selalu penuh', () async {
      // Melindungi dari perulangan tanpa akhir kalau sumber data rusak.
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: (dari, sampai) =>
            Future.value([for (var i = dari; i <= sampai; i++) i]),
        halaman: 2,
      );

      expect(hasil, isNotEmpty);
      // 500 halaman x 2 baris = 1000 baris, lalu berhenti.
      expect(hasil, hasLength(1000));
    });

    test('ukuran halaman bisa dikecilkan untuk pengujian', () async {
      final hasil = await SyncRemote.tarikBerpaginasi<int>(
        ambil: _sumber(7, 3),
        halaman: 3,
      );
      expect(hasil, [0, 1, 2, 3, 4, 5, 6]);
    });
  });
}
