import 'package:hive_flutter/hive_flutter.dart';

/// Penyimpanan lokal (Hive) untuk bookmark, riwayat, dan pengaturan.
///
/// [init] tidak pernah melempar: bila gagal, [siap] tetap `false`,
/// [lastError] berisi penyebabnya, dan semua box getter mengembalikan
/// `null` sehingga repository otomatis berjalan dalam mode memori.
/// Dengan begitu kegagalan storage tidak bisa mematikan aplikasi
/// saat startup.
class AppStorage {
  const AppStorage._();

  static const String bookmarksBoxName = 'bookmarks';
  static const String historyBoxName = 'history';
  static const String settingsBoxName = 'settings';

  static bool _siap = false;

  /// `true` bila semua box berhasil dibuka.
  static bool get siap => _siap;

  /// Penyebab kegagalan terakhir [init], bila ada.
  static String? lastError;

  /// Menyiapkan Hive dan membuka semua box. Aman dipanggil ulang.
  static Future<void> init() async {
    if (_siap) return;
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox(bookmarksBoxName),
        Hive.openBox(historyBoxName),
        Hive.openBox(settingsBoxName),
      ]);
      _siap = true;
    } catch (error) {
      lastError = error.toString();
    }
  }

  static Box? get bookmarksBox => _siap ? Hive.box(bookmarksBoxName) : null;
  static Box? get historyBox => _siap ? Hive.box(historyBoxName) : null;
  static Box? get settingsBox => _siap ? Hive.box(settingsBoxName) : null;
}
