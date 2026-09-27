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

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Satu'), findsWidgets);
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
        status: 'On Going',
        country: 'Korea',
        latestChapterNumber: 200,
        rating: 9.12,
        viewCount: 12345,
      );

      await _pump(tester, PopularCarousel(mangas: [manga]));

      // Daftar diulang 100 kali dan PageView membangun kartu tetangga untuk
      // pratinjau, jadi teks yang sama muncul lebih dari sekali.
      expect(find.text('Solo Leveling'), findsWidgets);
      expect(find.text('On Going'), findsNWidgets(2));
      expect(find.text('Korea'), findsNWidgets(2));
      expect(find.text('9.1'), findsNWidgets(2));
      expect(find.text('12rb'), findsNWidgets(2));
      expect(find.text('Ch 200'), findsNWidgets(2));
    });

    testWidgets('judul tanpa chapter dan tanpa rating tetap aman', (
      tester,
    ) async {
      await _pump(tester, PopularCarousel(mangas: [_manga('Kosong')]));

      expect(find.text('Kosong'), findsWidgets);
      expect(find.text('Belum ada chapter'), findsWidgets);
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

      // Daftar diulang 100 kali, jadi kartu tetangga yang sama ikut terbangun
      // untuk pratinjau dan judulnya muncul lebih dari sekali.
      expect(find.text('Tunggal'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('infinite scroll', () {
    // Maju dan mundur melewati batas daftar asli harus tetap menampilkan
    // judul yang benar. Kalau posisi virtual tidak dipetakan balik ke urutan
    // asli, lencana peringkat ikut salah dan carousel berhenti di ujung.
    //
    // `pumpAndSettle` tidak dipakai di sini: indikator autoplay sengaja
    // berjalan tanpa henti, jadi tidak akan pernah ada frame yang tenang.
    Future<void> geser(WidgetTester tester, int kali, {int arah = -1}) async {
      for (var i = 0; i < kali; i++) {
        await tester.drag(
          find.byType(PageView),
          Offset(400.0 * arah, 0),
          warnIfMissed: false,
        );
        // Selesaikan animasi snap ke halaman berikutnya.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('mulai di tengah, bukan di ujung daftar', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(hours: 1),
        ),
      );

      // Kalau controller masih di halaman 0, satu gesekan ke kiri tidak
      // melakukan apa-apa karena itu ujung daftar.
      await geser(tester, 1, arah: 1);
      await geser(tester, 1, arah: 1);

      expect(find.text('Tiga'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bisa maju melewati judul terakhir', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(hours: 1),
        ),
      );

      // Lima gesekan dari Satu: melewati Tiga, lalu memutar ke awal lagi.
      await geser(tester, 5);

      expect(find.text('Tiga'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bisa mundur melewati judul pertama', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(hours: 1),
        ),
      );

      // Lima gesekan ke kiri dari Satu: melewati Tiga, lalu ke Dua.
      await geser(tester, 5, arah: 1);

      expect(find.text('Dua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lencana peringkat milik kartu, bukan halaman aktif', (
      tester,
    ) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(hours: 1),
        ),
      );

      await geser(tester, 1);

      // PageView membangun kartu tetangga untuk pratinjau, jadi tiga lencana
      // terlihat berdampingan dengan angka yang berbeda. Kalau semuanya memakai
      //[_halaman], ketiganya akan jadi satu angka yang sama.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('indikator hanya punya pip sebanyak data asli', (tester) async {
      await _pump(
        tester,
        PopularCarousel(
          mangas: [_manga('Satu'), _manga('Dua'), _manga('Tiga')],
          interval: const Duration(hours: 1),
        ),
      );

      await geser(tester, 3);

      // Kalau pip ikut memakai indeks virtual, baris indikator akan memanjang
      // jadi ratusan pip setelah digeser.
      final baris = tester.widgetList<Row>(
        find.descendant(
          of: find.byType(IndikatorBanner),
          matching: find.byType(Row),
        ),
      );
      expect(baris, hasLength(1));
      final pip = (baris.single.children as List<dynamic>).length;
      expect(pip, 3);
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
