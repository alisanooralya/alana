import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/widgets/empty_view.dart';
import 'package:alana/core/widgets/error_view.dart';
import 'package:alana/core/widgets/loading_view.dart';
import 'package:alana/models/manga.dart';

import 'home_providers.dart';

/// Halaman Beranda.
///
/// Fondasi Fase 1: menampilkan daftar populer harian dengan
/// status memuat, gagal, dan kosong. Carousel, pagination,
/// dan pencarian menyusul di Fase 2.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularMangaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: popular.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          pesan: 'Gagal memuat daftar populer. ${error.toString()}',
          onRetry: () => ref.invalidate(popularMangaProvider),
        ),
        data: (response) {
          if (response.mangas.isEmpty) {
            return EmptyView(
              judul: 'Belum ada judul populer',
              deskripsi: 'Coba lagi nanti atau tarik untuk memuat ulang.',
              labelAksi: 'Muat ulang',
              onAksi: () => ref.invalidate(popularMangaProvider),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(popularMangaProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: response.mangas.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _PopularItem(manga: response.mangas[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PopularItem extends StatelessWidget {
  const _PopularItem({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: manga.thumbnail.isEmpty
            ? const Icon(Icons.image_not_supported_outlined, size: 48)
            : Image.network(
                manga.thumbnail,
                width: 56,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image_outlined, size: 48);
                },
              ),
        title: Text(manga.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          manga.status.isEmpty ? 'Status tidak diketahui' : manga.status,
        ),
        // Detail dan reader menyusul di Fase 3-4.
        onTap: null,
      ),
    );
  }
}
