import 'package:flutter/material.dart';

/// Header umum dipakai di banyak tab (Library, Explore, Home, History),
/// kecuali Profile. Berisi judul "Alana" (huruf "A" diberi warna beda)
/// dan dua action icon di kanan: search & notifikasi.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Dipanggil saat icon search ditekan.
  final VoidCallback? onSearchTap;

  /// Dipanggil saat icon bell ditekan.
  final VoidCallback? onNotificationTap;

  /// Tampilkan titik merah kecil di icon bell (mis. ada notif baru).
  final bool hasUnreadNotification;

  /// Warna untuk huruf "A". Default pakai warna primary tema.
  final Color? accentColor;

  const AppHeader({
    super.key,
    this.onSearchTap,
    this.onNotificationTap,
    this.hasUnreadNotification = false,
    this.accentColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aColor = accentColor ?? theme.colorScheme.primary;
    final textColor = theme.textTheme.titleLarge?.color;

    return AppBar(
      titleSpacing: 16,
      title: RichText(
        text: TextSpan(
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          children: [
            TextSpan(text: 'A', style: TextStyle(color: aColor)),
            const TextSpan(text: 'l'),
            TextSpan(text: 'a', style: TextStyle(color: aColor)),
            const TextSpan(text: 'n'),
            TextSpan(text: 'a', style: TextStyle(color: aColor)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchTap,
          tooltip: 'Cari',
        ),
        IconButton(
          icon: Badge(
            isLabelVisible: hasUnreadNotification,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: onNotificationTap,
          tooltip: 'Notifikasi',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
