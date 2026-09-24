import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository bookmark (Pustaka).
///
/// Fondasi Fase 1: API in-memory agar halaman bisa dikompilasi.
/// Implementasi penyimpanan lokal permanen dikerjakan di Fase 5
/// setelah disepakati memakai shared_preferences atau hive.
class BookmarkRepository {
  final List<String> _mangaIds = [];

  List<String> get mangaIds => List.unmodifiable(_mangaIds);
}

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository();
});
