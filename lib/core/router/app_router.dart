import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/about/presentation/about_page.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/forgot_password_page.dart';
import 'package:alana/features/auth/presentation/login_page.dart';
import 'package:alana/features/auth/presentation/register_page.dart';
import 'package:alana/features/auth/presentation/verify_email_page.dart';
import 'package:alana/features/detail/presentation/detail_page.dart';
import 'package:alana/features/downloads/presentation/downloads_page.dart';
import 'package:alana/features/history/presentation/history_page.dart';
import 'package:alana/features/home/presentation/home_page.dart';
import 'package:alana/features/home/presentation/jelajah_page.dart';
import 'package:alana/features/home/presentation/search_page.dart';
import 'package:alana/features/library/presentation/library_page.dart';
import 'package:alana/features/notifikasi/presentation/notification_list_page.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';
import 'package:alana/features/onboarding/presentation/onboarding_page.dart';
import 'package:alana/features/profile/presentation/edit_profile_page.dart';
import 'package:alana/features/profile/presentation/profile_page.dart';
import 'package:alana/features/profile/presentation/security_page.dart';
import 'package:alana/features/reader/presentation/reader_page.dart';
import 'package:alana/features/settings/presentation/diagnostics_page.dart';
import 'package:alana/features/settings/presentation/settings_page.dart';
import 'package:alana/features/splash/presentation/splash_page.dart';
import 'package:alana/features/splash/presentation/splash_providers.dart';

import 'auth_refresh.dart';
import 'scaffold_with_nav.dart';
import 'transisi.dart';

String? _targetDeepLink(GoRouterState state) {
  return internalLocationFromDeepLink(state.uri.toString());
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final sesiAsync = ref.watch(sesiProvider);
  final pendatangBaru = ref.watch(pendingUsernameSetupProvider);
  final sudahLihat = ref.watch(sudahOnboardingProvider);
  final splashSiap = ref.watch(splashSiapProvider);
  final refresh = GoRouterRefreshStream(
    SupabaseSetup.siap
        ? ref.watch(authRepositoryProvider).perubahanSesi
        : const Stream.empty(),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final lokasi = state.matchedLocation;
      final customTarget = _targetDeepLink(state);
      final target =
          customTarget ??
          (lokasi.startsWith('/detail/') || lokasi.startsWith('/baca/')
              ? lokasi
              : null);
      if (target != null) DeepLinkIntent.simpan(target);
      const rutePublik = {
        '/splash',
        '/onboarding',
        '/masuk',
        '/daftar',
        '/lupa-password',
        '/verifikasi-email',
      };
      if (sesiAsync.isLoading || !splashSiap) {
        return lokasi == '/splash' ? null : '/splash';
      }
      final sesi =
          sesiAsync.valueOrNull?.session ??
          (SupabaseSetup.siap
              ? SupabaseSetup.instance.auth.currentSession
              : null);
      final masuk = sesi != null;
      if (!sudahLihat) {
        return lokasi == '/onboarding' ? null : '/onboarding';
      }
      if (masuk && customTarget != null) {
        if (pendatangBaru) return '/profil/ubah?baru=1';
        DeepLinkIntent.ambil();
        return customTarget;
      }
      if (!masuk && !rutePublik.contains(lokasi)) return '/masuk';
      if (masuk && pendatangBaru && lokasi != '/profil/ubah') {
        return '/profil/ubah?baru=1';
      }
      if (masuk && (lokasi == '/masuk' || lokasi == '/daftar')) {
        return DeepLinkIntent.ambil() ?? '/';
      }
      if (masuk &&
          (lokasi == '/splash' ||
              lokasi == '/onboarding' ||
              lokasi == '/lupa-password' ||
              lokasi == '/verifikasi-email')) {
        return DeepLinkIntent.ambil() ?? '/';
      }
      if (masuk && lokasi == '/profil/ubah') {
        return DeepLinkIntent.ambil();
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) =>
            Transisi.fade(key: state.pageKey, child: const SplashPage()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) =>
            Transisi.fade(key: state.pageKey, child: const OnboardingPage()),
      ),
      GoRoute(
        path: '/masuk',
        name: 'masuk',
        pageBuilder: (context, state) =>
            Transisi.sumbu(key: state.pageKey, child: const LoginPage()),
      ),
      GoRoute(
        path: '/daftar',
        name: 'daftar',
        pageBuilder: (context, state) => Transisi.sumbu(
          key: state.pageKey,
          child: const RegisterPage(),
          tipe: SharedAxisTransitionType.vertical,
        ),
      ),
      GoRoute(
        path: '/lupa-password',
        name: 'lupa-password',
        pageBuilder: (context, state) => Transisi.fade(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/verifikasi-email',
        name: 'verifikasi-email',
        pageBuilder: (context, state) => Transisi.fade(
          key: state.pageKey,
          child: VerifyEmailPage(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => Transisi.lubang(
          key: state.pageKey,
          child: ScaffoldWithNavBar(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'beranda',
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'jelajah',
                    name: 'jelajah',
                    builder: (context, state) => const JelajahPage(),
                  ),
                  GoRoute(
                    path: 'cari',
                    name: 'pencarian',
                    builder: (context, state) => const SearchPage(),
                  ),
                  GoRoute(
                    path: 'notifikasi',
                    name: 'notifikasi',
                    builder: (context, state) => const NotificationListPage(),
                  ),
                  GoRoute(
                    path: 'detail/:mangaId',
                    name: 'detail',
                    builder: (context, state) => DetailPage(
                      mangaId: state.pathParameters['mangaId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'baca/:mangaId/:chapterId',
                    name: 'reader',
                    builder: (context, state) {
                      final extra = state.extra;
                      final args = extra is Map<String, dynamic>
                          ? extra
                          : const <String, dynamic>{};
                      return ReaderPage(
                        mangaId: state.pathParameters['mangaId'] ?? '',
                        chapterId: state.pathParameters['chapterId'] ?? '',
                        chapterName: args['chapterName']?.toString() ?? '',
                        mangaTitle: args['mangaTitle']?.toString() ?? '',
                        mangaThumbnail:
                            args['mangaThumbnail']?.toString() ?? '',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pustaka',
                name: 'pustaka',
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/riwayat',
                name: 'riwayat',
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profil',
                name: 'profil',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'ubah',
                    name: 'ubah-profil',
                    builder: (context, state) => EditProfilePage(
                      baru: state.uri.queryParameters['baru'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: 'tentang-aplikasi',
                    name: 'tentang-aplikasi',
                    builder: (context, state) => const AboutPage(),
                  ),
                  GoRoute(
                    path: 'unduhan',
                    name: 'unduhan',
                    builder: (context, state) => const DownloadsPage(),
                  ),
                  GoRoute(
                    path: 'keamanan',
                    name: 'keamanan',
                    builder: (context, state) => const SecurityPage(),
                  ),
                  GoRoute(
                    path: 'pengaturan',
                    name: 'pengaturan',
                    builder: (context, state) => const SettingsPage(),
                    routes: [
                      GoRoute(
                        path: 'diagnostik',
                        name: 'diagnostik',
                        builder: (context, state) => const DiagnosticsPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/:mangaId',
        name: 'deep-link-manga',
        builder: (context, state) =>
            DetailPage(mangaId: state.pathParameters['mangaId'] ?? ''),
      ),
      GoRoute(
        path: '/:mangaId/chapter/:chapterId',
        name: 'deep-link-chapter',
        builder: (context, state) => ReaderPage(
          mangaId: state.pathParameters['mangaId'] ?? '',
          chapterId: state.pathParameters['chapterId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/:mangaId/:chapterId',
        name: 'deep-link-chapter-host',
        builder: (context, state) => ReaderPage(
          mangaId: state.pathParameters['mangaId'] ?? '',
          chapterId: state.pathParameters['chapterId'] ?? '',
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(child: Text('Rute ${state.uri} tidak tersedia.')),
    ),
  );
});
