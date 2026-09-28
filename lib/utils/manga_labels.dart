library;

String mangaStatusLabel(dynamic statusCode) {
  final kode = switch (statusCode) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v.trim()),
    _ => null,
  };
  return switch (kode) {
    1 => 'On Going',
    2 => 'Selesai',
    3 => 'Hiatus',
    _ => '',
  };
}

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
