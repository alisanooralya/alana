/// Pilihan tema tampilan (disimpan di Hive).
enum AppThemeMode {
  /// Mengikuti pengaturan sistem (bawaan).
  sistem,

  /// Selalu terang.
  terang,

  /// Selalu gelap.
  gelap;

  String get label {
    switch (this) {
      case AppThemeMode.sistem:
        return 'Ikuti sistem';
      case AppThemeMode.terang:
        return 'Terang';
      case AppThemeMode.gelap:
        return 'Gelap';
    }
  }

  static AppThemeMode fromName(String? name) {
    for (final mode in AppThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return AppThemeMode.sistem;
  }
}

/// Seluruh pengaturan aplikasi dalam satu state.
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.sistem,
    this.keepScreenOn = false,
  });

  /// Tema tampilan.
  final AppThemeMode themeMode;

  /// Layar tetap menyala selama membaca di reader.
  final bool keepScreenOn;

  AppSettings copyWith({AppThemeMode? themeMode, bool? keepScreenOn}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }

  Map<String, dynamic> toMap() {
    return {'themeMode': themeMode.name, 'keepScreenOn': keepScreenOn};
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeMode: AppThemeMode.fromName(map['themeMode']?.toString()),
      keepScreenOn: map['keepScreenOn'] == true,
    );
  }
}
