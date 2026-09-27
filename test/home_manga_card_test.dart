import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/home/presentation/widgets/manga_card.dart';
import 'package:alana/models/manga.dart';

Manga _manga(String judul, {String status = 'On Going'}) {
  return Manga(
    title: judul,
    thumbnail: '',
    url: judul.toLowerCase(),
    status: status,
  );
}

/// Tinggi dan lebar kartu yang dipakai semua test di file ini, supaya
/// perbandingan posisi antar kartu tidak dipengaruhi ukuran yang berbeda.
const _lebar = 120.0;
const _tinggi = 240.0;

Future<void> _pump(WidgetTester tester, List<Manga> mangas) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            for (final manga in mangas)
              SizedBox(
                width: _lebar,
                height: _tinggi,
                child: MangaCard(manga: manga, width: double.infinity),
              ),
          ],
        ),
      ),
    ),
  );
}

Finder _statusDari(int kartu) => find.descendant(
  of: find.byType(MangaCard).at(kartu),
  matching: find.text('On Going'),
);

Finder _judulDari(int kartu, String judul) => find.descendant(
  of: find.byType(MangaCard).at(kartu),
  matching: find.text(judul),
);

void main() {
  group('MangaCard posisi status', () {
    testWidgets('status tidak bergeser saat judul satu atau dua baris', (
      tester,
    ) async {
      await _pump(tester, [
        _manga('Pendek'),
        _manga(
          'Judul yang sengaja dibuat panjang sekali supaya membungkus '
          'menjadi dua baris di dalam kartu selebar seratus dua puluh piksel',
        ),
      ]);

      // Kalau status ikut mengalir di bawah judul, kartu pertama (judul satu
      // baris) akan mengangkat statusnya sementara kartu kedua tidak. Dua
      // koordinat ini harus identik.
      final pendek = tester.getTopLeft(_statusDari(0)).dy;
      final panjang = tester.getTopLeft(_statusDari(1)).dy;

      expect(pendek, panjang);
    });

    testWidgets('judul panjang tidak menabrak baris status', (tester) async {
      await _pump(tester, [
        _manga(
          'Judul yang sengaja dibuat panjang sekali supaya membungkus '
          'menjadi dua baris di dalam kartu selebar seratus dua puluh piksel',
        ),
      ]);

      final bawahJudul = tester
          .getBottomLeft(
            _judulDari(
              0,
              'Judul yang sengaja dibuat panjang sekali supaya membungkus '
              'menjadi dua baris di dalam kartu selebar seratus dua puluh piksel',
            ),
          )
          .dy;
      final atasStatus = tester.getTopLeft(_statusDari(0)).dy;

      expect(bawahJudul, lessThanOrEqualTo(atasStatus));
      expect(tester.takeException(), isNull);
    });

    testWidgets('status menempel ke dasar kartu', (tester) async {
      await _pump(tester, [_manga('Pendek')]);

      // Status adalah elemen paling bawah di area teks, jadi jaraknya dari
      // dasar kartu cuma sebilah padding (8 piksel) ditambah margin bawaan
      // [Card] (4 piksel). Kalau status ikut mengalir, jaraknya justru
      // bertambah sebesar tinggi baris judul.
      final bawahStatus = tester.getBottomLeft(_statusDari(0)).dy;
      final bawahKartu = tester.getBottomLeft(find.byType(Card)).dy;

      expect(bawahKartu - bawahStatus, lessThanOrEqualTo(12));
    });
  });

  group('MangaCard warna status', () {
    testWidgets('status memakai warna berbeda dari judul', (tester) async {
      await _pump(tester, [_manga('Pendek')]);

      final gayaStatus = tester.widget<Text>(_statusDari(0)).style!;
      final gayaJudul = tester.widget<Text>(_judulDari(0, 'Pendek')).style!;

      expect(gayaStatus.color, isNotNull);
      expect(gayaJudul.color, isNotNull);
      expect(gayaStatus.color, isNot(gayaJudul.color));
    });

    testWidgets('status kosong tidak diberi warna status', (tester) async {
      // Judul kartu kedua sengaja tidak sama dengan teks status kosongnya,
      // kalau tidak `find.text` akan menemukan dua elemen.
      await _pump(tester, [
        _manga('Kartu pertama'),
        _manga('Kartu kedua', status: ''),
      ]);

      final gayaBerwarna = tester.widget<Text>(_statusDari(0)).style!;
      final gayaKosong = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(MangaCard).at(1),
              matching: find.text('Tanpa status'),
            ),
          )
          .style!;
      final gayaJudul = tester
          .widget<Text>(_judulDari(0, 'Kartu pertama'))
          .style!;

      // Status yang benar-benar ada harus berwarna dan berbeda dari judul.
      expect(gayaBerwarna.color, isNot(gayaJudul.color));

      // Tapi "Tanpa status" tidak boleh ikut berwarna: mewarnainya seperti
      // status sungguhan membuat ketiadaan data terlihat seperti data valid.
      expect(gayaKosong.color, isNot(gayaBerwarna.color));
    });
  });
}
