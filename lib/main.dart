import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/app_manager.dart';
import 'src/services/app_paths.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = AppManager(paths: AppPaths.fromEnvironment())..load();
  runApp(AppImageManagerApp(manager: manager));
}
