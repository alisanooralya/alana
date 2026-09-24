import 'package:hive_flutter/hive_flutter.dart';

/// Penyimpanan lokal (Hive) untuk bookmark dan riwayat baca.
///
/// Dipanggil sekali dari [main] sebelum aplikasi jalan.
/// Model disimpan sebagai `Map` polos (tanpa codegen) agar
/// tidak butuh `build_runner` dan tetap ringan.
class AppStorage {
  const AppStorage._();

  static const String bookmarksBoxName = 'bookmarks';
  static const String historyBoxName = 'history';
  static const String settingsBoxName = 'settings';

  static bool _siap = false;

  /// Menyiapkan Hive dan membuka semua box. Aman dipanggil ulang.
  static Future<void> init() async {
    if (_siap) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(bookmarksBoxName),
      Hive.openBox(historyBoxName),
      Hive.openBox(settingsBoxName),
    ]);
    _siap = true;
  }

  static Box get bookmarksBox => Hive.box(bookmarksBoxName);
  static Box get historyBox => Hive.box(historyBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
