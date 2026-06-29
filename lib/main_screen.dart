import 'package:flutter/material.dart';
import 'screens/library_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/history_screen.dart';
import 'screens/browse_screen.dart';
import 'screens/more_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<Widget> _tabs = [
    LibraryScreen(),
    UpdatesScreen(),
    HistoryScreen(),
    BrowseScreen(),
    MoreScreen(),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.new_releases_outlined),
            selectedIcon: Icon(Icons.new_releases),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
