class AppSettings {
  const AppSettings({
    this.checkUpdatesOnStart = false,
    this.cleanupMissing = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    checkUpdatesOnStart: json['checkUpdatesOnStart'] as bool? ?? false,
    cleanupMissing: json['cleanupMissing'] as bool? ?? true,
  );

  final bool checkUpdatesOnStart;
  final bool cleanupMissing;

  AppSettings copyWith({bool? checkUpdatesOnStart, bool? cleanupMissing}) =>
      AppSettings(
        checkUpdatesOnStart: checkUpdatesOnStart ?? this.checkUpdatesOnStart,
        cleanupMissing: cleanupMissing ?? this.cleanupMissing,
      );

  Map<String, dynamic> toJson() => {
    'checkUpdatesOnStart': checkUpdatesOnStart,
    'cleanupMissing': cleanupMissing,
  };
}
