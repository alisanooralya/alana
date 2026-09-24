import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/sync/data/sync_remote.dart';

import 'bookmarked_manga.dart';

/// Repository bookmark (Pustaka): Hive per-user + antrean push Supabase.
///
/// - UI tetap reaktif dan bisa offline (tulis lokal dulu/optimistic).
/// - Setiap mutasi menandai `pending` lalu mencoba dorong langsung;
///   gagal (offline) → tetap pending, didorong ulang oleh SyncService
///   saat koneksi kembali / aplikasi dibuka / pull-to-refresh.
/// - Hapus dicatat sebagai tombstone agar terpropagasi ke remote.
class BookmarkRepository extends Notifier<Map<String, BookmarkedManga>> {
  String? _uid;
  Map<String, DateTime> _tombs = {};
  String? _dibukaUntuk;

  @override
  Map<String, BookmarkedManga> build() {
    final uid = ref.watch(userIdProvider);
    _uid = uid;
    if (uid == null || uid.isEmpty) {
      _tombs = {};
      return const {};
    }
    final box = AppStorage.boxUserSync('bm', uid);
    if (box == null) {
      _bukaLaluMuatUlang(uid);
      _tombs = {};
      return const {};
    }
    return _muat(box);
  }

  /// Box belum terbuka (balapan dengan login): buka lalu muat ulang.
  void _bukaLaluMuatUlang(String uid) {
    if (_dibukaUntuk == uid) return;
    _dibukaUntuk = uid;
    Future(() async {
      await AppStorage.bukaBoxUser('bm', uid);
      ref.invalidateSelf();
    });
  }

  Map<String, BookmarkedManga> _muat(Box box) {
    _tombs = _bacaTombs(box);
    final entries = <String, BookmarkedManga>{};
    for (final key in box.keys) {
      if (key == AppStorage.tombsKey) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final item = BookmarkedManga.fromMap(Map<String, dynamic>.from(raw));
      if (item.mangaId.isNotEmpty) entries[item.mangaId] = item;
    }
    return Map.unmodifiable(entries);
  }

  static Map<String, DateTime> _bacaTombs(Box box) {
    final raw = box.get(AppStorage.tombsKey);
    if (raw is! Map) return {};
    final hasil = <String, DateTime>{};
    for (final e in raw.entries) {
      final waktu = DateTime.tryParse(e.value?.toString() ?? '');
      if (e.key.toString().isNotEmpty && waktu != null) {
        hasil[e.key.toString()] = waktu;
      }
    }
    return hasil;
  }

  void _persist(Map<String, BookmarkedManga> entries) {
    final box = _uid == null ? null : AppStorage.boxUserSync('bm', _uid!);
    if (box != null) {
      for (final key in box.keys.toList()) {
        if (key == AppStorage.tombsKey) continue;
        if (!entries.containsKey(key)) box.delete(key);
      }
      for (final e in entries.entries) {
        box.put(e.key, e.value.toMap());
      }
      box.put(AppStorage.tombsKey, {
        for (final t in _tombs.entries) t.key: t.value.toIso8601String(),
      });
    }
    state = Map.unmodifiable(entries);
  }

  bool isBookmarked(String mangaId) => state.containsKey(mangaId);

  /// Tombstone hapus yang belum terdorong.
  Map<String, DateTime> get tombs => Map.unmodifiable(_tombs);

  /// Menandai bila belum ada, menghapus bila sudah ada.
  /// Mengembalikan status baru (`true` = ditandai).
  bool toggle(BookmarkedManga item) {
    final next = Map<String, BookmarkedManga>.of(state);
    final sudahAda = next.containsKey(item.mangaId);
    if (sudahAda) {
      next.remove(item.mangaId);
      _tombs[item.mangaId] = DateTime.now();
    } else {
      next[item.mangaId] = item.copyWith(
        updatedAt: DateTime.now(),
        pending: true,
      );
      _tombs.remove(item.mangaId);
    }
    _persist(next);
    unawaited(_dorong(item.mangaId));
    return !sudahAda;
  }

  /// Menghapus bookmark. Aman bila ID tidak ada.
  void hapus(String mangaId) {
    if (!state.containsKey(mangaId)) return;
    final next = Map<String, BookmarkedManga>.of(state)..remove(mangaId);
    _tombs[mangaId] = DateTime.now();
    _persist(next);
    unawaited(_dorong(mangaId));
  }

  /// Mendorong satu id ke remote (upsert atau hapus-tomb).
  /// Gagal diam-diam: flag pending/tomb bertahan untuk retry.
  Future<void> _dorong(String mangaId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || !SupabaseSetup.siap) return;
    try {
      final entri = state[mangaId];
      if (entri != null) {
        await SyncRemote.dorongBookmarks(uid, [_barisBookmark(uid, entri)]);
        final kini = state[mangaId];
        if (kini != null && kini.updatedAt == entri.updatedAt) {
          final next = Map<String, BookmarkedManga>.of(state);
          next[mangaId] = kini.copyWith(pending: false);
          _persist(next);
        }
      } else {
        await SyncRemote.hapusBookmarks(uid, [mangaId]);
        _tombs.remove(mangaId);
        _persist(Map<String, BookmarkedManga>.of(state));
      }
    } catch (_) {
      // Tetap pending; SyncService mencoba lagi nanti.
    }
  }

  /// Menerapkan hasil merge: ganti seluruh state+box sekaligus.
  void terapkanGabungan(
    Map<String, BookmarkedManga> gabungan,
    Map<String, DateTime> tombs,
  ) {
    _tombs = Map<String, DateTime>.of(tombs);
    _persist(gabungan);
  }

  /// Menandai beberapa id sudah tersinkron.
  ///
  /// Hanya yang `updatedAt`-nya tidak lebih baru dari saat terkirim
  /// yang dibersihkan (aman dari balapan tulis saat sinkron jalan).
  void tandaiTersinkron(Map<String, DateTime> terkirim) {
    var berubah = false;
    final next = Map<String, BookmarkedManga>.of(state);
    for (final id in terkirim.keys) {
      final e = next[id];
      final t = terkirim[id];
      if (e != null && e.pending && t != null && !e.updatedAt.isAfter(t)) {
        next[id] = e.copyWith(pending: false);
        berubah = true;
      }
    }
    if (berubah) _persist(next);
  }

  /// Membuang tombstone yang sudah terdorong.
  void buangTombs(Iterable<String> ids) {
    var berubah = false;
    for (final id in ids) {
      if (_tombs.remove(id) != null) berubah = true;
    }
    if (berubah) _persist(Map<String, BookmarkedManga>.of(state));
  }

  /// Baris remote untuk satu entri lokal.
  static Map<String, dynamic> barisUntuk(String uid, BookmarkedManga e) =>
      _barisBookmark(uid, e);

  static Map<String, dynamic> _barisBookmark(String uid, BookmarkedManga e) {
    return {
      'user_id': uid,
      'manga_id': e.mangaId,
      'title': e.title,
      'cover_url': e.thumbnail,
      'created_at': e.updatedAt.toIso8601String(),
    };
  }
}

final bookmarkRepositoryProvider =
    NotifierProvider<BookmarkRepository, Map<String, BookmarkedManga>>(
      () => BookmarkRepository(),
    );
