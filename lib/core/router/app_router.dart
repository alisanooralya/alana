import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/about/presentation/about_page.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';
import 'package:alana/features/auth/presentation/forgot_password_page.dart';
import 'package:alana/features/auth/presentation/login_page.dart';
import 'package:alana/features/auth/presentation/register_page.dart';
import 'package:alana/features/auth/presentation/reset_password_page.dart';
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

/// Halaman detail/reader: satu-satunya lokasi yang layak "dikembalikan"
/// ke user setelah ia sempat terlempar ke halaman login.
bool _detailAtauReader(String lokasi) {
  return lokasi.startsWith('/detail/') || lokasi.startsWith('/baca/');
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Sesi, kesiapan splash, status onboarding, dan permintaan setup username
  // dibaca di dalam redirect, bukan di-watch di sini. Kalau di-watch, setiap
  // perubahan status membuat GoRouter baru yang membaca ulang
  // initialLocation '/', sehingga navigator ikut diganti: user yang sedang
  // membaca chapter 40 terlempar ke Beranda, stack navigasi hilang, dan
  // extra halaman (judul chapter, sampul) ikut hilang.
  final refresh = GoRouterRefresh([ref.watch(streamSesiProvider)]);
  ref.onDispose(refresh.dispose);

  void pemicu() => refresh.pemicu();
  ref.listen(splashSiapProvider, (previous, next) => pemicu());
  ref.listen(pendingUsernameSetupProvider, (previous, next) => pemicu());
  ref.listen(sudahOnboardingProvider, (previous, next) => pemicu());
  ref.listen(passwordRecoveryProvider, (previous, next) => pemicu());

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final sesiAsync = ref.read(sesiProvider);
      final splashSiap = ref.read(splashSiapProvider);
      final sudahLihat = ref.read(sudahOnboardingProvider);
      final pendatangBaru = ref.read(pendingUsernameSetupProvider);
      final recovery = ref.read(passwordRecoveryProvider);
      final lokasi = state.matchedLocation;
      final customTarget = _targetDeepLink(state);
      const rutePublik = {
        '/splash',
        '/onboarding',
        '/masuk',
        '/daftar',
        '/lupa-password',
        '/verifikasi-email',
        resetPasswordLokasi,
      };
      if (sesiAsync.isLoading || !splashSiap) {
        return lokasi == '/splash' ? null : '/splash';
      }
      // Sesi recovery hanya boleh dipakai untuk mengganti password. Tanpa
      // kunci ini user yang salah menekan tautan bisa menjelajah aplikasi
      // dengan sesi yang token refresh-nya masih valid.
      if (recovery && lokasi != resetPasswordLokasi) {
        return resetPasswordLokasi;
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
      if (masuk && !recovery && customTarget != null) {
        if (pendatangBaru) return '/profil/ubah?baru=1';
        DeepLinkIntent.buang();
        return customTarget;
      }
      if (!masuk && !rutePublik.contains(lokasi)) {
        // Hanya saat user benar-benar terlempar ke login yang lokasi
        // lamanya disimpan, bukan setiap kali redirect berjalan.
        final kembali =
            customTarget ?? (_detailAtauReader(lokasi) ? lokasi : null);
        if (kembali != null) DeepLinkIntent.simpan(kembali);
        return '/masuk';
      }
      if (masuk && !recovery && pendatangBaru && lokasi != '/profil/ubah') {
        // '/profil' dikecualikan supaya user bisa membuka halaman Profil dan
        // memakai tombol Keluar. Mengunci semua lokasi membuat halaman Edit
        // Profil jadi perangkap: menekan back hanya memantulkan user ke sini.
        return lokasi == '/profil' ? null : '/profil/ubah?baru=1';
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
        // Buang sisa target; jangan pernah mengarahkan halaman ini ke
        // deep link lama.
        DeepLinkIntent.buang();
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
      GoRoute(
        path: resetPasswordLokasi,
        name: 'reset-password',
        pageBuilder: (context, state) =>
            Transisi.fade(key: state.pageKey, child: const ResetPasswordPage()),
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
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/jelajah',
        name: 'jelajah',
        builder: (context, state) => const JelajahPage(),
      ),
      GoRoute(
        path: '/cari',
        name: 'pencarian',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/notifikasi',
        name: 'notifikasi',
        builder: (context, state) => const NotificationListPage(),
      ),
      GoRoute(
        path: '/detail/:mangaId',
        name: 'detail',
        builder: (context, state) =>
            DetailPage(mangaId: state.pathParameters['mangaId'] ?? ''),
      ),
      GoRoute(
        path: '/baca/:mangaId/:chapterId',
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
            mangaThumbnail: args['mangaThumbnail']?.toString() ?? '',
          );
        },
      ),
      GoRoute(
        path: '/profil/ubah',
        name: 'ubah-profil',
        builder: (context, state) =>
            EditProfilePage(baru: state.uri.queryParameters['baru'] == '1'),
      ),
      GoRoute(
        path: '/profil/tentang-aplikasi',
        name: 'tentang-aplikasi',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/profil/unduhan',
        name: 'unduhan',
        builder: (context, state) => const DownloadsPage(),
      ),
      GoRoute(
        path: '/profil/keamanan',
        name: 'keamanan',
        builder: (context, state) => const SecurityPage(),
      ),
      GoRoute(
        path: '/profil/pengaturan',
        name: 'pengaturan',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/profil/pengaturan/diagnostik',
        name: 'diagnostik',
        builder: (context, state) => const DiagnosticsPage(),
      ),
    ],
    // Tidak ada lagi route '/:mangaId' dan '/:mangaId/:chapterId'.
    // Keduanya menangkap semua path satu atau dua segmen yang tidak dikenal,
    // sehingga errorBuilder di bawah tidak mungkin terpakai: '/halamn-salah'
    // membuka DetailPage dengan id-ngawur dan berakhir di "Gagal memuat"
    // alih-alih halaman 404. Deep link tidak membutuhkannya karena
    // internalLocationFromDeepLink sudah mengubah alana://manga/<id> menjadi
    // /detail/<id> sebelum router menyentuh uri.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(child: Text('Rute ${state.uri} tidak tersedia.')),
    ),
  );
  // GoRouter menyimpan routeInformationProvider yang berupa WidgetsBindingObserver
  // dan routerDelegate; keduanya harus dilepas saat provider di-dispose.
  ref.onDispose(router.dispose);
  return router;
});
