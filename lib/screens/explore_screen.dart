import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';
import 'package:alana/services/manga_api.dart';
import 'package:alana/widgets/explore_grid_card.dart';
import 'package:alana/widgets/explore_toolbar.dart';
import 'package:alana/widgets/explore_filter_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MangaApiService _service = MangaApiService();
  final TextEditingController _searchController = TextEditingController();

  ExploreViewMode _mode = ExploreViewMode.grid;
  ExploreFilterResult _activeFilter = const ExploreFilterResult();

  List<Manga> _mangas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMangas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMangas({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: kalau searchManga sudah support parameter genre/format/status,
      // kirim _activeFilter di sini juga. Untuk sekarang query text saja.
      final result = await _service.searchManga(query);
      setState(() {
        _mangas = result.mangas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmitted(String value) {
    _loadMangas(query: value.trim());
  }

  Future<void> _onFilterTap() async {
    final result = await showExploreFilterSheet(
      context,
      initialValue: _activeFilter,
    );

    if (result == null) return;

    setState(() => _activeFilter = result);
    _loadMangas(query: _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadMangas(query: _searchController.text.trim()),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ExploreToolbar(
                    mode: _mode,
                    searchController: _searchController,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onFilterTap: _onFilterTap,
                    onSearchSubmitted: _onSearchSubmitted,
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Gagal memuat: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                )
              else if (_mangas.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Tidak ada hasil')),
                )
              else if (_mode == ExploreViewMode.grid)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final manga = _mangas[index];
                      return ExploreGridCard(
                        manga: manga,
                        onTap: () {
                          // TODO: navigasi ke halaman detail manga
                        },
                      );
                    }, childCount: _mangas.length),
                  ),
                )
              else
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Mode list segera hadir',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
