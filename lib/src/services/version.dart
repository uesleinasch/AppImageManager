final _versionPattern = RegExp(
  r'(\d+(?:\.\d+)*)(?:[-~]([0-9A-Za-z.\-]+))?(?:\+[0-9A-Za-z.\-]+)?',
);

class _ParsedVersion {
  _ParsedVersion(this.core, this.preRelease);

  final List<int> core;
  final List<String> preRelease;
}

_ParsedVersion? _parse(String input) {
  final match = _versionPattern.firstMatch(input.trim());
  if (match == null) return null;
  final core = match.group(1)!.split('.').map(int.parse).toList();
  final pre = match.group(2);
  return _ParsedVersion(
    core,
    pre == null || pre.isEmpty ? const [] : pre.split('.'),
  );
}

String normalizeVersion(String tagOrVersion) {
  final trimmed = tagOrVersion.trim();
  final match = _versionPattern.firstMatch(trimmed);
  return match?.group(0) ?? trimmed;
}

int? compareVersions(String a, String b) {
  final left = _parse(a);
  final right = _parse(b);
  if (left == null || right == null) return null;

  final length = left.core.length > right.core.length
      ? left.core.length
      : right.core.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.core.length ? left.core[i] : 0;
    final r = i < right.core.length ? right.core[i] : 0;
    if (l != r) return l.compareTo(r);
  }

  if (left.preRelease.isEmpty && right.preRelease.isEmpty) return 0;
  if (left.preRelease.isEmpty) return 1;
  if (right.preRelease.isEmpty) return -1;

  final preLength = left.preRelease.length > right.preRelease.length
      ? left.preRelease.length
      : right.preRelease.length;
  for (var i = 0; i < preLength; i++) {
    if (i >= left.preRelease.length) return -1;
    if (i >= right.preRelease.length) return 1;
    final l = left.preRelease[i];
    final r = right.preRelease[i];
    final ln = int.tryParse(l);
    final rn = int.tryParse(r);
    final int result;
    if (ln != null && rn != null) {
      result = ln.compareTo(rn);
    } else if (ln != null) {
      result = -1;
    } else if (rn != null) {
      result = 1;
    } else {
      result = l.compareTo(r);
    }
    if (result != 0) return result;
  }
  return 0;
}

bool isNewerVersion(String candidate, String current) {
  final result = compareVersions(candidate, current);
  if (result == null) return candidate.trim() != current.trim();
  return result > 0;
}
