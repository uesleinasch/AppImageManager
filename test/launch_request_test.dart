import 'package:appimage_manager/src/launch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sem argumentos não há pedido', () {
    expect(LaunchRequest.parse(const []), isNull);
    expect(LaunchRequest.parse(const ['--update']), isNull);
  });

  test('ações do menu', () {
    final update = LaunchRequest.parse(const ['--update', 'tool']);
    expect(update, isA<UpdateAppRequest>());
    expect((update! as UpdateAppRequest).appId, 'tool');

    final remove = LaunchRequest.parse(const ['--remove', 'tool']);
    expect((remove! as RemoveAppRequest).appId, 'tool');
  });

  test('arquivo por caminho, --install ou URI file://', () {
    String? path(List<String> args) =>
        (LaunchRequest.parse(args) as InstallFileRequest?)?.path;

    expect(path(const ['/tmp/a.AppImage']), '/tmp/a.AppImage');
    expect(path(const ['--install', '/tmp/a.AppImage']), '/tmp/a.AppImage');
    expect(
      path(const ['file:///tmp/My%20App.AppImage']),
      '/tmp/My App.AppImage',
    );
  });
}
