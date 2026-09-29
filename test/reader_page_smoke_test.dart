import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alana/features/downloads/data/download_manager.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/reader/presentation/reader_page.dart';
import 'package:alana/features/reader/presentation/reader_providers.dart';
import 'package:alana/features/reader/presentation/widgets/reader_image.dart';
import 'package:alana/models/page.dart' as manga;

/// Smoke test halaman reader: memastikan subtree-nya benar-benar dirender.
///
/// Test ini ada karena `ref.invalidate` pernah dipanggil dari `initState`.
/// Itu melempar assertion Riverpod yang menggagalkan build, dan seluruh
/// subtree reader diganti `ErrorWidget` — di mode release `ErrorWidget`
/// hanya kotak putih kosong, jadi gejalanya "layar putih" tanpa jejak
/// apa pun. Assertion di debug membuat `ErrorWidget` terlihat sebagai kotak
/// merah; test ini menangkapnya lebih awal dan lebih jelas.
class _DownloadManagerUji extends DownloadManager {
  @override
  Future<DownloadState> build() async =>
      DownloadState(entries: const {}, queue: const []);
}

List<manga.Page> _halaman(int jumlah) => [
  for (var i = 0; i < jumlah; i++)
    manga.Page(index: i, imageUrl: 'https://contoh.invalid/$i.jpg'),
];

Widget _app({
  required List<manga.Page> Function() halaman,
  required Widget Function(Widget) pembungkus,
}) {
  return ProviderScope(
    overrides: [
      pageListProvider.overrideWith((ref, chapterId) async => halaman()),
      downloadManagerProvider.overrideWith(_DownloadManagerUji.new),
    ],
    child: MaterialApp(
      home: pembungkus(
        const ReaderPage(
          mangaId: 'm1',
          chapterId: 'c1',
          chapterName: 'Ch 1',
          mangaTitle: 'Judul',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('reader merender list dan item gambarnya', (tester) async {
    await tester.pumpWidget(
      _app(halaman: () => _halaman(6), pembungkus: (w) => w),
    );
    await tester.pump();
    // `tungguAwal` menunggu paling lama 1,5 detik. Kalau tidak dilewati, timer
    //-nya masih hidup saat test ditutup dan `flutter test` menggagalkan.
    await tester.pump(const Duration(milliseconds: 2000));

    expect(
      find.byType(ErrorWidget),
      findsNothing,
      reason: 'ErrorWidget berarti build reader gagal',
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ReaderImage), findsWidgets);
  });

  testWidgets('halaman detail di bawah reader tidak merusak build', (
    tester,
  ) async {
    // Meniru kondisi nyata: halaman detail masih mounted di bawah reader dan
    // ia `watch(historyRepositoryProvider)`.
    await tester.pumpWidget(
      _app(
        halaman: () => _halaman(6),
        pembungkus: (reader) => Stack(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final riwayat = ref.watch(historyRepositoryProvider);
                return SizedBox(
                  height: 8,
                  child: Text('riwayat=${riwayat.length}'),
                );
              },
            ),
            Positioned.fill(child: reader),
          ],
        ),
      ),
    );
    await tester.pump();
    // `tungguAwal` menunggu paling lama 1,5 detik. Kalau tidak dilewati, timer
    //-nya masih hidup saat test ditutup dan `flutter test` menggagalkan.
    await tester.pump(const Duration(milliseconds: 2000));

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('gulir dan kembali tidak melempar exception', (tester) async {
    await tester.pumpWidget(
      _app(halaman: () => _halaman(20), pembungkus: (w) => w),
    );
    await tester.pump();
    // `tungguAwal` menunggu paling lama 1,5 detik. Kalau tidak dilewati, timer
    //-nya masih hidup saat test ditutup dan `flutter test` menggagalkan.
    await tester.pump(const Duration(milliseconds: 2000));

    final error = <Object>[];
    void tangkap() {
      final e = tester.takeException();
      if (e != null) error.add(e);
    }

    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 300));
      tangkap();
    }
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pump(const Duration(milliseconds: 300));
      tangkap();
    }

    expect(error, isEmpty);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('daftar halaman kosong tetap menampilkan penjelas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(halaman: () => const [], pembungkus: (w) => w),
    );
    await tester.pump();
    // `tungguAwal` menunggu paling lama 1,5 detik. Kalau tidak dilewati, timer
    //-nya masih hidup saat test ditutup dan `flutter test` menggagalkan.
    await tester.pump(const Duration(milliseconds: 2000));

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('Belum ada gambar'), findsOneWidget);
  });
}
