import 'dart:async';

import 'package:flutter/foundation.dart';

/// Listenable yang memberi tahu GoRouter setiap sumber memancarkan perubahan.
///
/// Dipakai sebagai `refreshListenable` agar `redirect` dievaluasi ulang saat
/// status sesi, kesiapan splash, status onboarding, atau permintaan setup
/// username berubah.
///
/// Penting: notifyListeners harus mekanismenya untuk evaluation ulang, bukan
/// dengan membuat ulang router. GoRouter yang dibuat ulang akan membaca ulang
/// `initialLocation`, sehingga menukar navigator beserta seluruh stack
/// navigasi dan `extra` halaman yang sedang dibuka.
class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh([Iterable<Stream<dynamic>> streams = const []]) {
    for (final stream in streams) {
      _langganan.add(stream.listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription<dynamic>> _langganan = [];

  /// Minta `redirect` dievaluasi ulang dari pemanggil non-stream.
  void pemicu() => notifyListeners();

  @override
  void dispose() {
    for (final langganan in _langganan) {
      langganan.cancel();
    }
    super.dispose();
  }
}
