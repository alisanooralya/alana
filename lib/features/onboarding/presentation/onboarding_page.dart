import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alana/core/router/transisi.dart';
import 'package:alana/features/onboarding/data/onboarding_repository.dart';

class _HalamanOnboarding {
  const _HalamanOnboarding(this.ikon, this.judul, this.deskripsi);

  final IconData ikon;
  final String judul;
  final String deskripsi;
}

const _halaman = [
  _HalamanOnboarding(
    Icons.auto_stories_outlined,
    'Baca Nyaman ala Webtoon',
    'Geser vertikal yang mulus, cubit untuk zoom, dan lanjutkan '
        'tepat di posisi terakhir kamu berhenti.',
  ),
  _HalamanOnboarding(
    Icons.bookmark_added_outlined,
    'Bookmark dan Lanjutkan',
    'Simpan judul favorit ke Pustaka dan pantau progres bacamu '
        'di Riwayat — semua tersimpan otomatis.',
  ),
  _HalamanOnboarding(
    Icons.cloud_sync_outlined,
    'Sinkron di Semua Perangkat',
    'Masuk dengan akunmu dan bookmark serta riwayatmu ikut '
        'ke mana pun kamu membaca.',
  ),
];

/// Onboarding 3 halaman. Selesai/lewati → flag lalu ke `/masuk`.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _controller;
  int _indeks = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selesai() async {
    await ref.read(sudahOnboardingProvider.notifier).selesai();
    if (mounted) context.go('/masuk');
  }

  void _keHalaman(int indeks) {
    _controller.animateToPage(
      indeks,
      duration: Transisi.skala(context, 350.ms),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final terakhir = _indeks == _halaman.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_indeks > 0) {
          _keHalaman(_indeks - 1);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: terakhir
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _selesai,
                          child: const Text('Lewati'),
                        ),
                      ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _halaman.length,
                  onPageChanged: (indeks) {
                    setState(() => _indeks = indeks);
                  },
                  itemBuilder: (context, indeks) {
                    return _IsiHalaman(
                      controller: _controller,
                      indeks: indeks,
                      data: _halaman[indeks],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _halaman.length; i++)
                    AnimatedContainer(
                      duration: Transisi.skala(context, 250.ms),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _indeks ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _indeks
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (terakhir) {
                        _selesai();
                      } else {
                        _keHalaman(_indeks + 1);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: Transisi.skala(context, 200.ms),
                      child: Text(
                        terakhir ? 'Mulai' : 'Lanjut',
                        key: ValueKey<bool>(terakhir),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _IsiHalaman extends StatelessWidget {
  const _IsiHalaman({
    required this.controller,
    required this.indeks,
    required this.data,
  });

  final PageController controller;
  final int indeks;
  final _HalamanOnboarding data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Ilustrasi(
            controller: controller,
            indeks: indeks,
            ikon: data.ikon,
            scheme: scheme,
          ),
          const SizedBox(height: 40),
          Text(
                data.judul,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
              .animate()
              .fadeIn(duration: Transisi.skala(context, 350.ms))
              .slideY(
                begin: 0.25,
                end: 0,
                duration: Transisi.skala(context, 350.ms),
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 12),
          Text(
                data.deskripsi,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
              .animate()
              .fadeIn(
                duration: Transisi.skala(context, 350.ms),
                delay: Transisi.skala(context, 120.ms),
              )
              .slideY(
                begin: 0.25,
                end: 0,
                duration: Transisi.skala(context, 350.ms),
                delay: Transisi.skala(context, 120.ms),
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}

/// Ilustrasi lingkaran gradien dengan parallax ringan saat digeser.
///
/// Hanya ilustrasi yang rebuild tiap frame (AnimatedBuilder);
/// sisa halaman tidak ikut rebuild.
class _Ilustrasi extends StatelessWidget {
  const _Ilustrasi({
    required this.controller,
    required this.indeks,
    required this.ikon,
    required this.scheme,
  });

  final PageController controller;
  final int indeks;
  final IconData ikon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var delta = 0.0;
        if (controller.hasClients) {
          try {
            delta = (controller.page ?? indeks.toDouble()) - indeks.toDouble();
          } catch (_) {
            delta = 0;
          }
        }
        return Transform.translate(
          offset: Offset(delta * -48, 0),
          child: child,
        );
      },
      child: RepaintBoundary(
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(ikon, size: 84, color: scheme.onPrimary),
        ),
      ),
    );
  }
}
