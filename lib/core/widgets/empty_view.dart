import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.judul,
    this.deskripsi,
    this.ikon = Icons.inbox_outlined,
    this.labelAksi,
    this.onAksi,
  });

  final String judul;

  final String? deskripsi;

  final IconData ikon;

  final String? labelAksi;

  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            if (deskripsi != null) ...[
              const SizedBox(height: 8),
              Text(
                deskripsi!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (labelAksi != null && onAksi != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAksi, child: Text(labelAksi!)),
            ],
          ],
        ),
      ),
    );
  }
}
