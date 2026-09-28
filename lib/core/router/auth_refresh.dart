import 'dart:async';

import 'package:flutter/foundation.dart';

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh([Iterable<Stream<dynamic>> streams = const []]) {
    for (final stream in streams) {
      _langganan.add(stream.listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription<dynamic>> _langganan = [];

  void pemicu() => notifyListeners();

  @override
  void dispose() {
    for (final langganan in _langganan) {
      langganan.cancel();
    }
    super.dispose();
  }
}
