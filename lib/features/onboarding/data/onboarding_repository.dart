import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akses SharedPreferences. Dioverride di main() setelah dimuat,
/// sehingga flag onboarding tersedia sinkron sejak frame pertama.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw StateError('SharedPreferences belum dimuat di main().'),
);

/// Flag `onboarding_done`: per-perangkat, tidak dihapus saat logout.
class OnboardingRepository {
  const OnboardingRepository(this._prefs);

  static const kunci = 'onboarding_done';

  final SharedPreferences _prefs;

  bool get sudah => _prefs.getBool(kunci) ?? false;

  Future<void> tandaiSelesai() => _prefs.setBool(kunci, true);
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(sharedPreferencesProvider));
});

/// Status onboarding yang reaktif (redirect mengikuti otomatis).
class OnboardingStatus extends Notifier<bool> {
  @override
  bool build() => ref.watch(onboardingRepositoryProvider).sudah;

  Future<void> selesai() async {
    await ref.read(onboardingRepositoryProvider).tandaiSelesai();
    state = true;
  }
}

final sudahOnboardingProvider = NotifierProvider<OnboardingStatus, bool>(
  () => OnboardingStatus(),
);
