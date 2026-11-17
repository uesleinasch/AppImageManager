import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/launch_request.dart';
import 'src/services/app_manager.dart';
import 'src/services/app_paths.dart';
import 'src/services/desktop_integration.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final paths = AppPaths.fromEnvironment();
  final manager = AppManager(
    paths: paths,
    integration: DesktopIntegration(
      paths,
      managerExecutable: Platform.resolvedExecutable,
    ),
  )..load();
  unawaited(manager.watchLibrary());
  unawaited(
    manager.ready.then((_) async {
      await manager.pruneMissing();
      await manager.watchApplications();
    }),
  );
  runApp(
    AppImageManagerApp(manager: manager, launch: LaunchRequest.parse(args)),
  );
}
