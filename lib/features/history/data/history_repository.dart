import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/sync/data/sync_remote.dart';

import 'reading_history.dart';

/// Repository riwayat baca: Hive per-user + antrean push Supabase.
///
/// - Tulis lokal dulu (debounce di reader), TIDAK ada kiriman jaringan
///   per event scroll. Push terjadi saat pindah chapter, keluar
///   Reader, aplikasi background, koneksi kembali, atau refresh.
/// - Hapus dicatat sebagai tombstone agar terpropagasi ke remote.
/// - Catatan: daftar chapter dibaca (`readChapterIds`) hanya lokal
///   (skema remote tidak punya kolomnya); yang tersinkron adalah
///   chapter + posisi terakhir.
class HistoryRepository extends Notifier<Map<String, MangaReadingProgress>> {
  String? _uid;
  Map<String, DateTime> _tombs = {};
  String? _dibukaUntuk;

  @override
  Map<String, MangaReadingProgress> build() {
    final uid = ref.watch(userIdProvider);
    _uid = uid;
    if (uid == null || uid.isEmpty) {
      _tombs = {};
      return const {};
    }
    final box = AppStorage.boxUserSync('rh', uid);
    if (box == null) {
      _bukaLaluMuatUlang(uid);
      _tombs = {};
      return const {};
    }
    return _muat(box);
  }

  void _bukaLaluMuatUlang(String uid) {
    if (_dibukaUntuk == uid) return;
    _dibukaUntuk = uid;
    Future(() async {
      await AppStorage.bukaBoxUser('rh', uid);
      ref.invalidateSelf();
    });
  }

  Map<String, MangaReadingProgress> _muat(Box box) {
    _tombs = _bacaTombs(box);
    final entries = <String, MangaReadingProgress>{};
    for (final key in box.keys) {
      if (key == AppStorage.tombsKey) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final progress = MangaReadingProgress.fromMap(
        Map<String, dynamic>.from(raw),
      );
      if (progress.mangaId.isNotEmpty) {
        entries[progress.mangaId] = progress;
      }
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

  void _persist(Map<String, MangaReadingProgress> entries) {
    final box = _uid == null ? null : AppStorage.boxUserSync('rh', _uid!);
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

  MangaReadingProgress? progressUntuk(String mangaId) => state[mangaId];

  Set<String> idDibacaUntuk(String mangaId) {
    return state[mangaId]?.readChapterIds ?? const {};
  }

  bool sudahDibaca(String mangaId, String chapterId) {
    return state[mangaId]?.readChapterIds.contains(chapterId) ?? false;
  }

  /// Tombstone hapus yang belum terdorong.
  Map<String, DateTime> get tombs => Map.unmodifiable(_tombs);

  void _tulis(MangaReadingProgress progress) {
    final next = Map<String, MangaReadingProgress>.of(state);
    next[progress.mangaId] = progress.copyWith(pending: true);
    _persist(next);
  }

  MangaReadingProgress _denganIdentitas(
    MangaReadingProgress progress,
    String mangaTitle,
    String mangaThumbnail,
  ) {
    if (mangaTitle.isEmpty && mangaThumbnail.isEmpty) return progress;
    return progress.copyWith(
      mangaTitle: mangaTitle.isEmpty ? progress.mangaTitle : mangaTitle,
      mangaThumbnail: mangaThumbnail.isEmpty
          ? progress.mangaThumbnail
          : mangaThumbnail,
    );
  }

  /// Mencatat chapter sebagai sudah dibaca sekaligus
  /// menjadikannya posisi terakhir (lokal saja).
  void tandaiDibaca({
    required String mangaId,
    String mangaTitle = '',
    String mangaThumbnail = '',
    required String chapterId,
    required String chapterName,
  }) {
    final lama = state[mangaId];
    final dibaca = {...?lama?.readChapterIds, chapterId};
    var baru =
        (lama ??
                MangaReadingProgress(
                  mangaId: mangaId,
                  updatedAt: DateTime.now(),
                ))
            .copyWith(
              lastChapterId: chapterId,
              lastChapterName: chapterName,
              readChapterIds: dibaca,
              updatedAt: DateTime.now(),
            );
    _tulis(_denganIdentitas(baru, mangaTitle, mangaThumbnail));
  }

  /// Menyimpan posisi scroll chapter yang sedang dibaca (lokal saja).
  /// Dipanggil berkala oleh reader (debounce).
  void simpanPosisi({
    required String mangaId,
    String mangaTitle = '',
    String mangaThumbnail = '',
    required String chapterId,
    String chapterName = '',
    required double scrollOffset,
    required int pageCount,
  }) {
    final lama =
        state[mangaId] ??
        MangaReadingProgress(mangaId: mangaId, updatedAt: DateTime.now());
    var baru = lama.copyWith(
      lastChapterId: chapterId,
      lastChapterName: chapterName.isEmpty ? lama.lastChapterName : chapterName,
      scrollOffset: scrollOffset,
      pageCount: pageCount,
      updatedAt: DateTime.now(),
    );
    _tulis(_denganIdentitas(baru, mangaTitle, mangaThumbnail));
  }

  /// Menghapus satu entri riwayat. Aman bila ID tidak ada.
  void hapus(String mangaId) {
    if (!state.containsKey(mangaId)) return;
    final next = Map<String, MangaReadingProgress>.of(state)..remove(mangaId);
    _tombs[mangaId] = DateTime.now();
    _persist(next);
    unawaited(_dorongHapus(mangaId));
  }

  /// Mendorong hapus-tomb satu id (dipakai repo; batch oleh service).
  Future<void> _dorongHapus(String mangaId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || !SupabaseSetup.siap) return;
    try {
      await SyncRemote.hapusHistory(uid, [mangaId]);
      _tombs.remove(mangaId);
      _persist(Map<String, MangaReadingProgress>.of(state));
    } catch (_) {
      // Tetap tombstone; SyncService mencoba lagi nanti.
    }
  }

  /// Menerapkan hasil merge: ganti seluruh state+box sekaligus.
  void terapkanGabungan(
    Map<String, MangaReadingProgress> gabungan,
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
    final next = Map<String, MangaReadingProgress>.of(state);
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
    if (berubah) _persist(Map<String, MangaReadingProgress>.of(state));
  }

  /// Baris remote untuk satu progres lokal.
  static Map<String, dynamic> barisUntuk(String uid, MangaReadingProgress e) {
    return {
      'user_id': uid,
      'manga_id': e.mangaId,
      'manga_title': e.mangaTitle,
      'cover_url': e.mangaThumbnail,
      'chapter_id': e.lastChapterId,
      'chapter_title': e.lastChapterName,
      'scroll_position': e.scrollOffset,
      'updated_at': e.updatedAt.toIso8601String(),
    };
  }
}

final historyRepositoryProvider =
    NotifierProvider<HistoryRepository, Map<String, MangaReadingProgress>>(
      () => HistoryRepository(),
    );
