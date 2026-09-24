import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync_providers.dart';

/// Indikator kecil bila ada data menunggu sinkron.
///
/// Tidak memblokir UI; hilang sendiri setelah terdorong.
class PendingBar extends ConsumerWidget {
  const PendingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlah = ref.watch(pendingSyncProvider);
    if (jumlah <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menunggu sinkron ($jumlah). Tetap bisa dipakai offline.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
