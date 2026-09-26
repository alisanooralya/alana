import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

/// Riwayat pencarian: Hive per-akun di box `sm_<uid>`, lokal saja.
///
/// Tidak ikut sync ke Supabase dan terhapus saat signOut karena
/// `AppStorage.hapusBoxUser` membersihkan box `sm`. Nilai disimpan
/// sebagai `List<String>` sehingga tidak butuh adapter.
class SearchHistoryRepository extends Notifier<List<String>> {
  /// Jumlah entri tersimpan, terbaru lebih dulu.
  static const int maks = 10;

  static const String _key = '__items__';

  String? _uid;
  String? _dibukaUntuk;

  @override
  List<String> build() {
    final uid = ref.watch(userIdProvider);
    _uid = uid;
    if (uid == null || uid.isEmpty) return const [];

    final box = AppStorage.boxUserSync('sm', uid);
    if (box == null) {
      _bukaLaluMuatUlang(uid);
      return const [];
    }
    return _muat(box);
  }

  void _bukaLaluMuatUlang(String uid) {
    if (_dibukaUntuk == uid) return;
    _dibukaUntuk = uid;
    Future(() async {
      await AppStorage.bukaBoxUser('sm', uid);
      ref.invalidateSelf();
    });
  }

  List<String> _muat(Box box) {
    final raw = box.get(_key);
    if (raw is! List) return const [];
    final hasil = <String>[];
    for (final e in raw) {
      final nilai = e?.toString().trim() ?? '';
      if (nilai.isEmpty || hasil.contains(nilai)) continue;
      hasil.add(nilai);
      if (hasil.length == maks) break;
    }
    return List.unmodifiable(hasil);
  }

  void _tulis(List<String> items) {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      AppStorage.boxUserSync('sm', uid)?.put(_key, items);
    }
    state = List.unmodifiable(items);
  }

  /// Mencatat satu kata kunci. Duplikat (tanpa beda huruf besar) digeser
  /// ke posisi paling atas, bukan ditambahkan lagi.
  void simpan(String query) {
    final nilai = query.trim();
    if (nilai.isEmpty) return;
    final next = <String>[
      nilai,
      ...state.where((e) => e.toLowerCase() != nilai.toLowerCase()),
    ];
    if (next.length > maks) next.removeRange(maks, next.length);
    _tulis(next);
  }

  void hapus(String query) {
    if (!state.contains(query)) return;
    _tulis(state.where((e) => e != query).toList());
  }

  void bersihkan() {
    if (state.isEmpty) return;
    _tulis(const []);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryRepository, List<String>>(
      () => SearchHistoryRepository(),
    );
