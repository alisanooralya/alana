/// Satu baris tabel `profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  /// Inisial untuk fallback avatar (1–2 huruf pertama).
  String get inisial {
    final bersih = displayName.isNotEmpty ? displayName : username;
    final kata = bersih
        .split(RegExp(r'\s+'))
        .where((bagian) => bagian.isNotEmpty)
        .toList();
    if (kata.isEmpty) return '?';
    if (kata.length == 1) return _huruf(kata.first, 2);
    return _huruf(kata.first, 1) + _huruf(kata.last, 1);
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString() ?? '',
    );
  }
}

/// [jumlah] rune pertama [teks], kapital.
String _huruf(String teks, int jumlah) {
  final runes = teks.runes.take(jumlah).toList();
  if (runes.isEmpty) return '?';
  return String.fromCharCodes(runes).toUpperCase();
}
