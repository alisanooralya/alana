import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';

final userIdProvider = Provider<String?>((ref) {
  if (!SupabaseSetup.siap) return null;
  return ref.watch(sesiProvider).valueOrNull?.session?.user.id ??
      SupabaseSetup.instance.auth.currentUser?.id;
});

final userEmailProvider = Provider<String?>((ref) {
  if (!SupabaseSetup.siap) return null;
  return ref.watch(sesiProvider).valueOrNull?.session?.user.email ??
      SupabaseSetup.instance.auth.currentUser?.email;
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  if (!SupabaseSetup.siap) return null;
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) return null;
  return ref.watch(profileRepositoryProvider).ambil(uid);
});
