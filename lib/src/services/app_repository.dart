import 'dart:convert';
import 'dart:io';

import '../models/managed_app.dart';

class AppRepository {
  const AppRepository(this.filePath);

  static const schemaVersion = 1;

  final String filePath;

  Future<List<ManagedApp>> load() async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return [];
    final apps = decoded['apps'] as List<dynamic>? ?? const [];
    return apps
        .whereType<Map<String, dynamic>>()
        .map(ManagedApp.fromJson)
        .toList();
  }

  String encode(List<ManagedApp> apps) => const JsonEncoder.withIndent('  ')
      .convert({
        'schemaVersion': schemaVersion,
        'apps': apps.map((app) => app.toJson()).toList(),
      });

  Future<String?> readRaw() async {
    try {
      return await File(filePath).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> save(List<ManagedApp> apps) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final content = encode(apps);
    final temp = File('$filePath.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(filePath);
  }
}
