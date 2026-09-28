import 'package:flutter/material.dart';

import 'popular_carousel.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.judul,
    required this.children,
    this.tinggi = 260,
  });

  final String judul;

  final List<Widget> children;

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
