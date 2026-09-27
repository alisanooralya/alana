/// Display labels for raw values coming from the manga API.
library;

/// Maps an API status code (1/2/3) to a readable label.
String mangaStatusLabel(dynamic statusCode) {
  // API ini bertipe longgar: json_utils menyediakan asInt/asNum justru karena
  // angka kadang datang sebagai string. Versi lama hanya membandingkan dengan
  // int, sehingga "1" menghasilkan label kosong dan baris status tampil
  // tanpa tulisan sama sekali.
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
