import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';

class SettingsRepository {
  const SettingsRepository(this.filePath);

  final String filePath;

  Future<AppSettings> load() async {
    final file = File(filePath);
    if (!await file.exists()) return const AppSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic>
          ? AppSettings.fromJson(decoded)
          : const AppSettings();
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final temp = File('$filePath.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
    await temp.rename(filePath);
  }
}
