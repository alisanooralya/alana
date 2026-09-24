import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/router/app_router.dart';
import 'package:alana/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ManhwaApp()));
}

/// Root aplikasi pembaca manhwa.
class ManhwaApp extends ConsumerWidget {
  const ManhwaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Alana - Baca Manhwa',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Mengikuti pengaturan sistem (terang/gelap).
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
