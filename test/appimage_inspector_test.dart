import 'dart:io';

import 'package:appimage_manager/src/services/appimage_inspector.dart';
import 'package:appimage_manager/src/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
