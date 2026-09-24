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
        .select('manga_id, title, cover_url, created_at')
        .eq('user_id', uid);
    return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
  }

  /// Batch upsert (satu request). `created_at` ditulis ulang sebagai
  /// jam LWW karena tabel tidak punya kolom updated_at.
  static Future<void> dorongBookmarks(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client()
        .from('bookmarks')
        .upsert(baris, onConflict: 'user_id,manga_id');
  }

  static Future<void> hapusBookmarks(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client()
        .from('bookmarks')
        .delete()
        .eq('user_id', uid)
        .inFilter('manga_id', mangaIds);
  }

  // ---------- reading_history ----------

  static Future<List<Map<String, dynamic>>> tarikHistory(String uid) async {
    final baris = await _client()
        .from('reading_history')
        .select(
          'manga_id, manga_title, cover_url, chapter_id, '
          'chapter_title, scroll_position, updated_at',
        )
        .eq('user_id', uid);
    return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
  }

  static Future<void> dorongHistory(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client()
        .from('reading_history')
        .upsert(baris, onConflict: 'user_id,manga_id');
  }

  static Future<void> hapusHistory(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client()
        .from('reading_history')
        .delete()
        .eq('user_id', uid)
        .inFilter('manga_id', mangaIds);
  }
}
