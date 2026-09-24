import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Satu entri error yang tertangkap.
class AppErrorEntry {
  const AppErrorEntry({
    required this.waktu,
    required this.ringkasan,
    required this.detail,
  });

  final DateTime waktu;
  final String ringkasan;
  final String detail;
}

/// Perekam error Dart di perangkat.
///
/// Dipasang sekali di [main] sebelum aplikasi jalan. Setiap error
/// framework maupun uncaught disimpan di memori (50 terakhir) dan
/// ditambahkan ke file, sehingga bisa dibaca dari halaman Diagnostik
/// tanpa PC, kabel, atau WiFi.
class ErrorLog {
  const ErrorLog._();

  static const _maks = 50;
  static const _namaFile = 'alana_error_log.txt';

  static final List<AppErrorEntry> _entries = [];

  /// Bertambah setiap ada entri baru. UI memakainya untuk refresh.
  static final ValueNotifier<int> versi = ValueNotifier(0);

  static List<AppErrorEntry> get entries => List.unmodifiable(_entries);

  static void pasang() {
    FlutterError.onError = (details) {
      catat(details.exception, details.stack);
      FlutterError.presentError(details);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      catat(error, stack);
      return true;
    };
  }

  static void catat(Object error, StackTrace? stack) {
    _entries.add(
      AppErrorEntry(
        waktu: DateTime.now(),
        ringkasan: error.toString(),
        detail: stack?.toString() ?? '',
      ),
    );
    if (_entries.length > _maks) {
      _entries.removeRange(0, _entries.length - _maks);
    }
    versi.value++;
    _simpanFile();
  }

  static Future<void> _simpanFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final isi = _entries
          .map(
            (e) => '[${e.waktu.toIso8601String()}] ${e.ringkasan}\n${e.detail}',
          )
          .join('\n---\n');
      await File('${dir.path}/$_namaFile').writeAsString(isi);
    } catch (_) {
      // Pencatatan tidak boleh mengganggu aplikasi.
    }
  }

  /// Isi file log dari sesi-sesi sebelumnya (kosong bila belum ada).
  static Future<String> bacaFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_namaFile');
      if (!await file.exists()) return '';
      final isi = await file.readAsString();
      return isi;
    } catch (_) {
      return '';
    }
  }

  static Future<void> bersihkan() async {
    _entries.clear();
    versi.value++;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_namaFile');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Abaikan.
    }
  }
}
