import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/notifikasi/data/device_token_repository.dart';
import 'package:alana/features/notifikasi/presentation/notification_permission_provider.dart';
import 'package:alana/features/notifikasi/presentation/notifikasi_providers.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';

@pragma('vm:entry-point')
Future<void> fcmBackground(RemoteMessage message) async {
  // Sengaja kosong.
}

class PushFcm {
  PushFcm(this.ref);

  final Ref ref;

  bool _siap = false;
  bool _sertaMulai = false;

  Future<void>? _antreanToken;

  String? _uid;

  static const Duration _masaVerifikasiToken = Duration(hours: 6);
  static const String _kunciVerifikasi = 'fcm_verified_at';

  // Stempel waktu saja tidak cukup: prefs bersama tidak tahu milik akun mana.
  // Tanpa uid, akun baru yang login di dalam jendela 6 jam akan melihat
  // "masih segar" dan melewatkan pendaftaran token-nya.
  static const String _kunciVerifikasiUid = 'fcm_verified_uid';

  Future<void> init() async {
    if (_siap || _sertaMulai) return;
    _sertaMulai = true;
    try {
      FirebaseMessaging.onBackgroundMessage(fcmBackground);
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _gantiToken(token);
      });
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(_buka);
      final awal = await FirebaseMessaging.instance.getInitialMessage();
      if (awal != null) _buka(awal);
      _siap = true;
    } catch (_) {
      // Izinkan percobaan lagi pada pemanggilan berikutnya.
    } finally {
      _sertaMulai = false;
    }
  }

  Future<void> sinkronToken(String? uid) {
    final sebelumnya = _antreanToken ?? Future.value();
    final lanjutan = sebelumnya.then((_) => _sinkronToken(uid));
    _antreanToken = lanjutan.catchError((_) {});
    return lanjutan;
  }

  Future<void> _sinkronToken(String? uid) async {
    final uidSebelum = _uid;
    final uidAktif = (uid == null || uid.isEmpty) ? null : uid;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final repo = ref.read(deviceTokenRepositoryProvider);
      if (uidAktif == null) {
        final deviceId = await ref.read(deviceIdentityProvider).get();
        if (uidSebelum != null && deviceId != null) {
          try {
            await repo.hapus(uid: uidSebelum, deviceId: deviceId);
          } catch (_) {
            _uid = uidSebelum;
            return;
          }
        }
        _uid = null;
        await prefs.remove(DeviceTokenRepository.kunciLokal);
        await prefs.remove(DeviceTokenRepository.kunciDeviceId);
        await prefs.remove(_kunciVerifikasi);
        await prefs.remove(_kunciVerifikasiUid);
        return;
      }
      _uid = uidAktif;
      if (!ref.read(pushAktifProvider)) return;
      final permission = await ref.read(notificationPermissionProvider.future);
      if (!permission.granted) return;
      final token = await FirebaseMessaging.instance.getToken();
      final deviceId = await ref.read(deviceIdentityProvider).get();
      if (token == null || token.isEmpty || deviceId == null) return;
      final tersimpan = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      final deviceTersimpan =
          prefs.getString(DeviceTokenRepository.kunciDeviceId) ?? '';
      final samaDenganLokal = token == tersimpan && deviceId == deviceTersimpan;
      if (samaDenganLokal && _masihSegar(prefs, uidAktif)) return;
      if (tersimpan.isNotEmpty) {
        await repo.hapusLegacy(uid: uidAktif, token: tersimpan);
      }
      await repo.hapusLegacy(uid: uidAktif, token: token);
      await repo.simpan(uid: uidAktif, deviceId: deviceId, token: token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
      await prefs.setString(DeviceTokenRepository.kunciDeviceId, deviceId);
      await prefs.setString(_kunciVerifikasi, DateTime.now().toIso8601String());
      await prefs.setString(_kunciVerifikasiUid, uidAktif);
    } catch (_) {
      // Abaikan: dicoba lagi pada pemanggilan berikutnya.
    }
  }

  // Hanya segar kalau cap waktu dan uid sama-sama milik akun yang sedang
  // aktif. Kalau uid berbeda, perlakukan sebagai belum pernah diverifikasi
  // supaya akun baru pasti mendaftarkan token-nya sendiri.
  bool _masihSegar(SharedPreferences prefs, String uidAktif) {
    if (prefs.getString(_kunciVerifikasiUid) != uidAktif) return false;
    final iso = prefs.getString(_kunciVerifikasi);
    if (iso == null || iso.isEmpty) return false;
    final waktu = DateTime.tryParse(iso);
    if (waktu == null) return false;
    return DateTime.now().difference(waktu) < _masaVerifikasiToken;
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

  Future<void> hapusTokenTersimpan() async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final deviceId = await ref.read(deviceIdentityProvider).get();
      final uid = _uid ?? ref.read(userIdProvider);
      if (uid != null && deviceId != null) {
        await ref
            .read(deviceTokenRepositoryProvider)
            .hapus(uid: uid, deviceId: deviceId);
      }
    } catch (_) {
      return;
    }
    await prefs.remove(DeviceTokenRepository.kunciLokal);
    await prefs.remove(DeviceTokenRepository.kunciDeviceId);
    await prefs.remove(_kunciVerifikasi);
    await prefs.remove(_kunciVerifikasiUid);
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
