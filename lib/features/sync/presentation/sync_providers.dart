import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

import '../data/sync_service.dart';

/// Jumlah item menunggu sinkron (pending + tombstone).
///
/// Dipakai indikator kecil di tab Pustaka/Riwayat. Dihitung ulang
/// setiap state repo berubah (mutasi hapus/tulis selalu rebuild).
final pendingSyncProvider = Provider<int>((ref) {
  final bookmark = ref.watch(bookmarkRepositoryProvider);
  final riwayat = ref.watch(historyRepositoryProvider);
  final uid = ref.watch(userIdProvider);
  var jumlah =
      bookmark.values.where((e) => e.pending).length +
      riwayat.values.where((e) => e.pending).length;
  if (uid != null && uid.isNotEmpty) {
    jumlah += AppStorage.hitungTombs('bm', uid);
    jumlah += AppStorage.hitungTombs('rh', uid);
  }
  return jumlah;
});
