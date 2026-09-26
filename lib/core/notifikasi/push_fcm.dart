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

  /// Listener sudah terdaftar.
  bool _siap = false;

  /// Pendaftaran sedang berjalan, mencegah dua panggilan bertumpuk.
  bool _sertaMulai = false;

  /// [sinkronToken] sedang berjalan. Panggilannya datang dari initState,
  /// resume, dan perubahan sesi, jadi tanpa ini dua sinkronisasi bisa saling
  /// menimpa: satu menghapus baris token milik akun yang baru saja masuk.
  Future<void>? _antreanToken;

  String? _uid;

  /// Umur data token lokal sebelum dianggap perlu diverifikasi ulang.
  ///
  /// Cache lokal pernah dianggap bukti bahwa baris token masih ada di server.
  /// Padahal `check-new-chapters` bisa menghapus baris token yang tidak
  /// terdaftar, dan database bisa di-reset. Akibatnya perangkat tidak pernah
  /// mendaftar ulang dan push mati permanen untuk instalasi itu.
  static const Duration _masaVerifikasiToken = Duration(hours: 6);

  /// Kunci SharedPreferences untuk waktu verifikasi terakhir.
  static const String _kunciVerifikasi = 'fcm_verified_at';

  /// Daftarkan semua listener.
  ///
  /// Penanda berhasil baru dipasang setelah registrasi selesai. Sebelumnya
  /// `_siap` diset true lebih dulu, jadi satu kegagalan saja (Firebase belum
  /// diinisialisasi, Play Services tidak ada, channel platform error)
  /// mematikan push untuk sisa proses dan tidak ada yang mencoba lagi.
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

  /// Sinkron token sesuai sesi: login/app-start → upsert;
  /// logout (uid null) → hapus baris token perangkat ini.
  ///
  /// Serialized lewat [_antreanToken]. Tanpa itu pemanggilan yang bersilangan
  /// (initState, resume, perubahan sesi) bisa saling menimpa: pemanggilan
  /// logout bisa menghapus baris token yang baru saja didaftarkan pemanggilan
  /// login, sehingga push berhenti tanpa explanation sampai cold start.
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
            // Jangan lupakan uid lama dan jangan bersihkan cache lokal.
            // Kalau _uid langsung>null, pemanggilan berikutnya melihat
            // uidSebelum == null sehingga penghapusan tidak akan pernah
            // dicoba lagi dan notifikasi akun lama terus masuk ke perangkat
            // yang sekarang dipakai akun lain.
            _uid = uidSebelum;
            return;
          }
        }
        _uid = null;
        await prefs.remove(DeviceTokenRepository.kunciLokal);
        await prefs.remove(DeviceTokenRepository.kunciDeviceId);
        await prefs.remove(_kunciVerifikasi);
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
      final samaDenganLokal =
          token == tersimpan && deviceId == deviceTersimpan;
      if (samaDenganLokal && _masihSegar(prefs)) return;
      if (tersimpan.isNotEmpty) {
        await repo.hapusLegacy(uid: uidAktif, token: tersimpan);
      }
      await repo.hapusLegacy(uid: uidAktif, token: token);
      await repo.simpan(uid: uidAktif, deviceId: deviceId, token: token);
      await prefs.setString(DeviceTokenRepository.kunciLokal, token);
      await prefs.setString(DeviceTokenRepository.kunciDeviceId, deviceId);
      await prefs.setString(
        _kunciVerifikasi,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Abaikan: dicoba lagi pada pemanggilan berikutnya.
    }
  }

  /// `true` bila verifikasi terakhir masih cukup baru.
  bool _masihSegar(SharedPreferences prefs) {
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

  /// Hapus token perangkat ini dari server + lokal (dipakai
  /// saat toggle dimatikan dan saat logout tanpa sesi).
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
      // Baris token masih ada di server. Jangan bersihkan cache lokal:
      // dengan begitu penanda ini bertahan dan penghapusan dicoba lagi pada
      // sinkronToken berikutnya. Sebelumnya cache dibersihkan apa pun hasilnya,
      // jadi toggle terlihat mati padahal cron tetap mengirim push, dan tidak
      // ada antrean yang mencoba mengulanginya.
      return;
    }
    await prefs.remove(DeviceTokenRepository.kunciLokal);
    await prefs.remove(DeviceTokenRepository.kunciDeviceId);
    await prefs.remove(_kunciVerifikasi);
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
