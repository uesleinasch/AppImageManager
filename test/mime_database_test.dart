import 'dart:io';

import 'package:appimage_manager/src/services/app_paths.dart';
import 'package:appimage_manager/src/services/mime_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('normaliza extensões', () {
    expect(MimeDatabase.normalizeExtension('.MD'), 'md');
    expect(MimeDatabase.normalizeExtension('*.excalidraw'), 'excalidraw');
    expect(MimeDatabase.normalizeExtension('tar.gz'), 'tar.gz');
    expect(MimeDatabase.normalizeExtension('a b'), isNull);
    expect(MimeDatabase.normalizeExtension('../x'), isNull);
    expect(MimeDatabase.normalizeExtension(''), isNull);
  });

  test('tipo próprio e XML escapado', () {
    expect(
      MimeDatabase.customTypeFor('tar.gz'),
      'application/x-appimagemanager-tar-gz',
    );
    final xml = MimeDatabase.packageXml({'application/x-a': '*.a&b'});
    expect(xml, contains('<mime-type type="application/x-a">'));
    expect(xml, contains('<glob pattern="*.a&amp;b"/>'));
  });

  test('acceptsFiles detecta field codes de arquivo', () {
    expect(MimeDatabase.acceptsFiles('--no-sandbox %U'), isTrue);
    expect(MimeDatabase.acceptsFiles('%f'), isTrue);
    expect(MimeDatabase.acceptsFiles('--flag'), isFalse);
    expect(MimeDatabase.acceptsFiles(null), isFalse);
  });

  test('typeForExtension consulta globs2 do usuário e do sistema', () async {
    final root = await Directory.systemTemp.createTemp('mime-db-');
    addTearDown(() => root.delete(recursive: true));
    final system = p.join(root.path, 'system');
    final paths = AppPaths(
      home: root.path,
      configHome: p.join(root.path, '.config'),
      dataHome: p.join(root.path, '.local', 'share'),
      cacheHome: p.join(root.path, '.cache'),
      systemDataDirs: [system, p.join(root.path, 'inexistente')],
    );
    File(p.join(system, 'mime', 'globs2'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '# comentário\n'
        '50:text/markdown:*.md\n'
        '10:text/x-baixo:*.md\n'
        '50:text/x-csrc:*.c:cs\n',
      );
    File(p.join(paths.mimeDir, 'globs2'))
      ..createSync(recursive: true)
      ..writeAsStringSync('50:application/x-board:*.board\n');

    final db = MimeDatabase(paths);
    expect(await db.typeForExtension('md'), 'text/markdown');
    expect(await db.typeForExtension('MD'), 'text/markdown');
    expect(await db.typeForExtension('board'), 'application/x-board');
    expect(await db.typeForExtension('c'), 'text/x-csrc');
    expect(await db.typeForExtension('nada'), isNull);
  });
}
