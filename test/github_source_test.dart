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
}
