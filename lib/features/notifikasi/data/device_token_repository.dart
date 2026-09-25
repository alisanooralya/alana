import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';

class DeviceIdentity {
  DeviceIdentity(this._prefs);

  static const _fallbackKey = 'device_identity_fallback';

  final SharedPreferences _prefs;
  String? _cached;

  Future<String?> get() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final androidId = (await const AndroidId().getId())?.trim();
      if (androidId != null && androidId.isNotEmpty) {
        return _cached = 'android:$androidId';
      }
    } catch (_) {}

    var fallback = _prefs.getString(_fallbackKey);
    if (fallback == null || fallback.isEmpty) {
      fallback = _uuidV4();
      await _prefs.setString(_fallbackKey, fallback);
    }
    return _cached = fallback;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class DeviceTokenRepository {
  const DeviceTokenRepository();

  static const kunciLokal = 'fcm_token';
  static const kunciDeviceId = 'fcm_device_id';

  Future<void> simpan({
    required String uid,
    required String deviceId,
    required String token,
  }) async {
    if (uid.isEmpty || deviceId.isEmpty || token.isEmpty) return;
    await SupabaseSetup.instance.from('device_tokens').upsert({
      'user_id': uid,
      'device_id': deviceId,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,device_id');
  }

  Future<void> hapusLegacy({required String uid, required String token}) async {
    if (uid.isEmpty || token.isEmpty) return;
    try {
      await SupabaseSetup.instance
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('fcm_token', token)
          .like('device_id', 'legacy:%');
    } catch (_) {}
  }

  Future<void> hapus({required String uid, required String deviceId}) async {
    if (uid.isEmpty || deviceId.isEmpty) return;
    try {
      await SupabaseSetup.instance
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('device_id', deviceId);
    } catch (_) {}
  }
}

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

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) {
  return DeviceIdentity(ref.watch(sharedPreferencesProvider));
});

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return const DeviceTokenRepository();
});

final pushAktifProvider = NotifierProvider<PushAktif, bool>(() => PushAktif());
