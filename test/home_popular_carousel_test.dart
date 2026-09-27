import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/home/presentation/widgets/popular_carousel.dart';
import 'package:alana/models/manga.dart';

/// Manga tanpa thumbnail: [CoverImage] lalu menampilkan ikon, tidak memanggil
/// jaringan. Widget carousel jadi bisa diuji tanpa HTTP mock.
Manga _manga(String judul, {int ch = 0, num rating = 0, int dilihat = 0}) {
  return Manga(
    title: judul,
    thumbnail: '',
    url: judul.toLowerCase(),
    latestChapterNumber: ch,
    rating: rating,
    viewCount: dilihat,
  );
}

Future<void> _pump(WidgetTester tester, Widget anak) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: anak)),
    ),
  );
}

void main() {
  group('Populer jadi carousel', () {
    testWidgets('setiap judul punya banner dengan lencana peringkat', (
      tester,
    ) async {
      final mangas = [_manga('Satu'), _manga('Dua'), _manga('Tiga')];

      await _pump(tester, PopularCarousel(mangas: mangas));

      // Hanya banner pertama yang dibangun; sisanya di-cache oleh PageView
      // sesuai viewportFraction.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Satu'), findsOneWidget);
    });

    testWidgets('judul panjang tidak membuat banner meluber', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [
            _manga(
              'Judul yang sangat panjang sekali sehingga tidak muat di '
              'dalam satu baris banner mana pun',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('jumlah pip indikator sesuai jumlah item', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
        ),
      );

      // Satu indikator untuk carousel ini; pip-nya sendiri tidak punya
      // teks jadi tidak bisa dihitung lewat find.text.
      expect(find.byType(IndikatorBanner), findsOneWidget);
    });
  });

  group('isi banner', () {
    testWidgets('status, negara, rating, jumlah dibaca, dan chapter', (
      tester,
    ) async {
      final manga = Manga(
        title: 'Solo Leveling',
        thumbnail: '',
        url: 'solo-leveling',
        status: 'Berjalan',
        country: 'Korea',
        latestChapterNumber: 200,
        rating: 9.12,
        viewCount: 12345,
      );

      await _pump(tester, PopularCarousel(mangas: [manga]));

      expect(find.text('Solo Leveling'), findsOneWidget);
      expect(find.text('Berjalan'), findsOneWidget);
      expect(find.text('Korea'), findsOneWidget);
      expect(find.text('9.1'), findsOneWidget);
      expect(find.text('12rb'), findsOneWidget);
      expect(find.text('Ch 200'), findsOneWidget);
    });

    testWidgets('judul tanpa chapter dan tanpa rating tetap aman', (
      tester,
    ) async {
      await _pump(tester, PopularCarousel(mangas: [_manga('Kosong')]));

      expect(find.text('Kosong'), findsOneWidget);
      expect(find.text('Belum ada chapter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('auto-advance', () {
    testWidgets('berpindah halaman setelah interval', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(seconds: 1),
        ),
      );

      expect(find.text('Satu'), findsOneWidget);

      // Selesaikan animasi perpindahan halaman.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Dua'), findsOneWidget);
    });

    testWidgets('berhenti saat satu item, tidak memanggil pageview', (
      tester,
    ) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Tunggal')],
          interval: const Duration(seconds: 1),
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Tunggal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('formatter', () {
    test('formatRating membuang desimal yang tidak perlu', () {
      expect(formatRating(9), '9');
      expect(formatRating(9.0), '9');
      expect(formatRating(9.12), '9.1');
      expect(formatRating(8.55), '8.6');
    });

    test('formatRingkas memendekkan jumlah dibaca', () {
      expect(formatRingkas(0), '0');
      expect(formatRingkas(999), '999');
      expect(formatRingkas(1000), '1rb');
      expect(formatRingkas(12345), '12rb');
      expect(formatRingkas(999999), '1000rb');
      expect(formatRingkas(1000000), '1,0jt');
      expect(formatRingkas(2500000), '2,5jt');
      expect(formatRingkas(12000000), '12jt');
    });

    test('infoChapter memakai waktu relatif bila ada', () {
      final tanpaWaktu = _manga('X', ch: 12);
      expect(infoChapter(tanpaWaktu), 'Ch 12');

      // Selisih 5 menit 30 detik supaya inMinutes Pasti 5, bukan 4 karena
      // mikrodetik yang hilang saat dikonversi ke string.
      final denganWaktu = Manga(
        title: 'X',
        thumbnail: '',
        url: 'x',
        latestChapterNumber: 12,
        latestChapterTime: DateTime.now()
            .subtract(const Duration(minutes: 5, seconds: 30))
            .toIso8601String(),
      );
      expect(infoChapter(denganWaktu), 'Ch 12 • 5 m');
    });

    test('infoChapter jatuh ke status saat chapter belum ada', () {
      expect(infoChapter(_manga('X')), 'Belum ada chapter');
      expect(
        infoChapter(
          Manga(title: 'X', thumbnail: '', url: 'x', status: 'Hiatus'),
        ),
        'Hiatus',
      );
    });
  });
}
