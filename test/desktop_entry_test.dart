import 'package:appimage_manager/src/models/github_source.dart';
import 'package:appimage_manager/src/models/managed_app.dart';
import 'package:appimage_manager/src/services/app_paths.dart';
import 'package:appimage_manager/src/services/desktop_entry.dart';
import 'package:appimage_manager/src/services/desktop_integration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopEntry.parse', () {
    const content = '''
# comentário
[Desktop Entry]
Name=Editor
Name[pt_BR]=Editor de Texto
Comment=Linha 1\\nLinha 2
Exec=AppRun --no-sandbox %U
Icon=editor
Categories=Development;TextEditor;
X-AppImage-Version=3.1.0

[Desktop Action new-window]
Name=Nova janela
Exec=AppRun --new-window
''';

    test('lê o grupo principal e ignora ações', () {
      final entry = DesktopEntry.parse(content);
      expect(entry['Name'], 'Editor');
      expect(entry['Exec'], 'AppRun --no-sandbox %U');
      expect(entry['X-AppImage-Version'], '3.1.0');
      expect(entry.list('Categories'), ['Development', 'TextEditor']);
      expect(entry['Comment'], 'Linha 1\nLinha 2');
    });

    test('prefere chave localizada quando o locale combina', () {
      expect(
        DesktopEntry.parse(content, locale: 'pt_BR.UTF-8')['Name'],
        'Editor de Texto',
      );
      expect(
        DesktopEntry.parse(content, locale: 'en_US.UTF-8')['Name'],
        'Editor',
      );
    });

    test('extrai argumentos do Exec', () {
      expect(DesktopEntry.parse(content).execArguments, '--no-sandbox %U');
    });
  });

  group('Exec quoting', () {
    test('não cita argumentos simples', () {
      expect(
        DesktopEntry.quoteExecArg('/opt/app.AppImage'),
        '/opt/app.AppImage',
      );
    });

    test('cita e escapa caracteres reservados', () {
      expect(
        DesktopEntry.quoteExecArg('/home/me/My Apps/a.AppImage'),
        '"/home/me/My Apps/a.AppImage"',
      );
      expect(DesktopEntry.quoteExecArg(r'/tmp/$x"y'), r'"/tmp/\$x\"y"');
    });

    test('splitExec respeita aspas', () {
      expect(DesktopEntry.splitExec(r'"/a b/c" --flag "x \"y\"" %F'), [
        '/a b/c',
        '--flag',
        'x "y"',
        '%F',
      ]);
    });
  });

  group('DesktopIntegration.buildEntry', () {
    final integration = DesktopIntegration(AppPaths.underRoot('/home/test'));
    final app = ManagedApp(
      id: 'editor',
      name: 'Editor',
      appImagePath: '/home/test/Applications/editor.AppImage',
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
      version: '3.1.0',
      iconPath: '/home/test/.local/share/appimage-manager/icons/editor-1.png',
      categories: const ['Development'],
      execArgs: '--no-sandbox %U',
      github: const GitHubSource(owner: 'a', repo: 'b'),
    );

    test('gera entrada de menu com argumentos originais', () {
      final entry = DesktopEntry.parse(
        integration.buildEntry(app, forAutostart: false),
      );
      expect(
        entry['Exec'],
        '/home/test/Applications/editor.AppImage --no-sandbox %U',
      );
      expect(entry['Icon'], app.iconPath);
      expect(entry['Categories'], 'Development;');
      expect(entry['X-AppImageManager-Id'], 'editor');
      expect(entry['X-GNOME-Autostart-enabled'], isNull);
    });

    test('StartupWMClass usa a classe personalizada quando existe', () {
      String? wmClass(ManagedApp value) => DesktopEntry.parse(
        integration.buildEntry(value, forAutostart: false),
      )['StartupWMClass'];

      final withOriginal = app.copyWith(startupWmClass: 'Editor');
      expect(wmClass(withOriginal), 'Editor');
      expect(
        wmClass(withOriginal.copyWith(wmClassOverride: 'br.com.editor')),
        'br.com.editor',
      );
    });

    test('lê os tipos declarados em pacote de mime', () {
      expect(
        DesktopIntegration.declaredMimeTypes(
          '<mime-info><mime-type type="a/b"><glob pattern="*.b"/></mime-type>'
          "<mime-type  type='c/d+json'/></mime-info>",
        ),
        {'a/b', 'c/d+json'},
      );
      expect(
        DesktopIntegration.isValidMimeType('application/vnd.x+json'),
        isTrue,
      );
      expect(DesktopIntegration.isValidMimeType('texto'), isFalse);
    });

    test('ações Atualizar e Remover chamam o AppImage Manager', () {
      final withActions = DesktopIntegration(
        AppPaths.underRoot('/home/test'),
        managerExecutable: '/opt/app image/appimage_manager',
      );
      final content = withActions.buildEntry(app, forAutostart: false);
      final entry = DesktopEntry.parse(content);

      expect(
        entry['Actions'],
        'appimagemanager-update;appimagemanager-remove;',
      );
      expect(entry['Exec'], contains('editor.AppImage'));
      expect(
        content,
        contains(
          '[Desktop Action appimagemanager-update]\n'
          'Name=Atualizar (AppImage Manager)\n'
          'Exec="/opt/app image/appimage_manager" --update editor\n',
        ),
      );
      expect(content, contains('--remove editor'));

      final autostart = withActions.buildEntry(app, forAutostart: true);
      expect(DesktopEntry.parse(autostart)['Actions'], isNull);
      expect(autostart, isNot(contains('Desktop Action')));
    });

    test('valida id de .desktop', () {
      expect(DesktopIntegration.isValidDesktopId('dev.acme.Tool_2-x'), isTrue);
      expect(DesktopIntegration.isValidDesktopId('../evil'), isFalse);
      expect(DesktopIntegration.isValidDesktopId('a b'), isFalse);
      expect(DesktopIntegration.isValidDesktopId('appimagemanager-x'), isFalse);
    });

    test('entrada de autostart remove field codes', () {
      final entry = DesktopEntry.parse(
        integration.buildEntry(app, forAutostart: true),
      );
      expect(
        entry['Exec'],
        '/home/test/Applications/editor.AppImage --no-sandbox',
      );
      expect(entry['X-GNOME-Autostart-enabled'], 'true');
    });
  });
}
