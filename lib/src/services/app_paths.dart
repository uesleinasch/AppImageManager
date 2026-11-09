import 'dart:io';

import 'package:path/path.dart' as p;

class AppPaths {
  const AppPaths({
    required this.home,
    required this.configHome,
    required this.dataHome,
    required this.cacheHome,
  });

  factory AppPaths.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? Directory.current.path;

    String xdg(String key, String fallback) {
      final value = env[key];
      if (value != null && value.isNotEmpty && p.isAbsolute(value)) {
        return value;
      }
      return p.join(home, fallback);
    }

    return AppPaths(
      home: home,
      configHome: xdg('XDG_CONFIG_HOME', '.config'),
      dataHome: xdg('XDG_DATA_HOME', p.join('.local', 'share')),
      cacheHome: xdg('XDG_CACHE_HOME', '.cache'),
    );
  }

  factory AppPaths.underRoot(String root) => AppPaths(
    home: root,
    configHome: p.join(root, '.config'),
    dataHome: p.join(root, '.local', 'share'),
    cacheHome: p.join(root, '.cache'),
  );

  static const appDirName = 'appimage-manager';
  static const desktopFilePrefix = 'appimagemanager-';

  final String home;
  final String configHome;
  final String dataHome;
  final String cacheHome;

  String get stagingDir => p.join(cacheHome, appDirName, 'staging');
  String get appsDir => p.join(home, 'Applications');
  String get configDir => p.join(configHome, appDirName);
  String get libraryFile => p.join(configDir, 'library.json');
  String get iconsDir => p.join(dataHome, appDirName, 'icons');
  String get applicationsDir => p.join(dataHome, 'applications');
  String get autostartDir => p.join(configHome, 'autostart');

  String appImagePath(String id) => p.join(appsDir, '$id.AppImage');

  String menuEntryPath(String id) =>
      p.join(applicationsDir, '$desktopFilePrefix$id.desktop');

  String autostartEntryPath(String id) =>
      p.join(autostartDir, '$desktopFilePrefix$id.desktop');
}
