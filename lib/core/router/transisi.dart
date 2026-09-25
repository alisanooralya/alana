import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Helper transisi halaman terpusat.
///
/// Durasi 300–450ms, curve easeOutCubic (kecuali dinyatakan lain).
/// Semua menghormati pengaturan aksesibilitas: bila animasi sistem
/// dimatikan, durasi menjadi nol (fade instan).
class Transisi {
  const Transisi._();

  static const _fadeDur = Duration(milliseconds: 300);
  static const _sumbuDur = Duration(milliseconds: 350);
  static const _lubangDur = Duration(milliseconds: 350);
  static const _tabDur = Duration(milliseconds: 150);

  /// Nol bila [MediaQuery.disableAnimationsOf] aktif.
  static Duration skala(BuildContext context, Duration d) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    return d;
  }

  static CustomTransitionPage<void> fade({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _fadeDur,
      transitionsBuilder: (context, animation, secondary, child) {
        final efektif = skala(context, _fadeDur);
        if (efektif == Duration.zero) return child;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }

  /// SharedAxis (horizontal/vertikal) ala Material.
  static CustomTransitionPage<void> sumbu({
    required LocalKey key,
    required Widget child,
    SharedAxisTransitionType tipe = SharedAxisTransitionType.horizontal,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _sumbuDur,
      transitionsBuilder: (context, animation, secondary, child) {
        if (skala(context, _sumbuDur) == Duration.zero) return child;
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondary,
          transitionType: tipe,
          fillColor: Theme.of(context).colorScheme.surface,
          child: child,
        );
      },
    );
  }

  /// FadeThrough untuk perpindahan selevel (auth ↔ auth, login → home).
  static CustomTransitionPage<void> lubang({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _lubangDur,
      transitionsBuilder: (context, animation, secondary, child) {
        if (skala(context, _lubangDur) == Duration.zero) return child;
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondary,
          fillColor: Theme.of(context).colorScheme.surface,
          child: child,
        );
      },
    );
  }

  /// Fade sangat singkat untuk bingkai shell (masuk pertama).
  static CustomTransitionPage<void> tab({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _tabDur,
      transitionsBuilder: (context, animation, secondary, child) {
        if (skala(context, _tabDur) == Duration.zero) return child;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }
}
