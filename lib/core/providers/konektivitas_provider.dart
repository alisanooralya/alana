import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status konektivitas perangkat (wifi/seluler/tidak ada).
final konektivitasProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// `true` bila perangkat sedang luring (tanpa koneksi).
///
/// Sebelum status pertama diterima dianggap daring agar tidak
/// menampilkan banner sesaat saat aplikasi dibuka.
final luringProvider = Provider<bool>((ref) {
  final status = ref.watch(konektivitasProvider).valueOrNull;
  if (status == null) return false;
  return status.isEmpty || status.contains(ConnectivityResult.none);
});
