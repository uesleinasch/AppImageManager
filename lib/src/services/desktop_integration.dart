import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/managed_app.dart';
import 'app_paths.dart';
import 'desktop_entry.dart';
import 'process_runner.dart';

class DesktopIntegration {
  const DesktopIntegration(
    this.paths, {
    this.runner = const ProcessRunner(),
    this.managerExecutable,
  });

  static const ownerKey = 'X-AppImageManager-Id';

  static final _fieldCode = RegExp(r'^%[a-zA-Z]$');
  static final _desktopIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
  static final _mimeTypePattern = RegExp(r'^[\w.+-]+/[\w.+-]+$');
  static final _declaredMimeType = RegExp(
    r'''<mime-type\b[^>]*?\btype\s*=\s*["']([^"']+)["']''',
  );

  static const updateAction = 'appimagemanager-update';
  static const removeAction = 'appimagemanager-remove';

  final AppPaths paths;
  final ProcessRunner runner;
  final String? managerExecutable;

  static bool isValidDesktopId(String value) =>
      _desktopIdPattern.hasMatch(value) &&
      !value.startsWith(AppPaths.desktopFilePrefix);

  static bool isValidMimeType(String value) => _mimeTypePattern.hasMatch(value);

  static Set<String> declaredMimeTypes(String xml) => {
    for (final match in _declaredMimeType.allMatches(xml)) match[1]!,
  };

  String buildEntry(ManagedApp app, {required bool forAutostart}) {
    final args = DesktopEntry.splitExec(app.execArgs ?? '')
        .where((arg) => !forAutostart || !_fieldCode.hasMatch(arg))
        .map(DesktopEntry.quoteExecArg)
        .join(' ');
    final exec = [
      DesktopEntry.quoteExecArg(app.appImagePath),
      if (args.isNotEmpty) args,
    ].join(' ');
    final manager = forAutostart ? null : managerExecutable;

    String managerExec(String flag) => DesktopEntry.escapeValue(
      [manager!, flag, app.id].map(DesktopEntry.quoteExecArg).join(' '),
    );

    return DesktopEntry.build(
      {
        'Type': 'Application',
        'Version': '1.5',
        'Name': DesktopEntry.escapeValue(app.name),
        if (app.comment != null)
          'Comment': DesktopEntry.escapeValue(app.comment!),
        'Exec': DesktopEntry.escapeValue(exec),
        'TryExec': DesktopEntry.escapeValue(app.appImagePath),
        if (app.iconPath != null)
          'Icon': DesktopEntry.escapeValue(app.iconPath!),
        'Terminal': 'false',
        if (app.categories.isNotEmpty)
          'Categories':
              '${app.categories.map(DesktopEntry.escapeValue).join(';')};',
        if (!forAutostart && app.fileAssociations && app.mimeTypes.isNotEmpty)
          'MimeType':
              '${app.mimeTypes.map(DesktopEntry.escapeValue).join(';')};',
        if (app.windowClass != null)
          'StartupWMClass': DesktopEntry.escapeValue(app.windowClass!),
        if (app.version != null)
          'X-AppImage-Version': DesktopEntry.escapeValue(app.version!),
        ownerKey: app.id,
        if (manager != null) 'Actions': '$updateAction;$removeAction;',
        if (forAutostart) 'X-GNOME-Autostart-enabled': 'true',
      },
      groups: {
        if (manager != null) ...{
          'Desktop Action $updateAction': {
            'Name': 'Atualizar (AppImage Manager)',
            'Exec': managerExec('--update'),
          },
          'Desktop Action $removeAction': {
            'Name': 'Remover (AppImage Manager)',
            'Exec': managerExec('--remove'),
          },
        },
      },
    );
  }

  Future<String> menuEntryPathFor(ManagedApp app) async {
    final preferred = _preferredMenuEntryPath(app);
    if (preferred != null) {
      final file = File(preferred);
      if (!await file.exists() || await _isOwnedBy(file, app.id)) {
        return preferred;
      }
    }
    return paths.menuEntryPath(app.id);
  }

  Future<String> sync(ManagedApp app) async {
    final menuPath = await menuEntryPathFor(app);
    for (final path in await _ownedMenuPaths(app)) {
      if (path != menuPath) await _syncFile(path, null);
    }
    await _syncFile(
      menuPath,
      app.menuEntry ? buildEntry(app, forAutostart: false) : null,
    );
    await _syncFile(
      paths.autostartEntryPath(app.id),
      app.autostart ? buildEntry(app, forAutostart: true) : null,
    );
    await _syncMimePackages(app);
    await _refreshDesktopDatabase();
    return menuPath;
  }

  Future<void> removeAll(ManagedApp app) async {
    for (final path in await _ownedMenuPaths(app)) {
      await _syncFile(path, null);
    }
    await _syncFile(paths.autostartEntryPath(app.id), null);
    await _syncMimePackages(app.copyWith(fileAssociations: false));
    await _deleteDirectory(Directory(paths.mimeStashDir(app.id)));
    await _refreshDesktopDatabase();
  }

  Future<void> stashMimePackages(ManagedApp app, List<String> files) async {
    final stash = Directory(paths.mimeStashDir(app.id));
    await _deleteDirectory(stash);
    final allowed = app.mimeTypes.toSet();
    for (final source in files) {
      final String content;
      try {
        content = await File(source).readAsString();
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
      final declared = declaredMimeTypes(content);
      if (declared.isEmpty || !allowed.containsAll(declared)) continue;
      await stash.create(recursive: true);
      await File(p.join(stash.path, p.basename(source))).writeAsString(content);
    }
  }

  Future<void> _syncMimePackages(ManagedApp app) async {
    final prefix = paths.mimePackagePrefix(app.id);
    final desired = <String, File>{};
    final stash = Directory(paths.mimeStashDir(app.id));
    if (app.fileAssociations && app.menuEntry && await stash.exists()) {
      await for (final entity in stash.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.xml')) {
          desired['$prefix${p.basename(entity.path)}'] = entity;
        }
      }
    }

    var changed = false;
    final installed = Directory(paths.mimePackagesDir);
    if (await installed.exists()) {
      await for (final entity in installed.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name.startsWith(prefix) &&
            !desired.containsKey(name)) {
          await entity.delete();
          changed = true;
        }
      }
    }
    for (final MapEntry(key: name, value: source) in desired.entries) {
      final target = File(p.join(paths.mimePackagesDir, name));
      final content = await source.readAsString();
      if (await target.exists() && await target.readAsString() == content) {
        continue;
      }
      await _syncFile(target.path, content);
      changed = true;
    }
    if (changed) {
      await runner.tryRun('update-mime-database', [paths.mimeDir]);
    }
  }

  Future<void> _deleteDirectory(Directory dir) async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  String? _preferredMenuEntryPath(ManagedApp app) {
    final desktopId = app.desktopId;
    if (desktopId == null || !isValidDesktopId(desktopId)) return null;
    return paths.applicationEntryPath('$desktopId.desktop');
  }

  Future<Set<String>> _ownedMenuPaths(ManagedApp app) async {
    final owned = {paths.menuEntryPath(app.id)};
    final recorded = app.menuEntryFile;
    final preferred = _preferredMenuEntryPath(app);
    for (final candidate in [
      if (recorded != null && p.basename(recorded) == recorded)
        paths.applicationEntryPath(recorded),
      ?preferred,
    ]) {
      if (await _isOwnedBy(File(candidate), app.id)) owned.add(candidate);
    }
    return owned;
  }

  Future<bool> _isOwnedBy(File file, String id) async {
    try {
      if (!await file.exists()) return false;
      return DesktopEntry.parse(await file.readAsString())[ownerKey] == id;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _syncFile(String path, String? content) async {
    final file = File(path);
    if (content == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temp = File('$path.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(path);
  }

  Future<void> _refreshDesktopDatabase() =>
      runner.tryRun('update-desktop-database', [paths.applicationsDir]);
}
