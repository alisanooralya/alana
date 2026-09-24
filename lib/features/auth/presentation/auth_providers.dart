import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

import '../data/auth_repository.dart';

/// Stream status sesi Supabase.
///
/// Router mendengarkan ini untuk redirect otomatis.
/// Sesi tersimpan otomatis sehingga tetap ada setelah
/// aplikasi ditutup dan dibuka lagi.
final sesiProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseSetup.siap) return const Stream.empty();
  return ref.watch(authRepositoryProvider).perubahanSesi;
});

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

/// `true` bila user Google baru wajib memilih username sendiri.
///
/// Diset setelah login Google pertama; dibersihkan setelah profil disimpan
/// atau saat keluar. Redirect mengarahkannya ke Edit Profil.
final pendingUsernameSetupProvider = StateProvider<bool>((ref) => false);
