import 'package:alana/services/manga_api_exception.dart';

/// Mengubah error teknis menjadi pesan Bahasa Indonesia yang jelas.
///
/// Aturan: timeout/gagal koneksi → pesan luring; 404 → tidak ditemukan;
/// 5xx → server bermasalah; selebihnya pesan umum tanpa istilah Inggris.
String pesanErrorRamah(Object error) {
  if (error is MangaApiException) {
    final kode = error.statusCode;
    if (kode == null) {
      if (_tandaJaringan(error.message)) {
        return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
      }
      return 'Gagal menghubungi server. Coba lagi nanti.';
    }
    if (kode == 404) return 'Data tidak ditemukan di server.';
    if (kode >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Gagal memuat (kode $kode). Coba lagi.';
  }
  if (_tandaJaringan(error.toString())) {
    return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
  }
  return 'Terjadi kesalahan. Coba lagi.';
}

bool _tandaJaringan(String teks) {
  final t = teks.toLowerCase();
  return t.contains('socketexception') ||
      t.contains('connection') ||
      t.contains('timed out') ||
      t.contains('timeout') ||
      t.contains('network') ||
      t.contains('host lookup') ||
      t.contains('failed host') ||
      t.contains('no address associated');
}
