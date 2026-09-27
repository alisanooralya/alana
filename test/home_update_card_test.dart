import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/home/presentation/widgets/update_card.dart';
import 'package:alana/models/manga.dart';
import 'package:alana/utils/relative_time.dart';

/// Salinan satu elemen dari respons `/v1/manga/list` yang asli, dipotong ke
/// field yang dipakai [Manga]. Kalau backend mengubah nama field, test ini
/// gagal sebelum efeknya kelihatan di UI.
Map<String, dynamic> _elemenApi({bool denganChapters = true}) {
  return {
    'title': 'I Became The Master Of The Weakest Demon King',
    'manga_id': '83bcbeb8-0388-4514-a683-c3e28f879be6',
    'cover_image_url': 'https://assets.shngm.id/thumbnail/cover/banner_1779466492126_kv00b7.jpg',
    'status': 1,
    'country_id': 'KR',
    'latest_chapter_number': 39,
    'latest_chapter_time': '2026-09-27T10:14:22Z',
    'user_rate': 8.5,
    'view_count': 2320595,
    if (denganChapters)
      'chapters': [
        {
          'chapter_id': '62c397c1',
          'chapter_number': 39,
          'created_at': '2026-09-27T10:14:22Z',
        },
        {
          'chapter_id': '74430b62',
          'chapter_number': 38,
          'created_at': '2026-09-19T16:38:42Z',
        },
        {
          'chapter_id': '151941f1',
          'chapter_number': 37,
          'created_at': '2026-09-12T16:46:10Z',
        },
      ],
  };
}

/// Dipasang lewat [WidgetTester.view] supaya [MediaQuery] ikut menyebut 360,
/// bukan 800 bawaan test.
const double _lebarLayar = 360;

/// Dua chapter supaya chip membungkus ke dua baris seperti pada contoh.
Manga _manga({String judul = 'I Became The Master Of The Weakest Demon King'}) {
  return Manga(
    title: judul,
    thumbnail: '',
    url: '83bcbeb8',
    countryCode: 'KR',
    chapters: [
      Chapter(
        number: 39,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 2, minutes: 5))
            .toIso8601String(),
      ),
      Chapter(
        number: 38,
        createdAt: DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Widget anak) async {
  tester.view.physicalSize = const Size(_lebarLayar, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Ukuran persis seperti grid yang menghitungnya, kalau tidak cover melebar.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: hitungLebarSel(_lebarLayar),
            height: hitungTinggiSel(_lebarLayar),
            child: anak,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Manga parsing chapters', () {
    test('larik chapters dibaca urut dari yang terbaru', () {
      final manga = Manga.fromJson(_elemenApi());

      expect(manga.chapters, hasLength(3));
      expect(manga.chapters.first.number, 39);
      expect(manga.chapters.last.number, 37);
    });

    test('chapterTerbaru membatasi sesuai jumlah diminta', () {
      final manga = Manga.fromJson(_elemenApi());

      expect(manga.chapterTerbaru(jumlah: 2).map((c) => c.number), [39, 38]);
      expect(manga.chapterTerbaru(jumlah: 1).map((c) => c.number), [39]);
      // Melebihi jumlah data tidak boleh meluber.
      expect(manga.chapterTerbaru(jumlah: 9), hasLength(3));
    });

    test('negara disimpan dua bentuk: kode dan nama', () {
      final manga = Manga.fromJson(_elemenApi());

      // Bendera butuh kode, teks butuh nama panjang.
      expect(manga.countryCode, 'KR');
      expect(manga.country, 'Korea');
    });

    test('tanpa larik chapters, chapter dirakit dari field terbaru', () {
      // Endpoint peringkat tidak mengirim `chapters`; tanpa cadangan, selnya
      // akan kosong tanpa chip.
      final manga = Manga.fromJson(_elemenApi(denganChapters: false));

      expect(manga.chapters, isEmpty);
      final turunan = manga.chapterTerbaru(jumlah: 2);
      expect(turunan, hasLength(1));
      expect(turunan.single.number, 39);
    });

    test('larik chapters rusak tidak membuat parsing gagal', () {
      Map<String, dynamic> rusak() => {
        ..._elemenApi(),
        'chapters': 'bukan larik',
      };

      expect(() => Manga.fromJson(rusak()), returnsNormally);

      Map<String, dynamic> kosong() => {
        ..._elemenApi(),
        'chapters': [
          null,
          42,
          {'chapter_number': 0},
          {'chapter_number': 7},
        ],
      };

      final manga = Manga.fromJson(kosong());
      // Nomor 0 akan tampil sebagai "Chapter 0".
      expect(manga.chapters.map((c) => c.number), [7]);
    });

    test('respon penuh tetap bisa dibaca lewat jsonDecode', () {
      // Menutup kemungkinan ada field yang tidak bisa diserialisasi.
      final manga = Manga.fromJson(
        jsonDecode(jsonEncode(_elemenApi())) as Map<String, dynamic>,
      );
      expect(manga.title, startsWith('I Became'));
    });
  });

  group('UpdateCard isi', () {
    testWidgets('menampilkan judul dan dua chip chapter', (tester) async {
      await _pump(tester, UpdateCard(manga: _manga()));

      expect(
        find.text('I Became The Master Of The Weakest Demon King'),
        findsOneWidget,
      );
      expect(find.text('Chapter 39'), findsOneWidget);
      expect(find.text('Chapter 38'), findsOneWidget);
    });

    testWidgets('waktu memakai label ringkas tanpa kata lalu', (tester) async {
      await _pump(tester, UpdateCard(manga: _manga()));

      // Contoh desain menulis "2 jam", bukan "2 jam lalu".
      expect(find.text('2 jam'), findsOneWidget);
      expect(find.text('3 hari'), findsOneWidget);
      expect(find.textContaining('lalu'), findsNothing);
    });

    testWidgets('bendera hanya tampil bila kode negara ada', (tester) async {
      await _pump(tester, UpdateCard(manga: _manga()));

      // Emoji regional indicator untuk "KR".
      expect(find.text('🇰🇷'), findsOneWidget);

      final tanpaNegara = Manga(
        title: 'Tanpa negara',
        thumbnail: '',
        url: 'x',
        chapters: _manga().chapters,
      );
      await _pump(tester, UpdateCard(manga: tanpaNegara));
      expect(find.text('🇰🇷'), findsNothing);
    });

    testWidgets('satu chapter tetap tampil satu chip', (tester) async {
      final manga = Manga.fromJson(_elemenApi(denganChapters: false));
      await _pump(tester, UpdateCard(manga: manga));

      expect(find.text('Chapter 39'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('judul sangat panjang tidak meluber', (tester) async {
      await _pump(
        tester,
        UpdateCard(
          manga: _manga(judul: 'Judul yang sangat panjang sekali ' * 4),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ukuran sel grid', () {
    test('dua kolom plus padding dan jarak pas ke lebar layar', () {
      const lebarLayar = 360.0;
      final sel = hitungLebarSel(lebarLayar);

      expect(sel * 2 + jarakAntarSelUpdate, 340.0);
      expect(
        lebarLayar - sel * 2,
        paddingHorizontalUpdate * 2 + jarakAntarSelUpdate,
      );
    });

    test('tinggi sel memuat cover, judul, dan dua chip', () {
      final tinggi = hitungTinggiSel(360.0);
      final tinggiCover = hitungLebarSel(360.0) / rasioCoverUpdate;

      // Kalau tidak, ada chip yang keluar dari kotak sel.
      expect(tinggi, greaterThan(tinggiCover));
      expect(tinggi, greaterThan(tinggiCover + 2 * tinggiChip));
    });
  });

  group('formatRelativeTimePendek', () {
    String label(Duration lalu) => formatRelativeTimePendek(
      DateTime.now().subtract(lalu).toIso8601String(),
    );

    test('membuang kata lalu, mempertahankan nilai yang lain', () {
      expect(label(const Duration(hours: 2, minutes: 5)), '2 jam');
      expect(label(const Duration(days: 3)), '3 hari');
      expect(label(const Duration(days: 40)), '1 bulan');
    });

    test('label yang tidak punya lalu tetap sama', () {
      expect(label(const Duration(minutes: 5, seconds: 30)), '5 m');
      expect(label(const Duration(hours: 26)), 'Kemarin');
      expect(label(const Duration(seconds: 10)), 'Baru');
    });

    test('input rusak tetap string kosong', () {
      expect(formatRelativeTimePendek(null), '');
      expect(formatRelativeTimePendek('bukan tanggal'), '');
    });

    test('versi panjang tidak ikut berubah', () {
      // Pemanggil lama (notifikasi, riwayat, carousel) tetap dapat "lalu".
      final waktu = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String();
      expect(formatRelativeTime(waktu), '3 hari lalu');
      expect(formatRelativeTimePendek(waktu), '3 hari');
    });
  });
}
