import 'package:flutter/material.dart';

import 'package:alana/models/manga_types.dart';
import 'package:alana/services/manga_api.dart';

class ExploreFilterResult {
  final Set<String> genres;
  final Set<String> formats;
  final Set<String> statuses;

  const ExploreFilterResult({
    this.genres = const {},
    this.formats = const {},
    this.statuses = const {},
  });
}

Future<ExploreFilterResult?> showExploreFilterSheet(
  BuildContext context, {
  ExploreFilterResult? initialValue,
}) {
  return showModalBottomSheet<ExploreFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ExploreFilterSheet(initialValue: initialValue),
  );
}

class ExploreFilterSheet extends StatefulWidget {
  final ExploreFilterResult? initialValue;

  const ExploreFilterSheet({super.key, this.initialValue});

  static const List<String> formatOptions = ['Manga', 'Manhua', 'Manhwa'];
  static const List<String> statusOptions = ['Ongoing', 'Completed', 'Hiatus'];

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

enum _FilterSection { genre, format, status }

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  final MangaApiService _service = MangaApiService();

  _FilterSection? _expandedSection = _FilterSection.genre;

  final TextEditingController _genreSearchController = TextEditingController();
  String _genreQuery = '';

  late Set<String> _selectedGenres;
  late Set<String> _selectedFormats;
  late Set<String> _selectedStatuses;

  List<Genre> _genres = [];
  bool _isLoadingGenres = true;
  String? _genreErrorMessage;

  @override
  void initState() {
    super.initState();
    _selectedGenres = {...?widget.initialValue?.genres};
    _selectedFormats = {...?widget.initialValue?.formats};
    _selectedStatuses = {...?widget.initialValue?.statuses};

    _genreSearchController.addListener(() {
      setState(() => _genreQuery = _genreSearchController.text.trim());
    });

    _loadGenres();
  }

  Future<void> _loadGenres() async {
    setState(() {
      _isLoadingGenres = true;
      _genreErrorMessage = null;
    });

    try {
      final genres = await _service.getGenreList();
      setState(() {
        _genres = genres;
        _isLoadingGenres = false;
      });
    } catch (e) {
      setState(() {
        _genreErrorMessage = e.toString();
        _isLoadingGenres = false;
      });
    }
  }

  @override
  void dispose() {
    _genreSearchController.dispose();
    super.dispose();
  }

  void _toggleSection(_FilterSection section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
    });
  }

  void _toggleValue(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      ExploreFilterResult(
        genres: _selectedGenres,
        formats: _selectedFormats,
        statuses: _selectedStatuses,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGenres = _genreQuery.isEmpty
        ? _genres
        : _genres
            .where((g) =>
                g.name.toLowerCase().contains(_genreQuery.toLowerCase()))
            .toList();

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            _FilterSectionHeader(
              title: 'Genre',
              isExpanded: _expandedSection == _FilterSection.genre,
              onTap: () => _toggleSection(_FilterSection.genre),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _expandedSection == _FilterSection.genre
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchGenreField(controller: _genreSearchController),
                          const SizedBox(height: 12),
                          if (_isLoadingGenres)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_genreErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Gagal memuat genre: $_genreErrorMessage',
                                style: TextStyle(color: Colors.red.shade400),
                              ),
                            )
                          else
                            _ChipWrap(
                              options: {
                                for (final g in filteredGenres) g.slug: g.name,
                              },
                              selected: _selectedGenres,
                              onToggle: (value) =>
                                  _toggleValue(_selectedGenres, value),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            _FilterSectionHeader(
              title: 'Format',
              isExpanded: _expandedSection == _FilterSection.format,
              onTap: () => _toggleSection(_FilterSection.format),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _expandedSection == _FilterSection.format
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ChipWrap(
                        options: {
                          for (final f in ExploreFilterSheet.formatOptions)
                            f: f,
                        },
                        selected: _selectedFormats,
                        onToggle: (value) =>
                            _toggleValue(_selectedFormats, value),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            _FilterSectionHeader(
              title: 'Status',
              isExpanded: _expandedSection == _FilterSection.status,
              onTap: () => _toggleSection(_FilterSection.status),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _expandedSection == _FilterSection.status
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ChipWrap(
                        options: {
                          for (final s in ExploreFilterSheet.statusOptions)
                            s: s,
                        },
                        selected: _selectedStatuses,
                        onToggle: (value) =>
                            _toggleValue(_selectedStatuses, value),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),

            Center(
              child: GestureDetector(
                onTap: _apply,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FilterSectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          AnimatedRotation(
            duration: const Duration(milliseconds: 250),
            turns: isExpanded ? 0.5 : 0,
            child: const Icon(Icons.keyboard_arrow_down, size: 26),
          ),
        ],
      ),
    );
  }
}

class _SearchGenreField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchGenreField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search genre',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          Icon(Icons.search, color: Colors.grey.shade700),
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> selected;
  final void Function(String value) onToggle;

  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Tidak ditemukan',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries.map((entry) {
        final value = entry.key;
        final label = entry.value;
        final isSelected = selected.contains(value);
        return GestureDetector(
          onTap: () => onToggle(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
