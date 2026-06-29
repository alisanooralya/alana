// Diadaptasi & disederhanakan dari struktur navigasi mangayomi
// (https://github.com/kodjodevf/mangayomi) — Lisensi asal: Apache-2.0.
//
// Urutan tab: Library, Explore, Home, History, Profile — dengan Home
// di tengah dan jadi tab default saat app dibuka. Icon punya animasi
// scale+bounce kecil saat dipilih (tanpa package tambahan).

import 'package:flutter/material.dart';
import 'screens/library_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Index 2 (Home) jadi tab default saat app pertama dibuka.
  int _currentIndex = 2;

  static const List<Widget> _tabs = [
    LibraryScreen(),
    ExploreScreen(),
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  static const List<_TabData> _tabData = [
    _TabData(
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark,
      label: 'Library',
    ),
    _TabData(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
    ),
    _TabData(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _TabData(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'History',
    ),
    _TabData(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack supaya state tiap tab (scroll position, dll) tetap
      // terjaga saat pindah tab, bukan dibuat ulang dari awal.
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          for (int i = 0; i < _tabData.length; i++)
            NavigationDestination(
              icon: _AnimatedNavIcon(
                icon: _tabData[i].icon,
                selectedIcon: _tabData[i].selectedIcon,
                isSelected: _currentIndex == i,
              ),
              label: _tabData[i].label,
            ),
        ],
      ),
    );
  }
}

class _TabData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _TabData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Icon tab dengan animasi scale+bounce kecil saat berubah status
/// terpilih/tidak. Pakai TweenAnimationBuilder, tidak butuh package
/// tambahan, dan cukup ringan untuk dipasang di bottom nav.
class _AnimatedNavIcon extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;

  const _AnimatedNavIcon({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Saat baru terpilih: melompat dari 0.7x ke 1.0x dengan efek "overshoot".
      tween: Tween<double>(begin: isSelected ? 0.7 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(isSelected ? selectedIcon : icon),
        );
      },
    );
  }
}
