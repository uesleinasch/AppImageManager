import 'dart:io';

import '../models/managed_app.dart';
import 'app_paths.dart';
import 'desktop_entry.dart';
import 'process_runner.dart';

class DesktopIntegration {
  const DesktopIntegration(this.paths, {this.runner = const ProcessRunner()});

  static final _fieldCode = RegExp(r'^%[a-zA-Z]$');

  final AppPaths paths;
  final ProcessRunner runner;

  String buildEntry(ManagedApp app, {required bool forAutostart}) {
    final args = DesktopEntry.splitExec(app.execArgs ?? '')
        .where((arg) => !forAutostart || !_fieldCode.hasMatch(arg))
        .map(DesktopEntry.quoteExecArg)
        .join(' ');
    final exec = [
      DesktopEntry.quoteExecArg(app.appImagePath),
      if (args.isNotEmpty) args,
    ].join(' ');

    return DesktopEntry.build({
      'Type': 'Application',
      'Version': '1.5',
      'Name': DesktopEntry.escapeValue(app.name),
      if (app.comment != null)
        'Comment': DesktopEntry.escapeValue(app.comment!),
      'Exec': DesktopEntry.escapeValue(exec),
      'TryExec': DesktopEntry.escapeValue(app.appImagePath),
      if (app.iconPath != null) 'Icon': DesktopEntry.escapeValue(app.iconPath!),
      'Terminal': 'false',
      if (app.categories.isNotEmpty)
        'Categories':
            '${app.categories.map(DesktopEntry.escapeValue).join(';')};',
      if (app.startupWmClass != null)
        'StartupWMClass': DesktopEntry.escapeValue(app.startupWmClass!),
      if (app.version != null)
        'X-AppImage-Version': DesktopEntry.escapeValue(app.version!),
      'X-AppImageManager-Id': app.id,
      if (forAutostart) 'X-GNOME-Autostart-enabled': 'true',
    });
  }

  Future<void> sync(ManagedApp app) async {
    await _syncFile(
      paths.menuEntryPath(app.id),
      app.menuEntry ? buildEntry(app, forAutostart: false) : null,
    );
    await _syncFile(
      paths.autostartEntryPath(app.id),
      app.autostart ? buildEntry(app, forAutostart: true) : null,
    );
    await _refreshDesktopDatabase();
  }

  Future<void> removeAll(String id) async {
    await _syncFile(paths.menuEntryPath(id), null);
    await _syncFile(paths.autostartEntryPath(id), null);
    await _refreshDesktopDatabase();
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
