import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/history/data/history_repository.dart';
import 'package:alana/features/history/data/reading_history.dart';
import 'package:alana/features/library/data/bookmark_repository.dart';
import 'package:alana/features/library/data/bookmarked_manga.dart';

import '../presentation/sync_providers.dart';

import 'merge.dart';
import 'sync_remote.dart';

DateTime _epoch() => DateTime.fromMillisecondsSinceEpoch(0);

class _SyncTick extends ChangeNotifier {
  void pemicu() => notifyListeners();
}

final _syncTick = _SyncTick();

void bangunkanPendingSync(Ref ref) {
  void pemicu() => ref.invalidate(pendingSyncProvider);
  ref.onDispose(() => _syncTick.removeListener(pemicu));
  _syncTick.addListener(pemicu);
}

class SyncService {
  SyncService(this.ref);

  final Ref ref;
  String? _uidAktif;
  bool _sibuk = false;

  String? get uidAktif => _uidAktif;

  Future<void> handleSesi(String? uid) async {
    if (uid == null || uid.isEmpty) {
      final lama = _uidAktif;
      _uidAktif = null;
      if (lama != null && lama.isNotEmpty) {
        await dorongSekarang(lama);
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

  Future<void> sinkronPenuh(String uid) async {
    if (_sibuk || !SupabaseSetup.siap || uid.isEmpty) return;
    _sibuk = true;
    try {
      final daftar = await Future.wait([
        SyncRemote.tarikBookmarks(uid),
        SyncRemote.tarikHistory(uid),
      ]);
      if (_uidAktif != uid) return;
      await _gabungBookmark(uid, daftar[0]);
      if (_uidAktif != uid) return;
      await _gabungHistory(uid, daftar[1]);
    } catch (_) {
      // Offline/gagal: data lokal tetap dipakai apa adanya.
    } finally {
      _sibuk = false;
    }
  }

  Future<void> pullSegar() {
    final uid = _uidAktif;
    if (uid == null || uid.isEmpty) return Future.value();
    return sinkronPenuh(uid);
  }

  Future<void> flushTertunda() {
    return dorongSekarang(_uidAktif);
  }

  static Future<void> dorongSekarang(String? uid, {String? mangaId}) async {
    if (uid == null || uid.isEmpty || !SupabaseSetup.siap) return;
    try {
      await _dorongBox(uid, 'rh', mangaId);
      await _dorongTombs(uid, 'rh');
      await _dorongBox(uid, 'bm', mangaId);
      await _dorongTombs(uid, 'bm');
      _syncTick.pemicu();
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
    final saatIni = ref.read(bookmarkRepositoryProvider);
    final lokal = <String, EntriGabung>{
      for (final e in saatIni.entries)
        e.key: (updated: e.value.updatedAt, data: e.value.toMap()),
    };
    final remote = <String, EntriGabung>{};
    final tombsRemote = <String, DateTime>{};
    for (final r in remoteRows) {
      final id = r['manga_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final dihapus = DateTime.tryParse(r['deleted_at']?.toString() ?? '');
      if (dihapus != null) {
        tombsRemote[id] = dihapus;
        continue;
      }
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
      tombsRemote: tombsRemote,
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
    final saatIni = ref.read(historyRepositoryProvider);
    final lokal = <String, EntriGabung>{
      for (final e in saatIni.entries)
        e.key: (updated: e.value.updatedAt, data: e.value.toMap()),
    };
    final remote = <String, EntriGabung>{};
    final tombsRemote = <String, DateTime>{};
    for (final r in remoteRows) {
      final id = r['manga_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final dihapus = DateTime.tryParse(r['deleted_at']?.toString() ?? '');
      if (dihapus != null) {
        tombsRemote[id] = dihapus;
        continue;
      }
      final waktu =
          DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? _epoch();
      final indeks = int.tryParse(r['scroll_index']?.toString() ?? '') ?? 0;
      final depan =
          double.tryParse(r['scroll_leading']?.toString() ?? '') ?? 0.0;
      final posisiLama =
          double.tryParse(r['scroll_position']?.toString() ?? '') ?? 0.0;
      remote[id] = (
        updated: waktu,
        data: <String, dynamic>{
          'mangaId': id,
          'mangaTitle': r['manga_title']?.toString() ?? '',
          'mangaThumbnail': r['cover_url']?.toString() ?? '',
          'lastChapterId': r['chapter_id']?.toString() ?? '',
          'lastChapterName': r['chapter_title']?.toString() ?? '',
          'readChapterIds': const <String>[],
          'scrollIndex': indeks,
          'scrollLeading': depan,
          'scrollOffset': posisiLama,
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
      tombsRemote: tombsRemote,
      keBaris: (data) =>
          HistoryRepository.barisUntuk(uid, MangaReadingProgress.fromMap(data)),
    );
    final gabungan = <String, MangaReadingProgress>{};
    for (final e in hasil.lokal.entries) {
      var p = MangaReadingProgress.fromMap(e.value);
      final l = saatIni[e.key];
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
  bangunkanPendingSync(ref);
  return SyncService(ref);
});
