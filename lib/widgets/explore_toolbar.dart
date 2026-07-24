import 'package:flutter/material.dart';

enum ExploreViewMode { grid, list }

class ExploreToolbar extends StatelessWidget {
  final ExploreViewMode mode;
  final TextEditingController searchController;
  final void Function(ExploreViewMode mode) onModeChanged;
  final VoidCallback onFilterTap;
  final void Function(String value) onSearchSubmitted;

  const ExploreToolbar({
    super.key,
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
          isActive: mode == ExploreViewMode.grid,
          onTap: () => onModeChanged(ExploreViewMode.grid),
        ),
        const SizedBox(width: 8),
        _ToolbarIconButton(
          icon: Icons.view_agenda_outlined,
          isActive: mode == ExploreViewMode.list,
          onTap: () => onModeChanged(ExploreViewMode.list),
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
