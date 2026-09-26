import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status konektivitas perangkat (wifi/seluler/tidak ada).
final konektivitasProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// `true` bila perangkat sedang luring (tanpa koneksi).
///
/// Sebelum status pertama diterima dianggap daring agar tidak menampilkan
/// banner sesaat saat aplikasi dibuka.
///
/// connectivity_plus menjamin list hasil tidak pernah kosong, jadi cabang
/// `isEmpty` sebelumnya tidak pernah terpakai dan sudah dihapus.
///
/// Catatan jujur: ini hanya tahu ada interface jaringan, bukan ada internet.
/// Perangkat yang terhubung ke Wi-Fi captive portal atau router mati akan
/// tetap dianggap daring, sehingga banner offline tidak muncul dan flush
/// sinkron tidak terpicu. Mengcobanya berarti mengukur konektivitas sungguhan
/// setiap perubahan status, yang lebih lambat dan boros data; penentuan ini
/// diserahkan ke kegagalan request.
final luringProvider = Provider<bool>((ref) {
  final status = ref.watch(konektivitasProvider).valueOrNull;
  if (status == null) return false;
  return status.contains(ConnectivityResult.none);
});
