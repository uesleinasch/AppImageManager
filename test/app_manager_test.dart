import 'dart:convert';
import 'dart:io';

import 'package:appimage_manager/src/models/github_source.dart';
import 'package:appimage_manager/src/services/app_manager.dart';
import 'package:appimage_manager/src/services/app_paths.dart';
import 'package:appimage_manager/src/services/desktop_entry.dart';
import 'package:appimage_manager/src/services/github_release_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

const _fakeElf = [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1, 0, 0, 0, 0, 0, 1, 2, 3];

void main() {
  late Directory root;
  late AppPaths paths;
  late AppManager manager;
  late String download;

  http.Response releaseResponse(String tag) => http.Response(
    jsonEncode({
      'tag_name': tag,
      'name': tag,
      'html_url': 'https://github.com/acme/tool/releases/tag/$tag',
      'prerelease': false,
      'assets': [
        {
          'name': 'Tool-$tag-x86_64.AppImage',
          'browser_download_url':
              'https://github.com/acme/tool/releases/download/$tag/Tool.AppImage',
          'size': _fakeElf.length,
        },
      ],
    }),
    200,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('manager-test-');
    paths = AppPaths.underRoot(root.path);
    download = p.join(root.path, 'Downloads', 'Tool-1.2.0-x86_64.AppImage');
    await File(download).create(recursive: true);
    await File(download).writeAsBytes(_fakeElf);

    manager = AppManager(
      paths: paths,
      github: GitHubReleaseService(
        client: MockClient((request) async {
          if (request.url.host == 'api.github.com') {
            return releaseResponse('v1.3.0');
          }
          return http.Response.bytes(_fakeElf, 200);
        }),
      ),
    );
    await manager.load();
  });

  tearDown(() async {
    manager.dispose();
    await root.delete(recursive: true);
  });

  Future<String> install({bool autostart = false, GitHubSource? github}) async {
    final draft = await manager.prepareInstall(download);
    final app = await manager.install(
      draft,
      name: draft.metadata.name,
      autostart: autostart,
      github: github,
    );
    expect(await Directory(draft.stagingDir).exists(), isFalse);
    return app.id;
  }

  test('instala, cria atalho no menu e persiste a biblioteca', () async {
    final id = await install();
    final app = manager.byId(id)!;

    expect(id, 'tool');
    expect(app.version, '1.2.0');
    expect(app.appImagePath, paths.appImagePath('tool'));
    expect(await File(app.appImagePath).readAsBytes(), _fakeElf);
    expect((await File(app.appImagePath).stat()).modeString(), 'rwxr-xr-x');

    final entry = DesktopEntry.parse(
      await File(paths.menuEntryPath(id)).readAsString(),
    );
    expect(entry['Name'], 'Tool');
    expect(entry['Exec'], app.appImagePath);
    expect(await File(paths.autostartEntryPath(id)).exists(), isFalse);

    final reloaded = AppManager(paths: paths);
    await reloaded.load();
    expect(reloaded.apps.single.id, 'tool');
    reloaded.dispose();
  });

  test('gera ids únicos para nomes repetidos', () async {
    await install();
    expect(await install(), 'tool-2');
  });

  test('liga e desliga autostart e menu', () async {
    final id = await install();

    await manager.setAutostart(id, true);
    expect(await File(paths.autostartEntryPath(id)).exists(), isTrue);

    await manager.setMenuEntry(id, false);
    expect(await File(paths.menuEntryPath(id)).exists(), isFalse);

    await manager.setAutostart(id, false);
    expect(await File(paths.autostartEntryPath(id)).exists(), isFalse);
  });

  test('renomear atualiza o atalho', () async {
    final id = await install();
    await manager.rename(id, 'Ferramenta');
    final entry = DesktopEntry.parse(
      await File(paths.menuEntryPath(id)).readAsString(),
    );
    expect(entry['Name'], 'Ferramenta');
    expect(() => manager.rename(id, '  '), throwsA(isA<AppManagerException>()));
  });

  test('atualização manual substitui o arquivo e mantém o id', () async {
    final id = await install();
    final newer = p.join(root.path, 'Downloads', 'Tool-1.4.0.AppImage');
    await File(newer).writeAsBytes([..._fakeElf, 9, 9]);

    await manager.updateFromFile(id, newer);

    final app = manager.byId(id)!;
    expect(app.version, '1.4.0');
    expect(await File(app.appImagePath).readAsBytes(), [..._fakeElf, 9, 9]);
    expect(manager.taskFor(id), isNull);
  });

  test('verifica e aplica atualização do GitHub', () async {
    final id = await install(
      github: const GitHubSource(owner: 'acme', repo: 'tool'),
    );

    final release = await manager.checkForUpdate(id);
    expect(release?.tag, 'v1.3.0');
    expect(manager.updateFor(id), isNotNull);
    expect(manager.byId(id)!.lastCheckedAt, isNotNull);

    await manager.applyGitHubUpdate(id);
    final app = manager.byId(id)!;
    expect(app.releaseTag, 'v1.3.0');
    expect(app.version, '1.3.0');
    expect(manager.updateFor(id), isNull);

    expect(await manager.checkForUpdate(id), isNull);
  });

  test('checkForUpdate exige fonte GitHub', () async {
    final id = await install();
    expect(
      () => manager.checkForUpdate(id),
      throwsA(isA<AppManagerException>()),
    );
  });

  test('remove apaga atalhos e, opcionalmente, o arquivo', () async {
    final id = await install(autostart: true);
    final file = manager.byId(id)!.appImagePath;

    await manager.remove(id, deleteFile: false);
    expect(manager.apps, isEmpty);
    expect(await File(paths.menuEntryPath(id)).exists(), isFalse);
    expect(await File(paths.autostartEntryPath(id)).exists(), isFalse);
    expect(await File(file).exists(), isTrue);
  });

  test('prepareInstall rejeita arquivos que não são AppImage', () async {
    final text = p.join(root.path, 'nota.txt');
    await File(text).writeAsString('não sou um AppImage');
    expect(manager.prepareInstall(text), throwsA(anything));
  });

  test('isUpdate compara tag instalada ou versão', () async {
    final id = await install();
    final app = manager.byId(id)!;
    ReleaseInfo release(String tag) => ReleaseInfo(
      tag: tag,
      name: tag,
      htmlUrl: Uri.parse('https://github.com'),
      prerelease: false,
      assets: const [],
    );

    expect(AppManager.isUpdate(app, release('v1.2.0')), isFalse);
    expect(AppManager.isUpdate(app, release('v1.2.1')), isTrue);
    expect(
      AppManager.isUpdate(app.copyWith(releaseTag: 'v9'), release('v9')),
      isFalse,
    );
    expect(
      AppManager.isUpdate(app.copyWith(releaseTag: 'v9'), release('v8')),
      isTrue,
    );
  });
}
