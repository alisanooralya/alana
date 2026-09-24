import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/data/auth_repository.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/forgot_password_page.dart';
import 'package:alana/features/auth/presentation/login_page.dart';
import 'package:alana/features/auth/presentation/register_page.dart';
import 'package:alana/features/auth/presentation/verify_email_page.dart';
import 'package:alana/features/detail/presentation/detail_page.dart';
import 'package:alana/features/history/presentation/history_page.dart';
import 'package:alana/features/home/presentation/home_page.dart';
import 'package:alana/features/home/presentation/search_page.dart';
import 'package:alana/features/library/presentation/library_page.dart';
import 'package:alana/features/profile/presentation/edit_profile_page.dart';
import 'package:alana/features/profile/presentation/profile_page.dart';
import 'package:alana/features/profile/presentation/security_page.dart';
import 'package:alana/features/reader/presentation/reader_page.dart';
import 'package:alana/features/settings/presentation/diagnostics_page.dart';
import 'package:alana/features/settings/presentation/settings_page.dart';

import 'auth_refresh.dart';
import 'scaffold_with_nav.dart';

/// Router aplikasi. Disediakan lewat Riverpod agar mudah diuji
/// dan di-watch dari [MaterialApp.router].
///
/// Akses wajib login: pengunjung tanpa sesi diarahkan ke `/masuk`,
/// user yang sudah login tidak bisa membuka halaman auth.
final goRouterProvider = Provider<GoRouter>((ref) {
  final sesiAsync = ref.watch(sesiProvider);
  final pendatangBaru = ref.watch(pendingUsernameSetupProvider);
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
      const rutePublik = {
        '/masuk',
        '/daftar',
        '/lupa-password',
        '/verifikasi-email',
      };
      // Sesi belum diketahui → tahan di tempat (cegah kedip login).
      if (sesiAsync.isLoading) return null;
      final sesi =
          sesiAsync.valueOrNull?.session ??
          (SupabaseSetup.siap
              ? SupabaseSetup.instance.auth.currentSession
              : null);
      final masuk = sesi != null;
      if (!masuk && !rutePublik.contains(lokasi)) return '/masuk';
      if (masuk && (lokasi == '/masuk' || lokasi == '/daftar')) return '/';
      // User Google baru wajib memilih username sendiri dulu.
      if (masuk && pendatangBaru && lokasi != '/profil/ubah') {
        return '/profil/ubah?baru=1';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/masuk',
        name: 'masuk',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/daftar',
        name: 'daftar',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/lupa-password',
        name: 'lupa-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/verifikasi-email',
        name: 'verifikasi-email',
        builder: (context, state) =>
            VerifyEmailPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'beranda',
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'cari',
                    name: 'pencarian',
                    builder: (context, state) => const SearchPage(),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(child: Text('Rute ${state.uri} tidak tersedia.')),
    ),
  );
});
