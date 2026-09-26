import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';

import '../data/auth_repository.dart';

/// Stream status sesi Supabase, dinormalisasi untuk kasus Supabase belum siap.
///
/// Tanpa normalisasi ini stream selesai tanpa emit, dan `StreamProvider` yang
/// seperti itu tidak pernah keluar dari `AsyncLoading` sehingga router
/// menyandera user di `/splash` selamanya.
final streamSesiProvider = Provider<Stream<AuthState?>>((ref) {
  if (!SupabaseSetup.siap) return Stream<AuthState?>.value(null);
  return ref.watch(authRepositoryProvider).perubahanSesi;
});

/// Status sesi untuk redirect router dan sinkronisasi push.
final sesiProvider = StreamProvider<AuthState?>(
  (ref) => ref.watch(streamSesiProvider),
);

/// `true` bila ada sesi aktif (sudah login).
///
/// Bila Supabase belum terkonfigurasi, selalu false dan
/// halaman login menampilkan pesan konfigurasi.
final sudahLoginProvider = Provider<bool>((ref) {
  if (!SupabaseSetup.siap) return false;
  final sesi =
      ref.watch(sesiProvider).valueOrNull?.session ??
      SupabaseSetup.instance.auth.currentSession;
  return sesi != null;
});

/// `true` bila sesi sedang dalam mode recovery password.
///
/// Diisi setelah tautan reset dari Supabase ditukar menjadi sesi token.
/// Selama `true` router menahan user di [resetPasswordLokasi] supaya sesi
/// recovery tidak dipakai menjelajah aplikasi sebelum password diganti.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// `true` bila user Google baru wajib memilih username sendiri.
///
/// Diset setelah login Google pertama; dibersihkan setelah profil disimpan
/// atau saat keluar. Redirect mengarahkannya ke Edit Profil.
final pendingUsernameSetupProvider = StateProvider<bool>((ref) => false);

/// `true` bila user aktif punya identity email (boleh ganti password).
final punyaEmailProvider = Provider<bool>((ref) {
  if (!SupabaseSetup.siap) return false;
  // Dengarkan sesi agar ikut berubah saat login/logout.
  ref.watch(sesiProvider);
  return ref.watch(authRepositoryProvider).punyaIdentitasEmail;
});
