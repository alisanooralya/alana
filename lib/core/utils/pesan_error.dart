import 'package:alana/services/manga_api_exception.dart';

/// Mengubah error teknis menjadi pesan Bahasa Indonesia yang jelas.
///
/// Aturan: timeout/gagal koneksi → pesan luring; 404 → tidak ditemukan;
/// 5xx → server bermasalah; kegagalan parsing → respons tidak terbaca;
/// selebihnya pesan umum tanpa istilah Inggris.
String pesanErrorRamah(Object error) {
  // Kegagalan parsing bukan masalah jaringan. Sebelumnya jenis ini ikut
  // tertangkap di cabang "kode == null" sehingga user diberi tahu jaringan
  // mereka bermasalah padahal servernya yang mengubah bentuk data - dan
  // tombol coba lagi tidak akan pernah menolong.
  if (error is FormatException) {
    return 'Data dari server tidak bisa dibaca. Coba lagi nanti.';
  }
  if (error is MangaApiException) {
    if (_tandaParsing(error.message)) {
      return 'Data dari server tidak bisa dibaca. Coba lagi nanti.';
    }
    final kode = error.statusCode;
    if (kode == null) {
      if (_tandaJaringan(error.message)) {
        return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
      }
      return 'Gagal menghubungi server. Coba lagi nanti.';
    }
    if (kode == 404) return 'Data tidak ditemukan di server.';
    if (kode == 400) return 'Permintaan ditolak server. Coba ubah filter lalu coba lagi.';
    if (kode >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Gagal memuat (kode $kode). Coba lagi.';
  }
  if (_tandaParsing(error.toString())) {
    return 'Data dari server tidak bisa dibaca. Coba lagi nanti.';
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

/// Tanda bahwa respons server tidak bisa diurai, bukan masalah jaringan.
bool _tandaParsing(String teks) {
  final t = teks.toLowerCase();
  return t.contains('formatexception') ||
      t.contains('unexpected character') ||
      t.contains('unexpected end of') ||
      t.contains('is missing') ||
      t.contains('invalid response') ||
      t.contains('unexpected null');
}
