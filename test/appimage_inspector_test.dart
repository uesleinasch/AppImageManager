import 'dart:io';

import 'package:appimage_manager/src/services/appimage_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
}
