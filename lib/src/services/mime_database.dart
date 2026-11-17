import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'desktop_entry.dart';

class MimeDatabase {
  const MimeDatabase(this.paths);

  static const customTypePrefix = 'application/x-appimagemanager-';

  static final _extensionPattern = RegExp(
    r'^\*?\.?([A-Za-z0-9][A-Za-z0-9_+-]*(?:\.[A-Za-z0-9_+-]+)*)$',
  );

  final AppPaths paths;

  static String? normalizeExtension(String input) {
    final match = _extensionPattern.firstMatch(input.trim());
    return match?.group(1)?.toLowerCase();
  }

  static String customTypeFor(String extension) =>
      '$customTypePrefix${extension.replaceAll(RegExp(r'[^a-z0-9+-]'), '-')}';

  static String packageXml(Map<String, String> globsByType) {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">\n',
    );
    globsByType.forEach((type, glob) {
      final extension = glob.replaceFirst('*', '');
      buffer
        ..write('  <mime-type type="${_xml(type)}">\n')
        ..write('    <comment>Arquivo ${_xml(extension)}</comment>\n')
        ..write('    <glob pattern="${_xml(glob)}"/>\n')
        ..write('  </mime-type>\n');
    });
    buffer.write('</mime-info>\n');
    return buffer.toString();
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  Future<String?> typeForExtension(String extension) async {
    final glob = '*.${extension.toLowerCase()}';
    String? best;
    var bestWeight = -1;
    for (final dir in [paths.mimeDir, ...paths.systemDataDirs.map(_mimeDir)]) {
      final file = File(p.join(dir, 'globs2'));
      final List<String> lines;
      try {
        lines = await file.readAsLines();
      } on FileSystemException {
        continue;
      }
      for (final line in lines) {
        if (line.startsWith('#')) continue;
        final parts = line.split(':');
        if (parts.length < 3 || parts[2].toLowerCase() != glob) continue;
        final weight = int.tryParse(parts[0]) ?? 0;
        if (weight > bestWeight) {
          bestWeight = weight;
          best = parts[1];
        }
      }
    }
    return best;
  }

  static String _mimeDir(String dataDir) => p.join(dataDir, 'mime');

  static bool acceptsFiles(String? execArgs) =>
      DesktopEntry.splitExec(execArgs ?? '')
          .any((arg) => const {'%f', '%F', '%u', '%U'}.contains(arg));
}
