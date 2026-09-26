const alanaScheme = 'alana';

/// Host deep link untuk tautan reset password dari Supabase.
const String resetPasswordHost = 'reset-password';

/// Lokasi internal halaman set password baru.
const String resetPasswordLokasi = '/reset-password';

/// Tautan tujuan yang dikirim ke Supabase sebagai `redirect_to`.
String resetPasswordLink() => '$alanaScheme://$resetPasswordHost';

/// Mengambil kode PKCE dari tautan reset password, null bila bukan tautan itu.
String? kodeRecoveryDari(Uri uri) {
  if (uri.scheme != alanaScheme || uri.host != resetPasswordHost) return null;
  final kode = uri.queryParameters['code'];
  if (kode == null || kode.isEmpty) return null;
  return kode;
}

String mangaDeepLink(String mangaId) {
  return '$alanaScheme://manga/${Uri.encodeComponent(mangaId)}';
}

String chapterDeepLink(String mangaId, String chapterId) {
  return '$alanaScheme://manga/${Uri.encodeComponent(mangaId)}/chapter/${Uri.encodeComponent(chapterId)}';
}

String? internalLocationFromDeepLink(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != alanaScheme) return null;
  final segments = uri.pathSegments.where((value) => value.isNotEmpty).toList();
  if (uri.host == 'manga') {
    if (segments.length == 1) {
      return '/detail/${Uri.encodeComponent(segments.first)}';
    }
    if (segments.length == 3 && segments[1] == 'chapter') {
      return '/baca/${Uri.encodeComponent(segments[0])}/${Uri.encodeComponent(segments[2])}';
    }
  }
  if (uri.host == 'chapter' && segments.length == 2) {
    return '/baca/${Uri.encodeComponent(segments[0])}/${Uri.encodeComponent(segments[1])}';
  }
  return null;
}

class DeepLinkIntent {
  const DeepLinkIntent._();

  static String? _pending;

  static void simpan(String lokasi) {
    if (lokasi.isNotEmpty) _pending = lokasi;
  }

  static String? ambil() {
    final lokasi = _pending;
    _pending = null;
    return lokasi;
  }

  /// Membuang target yang belum sempat dipakai.
  static void buang() => _pending = null;
}
