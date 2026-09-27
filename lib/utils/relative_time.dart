/// Mengubah stempel waktu ISO-8601 menjadi label waktu relatif singkat.
///
/// Label memakai Bahasa Indonesia: `Baru`, `5 m`, `2 j`, `3 h`, `Kemarin`,
/// `1 minggu`, `4 bulan`, `1 tahun`. String kosong bila [isoDate] null, kosong,
/// atau tidak bisa diurai.
String formatRelativeTime(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';

  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';

  // Selisih negatif berarti jam perangkat lebih maju daripada jam server.
  // Sebelumnya itu jatuh ke cabang "kurang dari semenit" sehingga notifikasi
  // tampil bertulis "Now lalu", yang tidak masuk akal dalam bahasa Indonesia.
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.isNegative) return 'Baru';

  final minutes = diff.inMinutes;
  final days = diff.inDays;

  if (minutes < 1) {
    return 'Baru';
  } else if (minutes < 60) {
    return '$minutes m';
  } else if (days < 1) {
    return '${diff.inMinutes} mnt';
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
