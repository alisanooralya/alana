import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/core/router/app_router.dart';
import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/theme/app_theme.dart';
import 'package:alana/features/settings/data/app_settings.dart';
import 'package:alana/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLog.pasang();
  runApp(const ProviderScope(child: Bootstrap()));
}

enum _StatusSiap { memuat, siap }

/// Gerbang startup: menampilkan layar muat, menyiapkan penyimpanan
/// di latar, lalu membuka aplikasi. Penyimpanan yang gagal TIDAK
/// menggagalkan startup — repository berjalan dalam mode memori.
class Bootstrap extends ConsumerStatefulWidget {
  const Bootstrap({super.key});

  @override
  ConsumerState<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<Bootstrap> {
  var _status = _StatusSiap.memuat;

  @override
  void initState() {
    super.initState();
    AppStorage.init().then((_) {
      if (mounted) setState(() => _status = _StatusSiap.siap);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _StatusSiap.memuat) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const _LayarMuat(),
      );
    }
    return const ManhwaApp();
  }
}

class _LayarMuat extends StatelessWidget {
  const _LayarMuat();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alana',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Memuat…',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Root aplikasi pembaca manhwa.
class ManhwaApp extends ConsumerWidget {
  const ManhwaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final tema = ref.watch(
      settingsRepositoryProvider.select((pengaturan) => pengaturan.themeMode),
    );

    return MaterialApp.router(
      title: 'Alana - Baca Manhwa',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: switch (tema) {
        AppThemeMode.sistem => ThemeMode.system,
        AppThemeMode.terang => ThemeMode.light,
        AppThemeMode.gelap => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
