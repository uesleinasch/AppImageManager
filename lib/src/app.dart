import 'package:flutter/material.dart';

import 'services/app_manager.dart';
import 'ui/home_page.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
const repositoryUrl = 'https://github.com/uesleinasch/AppImageManager';

class AppImageManagerApp extends StatelessWidget {
  const AppImageManagerApp({super.key, required this.manager});

  final AppManager manager;

  static const _seed = Color(0xFF2B6CB0);

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppImage Manager',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomePage(manager: manager),
    );
  }
}
