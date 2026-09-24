import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/features/detail/presentation/detail_page.dart';
import 'package:alana/features/history/presentation/history_page.dart';
import 'package:alana/features/home/presentation/home_page.dart';
import 'package:alana/features/home/presentation/search_page.dart';
import 'package:alana/features/library/presentation/library_page.dart';
import 'package:alana/features/reader/presentation/reader_page.dart';

import 'scaffold_with_nav.dart';

/// Router aplikasi. Disediakan lewat Riverpod agar mudah diuji
/// dan di-watch dari [MaterialApp.router].
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(child: Text('Rute ${state.uri} tidak tersedia.')),
    ),
  );
});
