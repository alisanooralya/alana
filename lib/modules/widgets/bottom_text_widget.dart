// Diadaptasi dari mangayomi (https://github.com/kodjodevf/mangayomi)
// Lisensi asal: Apache-2.0 — Copyright 2023 Moustapha Kodjo Amadou

import 'package:flutter/material.dart';

/// Teks judul yang ditampilkan di bawah/atas cover.
///
/// - Saat [isComfortableGrid] true -> teks polos di bawah cover (mode "Comfortable").
/// - Saat false -> teks overlay dengan gradient gelap di atas gambar (mode "Compact").
class BottomTextWidget extends StatelessWidget {
  final String text;
  final bool isComfortableGrid;
  final double fontSize;
  final int maxLines;
  final Color? textColor;

  const BottomTextWidget({
    super.key,
    required this.text,
    this.isComfortableGrid = false,
    this.fontSize = 12.0,
    this.maxLines = 2,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isComfortableGrid) {
      return Padding(
        padding: const EdgeInsets.only(left: 5, top: 4, bottom: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor ?? Theme.of(context).textTheme.bodyMedium?.color,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      );
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(6, 24, 6, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.0,
            color: textColor ?? Colors.white,
            shadows: const [Shadow(offset: Offset(0.5, 0.9), blurRadius: 3.0)],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}
