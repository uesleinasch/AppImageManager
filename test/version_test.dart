import 'package:appimage_manager/src/services/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('compara partes numéricas', () {
      expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('2.0', '2.0.0'), 0);
      expect(compareVersions('v1.2.3', '1.2.4'), lessThan(0));
    });

    test('versão final é maior que pré-lançamento', () {
      expect(compareVersions('1.0.0', '1.0.0-beta.2'), greaterThan(0));
      expect(compareVersions('1.0.0-beta.10', '1.0.0-beta.2'), greaterThan(0));
      expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
    });

    test('retorna null quando não há número', () {
      expect(compareVersions('nightly', '1.0'), isNull);
    });
  });

  group('isNewerVersion', () {
    test('usa comparação semântica', () {
      expect(isNewerVersion('v1.5.4', '1.5.3'), isTrue);
      expect(isNewerVersion('1.5.3', '1.5.3'), isFalse);
      expect(isNewerVersion('1.4.0', '1.5.3'), isFalse);
    });

    test('sem versão comparável considera diferença como novidade', () {
      expect(isNewerVersion('nightly', 'continuous'), isTrue);
      expect(isNewerVersion('nightly', 'nightly'), isFalse);
    });
  });

  test('normalizeVersion remove prefixos da tag', () {
    expect(normalizeVersion('v2.3.1'), '2.3.1');
    expect(normalizeVersion('release-1.0.0-rc.1'), '1.0.0-rc.1');
    expect(normalizeVersion('continuous'), 'continuous');
  });
}
