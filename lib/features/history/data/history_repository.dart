import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository riwayat baca.
///
/// Fondasi Fase 1: API in-memory agar halaman bisa dikompilasi.
/// Penyimpanan progres baca permanen dikerjakan di Fase 5.
class HistoryRepository {
  final List<String> _chapterIds = [];

  List<String> get chapterIds => List.unmodifiable(_chapterIds);
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});
