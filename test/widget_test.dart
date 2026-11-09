import 'dart:io';

import 'package:appimage_manager/src/app.dart';
import 'package:appimage_manager/src/models/managed_app.dart';
import 'package:appimage_manager/src/services/app_manager.dart';
import 'package:appimage_manager/src/services/app_paths.dart';
import 'package:appimage_manager/src/services/app_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppPaths paths;

  setUp(() {
    root = Directory.systemTemp.createTempSync('widget-test-');
    paths = AppPaths.underRoot(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('mostra estado vazio quando não há aplicativos', (tester) async {
    final manager = AppManager(paths: paths);
    await tester.runAsync(manager.load);
    await tester.pumpWidget(AppImageManagerApp(manager: manager));

    expect(find.text('Nenhum AppImage gerenciado'), findsOneWidget);
    expect(find.text('Adicionar AppImage'), findsOneWidget);
  });

  testWidgets('lista aplicativos e abre detalhes', (tester) async {
    await tester.runAsync(
      () => AppRepository(paths.libraryFile).save([
        ManagedApp(
          id: 'tool',
          name: 'Tool',
          appImagePath: paths.appImagePath('tool'),
          installedAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          version: '1.2.0',
        ),
      ]),
    );
    final manager = AppManager(paths: paths);
    await tester.runAsync(manager.load);

    await tester.pumpWidget(AppImageManagerApp(manager: manager));
    expect(find.text('Tool'), findsOneWidget);
    expect(find.text('1.2.0'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    await tester.tap(find.text('Tool'));
    await tester.pumpAndSettle();
    expect(find.text('Integração com o sistema'), findsOneWidget);
    expect(find.text('Iniciar com o sistema'), findsOneWidget);
  });
}
