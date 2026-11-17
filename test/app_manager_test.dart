import 'dart:convert';
import 'dart:io';

import 'package:appimage_manager/src/models/app_settings.dart';
import 'package:appimage_manager/src/models/github_source.dart';
import 'package:appimage_manager/src/services/app_manager.dart';
import 'package:appimage_manager/src/services/app_paths.dart';
import 'package:appimage_manager/src/services/appimage_inspector.dart';
import 'package:appimage_manager/src/services/desktop_entry.dart';
import 'package:appimage_manager/src/services/github_release_service.dart';
import 'package:appimage_manager/src/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

const _fakeElf = [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1, 0, 0, 0, 0, 0, 1, 2, 3];

class _FakeInspector extends AppImageInspector {
  String? desktopId;
  List<String> mimeTypes = const [];
  Map<String, String> mimePackages = const {};

  @override
  Future<AppImageMetadata> inspect(
    String appImagePath, {
    required String workDir,
    required String originalFileName,
  }) async {
    final guess = AppImageInspector.guessFromFileName(originalFileName);
    final packages = <String>[];
    for (final MapEntry(key: name, value: xml) in mimePackages.entries) {
      final file = File(p.join(workDir, name));
      await file.writeAsString(xml);
      packages.add(file.path);
    }
    return AppImageMetadata(
      name: guess.name,
      version: guess.version,
      startupWmClass: desktopId == null ? null : 'Tool',
      desktopId: desktopId,
      mimeTypes: mimeTypes,
      mimePackages: packages,
    );
  }
}

class _RecordingRunner extends ProcessRunner {
  _RecordingRunner(this.stdout);

  final String stdout;
  final calls = <List<String>>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    calls.add([executable, ...arguments]);
    return ProcessOutput(0, stdout, '');
  }
}

const _boardXml =
    '<?xml version="1.0"?>\n'
    '<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">'
    '<mime-type type="application/vnd.tool+json">'
    '<glob pattern="*.tool"/></mime-type></mime-info>';

const _hijackXml =
    '<mime-info><mime-type type="application/pdf">'
    '<glob pattern="*.pdf"/></mime-type></mime-info>';

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

  test('byAppImagePath acha o app pelo arquivo instalado', () async {
    final id = await install();
    expect(manager.byAppImagePath(paths.appImagePath(id))?.id, id);
    expect(manager.byAppImagePath(download), isNull);
  });

  test('recarrega a biblioteca gravada por outra instância', () async {
    final id = await install();
    await manager.watchLibrary();

    final other = AppManager(paths: paths);
    await other.load();
    await other.rename(id, 'Renomeado fora');
    other.dispose();

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (manager.byId(id)!.name != 'Renomeado fora' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(manager.byId(id)!.name, 'Renomeado fora');
  });

  test('limpa apps cujo arquivo foi apagado', () async {
    final id = await install(autostart: true);
    final names = <String>[];
    final sub = manager.missingRemoved.listen(names.add);

    expect(await manager.pruneMissing(), isEmpty);
    await File(manager.byId(id)!.appImagePath).delete();
    expect(await manager.pruneMissing(), ['Tool']);

    await Future<void>.delayed(Duration.zero);
    expect(names, ['Tool']);
    expect(manager.byId(id), isNull);
    expect(await File(paths.menuEntryPath(id)).exists(), isFalse);
    expect(await File(paths.autostartEntryPath(id)).exists(), isFalse);
    await sub.cancel();
  });

  test('vigia ~/Applications e limpa ao apagar o arquivo', () async {
    final id = await install();
    await manager.watchApplications();
    await File(manager.byId(id)!.appImagePath).delete();

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (manager.byId(id) != null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(manager.byId(id), isNull);
  });

  test('atualizar não dispara a limpeza', () async {
    final id = await install();
    await manager.watchApplications();
    final newer = p.join(root.path, 'Downloads', 'Tool-1.4.0.AppImage');
    await File(newer).writeAsBytes(_fakeElf);

    await manager.updateFromFile(id, newer);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(manager.byId(id)?.version, '1.4.0');
  });

  test('configurações persistem entre instâncias', () async {
    expect(manager.settings.cleanupMissing, isTrue);
    expect(manager.settings.checkUpdatesOnStart, isFalse);

    await manager.updateSettings(
      const AppSettings(checkUpdatesOnStart: true, cleanupMissing: false),
    );

    final reloaded = AppManager(paths: paths);
    await reloaded.load();
    expect(reloaded.settings.checkUpdatesOnStart, isTrue);
    expect(reloaded.settings.cleanupMissing, isFalse);
    reloaded.dispose();
  });

  test('sem limpeza automática, app sem arquivo continua na lista', () async {
    final id = await install();
    await manager.updateSettings(const AppSettings(cleanupMissing: false));
    await File(manager.byId(id)!.appImagePath).delete();

    await manager.startBackgroundServices();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(manager.byId(id), isNotNull);
  });

  test('handler padrão de AppImage usa xdg-mime', () async {
    final runner = _RecordingRunner(
      'io.github.uesleinasch.appimage_manager.desktop\n',
    );
    final withRunner = AppManager(paths: paths, runner: runner);

    expect(await withRunner.isDefaultAppImageHandler(), isTrue);
    await withRunner.makeDefaultAppImageHandler();
    expect(runner.calls.last, [
      'xdg-mime',
      'default',
      'io.github.uesleinasch.appimage_manager.desktop',
      'application/vnd.appimage',
      'application/x-iso9660-appimage',
    ]);
    withRunner.dispose();
  });

  group('tipos de arquivo manuais', () {
    late String id;

    setUp(() async {
      File(p.join(paths.mimeDir, 'globs2'))
        ..createSync(recursive: true)
        ..writeAsStringSync('50:text/markdown:*.md\n');
      id = await install();
    });

    Future<DesktopEntry> menuEntry() async =>
        DesktopEntry.parse(await File(paths.menuEntryPath(id)).readAsString());

    File manualPackage() => File(
      p.join(paths.mimePackagesDir, '${paths.mimePackagePrefix(id)}manual.xml'),
    );

    test('extensão conhecida usa o tipo do sistema e adiciona %F', () async {
      expect(await manager.addFileType(id, '.md'), 'text/markdown');

      final app = manager.byId(id)!;
      expect(app.customMimeTypes, ['text/markdown']);
      expect(app.customTypeGlobs, isEmpty);
      final entry = await menuEntry();
      expect(entry['MimeType'], 'text/markdown;');
      expect(entry['Exec'], '${app.appImagePath} %F');
      expect(await manualPackage().exists(), isFalse);
    });

    test('extensão desconhecida cria tipo próprio com pacote XML', () async {
      expect(
        await manager.addFileType(id, '*.Zzz'),
        'application/x-appimagemanager-zzz',
      );

      expect(manager.byId(id)!.customTypeGlobs, {
        'application/x-appimagemanager-zzz': '*.zzz',
      });
      expect(await manualPackage().readAsString(), contains('*.zzz'));
      expect(
        (await menuEntry())['MimeType'],
        'application/x-appimagemanager-zzz;',
      );
    });

    test('tipo MIME direto, duplicado e entrada inválida', () async {
      await manager.addFileType(id, 'Text/Plain');
      expect(manager.byId(id)!.customMimeTypes, ['text/plain']);
      expect(
        () => manager.addFileType(id, 'text/plain'),
        throwsA(isA<AppManagerException>()),
      );
      expect(
        () => manager.addFileType(id, 'nada válido!'),
        throwsA(isA<AppManagerException>()),
      );
    });

    test('remover tipo manual limpa MimeType, %F e pacote', () async {
      final type = await manager.addFileType(id, '.zzz');
      await manager.removeFileType(id, type);

      final app = manager.byId(id)!;
      expect(app.customMimeTypes, isEmpty);
      expect(app.customTypeGlobs, isEmpty);
      final entry = await menuEntry();
      expect(entry['MimeType'], isNull);
      expect(entry['Exec'], app.appImagePath);
      expect(await manualPackage().exists(), isFalse);
    });
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

  group('nome do .desktop e classe da janela', () {
    late _FakeInspector inspector;
    late AppManager integrated;

    setUp(() async {
      inspector = _FakeInspector()..desktopId = 'tool';
      integrated = AppManager(paths: paths, inspector: inspector);
      await integrated.load();
    });

    tearDown(() => integrated.dispose());

    Future<String> installIntegrated() async {
      final draft = await integrated.prepareInstall(download);
      final app = await integrated.install(draft, name: 'Tool');
      return app.id;
    }

    String entryPath(String fileName) => paths.applicationEntryPath(fileName);

    test('usa o id do .desktop original no nome do atalho', () async {
      final id = await installIntegrated();
      final app = integrated.byId(id)!;

      expect(app.desktopId, 'tool');
      expect(app.menuEntryFile, 'tool.desktop');
      expect(integrated.menuEntryPath(app), entryPath('tool.desktop'));
      expect(await File(paths.menuEntryPath(id)).exists(), isFalse);
      final entry = DesktopEntry.parse(
        await File(entryPath('tool.desktop')).readAsString(),
      );
      expect(entry['StartupWMClass'], 'Tool');
      expect(entry['X-AppImageManager-Id'], id);
    });

    test('não sobrescreve .desktop de terceiros com o mesmo id', () async {
      final foreign = File(entryPath('tool.desktop'));
      await foreign.create(recursive: true);
      await foreign.writeAsString('[Desktop Entry]\nName=Outro\n');

      final id = await installIntegrated();

      expect(
        integrated.byId(id)!.menuEntryFile,
        'appimagemanager-tool.desktop',
      );
      expect(await File(paths.menuEntryPath(id)).exists(), isTrue);
      expect(await foreign.readAsString(), '[Desktop Entry]\nName=Outro\n');
    });

    test('segundo app com o mesmo id de .desktop usa o prefixo', () async {
      final first = await installIntegrated();
      final second = await installIntegrated();

      expect(integrated.byId(first)!.menuEntryFile, 'tool.desktop');
      expect(
        integrated.byId(second)!.menuEntryFile,
        'appimagemanager-$second.desktop',
      );
    });

    test('classe da janela personalizada sobrepõe a original', () async {
      final id = await installIntegrated();
      Future<String?> wmClass() async => DesktopEntry.parse(
        await File(entryPath('tool.desktop')).readAsString(),
      )['StartupWMClass'];

      await integrated.setWindowClass(id, '  br.com.acme.tool ');
      expect(integrated.byId(id)!.wmClassOverride, 'br.com.acme.tool');
      expect(await wmClass(), 'br.com.acme.tool');

      await integrated.updateFromFile(id, download);
      expect(await wmClass(), 'br.com.acme.tool');

      await integrated.setWindowClass(id, '');
      expect(integrated.byId(id)!.wmClassOverride, isNull);
      expect(await wmClass(), 'Tool');

      expect(
        () => integrated.setWindowClass(id, 'a\nExec=x'),
        throwsA(isA<AppManagerException>()),
      );
    });

    test('reparar integração migra atalho antigo para o id original', () async {
      inspector.desktopId = null;
      final id = await installIntegrated();
      expect(await File(paths.menuEntryPath(id)).exists(), isTrue);

      inspector.desktopId = 'tool';
      await integrated.repairIntegration(id);

      final app = integrated.byId(id)!;
      expect(app.desktopId, 'tool');
      expect(app.startupWmClass, 'Tool');
      expect(await File(paths.menuEntryPath(id)).exists(), isFalse);
      expect(await File(entryPath('tool.desktop')).exists(), isTrue);
      expect(integrated.taskFor(id), isNull);
    });

    test('reparar todos devolve erros por app', () async {
      final id = await installIntegrated();
      await File(integrated.byId(id)!.appImagePath).delete();

      final errors = await integrated.repairAllIntegrations();

      expect(errors, hasLength(1));
      expect(errors.single, startsWith('Tool:'));
      expect(integrated.repairingAll, isFalse);
    });

    group('associação de arquivos', () {
      setUp(() {
        inspector
          ..mimeTypes = ['application/vnd.tool+json', 'inválido']
          ..mimePackages = {'tool.xml': _boardXml, 'evil.xml': _hijackXml};
      });

      String installedPackage(String id) => p.join(
        paths.mimePackagesDir,
        '${paths.mimePackagePrefix(id)}tool.xml',
      );

      Future<String?> mimeEntry() async => DesktopEntry.parse(
        await File(entryPath('tool.desktop')).readAsString(),
      )['MimeType'];

      test('registra MimeType e instala só pacotes dos tipos do app', () async {
        final id = await installIntegrated();

        expect(integrated.byId(id)!.mimeTypes, ['application/vnd.tool+json']);
        expect(await mimeEntry(), 'application/vnd.tool+json;');
        expect(await File(installedPackage(id)).readAsString(), _boardXml);
        final installed = await Directory(paths.mimePackagesDir)
            .list()
            .map((e) => p.basename(e.path))
            .toList();
        expect(installed, ['${paths.mimePackagePrefix(id)}tool.xml']);
      });

      test('desligar remove MimeType e pacote; ligar restaura', () async {
        final id = await installIntegrated();

        await integrated.setFileAssociations(id, false);
        expect(await mimeEntry(), isNull);
        expect(await File(installedPackage(id)).exists(), isFalse);

        await integrated.setFileAssociations(id, true);
        expect(await mimeEntry(), 'application/vnd.tool+json;');
        expect(await File(installedPackage(id)).exists(), isTrue);
      });

      test('autostart não declara MimeType', () async {
        final id = await installIntegrated();
        await integrated.setAutostart(id, true);
        final entry = DesktopEntry.parse(
          await File(paths.autostartEntryPath(id)).readAsString(),
        );
        expect(entry['MimeType'], isNull);
      });

      test('remover apaga pacote e cópia guardada', () async {
        final id = await installIntegrated();
        await integrated.remove(id);
        expect(await File(installedPackage(id)).exists(), isFalse);
        expect(await Directory(paths.mimeStashDir(id)).exists(), isFalse);
      });

      test('atualização sem tipos de arquivo remove a associação', () async {
        final id = await installIntegrated();
        inspector
          ..mimeTypes = const []
          ..mimePackages = const {};

        await integrated.updateFromFile(id, download);

        expect(integrated.byId(id)!.mimeTypes, isEmpty);
        expect(await mimeEntry(), isNull);
        expect(await File(installedPackage(id)).exists(), isFalse);
      });
    });

    test('remover apaga o atalho com o id original', () async {
      final id = await installIntegrated();
      await integrated.remove(id);
      expect(await File(entryPath('tool.desktop')).exists(), isFalse);
    });
  });
}
