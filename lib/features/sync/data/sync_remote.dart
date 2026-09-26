import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

/// Operasi remote Supabase untuk sinkronisasi (tanpa Riverpod/Hive).
///
/// Semua method statis agar bisa dipakai repo (optimistic push)
/// maupun SyncService tanpa dependensi melingkar. Melempar saat
/// gagal — pemanggil mempertahankan flag pending/tombstone.
class SyncRemote {
  const SyncRemote._();

  static SupabaseClient _client() => SupabaseSetup.instance;

  // ---------- bookmarks ----------

  static Future<List<Map<String, dynamic>>> tarikBookmarks(String uid) async {
    final baris = await _client()
        .from('bookmarks')
        .select('manga_id, title, cover_url, created_at, deleted_at')
        .eq('user_id', uid);
    return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
  }

  /// Batch upsert (satu request). `created_at` ditulis ulang sebagai
  /// jam LWW karena tabel tidak punya kolom updated_at.
  ///
  /// Memakai RPC `upsert_sync_rows`, bukan `.upsert()` biasa: PostgREST
  /// menyelesaikan konflik berdasarkan urutan kedatangan, sehingga push lama
  /// dari perangkat offline bisa menimpa baris yang lebih baru.
  static Future<void> dorongBookmarks(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client().rpc('upsert_sync_rows', {
      'p_user_id': uid,
      'p_tabel': 'bookmarks',
      'p_rows': baris,
    });
  }

  /// Soft delete: baris ditandai `deleted_at` (bukan DELETE keras) supaya
  /// perangkat lain tidak mengunggah ulang salinan lamanya.
  static Future<void> hapusBookmarks(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client().rpc('soft_delete_sync_rows', {
      'p_user_id': uid,
      'p_tabel': 'bookmarks',
      'p_manga_ids': mangaIds,
    });
  }

  // ---------- reading_history ----------

  static Future<List<Map<String, dynamic>>> tarikHistory(String uid) async {
    final baris = await _client()
        .from('reading_history')
        .select(
          'manga_id, manga_title, cover_url, chapter_id, '
          'chapter_title, scroll_position, updated_at, deleted_at',
        )
        .eq('user_id', uid);
    return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
  }

  /// Memakai RPC `upsert_sync_rows` untuk penjaga LWW, bukan `.upsert()` biasa.
  static Future<void> dorongHistory(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client().rpc('upsert_sync_rows', {
      'p_user_id': uid,
      'p_tabel': 'reading_history',
      'p_rows': baris,
    });
  }

  static Future<void> hapusHistory(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client().rpc('soft_delete_sync_rows', {
      'p_user_id': uid,
      'p_tabel': 'reading_history',
      'p_manga_ids': mangaIds,
    });
  }
}
