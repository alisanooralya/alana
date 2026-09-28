import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:alana/core/utils/deep_link.dart';

class LayananNotifikasi {
  const LayananNotifikasi._();

  static const channelId = 'pengingat_baca';
  static const channelName = 'Pengingat Baca';

  static const channelBabId = 'bab_baru';
  static const channelBabName = 'Chapter Baru';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _siap = false;
  static void Function(String lokasi)? _pergi;
  static String? _lokasiTertunda;

  static String? ambilTertunda() {
    final lokasi = _lokasiTertunda;
    _lokasiTertunda = null;
    return lokasi;
  }

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
        settings: pengaturan,
        onDidReceiveNotificationResponse: _saatDiketuk,
      );

      const kanal = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Pengingat melanjutkan bacaan yang tertunda.',
        importance: Importance.defaultImportance,
      );
      const kanalBab = AndroidNotificationChannel(
        channelBabId,
        channelBabName,
        description: 'Pemberitahuan chapter baru dari server.',
        importance: Importance.high,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(kanal);
      await android?.createNotificationChannel(kanalBab);

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

  static NotificationDetails _detail({String? channel}) {
    final id = channel ?? channelId;
    final nama = channel == channelBabId ? channelBabName : channelName;
    final deskripsi = channel == channelBabId
        ? 'Pemberitahuan chapter baru dari server.'
        : 'Pengingat melanjutkan bacaan yang tertunda.';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        nama,
        channelDescription: deskripsi,
        importance: channel == channelBabId
            ? Importance.high
            : Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  static Future<void> tampilkanBab({
    required int id,
    required String judul,
    required String isi,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: judul,
        body: isi,
        notificationDetails: _detail(channel: channelBabId),
        payload: payload,
      );
    } catch (_) {
      // Abaikan.
    }
  }

  static Future<void> tampilkanSekarang({
    required int id,
    required String judul,
    required String isi,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: judul,
        body: isi,
        notificationDetails: _detail(),
        payload: payload,
      );
    } catch (_) {
      // Abaikan.
    }
  }

  static Future<void> jadwalkan({
    required int id,
    required String judul,
    required String isi,
    required DateTime kapan,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: judul,
        body: isi,
        scheduledDate: tz.TZDateTime.from(kapan, tz.local),
        notificationDetails: _detail(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Abaikan (mis. izin ditolak).
    }
  }

  static Future<void> batalkan(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Abaikan.
    }
  }

  static Future<void> batalkanPengingat(List<int> ids) async {
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {
        // Abaikan: notifikasi yang sudah hilang tidak perlu dibatalkan.
      }
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

  static String? _lokasiDariPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final dariLink = internalLocationFromDeepLink(payload);
    if (dariLink != null) return dariLink;
    final pisah = payload.split('|');
    return ruteDariNotif(
      mangaId: pisah[0].trim(),
      chapterId: pisah.length > 1 ? pisah[1].trim() : '',
    );
  }

  static String? ruteDariNotif({
    String? mangaId,
    String? chapterId,
    String? link,
  }) {
    final dariLink = internalLocationFromDeepLink(link);
    if (dariLink != null) return dariLink;
    final m = (mangaId ?? '').trim();
    if (m.isEmpty) return null;
    final c = (chapterId ?? '').trim();
    if (c.isEmpty) return '/detail/$m';
    return '/baca/$m/$c';
  }

  static void bukaNotifikasi({
    String? mangaId,
    String? chapterId,
    String? link,
  }) {
    final lokasi = ruteDariNotif(
      mangaId: mangaId,
      chapterId: chapterId,
      link: link,
    );
    if (lokasi == null) return;
    final pergi = _pergi;
    if (pergi != null) {
      pergi(lokasi);
    } else {
      _lokasiTertunda = lokasi;
    }
  }
}
