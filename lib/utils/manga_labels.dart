/// Display labels for raw values coming from the manga API.
library;

/// Maps an API status code (1/2/3) to a readable label.
String mangaStatusLabel(dynamic statusCode) {
  if (statusCode == 1) return 'Ongoing';
  if (statusCode == 2) return 'Completed';
  if (statusCode == 3) return 'Hiatus';
  return '';
}

/// Maps an API country code (KR/CN/EN/JP) to a readable label.
String countryLabel(String? countryId) {
  switch ((countryId ?? '').toUpperCase()) {
    case 'KR':
      return 'Korea';
    case 'CN':
      return 'China';
    case 'EN':
      return 'English';
    case 'JP':
      return 'Japan';
    default:
      return countryId ?? '';
  }
}
