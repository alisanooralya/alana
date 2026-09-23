/// Formats ISO-8601 timestamps into compact relative labels.
library;

/// Returns a short relative time label for [isoDate] (`Now`, `5m`, `2H`,
/// `3D`, `1W`, `4M`, `1Y`). Returns an empty string when [isoDate] is null,
/// empty or cannot be parsed.
String formatRelativeTime(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';

  try {
    final date = DateTime.parse(isoDate).toLocal();
    final diff = DateTime.now().difference(date);

    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;

    if (minutes < 1) {
      return 'Now';
    } else if (hours < 1) {
      return '${minutes}m';
    } else if (days < 1) {
      return '${hours}H';
    } else if (days < 7) {
      return '${days}D';
    } else if (days < 30) {
      return '${(days / 7).floor()}W';
    } else if (days < 365) {
      return '${(days / 30).floor()}M';
    } else {
      return '${(days / 365).floor()}Y';
    }
  } on FormatException {
    return '';
  }
}
