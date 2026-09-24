import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';

/// ID user aktif (null bila belum login / Supabase belum siap).
final userIdProvider = Provider<String?>((ref) {
  if (!SupabaseSetup.siap) return null;
  return ref.watch(sesiProvider).valueOrNull?.session?.user.id ??
      SupabaseSetup.instance.auth.currentUser?.id;
});

/// Email user aktif (untuk ditampilkan di Profil).
final userEmailProvider = Provider<String?>((ref) {
  if (!SupabaseSetup.siap) return null;
  return ref.watch(sesiProvider).valueOrNull?.session?.user.email ??
      SupabaseSetup.instance.auth.currentUser?.email;
});

/// Stream profil milik user aktif (null bila belum ada baris).
final profileProvider = StreamProvider<Profile?>((ref) {
  if (!SupabaseSetup.siap) return const Stream.empty();
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).pantau(uid);
});
