import 'package:appimage_manager/src/models/github_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHubSource.tryParse', () {
    for (final input in [
      'obsidianmd/obsidian-releases',
      'https://github.com/obsidianmd/obsidian-releases',
      'https://github.com/obsidianmd/obsidian-releases/releases/latest',
      'github.com/obsidianmd/obsidian-releases.git',
      'git@github.com:obsidianmd/obsidian-releases.git',
      '  obsidianmd/obsidian-releases/  ',
    ]) {
      test('aceita "$input"', () {
        final source = GitHubSource.tryParse(input);
        expect(source, isNotNull);
        expect(source!.slug, 'obsidianmd/obsidian-releases');
      });
    }

    for (final input in [
      '',
      'obsidian',
      'https://gitlab.com/a/b',
      'dono inválido/repo',
    ]) {
      test('rejeita "$input"', () {
        expect(GitHubSource.tryParse(input), isNull);
      });
    }

    test('normaliza padrão vazio para null', () {
      final source = GitHubSource.tryParse('a/b', assetPattern: '  ');
      expect(source!.assetPattern, isNull);
    });
  });

  test('serializa e desserializa', () {
    const source = GitHubSource(
      owner: 'a',
      repo: 'b',
      assetPattern: '*x86_64.AppImage',
      includePrereleases: true,
    );
    expect(GitHubSource.fromJson(source.toJson()), source);
  });

  group('GitHubSource.fromUpdateInformation', () {
    test('gh-releases-zsync vira fonte com padrão sem .zsync', () {
      final source = GitHubSource.fromUpdateInformation(
        'gh-releases-zsync|acme|tool|latest|Tool-*x86_64.AppImage.zsync',
      )!;
      expect(source.slug, 'acme/tool');
      expect(source.assetPattern, 'Tool-*x86_64.AppImage');
      expect(source.includePrereleases, isFalse);
    });

    test('latest-pre inclui pré-lançamentos', () {
      final source = GitHubSource.fromUpdateInformation(
        'gh-releases-zsync|acme|tool|latest-pre|*.zsync',
      )!;
      expect(source.includePrereleases, isTrue);
      expect(source.assetPattern, isNull);
    });

    test('zsync apontando para latest/download do GitHub', () {
      final source = GitHubSource.fromUpdateInformation(
        'zsync|https://github.com/acme/tool/releases/latest/download/Tool%20x64.AppImage.zsync',
      )!;
      expect(source.slug, 'acme/tool');
      expect(source.assetPattern, 'Tool x64.AppImage');
    });

    test('ignora formatos sem acompanhamento do último release', () {
      for (final info in [
        null,
        '',
        'gh-releases-zsync|acme|tool|v1.0|Tool.zsync',
        'zsync|https://example.com/Tool.AppImage.zsync',
        'zsync|https://github.com/acme/tool/releases/download/v1/T.zsync',
        'pling-v1-zsync|123|Tool.zsync',
      ]) {
        expect(GitHubSource.fromUpdateInformation(info), isNull, reason: info);
      }
    });
  });
}
