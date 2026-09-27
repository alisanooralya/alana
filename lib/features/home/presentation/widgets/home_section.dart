import 'package:flutter/material.dart';

import 'popular_carousel.dart';

/// Kepala section + daftar kartu horizontal. Memakai [KepalaSection] yang
/// sama dengan section lain supaya posisinya konsisten.
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

  /// Harus cukup untuk cover (lebar * 4/3) + teks. Pada lebar bawaan 130
  /// itu 173 + 78 = 251, jadi 260 memberi ruang tanpa terlalu tinggi.
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
