// Diadaptasi dari mangayomi (https://github.com/kodjodevf/mangayomi)
// Lisensi asal: Apache-2.0 — Copyright 2023 Moustapha Kodjo Amadou
// Disederhanakan: tanpa dependency Isar/Riverpod, memakai Theme.of(context)
// langsung alih-alih extension khusus mangayomi.

import 'package:flutter/material.dart';

/// Widget dasar untuk menampilkan satu "kartu" cover (manga/comic/dll)
/// dengan layer tambahan di atasnya (badge, overlay teks, dsb lewat [children]
/// dan [bottomTextWidget]).
class CoverViewWidget extends StatelessWidget {
  /// Widget tambahan yang ditumpuk di atas cover (badge unread, dsb).
  final List<Widget> children;

  /// Tampilkan highlight saat item sedang di-long-press (mode seleksi).
  final bool isLongPressed;

  /// Gambar cover. Jika null, area cover akan kosong (placeholder color).
  final ImageProvider? image;

  /// Mode grid "comfortable": judul ditaruh di bawah cover (bukan overlay).
  final bool isComfortableGrid;

  /// Widget judul/teks di bagian bawah card.
  final Widget? bottomTextWidget;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const CoverViewWidget({
    super.key,
    this.children = const [],
    this.isComfortableGrid = false,
    this.bottomTextWidget,
    required this.onTap,
    this.image,
    this.onLongPress,
    this.isLongPressed = false,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Expanded(
            child: Material(
              borderRadius: BorderRadius.circular(5),
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                onSecondaryTap: onSecondaryTap,
                child: Container(
                  color: isLongPressed
                      ? primaryColor.withValues(alpha: 0.4)
                      : Colors.transparent,
                  child: image == null
                      ? (isComfortableGrid
                            ? Column(
                                children: [
                                  ...children,
                                  if (bottomTextWidget != null)
                                    bottomTextWidget!,
                                ],
                              )
                            : Stack(children: children))
                      : Ink.image(
                          fit: BoxFit.cover,
                          image: image!,
                          child: Stack(children: children),
                        ),
                ),
              ),
            ),
          ),
          if (isComfortableGrid && bottomTextWidget != null) bottomTextWidget!,
        ],
      ),
    );
  }
}
