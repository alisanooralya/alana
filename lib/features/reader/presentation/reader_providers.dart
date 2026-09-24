import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/models/page.dart' as manga;

import '../data/reader_repository.dart';

/// Daftar gambar satu chapter berdasarkan ID chapter-nya.
final pageListProvider = FutureProvider.family<List<manga.Page>, String>((
  ref,
  chapterId,
) {
  return ref.watch(readerRepositoryProvider).getPages(chapterId);
});
