import 'dart:async';

import 'package:flutter/foundation.dart';

/// Listenable yang memberi tahu GoRouter setiap stream memancarkan data.
///
/// Dipakai sebagai `refreshListenable` agar `redirect` dievaluasi ulang
/// setiap status sesi berubah (masuk/keluar) tanpa restart aplikasi.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _langganan = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _langganan;

  @override
  void dispose() {
    _langganan.cancel();
    super.dispose();
  }
}
