import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar profil: foto ber-cache, fallback inisial nama.
///
/// `cacheKey` mengikuti URL — karena URL avatar berversi
/// (`?v=timestamp`), foto baru otomatis tampil segar.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.inisial,
    this.radius = 40,
  });

  final String avatarUrl;
  final String inisial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          inisial,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: avatarUrl,
      imageBuilder: (context, provider) => CircleAvatar(
        radius: radius,
        backgroundImage: provider,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surfaceContainerHighest,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          inisial,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
