import 'dart:convert';
import 'dart:io';

import 'package:appimage_manager/src/models/github_source.dart';
import 'package:appimage_manager/src/services/github_release_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

ReleaseInfo _release(List<String> assetNames) => ReleaseInfo(
  tag: 'v1.0.0',
  name: 'v1.0.0',
  htmlUrl: Uri.parse('https://github.com/a/b/releases/tag/v1.0.0'),
  prerelease: false,
  assets: [
    for (final name in assetNames)
      ReleaseAsset(
        name: name,
        downloadUrl: Uri.parse('https://example.com/$name'),
        size: 10,
      ),
  ],
);

Map<String, dynamic> _releaseJson(
  String tag, {
  bool draft = false,
  bool prerelease = false,
}) => {
  'tag_name': tag,
  'name': '',
  'html_url': 'https://github.com/a/b/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'published_at': '2026-10-01T12:00:00Z',
  'assets': [
    {
      'name': 'App-$tag-x86_64.AppImage',
      'browser_download_url':
          'https://github.com/a/b/releases/download/$tag/App.AppImage',
      'size': 4,
    },
  ],
};

void main() {
  group('selectAsset', () {
    test('ignora arquivos que não são AppImage', () {
      final release = _release([
        'App.AppImage.zsync',
        'App.tar.gz',
        'App.AppImage',
      ]);
      expect(GitHubReleaseService.selectAsset(release)?.name, 'App.AppImage');
    });

    test('prefere a arquitetura atual', () {
      final release = _release(['App-arm64.AppImage', 'App-x86_64.AppImage']);
      expect(
        GitHubReleaseService.selectAsset(release, architecture: 'x86_64')?.name,
        'App-x86_64.AppImage',
      );
      expect(
        GitHubReleaseService.selectAsset(
          release,
          architecture: 'aarch64',
        )?.name,
        'App-arm64.AppImage',
      );
    });

    test('evita outras arquiteturas quando a atual não é citada', () {
      final release = _release(['App-arm64.AppImage', 'App.AppImage']);
      expect(
        GitHubReleaseService.selectAsset(release, architecture: 'x86_64')?.name,
        'App.AppImage',
      );
    });

    test('aplica padrão glob sem diferenciar maiúsculas', () {
      final release = _release([
        'App-1.0.AppImage',
        'App-Portable-1.0.AppImage',
      ]);
      expect(
        GitHubReleaseService.selectAsset(
          release,
          pattern: 'app-portable-*',
        )?.name,
        'App-Portable-1.0.AppImage',
      );
      expect(
        GitHubReleaseService.selectAsset(release, pattern: 'nada*'),
        isNull,
      );
    });
  });

  group('latestRelease', () {
    test('usa /releases/latest por padrão', () async {
      late Uri requested;
      final service = GitHubReleaseService(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode(_releaseJson('v2.1.0')), 200);
        }),
      );
      final release = await service.latestRelease(
        const GitHubSource(owner: 'a', repo: 'b'),
      );
      expect(requested.path, '/repos/a/b/releases/latest');
      expect(release.tag, 'v2.1.0');
      expect(release.name, 'v2.1.0');
      expect(release.version, '2.1.0');
      expect(release.assets.single.name, 'App-v2.1.0-x86_64.AppImage');
    });

    test(
      'com pré-lançamentos pega o primeiro release que não é rascunho',
      () async {
        final service = GitHubReleaseService(
          client: MockClient((request) async {
            expect(request.url.path, '/repos/a/b/releases');
            return http.Response(
              jsonEncode([
                _releaseJson('v3.0.0', draft: true),
                _releaseJson('v3.0.0-rc.1', prerelease: true),
                _releaseJson('v2.0.0'),
              ]),
              200,
            );
          }),
        );
        final release = await service.latestRelease(
          const GitHubSource(owner: 'a', repo: 'b', includePrereleases: true),
        );
        expect(release.tag, 'v3.0.0-rc.1');
      },
    );

    test('traduz 404 em mensagem amigável', () async {
      final service = GitHubReleaseService(
        client: MockClient((_) async => http.Response('{}', 404)),
      );
      expect(
        service.latestRelease(const GitHubSource(owner: 'a', repo: 'b')),
        throwsA(isA<GitHubException>()),
      );
    });

    test('envia token quando configurado', () async {
      final service = GitHubReleaseService(
        token: 'abc',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer abc');
          return http.Response(jsonEncode(_releaseJson('v1.0.0')), 200);
        }),
      );
      await service.latestRelease(const GitHubSource(owner: 'a', repo: 'b'));
    });
  });

  test('download grava o arquivo e informa progresso', () async {
    final dir = await Directory.systemTemp.createTemp('download-test-');
    addTearDown(() => dir.delete(recursive: true));
    final service = GitHubReleaseService(
      client: MockClient((_) async => http.Response.bytes([1, 2, 3, 4], 200)),
    );
    final progress = <int>[];
    final destination = p.join(dir.path, 'out.AppImage');
    await service.download(
      ReleaseAsset(
        name: 'x.AppImage',
        downloadUrl: Uri.parse('https://e.com/x'),
        size: 4,
      ),
      destination,
      onProgress: (received, _) => progress.add(received),
    );
    expect(await File(destination).readAsBytes(), [1, 2, 3, 4]);
    expect(progress.last, 4);
  });
}
