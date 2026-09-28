import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alana/core/supabase/supabase_setup.dart';

import '../data/auth_repository.dart';

final streamSesiProvider = Provider<Stream<AuthState?>>((ref) {
  if (!SupabaseSetup.siap) return Stream<AuthState?>.value(null);
  return ref.watch(authRepositoryProvider).perubahanSesi;
});

final sesiProvider = StreamProvider<AuthState?>(
  (ref) => ref.watch(streamSesiProvider),
);

final sudahLoginProvider = Provider<bool>((ref) {
  if (!SupabaseSetup.siap) return false;
  final sesi =
      ref.watch(sesiProvider).valueOrNull?.session ??
      SupabaseSetup.instance.auth.currentSession;
  return sesi != null;
});

final passwordRecoveryProvider = StateProvider<bool>((ref) => false);
final pendingUsernameSetupProvider = StateProvider<bool>((ref) => false);

final punyaEmailProvider = Provider<bool>((ref) {
  if (!SupabaseSetup.siap) return false;
  ref.watch(sesiProvider);
  return ref.watch(authRepositoryProvider).punyaIdentitasEmail;
});
