import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/library/data/bookmarked_manga.dart';

import 'merge.dart';
import 'sync_remote.dart';

DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0);

/// Orkestrasi sinkronisasi Supabase (sumber kebenaran lintas perangkat).
///
/// Lokal (Hive per-user) tetap sumber tampilan: cepat + offline.
/// Semua remote dipanggil tanpa memblokir UI; gagal = tetap pending
/// dan dicoba lagi saat koneksi kembali / dibuka / refresh.
class SyncService {
  SyncService(this.ref);

  final Ref ref;
  String? _uidAktif;
  bool _sibuk = false;

  String? get uidAktif => _uidAktif;

  /// Dipanggil setiap sesi berubah (login/logout/ganti akun).
  Future<void> handleSesi(String? uid) async {
    if (uid == null || uid.isEmpty) {
      final lama = _uidAktif;
      _uidAktif = null;
      if (lama != null && lama.isNotEmpty) {
        await AppStorage.hapusBoxUser(lama);
      }
      return;
    }
    if (uid == _uidAktif) return;
    _uidAktif = uid;
    await AppStorage.migrasiLegacy(AppStorage.bookmarksBoxName, 'bm', uid);
    await AppStorage.migrasiLegacy(AppStorage.historyBoxName, 'rh', uid);
    ref.invalidate(bookmarkRepositoryProvider);
    ref.invalidate(historyRepositoryProvider);
    await sinkronPenuh(uid);
  }

  /// Tarik remote + merge LWW + dorong batch yang pending.
  /// Dipakai setelah login, saat aplikasi dibuka, dan pull-to-refresh.
  Future<void> sinkronPenuh(String uid) async {
    if (_sibuk || !SupabaseSetup.siap || uid.isEmpty) return;
    _sibuk = true;
    try {
      final daftar = await Future.wait([
        SyncRemote.tarikBookmarks(uid),
        SyncRemote.tarikHistory(uid),
      ]);
      await _gabungBookmark(uid, daftar[0]);
      await _gabungHistory(uid, daftar[1]);
    } catch (_) {
      // Offline/gagal: data lokal tetap dipakai apa adanya.
    } finally {
      _sibuk = false;
    }
  }

  /// Tarik ulang + merge untuk user aktif (pull-to-refresh tab).
  Future<void> pullSegar() {
    final uid = _uidAktif;
    if (uid == null || uid.isEmpty) return Future.value();
    return sinkronPenuh(uid);
  }

  /// Dorong semua yang pending (dipanggil saat koneksi kembali,
  /// pindah chapter, keluar reader, dan aplikasi background).
  Future<void> flushTertunda() {
    return dorongSekarang(_uidAktif);
  }

  /// Versi statis (tanpa ref) untuk dipanggil dari dispose Reader.
  /// Memperbarui flag di box; repo dimuat ulang saat halaman dibuka.
  static Future<void> dorongSekarang(String? uid, {String? mangaId}) async {
    if (uid == null || uid.isEmpty || !SupabaseSetup.siap) return;
    try {
      await _dorongBox(uid, 'rh', mangaId);
      await _dorongTombs(uid, 'rh');
      await _dorongBox(uid, 'bm', mangaId);
      await _dorongTombs(uid, 'bm');
    } catch (_) {
      // Tetap pending; dicoba lagi pada kesempatan berikut.
    }
  }

  static Future<void> _dorongBox(
    String uid,
    String jenis,
    String? mangaId,
  ) async {
    final box = AppStorage.boxUserSync(jenis, uid);
    if (box == null) return;
    final unggah = <Map<String, dynamic>>[];
    final terkirim = <String, DateTime>{};
    for (final key in box.keys) {
      if (key == AppStorage.tombsKey) continue;
      if (mangaId != null && key != mangaId) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (data['pending'] != true) continue;
      if (jenis == 'bm') {
        final e = BookmarkedManga.fromMap(data);
        unggah.add(BookmarkRepository.barisUntuk(uid, e));
        terkirim[e.mangaId] = e.updatedAt;
      } else {
        final e = MangaReadingProgress.fromMap(data);
        unggah.add(HistoryRepository.barisUntuk(uid, e));
        terkirim[e.mangaId] = e.updatedAt;
      }
    }
    if (unggah.isEmpty) return;
    if (jenis == 'bm') {
      await SyncRemote.dorongBookmarks(uid, unggah);
    } else {
      await SyncRemote.dorongHistory(uid, unggah);
    }
    for (final id in terkirim.keys) {
      final raw = box.get(id);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final updated = DateTime.tryParse(data['updatedAt']?.toString() ?? '');
      if (updated != null && !updated.isAfter(terkirim[id]!)) {
        data['pending'] = false;
        box.put(id, data);
      }
    }
  }

  static Future<void> _dorongTombs(String uid, String jenis) async {
    final box = AppStorage.boxUserSync(jenis, uid);
    if (box == null) return;
    final raw = box.get(AppStorage.tombsKey);
    if (raw is! Map || raw.isEmpty) return;
    final ids = [for (final k in raw.keys) k.toString()];
    if (jenis == 'bm') {
      await SyncRemote.hapusBookmarks(uid, ids);
    } else {
      await SyncRemote.hapusHistory(uid, ids);
    }
    final sisa = Map<String, dynamic>.from(raw)
      ..removeWhere((k, _) => ids.contains(k.toString()));
    box.put(AppStorage.tombsKey, sisa);
  }

  Future<void> _gabungBookmark(
    String uid,
    List<Map<String, dynamic>> remoteRows,
  ) async {
    final repo = ref.read(bookmarkRepositoryProvider.notifier);
    final lokal = <String, EntriGabung>{
      for (final e in repo.state.entries)
        e.key: (updated: e.value.updatedAt, data: e.value.toMap()),
    };
    final remote = <String, EntriGabung>{};
    for (final r in remoteRows) {
      final id = r['manga_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final waktu =
          DateTime.tryParse(r['created_at']?.toString() ?? '') ?? _epoch();
      final iso = waktu.toIso8601String();
      remote[id] = (
        updated: waktu,
        data: <String, dynamic>{
          'mangaId': id,
          'title': r['title']?.toString() ?? 'Tanpa judul',
          'thumbnail': r['cover_url']?.toString() ?? '',
          'savedAt': iso,
          'updatedAt': iso,
          'pending': false,
        },
      );
    }
    final hasil = gabung(
      lokal: lokal,
      remote: remote,
      tombs: repo.tombs,
      keBaris: (data) =>
          BookmarkRepository.barisUntuk(uid, BookmarkedManga.fromMap(data)),
    );
    repo.terapkanGabungan({
      for (final e in hasil.lokal.entries)
        e.key: BookmarkedManga.fromMap(e.value),
    }, hasil.tombsSisa);
    try {
      await SyncRemote.dorongBookmarks(uid, hasil.unggah);
      await SyncRemote.hapusBookmarks(uid, hasil.hapusRemote);
      repo.tandaiTersinkron({
        for (final b in hasil.unggah)
          b['manga_id'].toString(): DateTime.parse(b['created_at'].toString()),
      });
      repo.buangTombs(hasil.hapusRemote);
    } catch (_) {
      // Gagal: flag pending/tomb bertahan untuk retry.
    }
  }

  Future<void> _gabungHistory(
    String uid,
    List<Map<String, dynamic>> remoteRows,
  ) async {
    final repo = ref.read(historyRepositoryProvider.notifier);
    final lokal = <String, EntriGabung>{
      for (final e in repo.state.entries)
        e.key: (updated: e.value.updatedAt, data: e.value.toMap()),
    };
    final remote = <String, EntriGabung>{};
    for (final r in remoteRows) {
      final id = r['manga_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final waktu =
          DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? _epoch();
      final posisi = double.tryParse(r['scroll_position']?.toString() ?? '');
      remote[id] = (
        updated: waktu,
        data: <String, dynamic>{
          'mangaId': id,
          'mangaTitle': r['manga_title']?.toString() ?? '',
          'mangaThumbnail': r['cover_url']?.toString() ?? '',
          'lastChapterId': r['chapter_id']?.toString() ?? '',
          'lastChapterName': r['chapter_title']?.toString() ?? '',
          'readChapterIds': const <String>[],
          'scrollOffset': posisi ?? 0.0,
          'pageCount': 0,
          'updatedAt': waktu.toIso8601String(),
          'pending': false,
        },
      );
    }
    final hasil = gabung(
      lokal: lokal,
      remote: remote,
      tombs: repo.tombs,
      keBaris: (data) =>
          HistoryRepository.barisUntuk(uid, MangaReadingProgress.fromMap(data)),
    );
    // Skema remote tidak punya daftar chapter dibaca:
    // gabungkan milik lokal agar tanda baca antar-perangkat tidak hilang.
    final gabungan = <String, MangaReadingProgress>{};
    for (final e in hasil.lokal.entries) {
      var p = MangaReadingProgress.fromMap(e.value);
      final l = repo.state[e.key];
      if (l != null) {
        p = p.copyWith(
          readChapterIds: {...l.readChapterIds, ...p.readChapterIds},
        );
      }
      gabungan[e.key] = p;
    }
    repo.terapkanGabungan(gabungan, hasil.tombsSisa);
    try {
      await SyncRemote.dorongHistory(uid, hasil.unggah);
      await SyncRemote.hapusHistory(uid, hasil.hapusRemote);
      repo.tandaiTersinkron({
        for (final b in hasil.unggah)
          b['manga_id'].toString(): DateTime.parse(b['updated_at'].toString()),
      });
      repo.buangTombs(hasil.hapusRemote);
    } catch (_) {
      // Gagal: flag pending/tomb bertahan untuk retry.
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
