import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'app_router.dart';

/// [AppLinks] harus dibuat sebelum `runApp`: tautan yang masuk saat cold start
/// hilang kalau langganan baru dibuat setelah framework berjalan.
final deepLinkAppLinks = AppLinks();

/// Menyalakan pembacaan deep link, lalu menavigate ke setiap tujuan yang
/// masuk. Dipanggil sekali dari `main`.
Future<void> mulaiDeepLink(WidgetRef ref) async {
  unawaited(_dengarkan(deepLinkAppLinks.uriLinkStream, ref));

  Uri? awal;
  try {
    awal = await deepLinkAppLinks.getInitialLink();
  } catch (error) {
    debugPrint('deep link awal gagal dibaca: $error');
  }
  await _tangani(awal, ref);
}

Future<void> _dengarkan(Stream<Uri> stream, WidgetRef ref) async {
  await for (final uri in stream) {
    await _tangani(uri, ref);
  }
}

Future<void> _tangani(Uri? uri, WidgetRef ref) async {
  if (uri == null) return;

  final kode = kodeRecoveryDari(uri);
  if (kode != null) {
    await _tukarKode(kode, ref);
    return;
  }

  final lokasi = internalLocationFromDeepLink(uri.toString());
  if (lokasi != null) _buka(ref, lokasi);
}

Future<void> _tukarKode(String kode, WidgetRef ref) async {
  if (SupabaseSetup.siap) {
    try {
      await SupabaseSetup.instance.auth.exchangeCodeForSession(kode);
      ref.read(passwordRecoveryProvider.notifier).state = true;
    } catch (error) {
      debugPrint('pertukaran kode reset password gagal: $error');
    }
  }
  _buka(ref, resetPasswordLokasi);
}

/// Menunda navigasi satu frame supaya router sudah siap menerima target.
void _buka(WidgetRef ref, String lokasi) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // WidgetRef tidak punya `mounted`; ref provider ini hidup selama aplikasi
    // berjalan, jadi yang perlu dijaga hanya router-nya sudah siap.
    try {
      ref.read(goRouterProvider).go(lokasi);
    } catch (error) {
      debugPrint('navigasi deep link gagal: $error');
    }
  });
}
