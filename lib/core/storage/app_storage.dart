import 'package:hive_flutter/hive_flutter.dart';

class AppStorage {
  const AppStorage._();

  static const String bookmarksBoxName = 'bookmarks';
  static const String historyBoxName = 'history';
  static const String settingsBoxName = 'settings';
  static const String downloadsBoxName = 'downloads';
  static const String pageRatioBoxName = 'page_ratio';

  static bool _siap = false;
  static bool get siap => _siap;

  static String? lastError;

  static Future<void> init() async {
    if (_siap) return;
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox(bookmarksBoxName),
        Hive.openBox(historyBoxName),
        Hive.openBox(settingsBoxName),
        Hive.openBox(downloadsBoxName),
        Hive.openBox(pageRatioBoxName),
      ]);
      _siap = true;
    } catch (error) {
      lastError = error.toString();
    }
  }

  static Box? get bookmarksBox => _siap ? Hive.box(bookmarksBoxName) : null;
  static Box? get historyBox => _siap ? Hive.box(historyBoxName) : null;
  static Box? get settingsBox => _siap ? Hive.box(settingsBoxName) : null;
  static Box? get downloadsBox => _siap ? Hive.box(downloadsBoxName) : null;
  static Box? get pageRatioBox => _siap ? Hive.box(pageRatioBoxName) : null;

  static const tombsKey = '__tombs__';

  static String boxUser(String jenis, String uid) => '${jenis}_$uid';

  static final Map<String, Future<Box?>> _pembukaan = {};

  static Future<Box?> bukaBoxUser(String jenis, String uid) {
    if (!_siap || uid.isEmpty) return Future.value();
    final nama = boxUser(jenis, uid);
    if (Hive.isBoxOpen(nama)) return Future.value(Hive.box(nama));
    final jalan = _pembukaan[nama];
    if (jalan != null) return jalan;
    final future = _bukaBox(nama);
    _pembukaan[nama] = future;
    return future;
  }

  static Future<Box?> _bukaBox(String nama) async {
    try {
      if (Hive.isBoxOpen(nama)) return Hive.box(nama);
      return await Hive.openBox(nama);
    } catch (error) {
      lastError = error.toString();
      return null;
    } finally {
      _pembukaan.remove(nama);
    }
  }

  static Box? boxUserSync(String jenis, String uid) {
    if (!_siap || uid.isEmpty) return null;
    final nama = boxUser(jenis, uid);
    if (!Hive.isBoxOpen(nama)) return null;
    return Hive.box(nama);
  }

  static int hitungTombs(String jenis, String uid) {
    final box = boxUserSync(jenis, uid);
    final raw = box?.get(tombsKey);
    if (raw is! Map) return 0;
    return raw.length;
  }

  static Future<void> migrasiLegacy(
    String boxGlobal,
    String jenis,
    String uid,
  ) async {
    final asal = _siap ? Hive.box(boxGlobal) : null;
    final tujuan = await bukaBoxUser(jenis, uid);
    if (asal == null || tujuan == null || asal.isEmpty) return;
    for (final key in asal.keys.toList()) {
      final raw = asal.get(key);
      if (raw is! Map) continue;
      final salin = Map<String, dynamic>.from(raw)..['pending'] = true;
      tujuan.put(key, salin);
    }
    await asal.clear();
  }

  static Future<void> hapusBoxUser(String uid) async {
    if (uid.isEmpty) return;
    for (final jenis in ['bm', 'rh', 'sm']) {
      try {
        final nama = boxUser(jenis, uid);
        _pembukaan.remove(nama);
        if (Hive.isBoxOpen(nama)) await Hive.box(nama).close();
        await Hive.deleteBoxFromDisk(nama);
      } catch (_) {
        // Abaikan: cache lokal tidak kritis.
      }
    }
  }
}
