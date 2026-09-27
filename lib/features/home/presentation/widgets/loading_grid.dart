import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'update_card.dart';

/// Skeleton grid "Pembaruan Terbaru". Di folder yang sama dengan [UpdateCard]
/// karena ukurannya diambil dari sana; taruh di `core/widgets` berarti `core`
/// ikut bergantung ke `features`.
class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key, this.itemCount = 4});

  /// Genap supaya baris terisi penuh.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final dasar = gelap ? Colors.grey.shade800 : Colors.grey.shade300;
    final terang = gelap ? Colors.grey.shade700 : Colors.grey.shade100;

    final lebar = MediaQuery.sizeOf(context).width;
    final lebarSel = hitungLebarSel(lebar);
    final tinggi = hitungTinggiSel(lebar);
    final tinggiCover = lebarSel / rasioCoverUpdate;

    return Shimmer.fromColors(
      baseColor: dasar,
      highlightColor: terang,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: paddingHorizontalUpdate,
        ),
        child: Wrap(
          spacing: jarakAntarSelUpdate,
          runSpacing: 18,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(
                width: lebarSel,
                height: tinggi,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Blok(
                      width: lebarSel,
                      height: tinggiCover,
                      radius: 12,
                      color: dasar,
                    ),
                    const SizedBox(height: 10),
                    _Blok(width: lebarSel * 0.9, height: 13, color: dasar),
                    const SizedBox(height: 7),
                    _Blok(width: lebarSel * 0.6, height: 13, color: dasar),
                    const SizedBox(height: 12),
                    _Blok(
                      width: lebarSel,
                      height: tinggiChip,
                      radius: 8,
                      color: dasar,
                    ),
                    const SizedBox(height: jarakAntarChip),
                    _Blok(
                      width: lebarSel,
                      height: tinggiChip,
                      radius: 8,
                      color: dasar,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Blok extends StatelessWidget {
  const _Blok({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
