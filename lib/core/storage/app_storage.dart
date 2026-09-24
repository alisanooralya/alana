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

  /// Kunci khusus di box user untuk daftar hapus tertunda (tombstone).
  /// Nilainya `Map` id → ISO waktu hapus. build() repository melewatinya.
  static const tombsKey = '__tombs__';

  /// Nama box per user: `{jenis}_{uid}` (jenis: `bm`, `rh`, `sm`).
  static String boxUser(String jenis, String uid) => '${jenis}_$uid';

  /// Membuka (atau mengembalikan) box milik user. Aman dipanggil ulang.
  static Future<Box?> bukaBoxUser(String jenis, String uid) async {
    if (!_siap || uid.isEmpty) return null;
    try {
      final nama = boxUser(jenis, uid);
      if (Hive.isBoxOpen(nama)) return Hive.box(nama);
      return await Hive.openBox(nama);
    } catch (error) {
      lastError = error.toString();
      return null;
    }
  }

  /// Box user yang sudah terbuka, null bila belum/tidak tersedia.
  static Box? boxUserSync(String jenis, String uid) {
    if (!_siap || uid.isEmpty) return null;
    final nama = boxUser(jenis, uid);
    if (!Hive.isBoxOpen(nama)) return null;
    return Hive.box(nama);
  }

  /// Menghitung tombstone (hapus tertunda) di box user.
  static int hitungTombs(String jenis, String uid) {
    final box = boxUserSync(jenis, uid);
    final raw = box?.get(tombsKey);
    if (raw is! Map) return 0;
    return raw.length;
  }

  /// Memindahkan isi box global lama (pra-akun) ke box user dengan
  /// status pending, lalu mengosongkan box global. Sekali jalan alami
  /// (no-op bila box global sudah kosong).
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

  /// Menghapus seluruh box milik user (dipakai saat signOut agar
  /// akun bergantian tidak bercampur; remote tetap jadi kebenaran).
  static Future<void> hapusBoxUser(String uid) async {
    if (uid.isEmpty) return;
    for (final jenis in ['bm', 'rh', 'sm']) {
      try {
        final nama = boxUser(jenis, uid);
        if (Hive.isBoxOpen(nama)) await Hive.box(nama).close();
        await Hive.deleteBoxFromDisk(nama);
      } catch (_) {
        // Abaikan: cache lokal tidak kritis.
      }
    }
  }
}
