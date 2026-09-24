import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alana/core/storage/app_storage.dart';

import 'app_settings.dart';

/// Repository pengaturan, reaktif + persisten (Hive box `settings`).
class SettingsRepository extends Notifier<AppSettings> {
  static const _key = 'pengaturan';

  @override
  AppSettings build() {
    final raw = AppStorage.settingsBox.get(_key);
    if (raw is! Map) return const AppSettings();
    return AppSettings.fromMap(Map<String, dynamic>.from(raw));
  }

  void _tulis(AppSettings next) {
    AppStorage.settingsBox.put(_key, next.toMap());
    state = next;
  }

  void aturTema(AppThemeMode mode) => _tulis(state.copyWith(themeMode: mode));

  void aturKeepScreenOn(bool aktif) {
    _tulis(state.copyWith(keepScreenOn: aktif));
  }
}

final settingsRepositoryProvider =
    NotifierProvider<SettingsRepository, AppSettings>(
      () => SettingsRepository(),
    );
