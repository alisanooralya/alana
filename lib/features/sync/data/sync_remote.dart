import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

class SyncRemote {
  const SyncRemote._();

  static const ukuranHalaman = 1000;
  static const _maksHalaman = 500;

  static SupabaseClient _client() => SupabaseSetup.instance;

  static Future<List<T>> tarikBerpaginasi<T>({
    required Future<List<T>> Function(int dari, int sampai) ambil,
    int halaman = ukuranHalaman,
  }) async {
    final hasil = <T>[];
    var ke = 0;
    while (ke < _maksHalaman) {
      final sepotong = await ambil(ke * halaman, ke * halaman + halaman - 1);
      if (sepotong.isEmpty) break;
      hasil.addAll(sepotong);
      if (sepotong.length < halaman) break;
      ke++;
    }
    return hasil;
  }

  static Future<List<Map<String, dynamic>>> tarikBookmarks(String uid) async {
    return tarikBerpaginasi<Map<String, dynamic>>(
      ambil: (dari, sampai) async {
        final baris = await _client()
            .from('bookmarks')
            .select('manga_id, title, cover_url, created_at, deleted_at')
            .eq('user_id', uid)
            .order('manga_id')
            .range(dari, sampai);
        return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
      },
    );
  }

  static Future<void> dorongBookmarks(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client().rpc(
      'upsert_sync_rows',
      params: {'p_user_id': uid, 'p_tabel': 'bookmarks', 'p_rows': baris},
    );
  }

  static Future<void> hapusBookmarks(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client().rpc(
      'soft_delete_sync_rows',
      params: {
        'p_user_id': uid,
        'p_tabel': 'bookmarks',
        'p_manga_ids': mangaIds,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> tarikHistory(String uid) async {
    return tarikBerpaginasi<Map<String, dynamic>>(
      ambil: (dari, sampai) async {
        final baris = await _client()
            .from('reading_history')
            .select(
              'manga_id, manga_title, cover_url, chapter_id, '
              'chapter_title, scroll_index, scroll_leading, scroll_position, '
              'updated_at, deleted_at',
            )
            .eq('user_id', uid)
            .order('manga_id')
            .range(dari, sampai);
        return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
      },
    );
  }

  static Future<void> dorongHistory(
    String uid,
    List<Map<String, dynamic>> baris,
  ) async {
    if (baris.isEmpty) return;
    await _client().rpc(
      'upsert_sync_rows',
      params: {'p_user_id': uid, 'p_tabel': 'reading_history', 'p_rows': baris},
    );
  }

  static Future<void> hapusHistory(String uid, List<String> mangaIds) async {
    if (mangaIds.isEmpty) return;
    await _client().rpc(
      'soft_delete_sync_rows',
      params: {
        'p_user_id': uid,
        'p_tabel': 'reading_history',
        'p_manga_ids': mangaIds,
      },
    );
  }
}
