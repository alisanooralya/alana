import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alana/core/diagnostics/error_log.dart';
import 'package:alana/core/notifikasi/layanan_notifikasi.dart';
import 'package:alana/core/providers/konektivitas_provider.dart';
import 'package:alana/core/router/app_router.dart';
import 'package:alana/core/storage/app_storage.dart';
import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/theme/app_theme.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/notifikasi/data/pengingat_repository.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';
import 'package:alana/features/profile/presentation/profile_providers.dart';
import 'package:alana/features/settings/data/app_settings.dart';
import 'package:alana/features/settings/data/settings_repository.dart';
import 'package:alana/features/sync/data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLog.pasang();
  // Flag onboarding dimuat sebelum runApp: tanpa kedip bagi pengguna lama.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const Bootstrap(),
    ),
  );
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
    // Supabase dulu (sesi menentukan rute awal), lalu Hive + notifikasi.
    // Keduanya gagal-aman: aplikasi tetap jalan.
    SupabaseSetup.init()
        .then((_) => AppStorage.init())
        .then((_) => LayananNotifikasi.init())
        .then((_) {
          if (mounted) {
            setState(() => _status = _StatusSiap.siap);
            _jadwalkanPengingat();
          }
        });
  }

  /// Jadwalkan ulang pengingat tiap aplikasi dibuka (best-effort).
  Future<void> _jadwalkanPengingat() async {
    try {
      if (!ref.read(pengingatAktifProvider)) return;
      await ref
          .read(pengingatRepositoryProvider)
          .jadwalkanUlang(ref.read(userIdProvider));
    } catch (_) {
      // Abaikan: pengingat non-kritis.
    }
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

    // Orkestrasi sinkronisasi: login/logout dan koneksi kembali.
    // Semua fire-and-forget; UI tidak pernah menunggu jaringan.
    ref.listen(sesiProvider, (previous, next) {
      unawaited(
        ref
            .read(syncServiceProvider)
            .handleSesi(next.valueOrNull?.session?.user.id),
      );
    });
    ref.listen(luringProvider, (previous, next) {
      if (previous == true && next == false) {
        unawaited(ref.read(syncServiceProvider).flushTertunda());
      }
    });

    // Ketuk notifikasi → pindah rute (termasuk dari terminated).
    LayananNotifikasi.daftarkanNavigasi((lokasi) {
      try {
        ref.read(goRouterProvider).go(lokasi);
      } catch (_) {
        // Router belum siap; lokasi sudah ditampung layanan.
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lokasi = LayananNotifikasi.ambilTertunda();
      if (lokasi != null) {
        try {
          ref.read(goRouterProvider).go(lokasi);
        } catch (_) {
          // Abaikan.
        }
      }
    });

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
