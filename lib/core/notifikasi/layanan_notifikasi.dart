import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Mekanik plugin notifikasi lokal (tanpa logika bisnis).
///
/// - Channel Android `pengingat_baca`.
/// - Payload format `"mangaId|chapterId"` (chapter boleh kosong).
/// - Navigasi didelegasikan lewat [daftarkanNavigasi] karena callback
///   plugin tidak punya akses Riverpod/router.
class LayananNotifikasi {
  const LayananNotifikasi._();

  static const channelId = 'pengingat_baca';
  static const channelName = 'Pengingat Baca';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _siap = false;
  static void Function(String lokasi)? _pergi;
  static String? _lokasiTertunda;

  /// Lokasi tertunda dari ketuk saat router belum siap (sekali ambil).
  static String? ambilTertunda() {
    final lokasi = _lokasiTertunda;
    _lokasiTertunda = null;
    return lokasi;
  }

  /// Daftarkan cara pindah rute. Dipanggil sekali dari ManhwaApp.
  /// Langsung meneruskan lokasi tertunda bila ada.
  static void daftarkanNavigasi(void Function(String lokasi) pergi) {
    _pergi = pergi;
    final tertunda = ambilTertunda();
    if (tertunda != null) pergi(tertunda);
  }

  static Future<void> init() async {
    if (_siap) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Fallback UTC: jadwal tetap jalan walau jam dinding meleset.
      }

      const pengaturan = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(
        pengaturan,
        onDidReceiveNotificationResponse: _saatDiketuk,
      );

      const kanal = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Pengingat melanjutkan bacaan yang tertunda.',
        importance: Importance.defaultImportance,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(kanal);

      // App dibuka dari notifikasi saat terminated.
      final awal = await _plugin.getNotificationAppLaunchDetails();
      if ((awal?.didNotificationLaunchApp ?? false) &&
          (awal?.notificationResponse?.payload?.isNotEmpty ?? false)) {
        _lokasiTertunda = _lokasiDariPayload(
          awal!.notificationResponse!.payload,
        );
      }
      _siap = true;
    } catch (_) {
      // Notifikasi non-kritis: aplikasi tetap jalan tanpanya.
    }
  }

  /// Minta izin tampilkan notifikasi (Android 13+). Aman di versi lama.
  static Future<bool> mintaIzin() async {
    try {
      final hasil = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return hasil ?? true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _detail() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Pengingat melanjutkan bacaan yang tertunda.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  /// Tampilkan langsung (untuk tombol uji).
  static Future<void> tampilkanSekarang({
    required int id,
    required String judul,
    required String isi,
    String? payload,
  }) async {
    try {
      await _plugin.show(id, judul, isi, _detail(), payload: payload);
    } catch (_) {
      // Abaikan.
    }
  }

  /// Jadwalkan sekali pada waktu lokal [kapan].
  static Future<void> jadwalkan({
    required int id,
    required String judul,
    required String isi,
    required DateTime kapan,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        judul,
        isi,
        tz.TZDateTime.from(kapan, tz.local),
        _detail(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Abaikan (mis. izin ditolak).
    }
  }

  static Future<void> batalkan(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {
      // Abaikan.
    }
  }

  static Future<void> batalkanSemua() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Abaikan.
    }
  }

  static void _saatDiketuk(NotificationResponse respons) {
    final lokasi = _lokasiDariPayload(respons.payload);
    if (lokasi == null) return;
    final pergi = _pergi;
    if (pergi != null) {
      pergi(lokasi);
    } else {
      _lokasiTertunda = lokasi;
    }
  }

  /// `"manga|chapter"` → `/baca/m/c` atau `/detail/m`. Null bila kosong.
  static String? _lokasiDariPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final pisah = payload.split('|');
    final mangaId = pisah[0].trim();
    if (mangaId.isEmpty) return null;
    final chapterId = pisah.length > 1 ? pisah[1].trim() : '';
    if (chapterId.isEmpty) return '/detail/$mangaId';
    return '/baca/$mangaId/$chapterId';
  }
}
