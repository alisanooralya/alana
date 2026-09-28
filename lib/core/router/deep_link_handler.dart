import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/supabase/supabase_setup.dart';
import 'package:alana/core/utils/deep_link.dart';
import 'package:alana/features/auth/presentation/auth_providers.dart';

import 'app_router.dart';

final deepLinkAppLinks = AppLinks();

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

void _buka(WidgetRef ref, String lokasi) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      ref.read(goRouterProvider).go(lokasi);
    } catch (error) {
      debugPrint('navigasi deep link gagal: $error');
    }
  });
}
