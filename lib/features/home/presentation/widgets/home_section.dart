import 'package:flutter/material.dart';

/// Kepala section Beranda: judul + slot daftar horizontal di bawahnya.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.judul,
    required this.children,
    this.tinggi = 230,
  });

  /// Judul section, mis. 'Populer Hari Ini'.
  final String judul;

  /// Daftar kartu horizontal.
  final List<Widget> children;

  /// Tinggi area horizontal.
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(judul, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: tinggi,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }
}
