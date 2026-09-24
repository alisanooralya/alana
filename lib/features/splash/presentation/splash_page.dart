import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'splash_providers.dart';

/// Halaman splash dalam aplikasi.
///
/// Logo fade + scale in (~600ms), tampil minimal ~800ms, dan menunggu
/// status sesi. Navigasi keluar ditangani redirect go_router.
/// Latar mengikuti surface agar mulus dari native splash.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _skala;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final tanpaAnimasi = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final durasi = tanpaAnimasi
        ? Duration.zero
        : const Duration(milliseconds: 600);
    _controller = AnimationController(vsync: this, duration: durasi);
    final lengkung = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(lengkung);
    _skala = Tween<double>(begin: 0.85, end: 1).animate(lengkung);
    _controller.forward();
    // Tampil minimal ~800ms (nol bila animasi dimatikan).
    _timer = Timer(
      tanpaAnimasi ? Duration.zero : const Duration(milliseconds: 800),
      () {
        if (mounted) {
          ref.read(splashSiapProvider.notifier).state = true;
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _skala,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 52,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alana',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Baca manhwa favoritmu',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
