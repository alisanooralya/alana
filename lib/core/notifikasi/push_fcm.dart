import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/features/notifikasi/data/device_token_repository.dart';
import 'package:alana/features/notifikasi/presentation/notification_permission_provider.dart';
import 'package:alana/features/notifikasi/presentation/notifikasi_providers.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';

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
    _uid = (uid == null || uid.isEmpty) ? null : uid;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final repo = ref.read(deviceTokenRepositoryProvider);
      if (_uid == null) {
        final lama = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
        if (lama.isNotEmpty) {
          await repo.hapus(lama);
          await prefs.remove(DeviceTokenRepository.kunciLokal);
        }
        return;
      }
      if (!ref.read(pushAktifProvider)) return;
      final permission = await ref.read(notificationPermissionProvider.future);
      if (!permission.granted) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final tersimpan = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      if (token == tersimpan) return;
      if (tersimpan.isNotEmpty) {
        await repo.hapus(tersimpan);
      }
      await repo.simpan(_uid!, token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
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
      final lama = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      if (token == lama) return;
      if (lama.isNotEmpty) {
        await repo.hapus(lama);
      }
      await repo.simpan(uid, token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
    } catch (_) {
      // Abaikan.
    }
  }

  /// Hapus token perangkat ini dari server + lokal (dipakai
  /// saat toggle dimatikan dan saat logout tanpa sesi).
  Future<void> hapusTokenTersimpan() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final lama = prefs.getString(DeviceTokenRepository.kunciLokal) ?? '';
      if (lama.isNotEmpty) {
        await ref.read(deviceTokenRepositoryProvider).hapus(lama);
        await prefs.remove(DeviceTokenRepository.kunciLokal);
      }
    } catch (_) {
      // Abaikan.
    }
  }

  Future<void> _foreground(RemoteMessage pesan) async {
    final data = pesan.data;
    final mangaId = data['manga_id']?.toString() ?? '';
    final chapterId = data['chapter_id']?.toString() ?? '';
    final judul = pesan.notification?.title ?? 'Chapter baru tersedia';
    final isi = pesan.notification?.body ?? 'Ketuk untuk membaca.';
    await LayananNotifikasi.tampilkanBab(
      id: (mangaId + chapterId).hashCode & 0x7fffffff,
      judul: judul,
      isi: isi,
      payload: '$mangaId|$chapterId',
    );
    ref.invalidate(daftarNotifikasiProvider);
    ref.invalidate(belumDibacaProvider);
  }

  void _buka(RemoteMessage pesan) {
    LayananNotifikasi.bukaNotifikasi(
      mangaId: pesan.data['manga_id']?.toString(),
      chapterId: pesan.data['chapter_id']?.toString(),
    );
  }
}

final pushServiceProvider = Provider<PushFcm>((ref) => PushFcm(ref));
