class Page {
  final int index;
  final String imageUrl;

  /// Lebar dibagi tinggi, atau `null` kalau belum diketahui.
  ///
  /// API `/v1/chapter/detail/{id}` mengirim daftar halaman sebagai array of
  /// string nama berkas dan **tidak** memuat dimensi, jadi pada praktiknya
  /// field ini selalu `null` dari jaringan. Ia tetap ada supaya begini:
  ///
  ///   1. bila backend suatu saat menambah `width`/`height`, halaman langsung
  ///      punya tinggi terkunci sejak frame pertama tanpa probe sama sekali;
  ///   2. `ReaderRatioController` bisa menulisnya; dan
  ///   3. ada tempat yang jelas untuk menyimpan rasio bersama `Page`, bukan
  ///      tersebar di widget.
  final double? aspectRatio;

  const Page({required this.index, required this.imageUrl, this.aspectRatio});

  Page copyWith({double? aspectRatio}) {
    return Page(
      index: index,
      imageUrl: imageUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}
