import 'package:flutter/material.dart';

import 'popular_carousel.dart';

/// Kepala section + daftar kartu horizontal di bawahnya.
///
/// Kepala section dipakai ulang dari [KepalaSection] supaya jarak antara
/// judul dan isinya sama persis di semua section Beranda.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.judul,
    required this.children,
    this.tinggi = 260,
  });

  /// Judul section, mis. 'Rekomendasi'.
  final String judul;

  /// Daftar kartu horizontal.
  final List<Widget> children;

  /// Tinggi area horizontal.
  ///
  /// Harus cukup untuk tinggi cover (lebar * 4/3) ditambah blok teks
  /// MangaCard. Pada lebar bawaan 130 itu 173 + 78 = 251, jadi 260 memberi
  /// ruang tanpa membuat area terlalu tinggi di layar kecil.
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KepalaSection(judul: judul),
        SizedBox(
          height: tinggi,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }
}
