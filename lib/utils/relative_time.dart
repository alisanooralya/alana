String formatRelativeTime(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';

  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';

  final diff = DateTime.now().difference(date.toLocal());
  if (diff.isNegative) return 'Baru';

  final minutes = diff.inMinutes;
  final days = diff.inDays;

  if (minutes < 1) {
    return 'Baru';
  } else if (minutes < 60) {
    return '$minutes m';
  } else if (days < 1) {
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

String formatRelativeTimePendek(String? isoDate) {
  return formatRelativeTime(isoDate).replaceFirst(RegExp(r'\s+lalu$'), '');
}
