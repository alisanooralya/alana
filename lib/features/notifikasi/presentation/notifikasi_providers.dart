import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/features/profile/presentation/profile_providers.dart';

import '../data/notifikasi.dart';
import '../data/notification_repository.dart';

final daftarNotifikasiProvider = FutureProvider.autoDispose<List<Notifikasi>>((
  ref,
) async {
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) return const [];
  return ref.watch(notificationRepositoryProvider).daftar(uid);
});

final belumDibacaProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(userIdProvider);
  if (uid == null || uid.isEmpty) return 0;
  return ref.watch(notificationRepositoryProvider).hitungBelumDibaca(uid);
});
