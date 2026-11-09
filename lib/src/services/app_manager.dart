import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/github_source.dart';
import '../models/managed_app.dart';
import 'app_paths.dart';
import 'app_repository.dart';
import 'appimage_inspector.dart';
import 'desktop_integration.dart';
import 'github_release_service.dart';
import 'process_runner.dart';
import 'version.dart';

class InstallDraft {
  const InstallDraft({
    required this.sourcePath,
    required this.stagingDir,
    required this.stagedFile,
    required this.metadata,
  });

  final String sourcePath;
  final String stagingDir;
  final String stagedFile;
  final AppImageMetadata metadata;
}

class AppTask {
  const AppTask(this.label, {this.progress});

  final String label;
  final double? progress;
}

class AppManagerException implements Exception {
  const AppManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppManager extends ChangeNotifier {
  AppManager({
    required this.paths,
    AppRepository? repository,
    AppImageInspector? inspector,
    DesktopIntegration? integration,
    GitHubReleaseService? github,
    ProcessRunner? runner,
    DateTime Function()? clock,
  }) : _runner = runner ?? const ProcessRunner(),
       _repository = repository ?? AppRepository(paths.libraryFile),
       _inspector =
           inspector ??
           AppImageInspector(runner: runner ?? const ProcessRunner()),
       _integration =
           integration ??
           DesktopIntegration(paths, runner: runner ?? const ProcessRunner()),
       _github =
           github ??
           GitHubReleaseService(token: Platform.environment['GITHUB_TOKEN']),
       _clock = clock ?? DateTime.now;

  final AppPaths paths;
  final ProcessRunner _runner;
  final AppRepository _repository;
  final AppImageInspector _inspector;
  final DesktopIntegration _integration;
  final GitHubReleaseService _github;
  final DateTime Function() _clock;

  List<ManagedApp> _apps = [];
  final Map<String, AppTask> _tasks = {};
  final Map<String, ReleaseInfo> _updates = {};
  bool _loading = true;
  bool _checkingAll = false;
  Object? _loadError;

  bool get loading => _loading;
  bool get checkingAll => _checkingAll;
  Object? get loadError => _loadError;

  UnmodifiableListView<ManagedApp> get apps => UnmodifiableListView(
    [..._apps]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  ManagedApp? byId(String id) => _apps.where((a) => a.id == id).firstOrNull;
  AppTask? taskFor(String id) => _tasks[id];
  ReleaseInfo? updateFor(String id) => _updates[id];
  int get availableUpdates => _updates.length;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _apps = await _repository.load();
    } catch (error) {
      _loadError = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<InstallDraft> prepareInstall(String sourcePath) async {
    await AppImageInspector.detectType(sourcePath);
    final stagingDir = await _createStagingDir();
    try {
      final staged = p.join(stagingDir.path, 'candidate.AppImage');
      await File(sourcePath).copy(staged);
      await _makeExecutable(staged);
      final metadata = await _inspector.inspect(
        staged,
        workDir: stagingDir.path,
        originalFileName: p.basename(sourcePath),
      );
      return InstallDraft(
        sourcePath: sourcePath,
        stagingDir: stagingDir.path,
        stagedFile: staged,
        metadata: metadata,
      );
    } catch (_) {
      await _deleteQuietly(stagingDir);
      rethrow;
    }
  }

  Future<void> discardDraft(InstallDraft draft) =>
      _deleteQuietly(Directory(draft.stagingDir));

  Future<ManagedApp> install(
    InstallDraft draft, {
    required String name,
    bool menuEntry = true,
    bool autostart = false,
    GitHubSource? github,
    bool removeOriginal = false,
  }) async {
    final displayName = name.trim().isEmpty ? draft.metadata.name : name.trim();
    final id = await _uniqueId(displayName);
    final target = paths.appImagePath(id);
    final now = _clock();

    try {
      await _placeFile(draft.stagedFile, target);
      final iconPath = await _storeIcon(id, draft.metadata.iconFile, null);
      var app = ManagedApp(
        id: id,
        name: displayName,
        appImagePath: target,
        installedAt: now,
        updatedAt: now,
        version: draft.metadata.version,
        comment: draft.metadata.comment,
        iconPath: iconPath,
        categories: draft.metadata.categories,
        execArgs: draft.metadata.execArgs,
        startupWmClass: draft.metadata.startupWmClass,
        menuEntry: menuEntry,
        autostart: autostart,
        github: github,
      );
      await _integration.sync(app);
      _apps = [..._apps, app];
      await _repository.save(_apps);

      if (removeOriginal &&
          p.canonicalize(draft.sourcePath) != p.canonicalize(target)) {
        await _deleteQuietly(File(draft.sourcePath));
      }
      notifyListeners();
      return app;
    } finally {
      await discardDraft(draft);
    }
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppManagerException('O nome não pode ficar vazio.');
    }
    await _commit(_require(id).copyWith(name: trimmed), syncDesktop: true);
  }

  Future<void> setMenuEntry(String id, bool enabled) =>
      _commit(_require(id).copyWith(menuEntry: enabled), syncDesktop: true);

  Future<void> setAutostart(String id, bool enabled) =>
      _commit(_require(id).copyWith(autostart: enabled), syncDesktop: true);

  Future<void> setUpdateSource(String id, GitHubSource? source) async {
    final app = _require(id);
    _updates.remove(id);
    await _commit(
      app.copyWith(
        github: source,
        releaseTag: source?.slug == app.github?.slug ? app.releaseTag : null,
      ),
    );
  }

  Future<void> updateFromFile(String id, String sourcePath) async {
    await _runTask(id, 'Atualizando a partir de arquivo', (progress) async {
      final draft = await prepareInstall(sourcePath);
      try {
        await _replaceInstalled(
          _require(id),
          draft.stagedFile,
          draft.metadata,
          releaseTag: null,
          fallbackVersion: null,
        );
      } finally {
        await discardDraft(draft);
      }
    });
  }

  Future<ReleaseInfo?> checkForUpdate(String id) async {
    final app = _require(id);
    final source = app.github;
    if (source == null) {
      throw const AppManagerException(
        'Este aplicativo não está vinculado a um repositório do GitHub.',
      );
    }
    final release = await _github.latestRelease(source);
    final hasUpdate = isUpdate(app, release);
    if (hasUpdate) {
      _updates[id] = release;
    } else {
      _updates.remove(id);
    }
    await _commit(app.copyWith(lastCheckedAt: _clock()));
    return hasUpdate ? release : null;
  }

  static bool isUpdate(ManagedApp app, ReleaseInfo release) {
    if (app.releaseTag != null) return app.releaseTag != release.tag;
    final current = app.version;
    if (current == null || current.isEmpty) return true;
    return isNewerVersion(release.version, current);
  }

  Future<List<String>> checkAllUpdates() async {
    if (_checkingAll) return const [];
    _checkingAll = true;
    notifyListeners();
    final errors = <String>[];
    try {
      for (final app in _apps.where((a) => a.usesGitHub).toList()) {
        try {
          await checkForUpdate(app.id);
        } catch (error) {
          errors.add('${app.name}: $error');
        }
      }
    } finally {
      _checkingAll = false;
      notifyListeners();
    }
    return errors;
  }

  Future<void> applyGitHubUpdate(String id) async {
    await _runTask(id, 'Baixando atualização', (progress) async {
      final app = _require(id);
      final source = app.github;
      if (source == null) {
        throw const AppManagerException('Nenhuma fonte do GitHub configurada.');
      }
      final release = _updates[id] ?? await _github.latestRelease(source);
      final asset = GitHubReleaseService.selectAsset(
        release,
        pattern: source.assetPattern,
        architecture: GitHubReleaseService.currentArchitecture(),
      );
      if (asset == null) {
        throw AppManagerException(
          'Nenhum arquivo .AppImage compatível em ${release.tag}. '
          'Ajuste o padrão de arquivo nas configurações de atualização.',
        );
      }

      final stagingDir = await _createStagingDir();
      try {
        final staged = p.join(stagingDir.path, 'candidate.AppImage');
        await _github.download(
          asset,
          staged,
          onProgress: (received, total) =>
              progress(total == null || total == 0 ? null : received / total),
        );
        progress(null);
        await AppImageInspector.detectType(staged);
        await _makeExecutable(staged);
        final metadata = await _inspector.inspect(
          staged,
          workDir: stagingDir.path,
          originalFileName: asset.name,
        );
        await _replaceInstalled(
          _require(id),
          staged,
          metadata,
          releaseTag: release.tag,
          fallbackVersion: release.version,
        );
        _updates.remove(id);
      } finally {
        await _deleteQuietly(stagingDir);
      }
    });
  }

  Future<void> remove(String id, {bool deleteFile = true}) async {
    final app = _require(id);
    await _integration.removeAll(id);
    if (deleteFile) await _deleteQuietly(File(app.appImagePath));
    if (app.iconPath != null && p.isWithin(paths.iconsDir, app.iconPath!)) {
      await _deleteQuietly(File(app.iconPath!));
    }
    _apps = _apps.where((a) => a.id != id).toList();
    _updates.remove(id);
    await _repository.save(_apps);
    notifyListeners();
  }

  Future<void> launch(String id) async {
    final app = _require(id);
    if (!await File(app.appImagePath).exists()) {
      throw AppManagerException('Arquivo não encontrado: ${app.appImagePath}');
    }
    await _runner.startDetached(
      app.appImagePath,
      const [],
      workingDirectory: paths.home,
    );
  }

  Future<void> _replaceInstalled(
    ManagedApp app,
    String stagedFile,
    AppImageMetadata metadata, {
    required String? releaseTag,
    required String? fallbackVersion,
  }) async {
    await _placeFile(stagedFile, app.appImagePath);
    final iconPath = await _storeIcon(app.id, metadata.iconFile, app.iconPath);
    await _commit(
      app.copyWith(
        updatedAt: _clock(),
        version: metadata.version ?? fallbackVersion ?? app.version,
        comment: metadata.comment ?? app.comment,
        iconPath: iconPath,
        categories: metadata.categories.isEmpty
            ? app.categories
            : metadata.categories,
        execArgs: metadata.execArgs ?? app.execArgs,
        startupWmClass: metadata.startupWmClass ?? app.startupWmClass,
        releaseTag: releaseTag,
      ),
      syncDesktop: true,
    );
  }

  Future<void> _runTask(
    String id,
    String label,
    Future<void> Function(void Function(double? progress) progress) body,
  ) async {
    if (_tasks.containsKey(id)) {
      throw const AppManagerException(
        'Já existe uma operação em andamento para este aplicativo.',
      );
    }
    _tasks[id] = AppTask(label);
    notifyListeners();
    try {
      await body((value) {
        _tasks[id] = AppTask(label, progress: value);
        notifyListeners();
      });
    } finally {
      _tasks.remove(id);
      notifyListeners();
    }
  }

  ManagedApp _require(String id) {
    final app = byId(id);
    if (app == null) {
      throw const AppManagerException('Aplicativo não encontrado.');
    }
    return app;
  }

  Future<void> _commit(ManagedApp updated, {bool syncDesktop = false}) async {
    if (syncDesktop) await _integration.sync(updated);
    _apps = [for (final app in _apps) app.id == updated.id ? updated : app];
    await _repository.save(_apps);
    notifyListeners();
  }

  Future<String> _uniqueId(String name) async {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final slug = base.isEmpty ? 'app' : base;
    var candidate = slug;
    var suffix = 2;
    while (byId(candidate) != null ||
        await File(paths.appImagePath(candidate)).exists()) {
      candidate = '$slug-${suffix++}';
    }
    return candidate;
  }

  Future<Directory> _createStagingDir() async {
    final root = Directory(paths.stagingDir);
    await root.create(recursive: true);
    return root.createTemp('job-');
  }

  Future<void> _placeFile(String source, String target) async {
    await Directory(p.dirname(target)).create(recursive: true);
    final partial = '$target.part';
    await File(source).copy(partial);
    await _makeExecutable(partial);
    await File(partial).rename(target);
  }

  Future<String?> _storeIcon(
    String id,
    String? iconFile,
    String? previous,
  ) async {
    if (iconFile == null) return previous;
    final file = File(iconFile);
    if (!await file.exists()) return previous;

    final bytes = await file
        .openRead(0, 1024)
        .expand((chunk) => chunk)
        .toList();
    final extension = AppImageInspector.imageExtension(bytes);
    if (extension == null) return previous;

    await Directory(paths.iconsDir).create(recursive: true);
    final target = p.join(
      paths.iconsDir,
      '$id-${_clock().millisecondsSinceEpoch}.$extension',
    );
    await file.copy(target);
    if (previous != null &&
        previous != target &&
        p.isWithin(paths.iconsDir, previous)) {
      await _deleteQuietly(File(previous));
    }
    return target;
  }

  Future<void> _makeExecutable(String path) async {
    final result = await _runner.run('chmod', ['755', path]);
    if (!result.succeeded) {
      throw AppManagerException(
        'Não foi possível tornar o arquivo executável: ${result.stderr.trim()}',
      );
    }
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } on FileSystemException {
      return;
    }
  }

  @override
  void dispose() {
    _github.close();
    super.dispose();
  }
}
