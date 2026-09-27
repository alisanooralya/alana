/// Mengubah stempel waktu ISO-8601 menjadi label relatif: `Baru`, `5 m`,
/// `2 jam`, `Kemarin`, `3 hari lalu`, `1 minggu lalu`, `1 tahun lalu`.
/// String kosong bila [isoDate] null, kosong, atau tidak bisa diurai.
String formatRelativeTime(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';

  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';

  // Negatif berarti jam perangkat lebih maju dari server. Sebelumnya jatuh ke
  // cabang "kurang dari semenit" dan tampilannya jadi "Now lalu".
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.isNegative) return 'Baru';

  final minutes = diff.inMinutes;
  final days = diff.inDays;

  if (minutes < 1) {
    return 'Baru';
  } else if (minutes < 60) {
    return '$minutes m';
  } else if (days < 1) {
    // Bulat ke bawah supaya 23 jam 59 menit tidak melompati "Kemarin".
    return '${(minutes / 60).floor()} jam';
  } else if (days == 1) {
    return 'Kemarin';
  } else if (days < 7) {
    return '$days hari lalu';
  } else if (days < 30) {
    return '${(days / 7).floor()} minggu lalu';
  } else if (days < 365) {
    return '${(days / 30).floor()} bulan lalu';
  }
  return '${(days / 365).floor()} tahun lalu';
}

/// Versi ringkas tanpa kata "lalu": `2 jam`, `3 hari`, `1 minggu`. Dipakai di
/// chip chapter yang sempit dan konteksnya sudah jelas.
///
/// Dihasilkan dari [formatRelativeTime] supaya satu timestamp tidak pernah
/// tampil dengan dua bentuk berbeda di dua layar berbeda.
String formatRelativeTimePendek(String? isoDate) {
  return formatRelativeTime(isoDate).replaceFirst(RegExp(r'\s+lalu$'), '');
}
