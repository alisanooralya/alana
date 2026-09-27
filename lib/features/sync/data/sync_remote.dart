import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

/// Operasi remote Supabase untuk sinkronisasi (tanpa Riverpod/Hive).
///
/// Semua method statis agar bisa dipakai repo (optimistic push)
/// maupun SyncService tanpa dependensi melingkar. Melempar saat
/// gagal — pemanggil mempertahankan flag pending/tombstone.
class SyncRemote {
  const SyncRemote._();

  /// Batas baris per permintaan, sama dengan default PostgREST.
  ///
  /// Dipakai juga sebagai ukuran halaman supaya mintanya sama dengan batas
  /// yang diam-diam/sniffer server terapkan.
  static const ukuranHalaman = 1000;

  /// Pengaman jumlah halaman, supaya perulangan tidak berjalan tanpa akhir
  /// kalau `[ambil]` selalu mengembalikan halaman penuh.
  static const _maksHalaman = 500;

  static SupabaseClient _client() => SupabaseSetup.instance;

  /// Mengambil semua baris dengan berpage, lalu digabung jadi satu daftar.
  ///
  /// PostgREST memotong hasil di 1000 baris dan mengembalikan response 200,
  /// bukan error. Tanpa paging, user dengan lebih dari 1000 bookmark atau
  /// riwayat akan melihat sinkronisasi "sukses" padahal separuhnya tidak
  /// pernah dibaca. Data yang tidak terbaca itu lalu dianggap tidak ada, jadi
  /// bookmark lama bisa hilang diam-diam dari perangkat.
  ///
  /// Paginasi tanpa `order` tidak aman: urutan baris tanpa orders tidak
  /// dijamin, sehingga `range()` antar permintaan bisa melompati baris atau
  /// mengirimnya dua kali. Karena itu pemanggil wajib mengurutkan dengan
  /// kolom yang unik per user, yaitu bagian `manga_id` dari primary key.
  ///
  /// Logika paginasi dipisah dari klien PostgREST supaya bisa diuji tanpa
  /// HTTP.
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
      // Halaman terakhir biasanya tidak penuh. Halaman penuh berarti mungkin
      // masih ada baris setelahnya, jadi halaman berikutnya yang memastikan.
      if (sepotong.length < halaman) break;
      ke++;
    }
    return hasil;
  }

  // ---------- bookmarks ----------

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
    await _client().rpc(
      'upsert_sync_rows',
      params: {'p_user_id': uid, 'p_tabel': 'bookmarks', 'p_rows': baris},
    );
  }

  /// Soft delete: baris ditandai `deleted_at` (bukan DELETE keras) supaya
  /// perangkat lain tidak mengunggah ulang salinan lamanya.
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

  // ---------- reading_history ----------

  static Future<List<Map<String, dynamic>>> tarikHistory(String uid) async {
    return tarikBerpaginasi<Map<String, dynamic>>(
      ambil: (dari, sampai) async {
        final baris = await _client()
            .from('reading_history')
            .select(
              'manga_id, manga_title, cover_url, chapter_id, '
              'chapter_title, scroll_position, updated_at, deleted_at',
            )
            .eq('user_id', uid)
            .order('manga_id')
            .range(dari, sampai);
        return [for (final b in baris) Map<String, dynamic>.from(b as Map)];
      },
    );
  }

  /// Memakai RPC `upsert_sync_rows` untuk penjaga LWW, bukan `.upsert()` biasa.
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
