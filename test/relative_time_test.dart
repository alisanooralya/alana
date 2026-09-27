import 'package:flutter_test/flutter_test.dart';

import 'package:alana/utils/manga_labels.dart';
import 'package:alana/utils/relative_time.dart';

/// Dipakai empat layar sekaligus, jadi setiap cabangnya dikunci test.
void main() {
  group('formatRelativeTime', () {
    String label(Duration lalu) =>
        formatRelativeTime(DateTime.now().subtract(lalu).toIso8601String());

    test('kurang dari semenit tetap "Baru"', () {
      expect(label(const Duration(seconds: 20)), 'Baru');
    });

    test('menit', () {
      expect(label(const Duration(minutes: 1, seconds: 20)), '1 m');
      expect(label(const Duration(minutes: 59, seconds: 20)), '59 m');
    });

    test('jam menggantikan menit mentah', () {
      // Versi lama menulis "120 mnt" untuk dua jam.
      expect(label(const Duration(hours: 2, minutes: 5)), '2 jam');
      expect(label(const Duration(hours: 23, minutes: 59)), '23 jam');
    });

    test('satu hari penuh jadi "Kemarin"', () {
      expect(label(const Duration(hours: 24, minutes: 5)), 'Kemarin');
      expect(label(const Duration(days: 1, hours: 20)), 'Kemarin');
    });

    test('hari, minggu, bulan, tahun', () {
      expect(label(const Duration(days: 3, hours: 1)), '3 hari lalu');
      expect(label(const Duration(days: 10)), '1 minggu lalu');
      expect(label(const Duration(days: 45)), '1 bulan lalu');
      expect(label(const Duration(days: 400)), '1 tahun lalu');
    });

    test('input rusak menghasilkan string kosong, bukan "Baru"', () {
      expect(formatRelativeTime(null), '');
      expect(formatRelativeTime(''), '');
      expect(formatRelativeTime('bukan tanggal'), '');
    });

    test('jam perangkat lebih maju dari server tidak jadi "Now lalu"', () {
      final besok = DateTime.now().add(const Duration(hours: 2));
      expect(formatRelativeTime(besok.toIso8601String()), 'Baru');
    });
  });

  group('mangaStatusLabel', () {
    test('kode status dipetakan ke label yang tampil di UI', () {
      expect(mangaStatusLabel(1), 'On Going');
      expect(mangaStatusLabel(2), 'Selesai');
      expect(mangaStatusLabel(3), 'Hiatus');
    });

    test('kode yang datang sebagai string atau angka pecahan tetap kena', () {
      // Membandingkan dengan int saja pernah membuat "1" menghasilkan label
      // kosong.
      expect(mangaStatusLabel('1'), 'On Going');
      expect(mangaStatusLabel(1.0), 'On Going');
      expect(mangaStatusLabel(' 3 '), 'Hiatus');
    });

    test('status di luar daftar menghasilkan string kosong', () {
      expect(mangaStatusLabel(null), '');
      expect(mangaStatusLabel(9), '');
      expect(mangaStatusLabel('abc'), '');
    });
  });

  group('countryLabel', () {
    test('kode negara dipetakan ke nama yang lebih panjang', () {
      expect(countryLabel('KR'), 'Korea');
      expect(countryLabel('cn'), 'China');
      expect(countryLabel('EN'), 'English');
      expect(countryLabel('JP'), 'Japan');
    });

    test('kode yang tidak dikenal diteruskan apa adanya', () {
      expect(countryLabel('FR'), 'FR');
      expect(countryLabel(null), '');
    });
  });
}
