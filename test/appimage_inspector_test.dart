import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appimage_manager/src/services/appimage_inspector.dart';
import 'package:appimage_manager/src/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List _elfWithUpdateInformation(String information) {
  final names = ascii.encode('\x00.shstrtab\x00.upd_info\x00');
  final data = Uint8List(64)..setAll(0, utf8.encode(information));
  const namesOffset = 64;
  final dataOffset = namesOffset + names.length;
  final tableOffset = dataOffset + data.length;
  final bytes = ByteData(tableOffset + 3 * 64);
  const le = Endian.little;
  for (final (i, byte) in [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1].indexed) {
    bytes.setUint8(i, byte);
  }
  bytes
    ..setUint64(0x28, tableOffset, le)
    ..setUint16(0x3a, 64, le)
    ..setUint16(0x3c, 3, le)
    ..setUint16(0x3e, 1, le);
  void section(int index, int name, int offset, int size) {
    final base = tableOffset + index * 64;
    bytes
      ..setUint32(base, name, le)
      ..setUint64(base + 0x18, offset, le)
      ..setUint64(base + 0x20, size, le);
  }

  section(1, 1, namesOffset, names.length);
  section(2, 11, dataOffset, data.length);
  final result = bytes.buffer.asUint8List();
  result
    ..setAll(namesOffset, names)
    ..setAll(dataOffset, data);
  return result;
}

class _ExtractingRunner extends ProcessRunner {
  const _ExtractingRunner(this.files);

  final Map<String, String> files;

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final pattern = RegExp(
      '^${RegExp.escape(arguments.last).replaceAll(r'\*', '[^/]*')}\$',
    );
    for (final entry in files.entries) {
      if (!pattern.hasMatch(entry.key)) continue;
      final file = File(p.join(workingDirectory!, 'squashfs-root', entry.key));
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    return const ProcessOutput(0, '', '');
  }
}

void main() {
  group('guessFromFileName', () {
    final cases = {
      'Obsidian-1.5.3.AppImage': ('Obsidian', '1.5.3'),
      'balenaEtcher-1.18.11-x64.AppImage': ('balenaEtcher', '1.18.11'),
      'Joplin-3.0.15-beta.2.AppImage': ('Joplin', '3.0.15-beta.2'),
      'kdenlive_v24.02.1_x86_64.appimage': ('kdenlive', '24.02.1'),
      'MyTool.AppImage': ('MyTool', null),
    };
    cases.forEach((fileName, expected) {
      test(fileName, () {
        final guess = AppImageInspector.guessFromFileName(fileName);
        expect(guess.name, expected.$1);
        expect(guess.version, expected.$2);
      });
    });
  });

  group('detectType', () {
    late Directory dir;

    setUp(
      () async =>
          dir = await Directory.systemTemp.createTemp('inspector-test-'),
    );
    tearDown(() => dir.delete(recursive: true));

    Future<String> write(List<int> bytes) async {
      final file = File(p.join(dir.path, 'file.AppImage'));
      await file.writeAsBytes(bytes);
      return file.path;
    }

    test('reconhece AppImage tipo 2', () async {
      final path = await write([
        0x7f,
        0x45,
        0x4c,
        0x46,
        2,
        1,
        1,
        0,
        0x41,
        0x49,
        0x02,
        0,
      ]);
      expect(await AppImageInspector.detectType(path), AppImageType.type2);
    });

    test('ELF sem assinatura é desconhecido', () async {
      final path = await write([
        0x7f,
        0x45,
        0x4c,
        0x46,
        2,
        1,
        1,
        0,
        0,
        0,
        0,
        0,
      ]);
      expect(await AppImageInspector.detectType(path), AppImageType.unknown);
    });

    test('rejeita arquivo que não é ELF', () async {
      final path = await write('#!/bin/sh\necho oi\n'.codeUnits);
      expect(
        AppImageInspector.detectType(path),
        throwsA(isA<InvalidAppImageException>()),
      );
    });
  });

  test('imageExtension identifica PNG e SVG', () {
    expect(
      AppImageInspector.imageExtension([0x89, 0x50, 0x4e, 0x47, 0x0d]),
      'png',
    );
    expect(
      AppImageInspector.imageExtension('<?xml version="1.0"?><svg>'.codeUnits),
      'svg',
    );
    expect(AppImageInspector.imageExtension('texto'.codeUnits), isNull);
  });

  group('readUpdateInformation', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('upd-info-'));
    tearDown(() => dir.delete(recursive: true));

    Future<String> write(List<int> bytes) async {
      final file = File(p.join(dir.path, 'a.AppImage'));
      await file.writeAsBytes(bytes);
      return file.path;
    }

    test('lê a seção .upd_info', () async {
      const info = 'gh-releases-zsync|acme|tool|latest|Tool-*.AppImage.zsync';
      final path = await write(_elfWithUpdateInformation(info));
      expect(await AppImageInspector.readUpdateInformation(path), info);
    });

    test('seção vazia, ELF truncado ou arquivo comum dão null', () async {
      expect(
        await AppImageInspector.readUpdateInformation(
          await write(_elfWithUpdateInformation('')),
        ),
        isNull,
      );
      expect(
        await AppImageInspector.readUpdateInformation(
          await write(_elfWithUpdateInformation('x').sublist(0, 80)),
        ),
        isNull,
      );
      expect(
        await AppImageInspector.readUpdateInformation(
          await write('texto qualquer'.codeUnits),
        ),
        isNull,
      );
    });
  });

  test('inspect guarda o id do .desktop interno', () async {
    final dir = await Directory.systemTemp.createTemp('inspector-test-');
    addTearDown(() => dir.delete(recursive: true));
    final appImage = File(p.join(dir.path, 'PairLAN-0.7.0.AppImage'));
    await appImage.writeAsBytes([
      0x7f, 0x45, 0x4c, 0x46, 2, 1, 1, 0, 0x41, 0x49, 0x02, 0, //
    ]);
    final work = await Directory(p.join(dir.path, 'work')).create();

    final metadata =
        await const AppImageInspector(
          runner: _ExtractingRunner({
            'pairlan.desktop':
                '[Desktop Entry]\nName=PairLAN\nIcon=pairlan\n'
                'StartupWMClass=PairLAN\nMimeType=application/x-pair;\n',
            'usr/share/mime/packages/pairlan.xml': '<mime-info/>',
          }),
        ).inspect(
          appImage.path,
          workDir: work.path,
          originalFileName: p.basename(appImage.path),
        );

    expect(metadata.name, 'PairLAN');
    expect(metadata.desktopId, 'pairlan');
    expect(metadata.startupWmClass, 'PairLAN');
    expect(metadata.mimeTypes, ['application/x-pair']);
    expect(metadata.mimePackages.map(p.basename), ['pairlan.xml']);
  });
}
