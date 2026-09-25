import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';

/// Token FCM perangkat ini (tabel `device_tokens`, PK = token).
class DeviceTokenRepository {
  const DeviceTokenRepository();

  static const kunciLokal = 'fcm_token';

  Future<void> simpan(String uid, String token) async {
    if (uid.isEmpty || token.isEmpty) return;
    await SupabaseSetup.instance.from('device_tokens').upsert({
      'user_id': uid,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'fcm_token');
  }

  Future<void> hapus(String token) async {
    if (token.isEmpty) return;
    try {
      await SupabaseSetup.instance
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);
    } catch (_) {
      // Abaikan: baris mungkin sudah hilang.
    }
  }
}

/// On/off push chapter baru (per-perangkat, default nyala).
/// Mati = token dihapus dari server (push berhenti), bukan server.
class PushAktif extends Notifier<bool> {
  static const kunci = 'push_chapter_baru';

  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(kunci) ?? true;
  }

  Future<void> atur(bool aktif) async {
    await ref.read(sharedPreferencesProvider).setBool(kunci, aktif);
    state = aktif;
  }
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return const DeviceTokenRepository();
});

final pushAktifProvider = NotifierProvider<PushAktif, bool>(() => PushAktif());
