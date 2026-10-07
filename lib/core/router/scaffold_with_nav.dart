import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final shellPertamaProvider = StateProvider<bool>((ref) => true);

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

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
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // Bar kustom 60px; NavigationBar bawaan terkunci 80px.
  static const _tinggiBar = 60.0;

  static final _tujuan = [
    (Icons.home_outlined, Icons.home, 'Beranda'),
    (Icons.local_library_outlined, Icons.local_library, 'Pustaka'),
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  Widget _bar() {
    final scheme = Theme.of(context).colorScheme;
    final gayaLabel = Theme.of(context).textTheme.labelMedium;
    final saatIni = widget.navigationShell.currentIndex;
    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: _tinggiBar,
        child: Row(
          children: [
            for (var i = 0; i < _tujuan.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => _onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: i == saatIni
                            ? BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              )
                            : null,
                        child: Icon(
                          i == saatIni ? _tujuan[i].$2 : _tujuan[i].$1,
                          color: i == saatIni
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (i == saatIni)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _tujuan[i].$3,
                            style: (gayaLabel ?? const TextStyle()).copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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

    final bar = _bar();

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
