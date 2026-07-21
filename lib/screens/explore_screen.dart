import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';
import 'package:alana/services/manga_api.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

enum _ViewMode { grid, list }

class _ExploreScreenState extends State<ExploreScreen> {
  final MangaApiService _service = MangaApiService();
  final TextEditingController _searchController = TextEditingController();

  _ViewMode _mode = _ViewMode.grid;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.withValues(alpha: 0.1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadMangas(query: _searchController.text.trim()),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _ExploreToolbar(
                    mode: _mode,
                    searchController: _searchController,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onFilterTap: () {
                      // TODO: buka filter drawer di sini nanti
                    },
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
              else if (_mode == _ViewMode.grid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final manga = _mangas[index];
                        return _ExploreGridCard(
                          manga: manga,
                          onTap: () {
                            // TODO: navigasi ke halaman detail manga
                          },
                        );
                      },
                      childCount: _mangas.length,
                    ),
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

class _ExploreToolbar extends StatelessWidget {
  final _ViewMode mode;
  final TextEditingController searchController;
  final void Function(_ViewMode mode) onModeChanged;
  final VoidCallback onFilterTap;
  final void Function(String value) onSearchSubmitted;

  const _ExploreToolbar({
    required this.mode,
    required this.searchController,
    required this.onModeChanged,
    required this.onFilterTap,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToolbarIconButton(
          icon: Icons.grid_view_rounded,
          isActive: mode == _ViewMode.grid,
          onTap: () => onModeChanged(_ViewMode.grid),
        ),
        const SizedBox(width: 8),
        _ToolbarIconButton(
          icon: Icons.view_agenda_outlined,
          isActive: mode == _ViewMode.list,
          onTap: () => onModeChanged(_ViewMode.list),
        ),
        const SizedBox(width: 8),
        _ToolbarIconButton(
          icon: Icons.tune_rounded,
          isActive: false,
          onTap: onFilterTap,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onSubmitted: onSearchSubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search anything',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _ExploreGridCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback? onTap;

  const _ExploreGridCard({required this.manga, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                manga.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey.shade500,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
