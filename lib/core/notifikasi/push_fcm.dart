import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/notifikasi/data/device_token_repository.dart';
import 'package:alana/features/notifikasi/presentation/notification_permission_provider.dart';
import 'package:alana/features/notifikasi/presentation/notifikasi_providers.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

/// Handler background FCM (wajib top-level + pragma).
/// Pesan bertipe notification+data tampil otomatis di tray;
/// tidak ada kerja tambahan di sini.
@pragma('vm:entry-point')
Future<void> fcmBackground(RemoteMessage message) async {
  // Sengaja kosong.
}

/// Pengkabelan push FCM: token, foreground, tap, terminated.
///
/// Menerima RemoteMessage berisi data `manga_id`/`chapter_id`
/// (lihat Edge Function check-new-chapters).
class PushFcm {
  PushFcm(this.ref);

  final Ref ref;
  bool _siap = false;
  String? _uid;

  /// Daftarkan semua listener (sekali saja, setelah login/services siap).
  Future<void> init() async {
    if (_siap) return;
    _siap = true;
    try {
      FirebaseMessaging.onBackgroundMessage(fcmBackground);
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _gantiToken(token);
      });
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_buka);
      final awal = await FirebaseMessaging.instance.getInitialMessage();
      if (awal != null) _buka(awal);
    } catch (_) {
      // Push non-kritis.
    }
  }

  /// Sinkron token sesuai sesi: login/app-start → upsert;
  /// logout (uid null) → hapus baris token perangkat ini.
  Future<void> sinkronToken(String? uid) async {
    final uidSebelum = _uid;
    final uidAktif = (uid == null || uid.isEmpty) ? null : uid;
    _uid = uidAktif;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final repo = ref.read(deviceTokenRepositoryProvider);
      if (uidAktif == null) {
        final deviceId = await ref.read(deviceIdentityProvider).get();
        if (uidSebelum != null && deviceId != null) {
          await repo.hapus(uid: uidSebelum, deviceId: deviceId);
        }
        await prefs.remove(DeviceTokenRepository.kunciLokal);
        await prefs.remove(DeviceTokenRepository.kunciDeviceId);
        return;
      }
      if (!ref.read(pushAktifProvider)) return;
      final permission = await ref.read(notificationPermissionProvider.future);
      if (!permission.granted) return;
      final token = await FirebaseMessaging.instance.getToken();
      final deviceId = await ref.read(deviceIdentityProvider).get();
      if (token == null || token.isEmpty || deviceId == null) return;
      final tersimpan = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      final deviceTersimpan =
          prefs.getString(DeviceTokenRepository.kunciDeviceId) ?? '';
      if (token == tersimpan && deviceId == deviceTersimpan) return;
      if (tersimpan.isNotEmpty) {
        await repo.hapusLegacy(uid: uidAktif, token: tersimpan);
      }
      await repo.hapusLegacy(uid: uidAktif, token: token);
      await repo.simpan(uid: uidAktif, deviceId: deviceId, token: token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
      await prefs.setString(DeviceTokenRepository.kunciDeviceId, deviceId);
    } catch (_) {
      // Abaikan.
    }
  }

  Future<void> _gantiToken(String token) async {
    try {
      final uid = _uid;
      if (uid == null || !ref.read(pushAktifProvider)) return;
      final permission = await ref.read(notificationPermissionProvider.future);
      if (!permission.granted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      final repo = ref.read(deviceTokenRepositoryProvider);
      final deviceId = await ref.read(deviceIdentityProvider).get();
      final lama = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      final deviceLama =
          prefs.getString(DeviceTokenRepository.kunciDeviceId) ?? '';
      if (token == lama && deviceId == deviceLama) return;
      if (deviceId == null) return;
      if (lama.isNotEmpty) {
        await repo.hapusLegacy(uid: uid, token: lama);
      }
      await repo.hapusLegacy(uid: uid, token: token);
      await repo.simpan(uid: uid, deviceId: deviceId, token: token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
      await prefs.setString(DeviceTokenRepository.kunciDeviceId, deviceId);
    } catch (_) {
      // Abaikan.
    }
  }

  /// Hapus token perangkat ini dari server + lokal (dipakai
  /// saat toggle dimatikan dan saat logout tanpa sesi).
  Future<void> hapusTokenTersimpan() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final deviceId = await ref.read(deviceIdentityProvider).get();
      final uid = _uid ?? ref.read(userIdProvider);
      if (uid != null && deviceId != null) {
        await ref
            .read(deviceTokenRepositoryProvider)
            .hapus(uid: uid, deviceId: deviceId);
      }
      await prefs.remove(DeviceTokenRepository.kunciLokal);
      await prefs.remove(DeviceTokenRepository.kunciDeviceId);
    } catch (_) {
      // Abaikan.
    }
  }

  Future<void> _foreground(RemoteMessage pesan) async {
    final data = pesan.data;
    final mangaId = data['manga_id']?.toString() ?? '';
    final chapterId = data['chapter_id']?.toString() ?? '';
    final link =
        data['link']?.toString() ??
        (mangaId.isEmpty
            ? ''
            : chapterId.isEmpty
            ? mangaDeepLink(mangaId)
            : chapterDeepLink(mangaId, chapterId));
    final judul = pesan.notification?.title ?? 'Chapter baru tersedia';
    final isi = pesan.notification?.body ?? 'Ketuk untuk membaca.';
    await LayananNotifikasi.tampilkanBab(
      id: (mangaId + chapterId).hashCode & 0x7fffffff,
      judul: judul,
      isi: isi,
      payload: link,
    );
    ref.invalidate(daftarNotifikasiProvider);
    ref.invalidate(belumDibacaProvider);
  }

  void _buka(RemoteMessage pesan) {
    LayananNotifikasi.bukaNotifikasi(
      mangaId: pesan.data['manga_id']?.toString(),
      chapterId: pesan.data['chapter_id']?.toString(),
      link: pesan.data['link']?.toString(),
    );
  }
}

final pushServiceProvider = Provider<PushFcm>((ref) => PushFcm(ref));
