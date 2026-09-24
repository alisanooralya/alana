import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `true` sampai bingkai shell pertama kali tampil.
///
/// Dipakai untuk animasi slide-up + fade bottom navigation
/// hanya saat pertama masuk dari login.
final shellPertamaProvider = StateProvider<bool>((ref) => true);

/// Kerangka utama dengan bottom navigation 4 tab.
///
/// Dipakai sebagai `builder` dari `StatefulShellRoute.indexedStack`
/// di [app_router.dart].
class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  /// Shell navigasi yang mengelola tiap cabang tab.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _geser;
  late final Animation<double> _pudar;
  bool _sudahMain = false;

  @override
  void initState() {
    super.initState();
    final tanpaAnimasi = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration: tanpaAnimasi
          ? Duration.zero
          : const Duration(milliseconds: 300),
    );
    final lengkung = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _geser = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(lengkung);
    _pudar = Tween<double>(begin: 0, end: 1).animate(lengkung);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      // Kembali ke lokasi awal tab bila tab aktif ditekan ulang.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pertama = ref.watch(shellPertamaProvider);

    if (pertama && !_sudahMain) {
      _sudahMain = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.duration == Duration.zero) {
          ref.read(shellPertamaProvider.notifier).state = false;
          return;
        }
        _controller.forward().whenComplete(() {
          if (mounted) {
            ref.read(shellPertamaProvider.notifier).state = false;
          }
        });
      });
    }

    final bar = NavigationBar(
      selectedIndex: widget.navigationShell.currentIndex,
      onDestinationSelected: _onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Pustaka',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: pertama
          ? SlideTransition(
              position: _geser,
              child: FadeTransition(opacity: _pudar, child: bar),
            )
          : bar,
    );
  }
}
