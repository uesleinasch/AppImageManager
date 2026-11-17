import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'desktop_entry.dart';
import 'process_runner.dart';

enum AppImageType { type1, type2, unknown }

class AppImageMetadata {
  const AppImageMetadata({
    required this.name,
    this.version,
    this.comment,
    this.categories = const [],
    this.execArgs,
    this.startupWmClass,
    this.iconFile,
    this.desktopId,
    this.mimeTypes = const [],
    this.mimePackages = const [],
    this.updateInformation,
  });

  final String name;
  final String? version;
  final String? comment;
  final List<String> categories;
  final String? execArgs;
  final String? startupWmClass;
  final String? iconFile;
  final String? desktopId;
  final List<String> mimeTypes;
  final List<String> mimePackages;
  final String? updateInformation;
}

class FileNameGuess {
  const FileNameGuess(this.name, this.version);

  final String name;
  final String? version;
}

class InvalidAppImageException implements Exception {
  const InvalidAppImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppImageInspector {
  const AppImageInspector({this.runner = const ProcessRunner()});

  final ProcessRunner runner;

  static final _fileNamePattern = RegExp(
    r'^(.+?)[-_ ]v?(\d+(?:\.\d+)+(?:[-~](?:alpha|beta|rc|pre|dev)[0-9.]*)?)(?:[-_ .].*)?$',
    caseSensitive: false,
  );

  static FileNameGuess guessFromFileName(String fileName) {
    final stem = fileName.replaceFirst(
      RegExp(r'\.appimage$', caseSensitive: false),
      '',
    );
    final match = _fileNamePattern.firstMatch(stem);
    if (match == null) return FileNameGuess(stem, null);
    return FileNameGuess(match.group(1)!, match.group(2));
  }

  static Future<AppImageType> detectType(String path) async {
    final file = await File(path).open();
    try {
      final header = await file.read(11);
      if (header.length < 4 ||
          header[0] != 0x7f ||
          header[1] != 0x45 ||
          header[2] != 0x4c ||
          header[3] != 0x46) {
        throw const InvalidAppImageException(
          'O arquivo selecionado não é um executável ELF/AppImage válido.',
        );
      }
      if (header.length == 11 && header[8] == 0x41 && header[9] == 0x49) {
        if (header[10] == 0x02) return AppImageType.type2;
        if (header[10] == 0x01) return AppImageType.type1;
      }
      return AppImageType.unknown;
    } finally {
      await file.close();
    }
  }

  static Future<String?> readUpdateInformation(String path) async {
    final file = await File(path).open();
    try {
      final header = await file.read(64);
      if (header.length < 52 ||
          header[0] != 0x7f ||
          header[1] != 0x45 ||
          header[2] != 0x4c ||
          header[3] != 0x46) {
        return null;
      }
      final is64 = header[4] == 2;
      final endian = header[5] == 1 ? Endian.little : Endian.big;
      final h = ByteData.sublistView(header);
      if (is64 && header.length < 64) return null;
      final sectionTable = is64
          ? h.getUint64(0x28, endian)
          : h.getUint32(0x20, endian);
      final entrySize = h.getUint16(is64 ? 0x3a : 0x2e, endian);
      final count = h.getUint16(is64 ? 0x3c : 0x30, endian);
      final namesIndex = h.getUint16(is64 ? 0x3e : 0x32, endian);
      if (count == 0 || entrySize < (is64 ? 64 : 40) || namesIndex >= count) {
        return null;
      }

      await file.setPosition(sectionTable);
      final table = await file.read(entrySize * count);
      if (table.length < entrySize * count) return null;
      final t = ByteData.sublistView(table);
      ({int name, int offset, int size}) section(int index) {
        final base = index * entrySize;
        return (
          name: t.getUint32(base, endian),
          offset: is64
              ? t.getUint64(base + 0x18, endian)
              : t.getUint32(base + 0x10, endian),
          size: is64
              ? t.getUint64(base + 0x20, endian)
              : t.getUint32(base + 0x14, endian),
        );
      }

      Future<Uint8List?> readAt(int offset, int size, int limit) async {
        if (size <= 0 || size > limit) return null;
        await file.setPosition(offset);
        final bytes = await file.read(size);
        return bytes.length == size ? bytes : null;
      }

      final names = section(namesIndex);
      final nameTable = await readAt(names.offset, names.size, 1 << 20);
      if (nameTable == null) return null;
      for (var i = 0; i < count; i++) {
        final entry = section(i);
        if (entry.name >= nameTable.length) continue;
        final end = nameTable.indexOf(0, entry.name);
        final name = ascii.decode(
          nameTable.sublist(entry.name, end < 0 ? nameTable.length : end),
          allowInvalid: true,
        );
        if (name != '.upd_info') continue;
        final data = await readAt(entry.offset, entry.size, 8192);
        if (data == null) return null;
        final terminator = data.indexOf(0);
        final value = utf8
            .decode(
              terminator < 0 ? data : data.sublist(0, terminator),
              allowMalformed: true,
            )
            .trim();
        return value.isEmpty ? null : value;
      }
      return null;
    } on RangeError {
      return null;
    } finally {
      await file.close();
    }
  }

  static String? imageExtension(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    final head = String.fromCharCodes(bytes.take(1024)).toLowerCase();
    if (head.contains('<svg')) return 'svg';
    return null;
  }

  Future<AppImageMetadata> inspect(
    String appImagePath, {
    required String workDir,
    required String originalFileName,
  }) async {
    final guess = guessFromFileName(originalFileName);
    final type = await detectType(appImagePath);
    final updateInformation = await readUpdateInformation(appImagePath);
    final fallback = AppImageMetadata(
      name: guess.name,
      version: guess.version,
      updateInformation: updateInformation,
    );

    if (type != AppImageType.type2) return fallback;

    final root = p.join(workDir, 'squashfs-root');
    try {
      await _extract(appImagePath, '*.desktop', workDir);
    } on ProcessException {
      return fallback;
    }

    final extraction = _Extraction(this, appImagePath, workDir, root);
    final found = await _readDesktopEntry(extraction);
    if (found == null) return fallback;
    final (desktopId, entry) = found;

    final iconName = entry['Icon'];
    final mimeTypes = entry.list('MimeType');
    return AppImageMetadata(
      name: entry['Name'] ?? guess.name,
      version: entry['X-AppImage-Version'] ?? guess.version,
      comment: entry['Comment'],
      categories: entry.list('Categories'),
      execArgs: entry.execArguments,
      startupWmClass: entry['StartupWMClass'],
      iconFile: await _extractIcon(extraction, iconName),
      desktopId: desktopId,
      mimeTypes: mimeTypes,
      mimePackages: mimeTypes.isEmpty
          ? const []
          : await _extractMimePackages(extraction),
      updateInformation: updateInformation,
    );
  }

  Future<(String, DesktopEntry)?> _readDesktopEntry(
    _Extraction extraction,
  ) async {
    final dir = Directory(extraction.root);
    if (!await dir.exists()) return null;
    final names = await dir
        .list(followLinks: false)
        .map((entity) => p.basename(entity.path))
        .where((name) => name.endsWith('.desktop'))
        .toList();

    for (final name in names..sort()) {
      final file = await extraction.materialize(name);
      if (file == null) continue;
      return (
        p.basenameWithoutExtension(name),
        DesktopEntry.parse(
          await File(file).readAsString(),
          locale: Platform.environment['LANG'],
        ),
      );
    }
    return null;
  }

  Future<List<String>> _extractMimePackages(_Extraction extraction) async {
    try {
      await _extract(
        extraction.appImagePath,
        'usr/share/mime/packages/*.xml',
        extraction.workDir,
      );
    } on ProcessException {
      return const [];
    }
    final dir = Directory(
      p.join(extraction.root, 'usr', 'share', 'mime', 'packages'),
    );
    if (!await dir.exists()) return const [];
    final names = await dir
        .list(followLinks: false)
        .map((entity) => p.basename(entity.path))
        .where((name) => name.endsWith('.xml'))
        .toList();
    final files = <String>[];
    for (final name in names..sort()) {
      final file = await extraction.materialize(
        p.join('usr', 'share', 'mime', 'packages', name),
      );
      if (file != null) files.add(file);
    }
    return files;
  }

  Future<String?> _extractIcon(_Extraction extraction, String? iconName) async {
    final safeName =
        iconName != null &&
            iconName.isNotEmpty &&
            !iconName.contains('/') &&
            !iconName.contains('*')
        ? iconName
        : null;

    final candidates = [
      if (safeName != null) ...['$safeName.svg', '$safeName.png'],
      '.DirIcon',
    ];
    for (final candidate in candidates) {
      final file = await extraction.materialize(candidate);
      if (file != null) return file;
    }

    if (safeName == null) return null;
    final appImagePath = extraction.appImagePath;
    final workDir = extraction.workDir;
    final root = extraction.root;
    await _extract(
      appImagePath,
      'usr/share/icons/hicolor/*/apps/$safeName.*',
      workDir,
    );
    return _bestHicolorIcon(p.join(root, 'usr', 'share', 'icons', 'hicolor'));
  }

  Future<String?> _bestHicolorIcon(String hicolorDir) async {
    final dir = Directory(hicolorDir);
    if (!await dir.exists()) return null;

    String? best;
    var bestScore = -1;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (extension != '.png' && extension != '.svg') continue;
      final sizeDir = p.basename(p.dirname(p.dirname(entity.path)));
      final score = extension == '.svg'
          ? 100000
          : int.tryParse(sizeDir.split('x').first) ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = entity.path;
      }
    }
    return best;
  }

  Future<void> _extract(String appImagePath, String pattern, String workDir) =>
      runner.run(appImagePath, [
        '--appimage-extract',
        pattern,
      ], workingDirectory: workDir);
}

class _Extraction {
  _Extraction(this.inspector, this.appImagePath, this.workDir, this.root);

  static const _maxLinkDepth = 8;

  final AppImageInspector inspector;
  final String appImagePath;
  final String workDir;
  final String root;

  Future<String?> materialize(String relative, {int depth = 0}) async {
    if (depth > _maxLinkDepth) return null;
    final path = p.normalize(p.join(root, relative));
    if (!p.isWithin(root, path)) return null;

    var type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await inspector._extract(
        appImagePath,
        p.relative(path, from: root),
        workDir,
      );
      type = await FileSystemEntity.type(path, followLinks: false);
    }

    if (type == FileSystemEntityType.file) return path;
    if (type != FileSystemEntityType.link) return null;

    final target = await Link(path).target();
    if (p.isAbsolute(target)) return null;
    return materialize(
      p.relative(p.join(p.dirname(path), target), from: root),
      depth: depth + 1,
    );
  }
}
