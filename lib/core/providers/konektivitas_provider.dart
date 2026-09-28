import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final konektivitasProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final luringProvider = Provider<bool>((ref) {
  final status = ref.watch(konektivitasProvider).valueOrNull;
  if (status == null) return false;
  return status.contains(ConnectivityResult.none);
});
